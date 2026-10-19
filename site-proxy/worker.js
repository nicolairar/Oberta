// Serves charliemobile.dev/oberta* from the Obertà Pages project.
export default {
  async fetch(request) {
    const url = new URL(request.url);
    // Senza la barra finale i percorsi relativi (style.css, img/) finirebbero
    // alla radice del sito: si rimanda a /oberta/.
    if (url.pathname === '/oberta') {
      url.pathname = '/oberta/';
      return Response.redirect(url.toString(), 301);
    }
    const target = new URL(url.pathname + url.search, 'https://oberta.pages.dev');
    const response = await fetch(new Request(target, request), { redirect: 'manual' });
    const location = response.headers.get('location');
    if (!location) return response;
    const headers = new Headers(response.headers);
    headers.set('location', location.replace('https://oberta.pages.dev', `https://${url.host}`));
    return new Response(response.body, { status: response.status, headers });
  },
};
