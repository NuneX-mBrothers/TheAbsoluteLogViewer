/* The Absolute LogViewer — site behaviours
   live-tail demo · i18n · scroll reveal · lightbox · Chrome notice · downloads */
(function () {
  "use strict";

  // Version badge: on the built site the build replaces __VERSION__; in a local
  // file:// preview it is still the placeholder, so show a friendly fallback.
  var _vb = document.querySelector(".ver-badge");
  if (_vb && _vb.textContent.indexOf("__VERSION__") >= 0) _vb.textContent = "v1.5.1.6";

  /* ──────────────────────────────────────────────────────────
     1) Live-tail terminal demo (mirrors what the app does)
     ────────────────────────────────────────────────────────── */
  var T = document.getElementById("term");
  if (T) {
    var n = 1432, i = 4, paused = false;
    var ts = function () {
      var base = 10 * 3600 + 23 * 60;
      var s = base + n * 2;
      var hh = String(Math.floor(s / 3600) % 24).padStart(2, "0");
      var mm = String(Math.floor(s / 60) % 60).padStart(2, "0");
      var ss = String(s % 60).padStart(2, "0");
      return hh + ":" + mm + ":" + ss + "." + String(100 + ((n * 137) % 900));
    };
    var S = [
      { c: "t-info", l: "INFO ", t: 'request <span class="word">GET</span> /api/v2/orders → 200 in 42ms' },
      { c: "t-ok", l: "OK   ", t: 'cache warmed · <span class="b-ok">12480</span> keys · hit-rate 98.2%' },
      { c: "t-info", l: "INFO ", t: 'worker thread-07 picked job #<span class="word">88231</span>' },
      { c: "t-warn", l: "WARN ", t: 'slow query 812ms on table <span class="word">orders</span> — consider index' },
      { c: "t-info", l: "INFO ", t: 'user 0x4F2A authenticated from 10.0.<span class="word">12</span>.88' },
      { c: "t-err", l: "ERROR", t: '<span class="b-err">NullReferenceException</span> at Core.Pricing.Resolve()' },
      { c: "t-dim", l: "DEBUG", t: "gc gen2 pause 3.1ms · heap 214MB" },
      { c: "t-info", l: "INFO ", t: "flushed 1,024 events to sink in 8ms" },
      { c: "t-warn", l: "WARN ", t: 'retry 2/3 connecting to <span class="word">redis</span>:6379' },
      { c: "t-ok", l: "OK   ", t: 'deploy <span class="b-ok">v1.5.1.6</span> healthy · 3 nodes green' },
      { c: "t-err", l: "ERROR", t: 'timeout after 30s — <span class="b-err">upstream unavailable</span>' },
      { c: "t-info", l: "INFO ", t: "checkpoint written · offset 4_817_002" }
    ];
    var cursor = document.createElement("div");
    cursor.className = "row";
    var add = function () {
      var s = S[i % S.length]; i++; n++;
      var row = document.createElement("div");
      row.className = "row";
      row.innerHTML = '<span class="ln">' + n + '</span><span><span class="lvl ' + s.c + '">' +
        s.l + '</span> <span class="t-dim">' + ts() + "</span> " + s.t + "</span>";
      T.insertBefore(row, cursor);
      var rows = T.querySelectorAll(".row");
      if (rows.length > 14) rows[0].remove();
      T.scrollTop = T.scrollHeight;
    };
    cursor.innerHTML = '<span class="ln"></span><span><span class="cursor"></span></span>';
    T.appendChild(cursor);
    for (var k = 0; k < 12; k++) add();
    T.scrollTop = T.scrollHeight;
    setInterval(function () { if (!paused) add(); }, 1150);
    T.addEventListener("mouseenter", function () { paused = true; });
    T.addEventListener("mouseleave", function () { paused = false; });
  }

  /* ──────────────────────────────────────────────────────────
     2) i18n — dictionaries registered on window.I18N (loaded as
        plain <script> so it also works from file:// previews)
     ────────────────────────────────────────────────────────── */
  var DICT = window.I18N || {};
  var SUPPORTED = ["en", "pt", "de", "zh"];
  var KEY = "talv.lang";

  function pickLang() {
    var saved = null;
    try { saved = localStorage.getItem(KEY); } catch (e) {}
    if (saved && SUPPORTED.indexOf(saved) >= 0) return saved;
    var nav = (navigator.language || "en").slice(0, 2).toLowerCase();
    return SUPPORTED.indexOf(nav) >= 0 ? nav : "en";
  }

  function applyLang(lang) {
    var d = DICT[lang] || DICT.en || {};
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var v = d[el.getAttribute("data-i18n")];
      if (v != null) el.textContent = v;
    });
    document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
      var v = d[el.getAttribute("data-i18n-html")];
      if (v != null) el.innerHTML = v;
    });
    if (d["meta.title"]) document.title = d["meta.title"];
    if (d["meta.desc"]) {
      var m = document.querySelector('meta[name="description"]');
      if (m) m.setAttribute("content", d["meta.desc"]);
    }
    document.documentElement.lang = lang;
    document.querySelectorAll(".lang-btn").forEach(function (b) {
      b.setAttribute("aria-pressed", b.getAttribute("data-lang") === lang ? "true" : "false");
    });
    try { localStorage.setItem(KEY, lang); } catch (e) {}
  }

  document.querySelectorAll(".lang-btn").forEach(function (b) {
    b.addEventListener("click", function () { applyLang(b.getAttribute("data-lang")); });
  });
  applyLang(pickLang());

  /* ──────────────────────────────────────────────────────────
     3) Scroll reveal
     ────────────────────────────────────────────────────────── */
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } });
    }, { threshold: 0.12 });
    document.querySelectorAll(".reveal").forEach(function (el) { io.observe(el); });
  } else {
    document.querySelectorAll(".reveal").forEach(function (el) { el.classList.add("in"); });
  }

  /* ──────────────────────────────────────────────────────────
     4) Lightbox (gallery) — keyboard accessible, focus restored
     ────────────────────────────────────────────────────────── */
  var lb = document.getElementById("lightbox");
  if (lb) {
    var lbImg = lb.querySelector("img"), lbClose = lb.querySelector(".lb-close"), opener = null;
    function openLb(src, alt) {
      opener = document.activeElement;
      lbImg.src = src; lbImg.alt = alt || "";
      lb.classList.add("open"); lbClose.focus();
    }
    function closeLb() {
      lb.classList.remove("open"); lbImg.src = "";
      if (opener && opener.focus) opener.focus();
    }
    document.querySelectorAll(".shot").forEach(function (s) {
      var img = s.querySelector("img");
      var go = function () { openLb(img.getAttribute("data-full") || img.src, img.alt); };
      s.addEventListener("click", go);
      s.addEventListener("keydown", function (e) {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); go(); }
      });
    });
    lbClose.addEventListener("click", closeLb);
    lb.addEventListener("click", function (e) { if (e.target === lb) closeLb(); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape" && lb.classList.contains("open")) closeLb(); });
  }

  /* ──────────────────────────────────────────────────────────
     5) Chrome notice (ClickOnce needs Edge) — discreet, only the
        small note in the install card, never the hero CTA.
     ────────────────────────────────────────────────────────── */
  var ua = navigator.userAgent;
  var isChrome = /Chrome/.test(ua) && !/Edg|OPR|Brave/.test(ua) && !!window.chrome;
  if (isChrome) {
    var note = document.getElementById("chromeNote");
    if (note) note.style.display = "block";
  }

  /* ──────────────────────────────────────────────────────────
     6) Downloads counter (GitHub Releases API) — cached, silent
     ────────────────────────────────────────────────────────── */
  (function () {
    var box = document.getElementById("dl-counter");
    var elT = document.getElementById("dl-total"),
        elS = document.getElementById("dl-standalone"),
        elP = document.getElementById("dl-portable");
    if (!box || !elT) return;
    var CK = "talv.dl", now = Date.now();
    function show(t, s, p) {
      elT.textContent = Number(t).toLocaleString();
      if (elS) elS.textContent = Number(s).toLocaleString();
      if (elP) elP.textContent = Number(p).toLocaleString();
      box.style.display = "flex";
    }
    try {
      var c = JSON.parse(sessionStorage.getItem(CK) || "null");
      if (c && typeof c.sa === "number" && now - c.ts < 300000) { show(c.tot, c.sa, c.por); return; }
    } catch (e) {}
    var run = function () {
      fetch("https://api.github.com/repos/NuneX-mBrothers/TheAbsoluteLogViewer/releases")
        .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
        .then(function (rel) {
          var t = 0, s = 0, p = 0;
          rel.forEach(function (rl) {
            (rl.assets || []).forEach(function (a) {
              var dc = a.download_count || 0; t += dc;
              if (/portable/i.test(a.name)) p += dc; else s += dc;
            });
          });
          if (t > 0) { show(t, s, p); try { sessionStorage.setItem(CK, JSON.stringify({ tot: t, sa: s, por: p, ts: now })); } catch (e) {} }
        })
        .catch(function () {});
    };
    if (window.requestIdleCallback) requestIdleCallback(run); else setTimeout(run, 1200);
  })();

  /* ──────────────────────────────────────────────────────────
     7) Download analytics (GoatCounter events, cookieless)
        Conta cliques por tipo de edicao. O count.js e carregado no
        fim do index.html e expoe window.goatcounter.count().
        Paths prefixados com /logviewer/ porque a conta GoatCounter e
        partilhada com os outros produtos mBrothers (evita colidir com
        os /download/* deles). So aparece no dashboard; nao e mostrado.
     ────────────────────────────────────────────────────────── */
  (function () {
    var MAP = [
      { sel: 'a[href$="LogViewer.application"]', path: "/logviewer/download/clickonce",     title: "Download ClickOnce" },
      { sel: 'a[href$="/LogViewer.exe"]',        path: "/logviewer/download/standalone",    title: "Download Standalone" },
      { sel: 'a[href$="/LogViewer.zip"]',        path: "/logviewer/download/standalone-zip", title: "Download Standalone ZIP" },
      { sel: 'a[href$="LogViewerPortable.exe"]', path: "/logviewer/download/portable",      title: "Download Portable" },
      { sel: 'a[href$="LogViewerPortable.zip"]', path: "/logviewer/download/portable-zip",  title: "Download Portable ZIP" }
    ];
    MAP.forEach(function (m) {
      document.querySelectorAll(m.sel).forEach(function (a) {
        a.addEventListener("click", function () {
          if (window.goatcounter && window.goatcounter.count) {
            window.goatcounter.count({ path: m.path, title: m.title, event: true });
          }
        });
      });
    });
  })();
})();
