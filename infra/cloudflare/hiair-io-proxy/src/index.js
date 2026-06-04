export default {
  async fetch(request) {
    const url = new URL(request.url);
    const target = new URL(url.pathname + url.search, "https://hiair-web.pages.dev");
    return fetch(new Request(target, request));
  },
};
