export async function onRequestGet({ env }) {
  const object = await env.DOWNLOADS.get("kupifa.dmg");
  if (!object) {
    return new Response("kupifa.dmg is not uploaded yet.", { status: 404 });
  }

  const headers = new Headers();
  headers.set("Content-Type", "application/x-apple-diskimage");
  headers.set("Content-Disposition", 'attachment; filename="kupifa.dmg"');
  headers.set("Cache-Control", "public, max-age=300");
  if (object.size != null) {
    headers.set("Content-Length", String(object.size));
  }

  return new Response(object.body, { headers });
}
