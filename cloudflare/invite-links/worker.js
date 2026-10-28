const APP_IDS = [
  "55Z24S2H7V.com.lizandramalta.familyroutine",
  "55Z24S2H7V.com.lizandramalta.mutua",
];

const association = JSON.stringify({
  applinks: {
    details: [
      {
        appIDs: APP_IDS,
        components: [{ "/": "/invite/*" }],
      },
    ],
  },
});

const invitationPage = `<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow, noarchive">
  <title>Convite | Mutua</title>
  <style>
    :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #f7f5f0; color: #202b28; }
    main { box-sizing: border-box; width: min(100%, 32rem); padding: 2rem; }
    h1 { font-size: 1.75rem; line-height: 1.2; }
    p { line-height: 1.55; }
  </style>
</head>
<body>
  <main>
    <h1>Abra o convite no app Mutua</h1>
    <p>Se o app já está instalado, abra este mesmo link no seu iPhone ou iPad.</p>
    <p>Se ainda não está instalado, obtenha a versão do app com quem enviou o convite e depois abra o link novamente. Quando estiver disponível na App Store, você também poderá instalá-lo por lá.</p>
    <p>A senha enviada com o convite será solicitada dentro do app.</p>
  </main>
</body>
</html>`;

addEventListener("fetch", (event) => {
  event.respondWith(handleRequest(event.request));
});

function handleRequest(request) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response(null, { status: 405, headers: { Allow: "GET, HEAD" } });
  }

  const pathname = new URL(request.url).pathname;
  if (pathname === "/.well-known/apple-app-site-association") {
    return new Response(request.method === "HEAD" ? null : association, {
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=3600",
      },
    });
  }

  if (/^\/invite\/[A-Za-z0-9_-]{1,256}$/.test(pathname)) {
    return new Response(request.method === "HEAD" ? null : invitationPage, {
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
        "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'",
        "X-Content-Type-Options": "nosniff",
      },
    });
  }

  return new Response(null, {
    status: 404,
    headers: { "Cache-Control": "no-store" },
  });
}
