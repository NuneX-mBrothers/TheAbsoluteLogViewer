/* Ambient constellation network — drifting nodes linked by proximity lines,
   reactive to the cursor. On-brand "flowing data" backdrop.
   Lightweight: capped node count, distance-squared checks, DPR-aware,
   pauses when the tab is hidden, disabled under reduced-motion. */
(function () {
  "use strict";
  var canvas = document.getElementById("bg-canvas");
  if (!canvas) return;
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  var ctx = canvas.getContext("2d");
  var DPR = Math.min(window.devicePixelRatio || 1, 2);
  var W = 0, H = 0, nodes = [], mouse = { x: -9999, y: -9999 }, raf = 0, running = true;

  function size() {
    W = window.innerWidth; H = window.innerHeight;
    canvas.style.width = W + "px"; canvas.style.height = H + "px";
    canvas.width = Math.floor(W * DPR); canvas.height = Math.floor(H * DPR);
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    var target = Math.min(120, Math.round((W * H) / 13000));
    nodes = [];
    for (var i = 0; i < target; i++) {
      nodes.push({
        x: Math.random() * W, y: Math.random() * H,
        vx: (Math.random() - 0.5) * 0.42, vy: (Math.random() - 0.5) * 0.42,
        r: Math.random() * 1.6 + 1.0
      });
    }
  }

  var LINK = 155, LINK2 = LINK * LINK, PULL = 190, PULL2 = PULL * PULL;

  function step() {
    if (!running) return;
    ctx.clearRect(0, 0, W, H);

    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      n.x += n.vx; n.y += n.vy;
      if (n.x < -10) n.x = W + 10; else if (n.x > W + 10) n.x = -10;
      if (n.y < -10) n.y = H + 10; else if (n.y > H + 10) n.y = -10;

      var mdx = n.x - mouse.x, mdy = n.y - mouse.y, md2 = mdx * mdx + mdy * mdy;
      if (md2 < PULL2) {
        var f = (1 - md2 / PULL2) * 0.9, dd = Math.sqrt(md2) + 0.01;
        n.x += (mdx / dd) * f; n.y += (mdy / dd) * f;
      }

      for (var j = i + 1; j < nodes.length; j++) {
        var m = nodes[j], dx = n.x - m.x, dy = n.y - m.y, d2 = dx * dx + dy * dy;
        if (d2 < LINK2) {
          var a = (1 - d2 / LINK2);
          ctx.strokeStyle = "rgba(0,230,118," + (a * 0.55).toFixed(3) + ")";
          ctx.lineWidth = a * 1.3;
          ctx.beginPath(); ctx.moveTo(n.x, n.y); ctx.lineTo(m.x, m.y); ctx.stroke();
        }
      }
    }

    for (var k = 0; k < nodes.length; k++) {
      var p = nodes[k];
      var mx = p.x - mouse.x, my = p.y - mouse.y, near = (mx * mx + my * my) < PULL2;
      if (near) {
        ctx.fillStyle = "rgba(94,234,212,.95)";
        ctx.shadowColor = "rgba(0,230,118,.9)"; ctx.shadowBlur = 8;
      } else {
        ctx.fillStyle = "rgba(0,230,118,.75)";
        ctx.shadowColor = "rgba(0,230,118,.5)"; ctx.shadowBlur = 4;
      }
      ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 6.2832); ctx.fill();
    }
    ctx.shadowBlur = 0;
    raf = requestAnimationFrame(step);
  }

  window.addEventListener("resize", size, { passive: true });
  window.addEventListener("mousemove", function (e) { mouse.x = e.clientX; mouse.y = e.clientY; }, { passive: true });
  window.addEventListener("mouseout", function () { mouse.x = mouse.y = -9999; }, { passive: true });
  document.addEventListener("visibilitychange", function () {
    running = !document.hidden;
    if (running) { cancelAnimationFrame(raf); raf = requestAnimationFrame(step); }
  });

  size();
  raf = requestAnimationFrame(step);
})();
