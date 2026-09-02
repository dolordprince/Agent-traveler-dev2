/*! coi-serviceworker - Permanent iframe patch for WebContainers */
if ("undefined" === typeof window) {
  self.addEventListener("install", () => self.skipWaiting());
  self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
  self.addEventListener("fetch", (e) => {
    if (e.request.cache === "only-if-cached" && e.request.mode !== "same-origin") return;
    e.respondWith(
      fetch(e.request).then((res) => {
        if (res.status === 0) return res;
        const h = new Headers(res.headers);
        h.set("Cross-Origin-Embedder-Policy", "credentialless");
        h.set("Cross-Origin-Opener-Policy", "same-origin");
        return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
      }).catch(() => fetch(e.request))
    );
  });
} else {
  (() => {
    if (!window.crossOriginIsolated) {
      navigator.serviceWorker.register('./coi-serviceworker.js').then((reg) => {
        reg.addEventListener("updatefound", () => window.location.reload());
        if (reg.active && !navigator.serviceWorker.controller) {
          window.location.reload();
        }
      });
    }
  })();
}
