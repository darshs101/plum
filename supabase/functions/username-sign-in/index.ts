// Server-only username resolution; emails and service credentials never leave the server.
// Deploy with gateway verify_jwt=false: successful password validation returns a normal session.
Deno.serve(async request => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405, headers: { "Cache-Control": "no-store" } });
  const invalid = () => Response.json({ message: "Invalid username or password." }, { status: 401, headers: { "Cache-Control": "no-store" } });
  try {
    const { username, password } = await request.json();
    if (typeof username !== "string" || !/^[a-z0-9_]{3,30}$/.test(username) || typeof password !== "string" || password.length > 4096) return invalid();
    const base = Deno.env.get("SUPABASE_URL")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const serverHeaders = { apikey: service, Authorization: `Bearer ${service}` };
    const hash = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))), byte => byte.toString(16).padStart(2, "0")).join("");
    const ip = request.headers.get("cf-connecting-ip") ?? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const limit = await fetch(`${base}/rest/v1/rpc/check_username_sign_in_limit`, {
      method: "POST", headers: { ...serverHeaders, "Content-Type": "application/json" },
      body: JSON.stringify({ ip_hash: await hash(ip), username_hash: await hash(username) }),
    });
    if (!limit.ok) return new Response("Sign-in temporarily unavailable.", { status: 503, headers: { "Cache-Control": "no-store" } });
    if (await limit.json() !== true) return Response.json({ message: "Too many sign-in attempts. Try again later." }, { status: 429, headers: { "Cache-Control": "no-store", "Retry-After": "900" } });
    const profiles = await fetch(`${base}/rest/v1/profiles?username=eq.${encodeURIComponent(username)}&suspended_at=is.null&select=id&limit=1`, { headers: serverHeaders });
    if (!profiles.ok) return invalid();
    const rows = await profiles.json();
    let email = "missing-username@plum.invalid";
    if (rows[0]) {
      const userResponse = await fetch(`${base}/auth/v1/admin/users/${rows[0].id}`, { headers: serverHeaders });
      if (userResponse.ok) email = (await userResponse.json()).email ?? email;
    }
    // GoTrue remains responsible for password validation after the server-side throttle.
    const result = await fetch(`${base}/auth/v1/token?grant_type=password`, { method: "POST", headers: { apikey: Deno.env.get("SUPABASE_ANON_KEY")!, "Content-Type": "application/json" }, body: JSON.stringify({ email, password }) });
    if (!result.ok) return invalid();
    const session = await result.json();
    return Response.json({ access_token: session.access_token, refresh_token: session.refresh_token }, { headers: { "Cache-Control": "no-store" } });
  } catch { return invalid(); }
});
