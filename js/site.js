/* The Absolute LogViewer — site behaviours
   live-tail demo · i18n · scroll reveal · lightbox · Chrome notice · downloads */
(function () {
  "use strict";

  // NOTA (2026-08-18): o site deixou de ser gerado a partir de uma cópia em
  // docs/ — esta pasta É a fonte e o que fica publicado, como no ExplorerFocus.
  // Por isso o index.html já traz a versão real escrita, e o publish limita-se a
  // reescrever a anterior. Não voltar a pôr aqui um fallback para "__VERSION__":
  // o marcador deixou de existir, e um fallback escondia um publish que falhasse
  // a reescrita, deixando o número errado no site sem ninguém dar por isso.

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
     2) Selector de linguas — so o comportamento do menu.
        O i18n do lado do cliente SAIU daqui: cada lingua tem a sua
        pagina, com o texto ja no HTML, e o selector e uma lista de
        ligacoes dentro de um <details>. Os dicionarios continuam em
        i18n/*.js, mas como FONTE do gerador, nao para o browser.
     ────────────────────────────────────────────────────────── */
  var menu = document.querySelector("details.lang-picker");
  if (menu) {
    document.addEventListener("click", function (e) {
      if (menu.open && !menu.contains(e.target)) menu.open = false;
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && menu.open) { menu.open = false; menu.querySelector("summary").focus(); }
    });
  }

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
     6b) Fora do Windows (Android, iPhone, iPad, Mac, Linux): o
        LogViewer é um programa para Windows (2026-10-08, o mesmo do
        ExplorerFocus). Mostra o aviso por baixo dos botões e, no clique
        em descarregar, pergunta («… Descarregar na mesma?»). Quem
        confirma segue (há quem passe o ficheiro depois para o
        computador); quem cancela não descarrega nem conta como descarga.
        Escuta na fase de captura, para correr antes do contador da 7.
     ────────────────────────────────────────────────────────── */
  (function () {
    var n = document.getElementById("osNote");
    if (!n || /Windows/i.test(navigator.userAgent || "")) return;
    n.hidden = false;
    var ask = document.getElementById("osAsk");
    var pergunta = n.textContent.trim() + "\n\n" + (ask ? ask.textContent.trim() : "");
    var SEL = 'a[href$="LogViewer.application"], a[href$="/LogViewer.exe"], a[href$="/LogViewer.zip"], ' +
              'a[href$="LogViewerPortable.exe"], a[href$="LogViewerPortable.zip"]';
    document.querySelectorAll(SEL).forEach(function (a) {
      a.addEventListener("click", function (e) {
        if (window.confirm(pergunta)) return;
        e.preventDefault();
        e.stopImmediatePropagation();
      }, true);
    });
  })();

  /* ──────────────────────────────────────────────────────────
     8) «Envie a um amigo» (30/09) — o mesmo do ExplorerFocus.
        Monta as ligações a partir dos textos da página (cada língua traz
        os seus) e do endereço canónico (a página na língua de quem
        partilha). ?ref=<canal> marca a ligação partilhada (desde 06/11 as
        visitas contam-se no servidor). «Outro…» abre a partilha do
        sistema; sem ela, copia a ligação; se copiar falhar, MOSTRA-A.
     ────────────────────────────────────────────────────────── */
  (function () {
    var box = document.querySelector(".foot-share");
    if (!box) return;
    function txt(k) { var el = box.querySelector('[data-i18n="' + k + '"]'); return el ? el.textContent.trim() : ""; }
    var canon = document.querySelector('link[rel="canonical"]');
    var base = canon ? canon.href : location.origin + location.pathname;
    function link(ref) { return base + (base.indexOf("?") < 0 ? "?" : "&") + "ref=" + ref; }
    var msg = txt("share.msg"), subj = txt("share.subject");
    var hrefs = {
      x: "https://twitter.com/intent/tweet?text=" + encodeURIComponent(msg) + "&url=" + encodeURIComponent(link("x")),
      whatsapp: "https://wa.me/?text=" + encodeURIComponent(msg + " " + link("wa")),
      email: "mailto:?subject=" + encodeURIComponent(subj) + "&body=" + encodeURIComponent(msg + "\n" + link("mail"))
    };
    box.querySelectorAll("[data-share]").forEach(function (a) {
      var ch = a.getAttribute("data-share");
      if (hrefs[ch]) a.href = hrefs[ch];
      if (ch === "other" && !navigator.share) a.textContent = txt("share.copy");
      a.addEventListener("click", function (e) {
        if (ch !== "other") return;
        e.preventDefault();
        var url = link("share");
        if (navigator.share) { navigator.share({ title: subj, text: msg, url: url }).catch(function () {}); return; }
        var texto = msg + " " + url;
        function antigo() {
          var ta = document.createElement("textarea"); ta.value = texto; ta.setAttribute("readonly", "");
          ta.style.position = "fixed"; ta.style.opacity = "0"; document.body.appendChild(ta); ta.select();
          var ok = false; try { ok = document.execCommand("copy"); } catch (err) {}
          document.body.removeChild(ta); return ok;
        }
        var copia = (navigator.clipboard && navigator.clipboard.writeText)
          ? navigator.clipboard.writeText(texto).then(function () { return true; }, antigo)
          : Promise.resolve(antigo());
        copia.then(function (ok) {
          if (!ok) { window.prompt(txt("share.copy"), texto); return; }
          a.textContent = txt("share.copied");
          setTimeout(function () { a.textContent = txt("share.copy"); }, 2000);
        });
      });
    });
  })();
})();

/* O topo: as fotografias reais passam a cada 5 s (14/11/2026). Com o rato em cima param; com «reduzir o movimento»
   no sistema, não passam sozinhas: só pelos pontos. */
(function () {
  var box = document.getElementById("heroShots");
  if (!box) return;
  var imgs = box.querySelectorAll(".frame img"), dots = box.querySelectorAll(".dots button"), i = 0, paused = false;
  function show(k) {
    imgs[i].classList.remove("on"); dots[i].classList.remove("on");
    i = (k + imgs.length) % imgs.length;
    imgs[i].classList.add("on"); dots[i].classList.add("on");
  }
  dots.forEach(function (d, k) { d.addEventListener("click", function () { show(k); }); });
  box.addEventListener("mouseenter", function () { paused = true; });
  box.addEventListener("mouseleave", function () { paused = false; });
  var calmo = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!calmo) setInterval(function () { if (!paused && !document.hidden) show(i + 1); }, 5000);
})();

