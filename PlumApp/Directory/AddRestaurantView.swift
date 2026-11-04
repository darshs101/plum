import SwiftUI
import PhotosUI

struct AddRestaurantView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: (Restaurant) -> Void
    @State private var name = ""
    @State private var address = ""
    @State private var neighborhood = ""
    @State private var cuisine = ""
    @State private var price = 2
    @State private var photo: PhotosPickerItem?
    @State private var originalData: Data?
    @State private var data: Data?
    @State private var working = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("One physical location") {
                    TextField("Restaurant name", text: $name).accessibilityIdentifier("restaurant.name")
                    TextField("Street address, city, state", text: $address).accessibilityIdentifier("restaurant.address")
                    TextField("Neighborhood (optional)", text: $neighborhood)
                    TextField("Cuisine (optional)", text: $cuisine)
                    Picker("Price", selection: $price) { ForEach(1...4, id: \.self) { Text(String(repeating: "$", count: $0)).tag($0) } }
                }
                Section("Location photo (required)") {
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose or change photo", systemImage: "photo") }.accessibilityIdentifier("restaurant.photoPicker")
                    if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180) }
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Add restaurant") { Task { await save() } }.disabled(working || data == nil || name.trimmingCharacters(in: .whitespaces).isEmpty || address.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityIdentifier("restaurant.submit")
                if working { ProgressView("Saving location…") }
            }.navigationTitle("Add restaurant")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) } }
            .task(id: photo) {
                guard let photo else { return }
                do { guard let original = try await photo.loadTransferable(type: Data.self), let jpeg = PhotoProcessing.preview(original) else { throw PlumError.unavailable }; originalData = original; data = jpeg }
                catch { self.error = "Couldn’t load that photo. Please choose another." }
            }
        }
    }
    private func save() async {
        guard let data else { return }; working = true; defer { working = false }
        do {
            let restaurant = try await PlumServices.directory.createRestaurant(.init(name: name.trimmingCharacters(in: .whitespaces), address: address.trimmingCharacters(in: .whitespaces), neighborhood: neighborhood.isEmpty ? nil : neighborhood, cuisine: cuisine.isEmpty ? nil : cuisine, priceLevel: price, photo: .init(id: UUID(), data: data, contentType: "image/jpeg", linkedDishIDs: [], originalData: originalData, originalContentType: photo?.supportedContentTypes.first?.preferredMIMEType)))
            onCreated(restaurant); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
