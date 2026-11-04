import SwiftUI

struct AdminConsoleView: View {
    struct Report: Decodable, Identifiable { let id: UUID; let target_type: String; let target_id: UUID; let reason: String; let status: String }
    struct Audit: Decodable, Identifiable { let id: UUID; let action: String; let target_type: String; let created_at: Date }
    @State private var reports: [Report] = []
    @State private var audit: [Audit] = []
    @State private var error: String?
    @State private var kind = "restaurant"
    @State private var source = ""
    @State private var target = ""
    @State private var name = ""
    @State private var address = ""
    @State private var working = false
    @State private var authorized = false
    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            if authorized {
                Section("Reports") {
                    if reports.isEmpty { Text("No open reports.") }
                    ForEach(reports) { report in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(report.target_type.capitalized) · \(report.status)").font(.headline)
                            Text(report.reason); Text(report.target_id.uuidString).font(.caption).textSelection(.enabled)
                            HStack { Button("Triage") { moderate(report, status: "triaged") }; Button("Dismiss") { moderate(report, status: "dismissed") }; Button(report.target_type == "account" ? "Suspend" : "Remove", role: .destructive) { moderate(report, status: "resolved", remove: true) } }.buttonStyle(.bordered).font(.caption).disabled(working)
                        }
                    }
                }
                Section("Directory curation") {
                    Picker("Record", selection: $kind) { Text("Restaurant").tag("restaurant"); Text("Dish").tag("dish") }
                    TextField("Record / source UUID", text: $source).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Name", text: $name)
                    if kind == "restaurant" { TextField("Address (leave blank to keep)", text: $address) }
                    Button("Save listing edit") { run { guard let id = UUID(uuidString: source) else { return }; struct Edit: Encodable { let record_type: String; let record_uuid: UUID; let new_name: String; let new_address: String? }; _ = try await PlumAPI.client.rpc("admin_edit_directory", params: Edit(record_type: kind, record_uuid: id, new_name: name, new_address: address.isEmpty ? nil : address)).execute(); await load() } }.disabled(working || UUID(uuidString: source) == nil || name.isEmpty)
                    TextField("Surviving record UUID", text: $target).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Merge source into survivor", role: .destructive) { run {
                        guard let from = UUID(uuidString: source), let to = UUID(uuidString: target) else { return }
                        let params = kind == "dish" ? ["source_dish":from.uuidString,"target_dish":to.uuidString] : ["source_restaurant":from.uuidString,"target_restaurant":to.uuidString]
                        _ = try await PlumAPI.client.rpc(kind == "dish" ? "merge_dish" : "merge_restaurant", params: params).execute(); source = ""; await load()
                    } }.disabled(working || UUID(uuidString: source) == nil || UUID(uuidString: target) == nil || source == target)
                }
                Section("Audit history") { ForEach(audit) { action in VStack(alignment: .leading) { Text("\(action.action) · \(action.target_type)"); Text(action.created_at, style: .date).font(.caption) } } }
            } else { Text("This console requires a server-assigned Plum admin role.") }
        }.navigationTitle("Moderation").task { await load() }.refreshable { await load() }
    }
    private func run(_ operation: @escaping @MainActor () async throws -> Void) { working = true; error = nil; Task { defer { working = false }; do { try await operation() } catch { self.error = error.localizedDescription } } }
    private func moderate(_ report: Report, status: String, remove: Bool = false) { run { struct Params: Encodable { let report_uuid: UUID; let next_status: String; let remove_target: Bool }; _ = try await PlumAPI.client.rpc("moderate_report", params: Params(report_uuid: report.id, next_status: status, remove_target: remove)).execute(); await load() } }
    private func load() async { do { authorized = try await PlumAPI.client.auth.session.user.appMetadata["plum_role"] == .string("admin"); guard authorized else { return }; reports = try await PlumAPI.client.from("reports").select().in("status", values: ["open","triaged"]).order("created_at").execute().value; audit = try await PlumAPI.client.from("admin_actions").select("id,action,target_type,created_at").order("created_at", ascending: false).limit(100).execute().value } catch { self.error = error.localizedDescription } }
}
