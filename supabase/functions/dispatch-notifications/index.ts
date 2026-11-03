// Server-only worker. Invoke from a scheduled job using PLUM_PUSH_WORKER_SECRET.
// SUPABASE_SERVICE_ROLE_KEY is provided only by the Edge runtime, never by iOS.
const env = (name: string) => { const value = Deno.env.get(name); if (!value) throw new Error(`Missing server setting: ${name}`); return value; };
const bytes = (text: string) => new TextEncoder().encode(text);
const base64url = (value: Uint8Array) => btoa(String.fromCharCode(...value)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
let cached: { token: string; expires: number } | undefined;
async function apnsToken() {
  if (cached && cached.expires > Date.now()) return cached.token;
  const pem = env("APNS_PRIVATE_KEY").replaceAll("\\n", "\n").replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), c => c.charCodeAt(0)), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = base64url(bytes(JSON.stringify({ alg: "ES256", kid: env("APNS_KEY_ID") })));
  const claims = base64url(bytes(JSON.stringify({ iss: env("APNS_TEAM_ID"), iat: Math.floor(Date.now() / 1000) })));
  const unsigned = `${header}.${claims}`;
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, bytes(unsigned));
  cached = { token: `${unsigned}.${base64url(new Uint8Array(signature))}`, expires: Date.now() + 45 * 60 * 1000 };
  return cached.token;
}
async function database(path: string, method = "GET", body?: unknown) {
  const response = await fetch(`${env("SUPABASE_URL")}/rest/v1/${path}`, {
    method, headers: { apikey: env("SUPABASE_SERVICE_ROLE_KEY"), Authorization: `Bearer ${env("SUPABASE_SERVICE_ROLE_KEY")}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`Database request failed: ${response.status}`);
  return response.status === 204 ? undefined : response.json();
}
const titles: Record<string, string> = { like: "Someone liked your tasting", comment: "New comment on your tasting", reply: "Someone replied to your comment", follow: "You have a new follower", follow_request: "You have a follow request", follow_approval: "Your follow request was approved" };
Deno.serve(async request => {
  try {
    if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
    if (request.headers.get("Authorization") !== `Bearer ${env("PLUM_PUSH_WORKER_SECRET")}`) return new Response("Unauthorized", { status: 401 });
    const pending = await database("notification_outbox?delivered_at=is.null&select=id,notifications(id,recipient_id,kind,post_id)&order=created_at&limit=100");
    let delivered = 0;
    for (const row of pending) {
      const notification = row.notifications;
      if (!notification) continue;
      const devices = await database(`device_tokens?user_id=eq.${notification.recipient_id}&permission_status=in.(authorized,provisional)&select=token`);
      let failed = false;
      for (const device of devices) {
        const response = await fetch(`https://${Deno.env.get("APNS_ENVIRONMENT") === "production" ? "api" : "api.sandbox"}.push.apple.com/3/device/${device.token}`, {
          method: "POST", headers: { authorization: `bearer ${await apnsToken()}`, "apns-topic": env("APNS_BUNDLE_ID"), "apns-push-type": "alert", "apns-priority": "10" },
          body: JSON.stringify({ aps: { alert: { title: "Plum", body: titles[notification.kind] ?? "New activity on Plum" }, sound: "default" }, post_id: notification.post_id, notification_id: notification.id }),
        });
        if (!response.ok) {
          const error = await response.json();
          if (response.status === 410 || error.reason === "BadDeviceToken") await database(`device_tokens?token=eq.${device.token}`, "DELETE");
          else failed = true;
        }
      }
      if (!failed) { await database(`notification_outbox?id=eq.${row.id}`, "PATCH", { delivered_at: new Date().toISOString() }); delivered++; }
    }
    return Response.json({ delivered });
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Notification worker failed");
    return Response.json({ error: "Notification delivery failed; queue retained for retry." }, { status: 500 });
  }
});
