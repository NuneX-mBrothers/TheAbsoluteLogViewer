# -*- coding: utf-8 -*-
"""Gera as páginas por idioma do site do LogViewer — fase A.

    /            inglês, como sempre. Só ganha o bloco hreflang e o selector
                 de línguas a apontar para os endereços.
    /pt/ /fr/ /es/ /de/ /zh/
                 a MESMA página com o texto já traduzido no HTML (não por
                 JavaScript), com `lang`, título, descrição e canonical
                 próprios, e hreflang recíproco entre todas.

⛔ Isto não é conteúdo escrito à mão: é GERADO. Sempre que o texto do site
   mudar, correr outra vez — senão as páginas por idioma ficam para trás.

Corre-se da raiz do LogViewer-dist:  python tools/gerar-linguas.py
Ponto de regresso: a etiqueta `antes-das-urls-por-idioma`.
"""
import html as H
import io
import json
import os
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = "https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/"
LINGUAS = ["en", "pt", "fr", "es", "de", "zh"]          # en = raiz
ROTULO = {"en": "EN", "pt": "PT", "fr": "FR", "es": "ES", "de": "DE", "zh": "中文"}
LOCALE = {"en": "en_US", "pt": "pt_PT", "fr": "fr_FR", "es": "es_ES", "de": "de_DE", "zh": "zh_CN"}


def dicionario(lg):
    """O dicionário vem do próprio ficheiro .js, lido pelo node — assim não há
    um segundo parser a inventar o que o site lê de verdade."""
    js = ("global.window={I18N:{}};require(%s);"
          "process.stdout.write(JSON.stringify(window.I18N.%s));"
          % (json.dumps(os.path.join(RAIZ, "i18n", lg + ".js").replace("\\", "/")), lg))
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0 or not r.stdout:
        sys.exit("⛔ não consegui ler o dicionário %s: %s" % (lg, r.stderr.strip()[:200]))
    return json.loads(r.stdout)


def traduzir(pagina, d):
    """Substitui o conteúdo de cada elemento com data-i18n / data-i18n-html."""
    faltas, feitas = [], 0

    def troca(m, escapar):
        nonlocal feitas
        abre, tag, chave, _conteudo, fecha = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
        v = d.get(chave)
        if v is None:
            faltas.append(chave)
            return m.group(0)
        feitas += 1
        return abre + (H.escape(v, quote=False) if escapar else v) + fecha

    p_txt = re.compile(r'(<([a-zA-Z][\w-]*)\b[^>]*\bdata-i18n="([^"]+)"[^>]*>)(.*?)(</\2>)', re.S)
    p_htm = re.compile(r'(<([a-zA-Z][\w-]*)\b[^>]*\bdata-i18n-html="([^"]+)"[^>]*>)(.*?)(</\2>)', re.S)
    pagina = p_htm.sub(lambda m: troca(m, False), pagina)
    pagina = p_txt.sub(lambda m: troca(m, True), pagina)
    return pagina, feitas, faltas


def prefixar(pagina):
    """Numa subpasta, os caminhos relativos passam a ../ — menos as âncoras,
    o mailto: e tudo o que já é absoluto."""
    def f(m):
        v = m.group(2)
        # ⛔ `../` e `./` ficam como estão: são os do selector de línguas, que
        #    já vem escrito relativo à pasta certa. Sem isto levavam mais um
        #    `../` e o selector apontava para fora do site.
        if re.match(r'^(https?:|//|#|mailto:|data:|/|\.\./|\./)', v):
            return m.group(0)
        return m.group(1) + "../" + v + m.group(3)
    return re.sub(r'(\s(?:src|href|data-full)=")([^"]+)(")', f, pagina)


def bloco_hreflang(indentar="  "):
    l = [indentar + '<link rel="alternate" hreflang="x-default" href="%s" />' % BASE]
    for lg in LINGUAS:
        url = BASE if lg == "en" else BASE + lg + "/"
        l.append(indentar + '<link rel="alternate" hreflang="%s" href="%s" />' % (lg, url))
    return "\n".join(l)


def selector(lg_actual):
    """O selector passa a LIGAÇÕES: é assim que os endereços se descobrem.
    Da raiz vai-se para `pt/`; de dentro de uma língua, para `../pt/`."""
    saida = []
    for lg in LINGUAS:
        if lg_actual == "en":
            href = "./" if lg == "en" else lg + "/"
        else:
            href = "../" if lg == "en" else "../" + lg + "/"
        actual = ' aria-current="true"' if lg == lg_actual else ""
        saida.append('        <a class="lang-btn" href="%s" hreflang="%s" lang="%s"%s>%s</a>'
                     % (href, lg, lg, actual, ROTULO[lg]))
    return "\n".join(saida)


def uma_vez(pagina, velho, novo, rot):
    if pagina.count(velho) != 1:
        sys.exit("⛔ [%s] «%s…» aparece %d vezes" % (rot, velho[:50], pagina.count(velho)))
    return pagina.replace(velho, novo)


origem = io.open(os.path.join(RAIZ, "index.html"), encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in origem else "\n"
base_lf = origem.replace("\r\n", "\n")

# ── o selector antigo (botões) sai; entram ligações ─────────────────────────
m_sel = re.search(r'( *)<div class="lang-picker"[^>]*>\n(?:.*?\n)*? *</div>\n', base_lf)
if not m_sel:
    sys.exit("⛔ não achei o bloco .lang-picker")
SEL_ANTIGO = m_sel.group(0)
SEL_CABEC = re.match(r'( *<div class="lang-picker"[^>]*>)', SEL_ANTIGO.lstrip("\n")).group(1)

# ── o comentário + hreflang antigos saem; entra o bloco completo ────────────
# ⚠ O gerador tem de aceitar a SUA PRÓPRIA saída como entrada: à segunda
#   corrida o bloco do cabeçalho já é o novo. Por isso o padrão apanha os
#   dois — o comentário antigo («Só x-default») ou o novo, e uma linha de
#   hreflang ou as sete.
m_hl = re.search(r'(?: *<!--(?:(?!-->).)*?-->\n)? *<link rel="alternate" hreflang="x-default"[^>]*/>\n'
                 r'(?: *<link rel="alternate" hreflang="[a-zA-Z-]+"[^>]*/>\n)*', base_lf, re.S)
if not m_hl:
    sys.exit("⛔ não achei o bloco hreflang")
HL_ANTIGO = m_hl.group(0)

COMENTARIO = (
    "  <!-- Uma porta por lingua (fase A, 2026-09-12). Cada pagina tem canonical\n"
    "       propria e hreflang reciproco; o texto vai JA TRADUZIDO no HTML.\n"
    "       As paginas /pt/ /fr/ /es/ /de/ /zh/ sao GERADAS por tools/gerar-linguas.py\n"
    "       -- mexer no texto do site obriga a correr o gerador outra vez.\n"
    "       Regresso: etiqueta antes-das-urls-por-idioma. -->\n")

feito = []
for lg in LINGUAS:
    d = dicionario(lg)
    pag = base_lf
    url = BASE if lg == "en" else BASE + lg + "/"

    # cabeçalho: língua, canonical, hreflang, selector
    if lg == "en":
        pag = uma_vez(pag, '<html lang="en">', '<html lang="en">', lg)
    else:
        pag = uma_vez(pag, '<html lang="en">', '<html lang="%s" data-lang-fixa="%s">' % (lg, lg), lg)
    pag = uma_vez(pag, HL_ANTIGO, COMENTARIO + bloco_hreflang() + "\n", lg)
    pag = uma_vez(pag, SEL_ANTIGO, "      " + SEL_CABEC.strip() + "\n" + selector(lg) + "\n      </div>\n", lg)
    pag = uma_vez(pag, '<link rel="canonical" href="%s" />' % BASE,
                  '<link rel="canonical" href="%s" />' % url, lg)
    pag = uma_vez(pag, '<meta property="og:url" content="%s" />' % BASE,
                  '<meta property="og:url" content="%s" />' % url, lg)

    if lg != "en":
        # texto, meta e JSON-LD na língua
        pag, feitas, faltas = traduzir(pag, d)
        if faltas:
            sys.exit("⛔ [%s] chaves sem tradução: %s" % (lg, sorted(set(faltas))[:8]))
        pag = re.sub(r'<title>.*?</title>', lambda _: '<title>%s</title>' % H.escape(d["meta.title"], quote=False), pag, count=1, flags=re.S)
        pag = re.sub(r'(<meta name="description" content=")[^"]*(")', lambda m: m.group(1) + H.escape(d["meta.desc"], quote=True) + m.group(2), pag, count=1)
        pag = re.sub(r'(<meta property="og:title" content=")[^"]*(")', lambda m: m.group(1) + H.escape(d["meta.title"], quote=True) + m.group(2), pag, count=1)
        pag = re.sub(r'(<meta property="og:description" content=")[^"]*(")', lambda m: m.group(1) + H.escape(d["meta.desc"], quote=True) + m.group(2), pag, count=1)
        pag = re.sub(r'(<meta name="twitter:title" content=")[^"]*(")', lambda m: m.group(1) + H.escape(d["meta.title"], quote=True) + m.group(2), pag, count=1)
        pag = re.sub(r'(<meta name="twitter:description" content=")[^"]*(")', lambda m: m.group(1) + H.escape(d["meta.desc"], quote=True) + m.group(2), pag, count=1)
        pag = uma_vez(pag, '<meta property="og:locale" content="en_US" />',
                      '<meta property="og:locale" content="%s" />' % LOCALE[lg], lg)
        pag = uma_vez(pag, '"url": "%s",' % BASE, '"url": "%s",' % url, lg)
        # os dicionários deixam de ser precisos: o texto já está na página
        pag = re.sub(r' *<script src="i18n/[a-z]{2}\.js"></script>\n', "", pag)
        # e os caminhos relativos passam a ../
        pag = prefixar(pag)
        destino = os.path.join(RAIZ, lg)
        os.makedirs(destino, exist_ok=True)
        destino = os.path.join(destino, "index.html")
        marca = "%s/ · %d textos" % (lg, feitas)
    else:
        destino = os.path.join(RAIZ, "index.html")
        marca = "raiz (inglês) · hreflang + selector"

    io.open(destino, "w", encoding="utf-8", newline="").write(pag.replace("\n", nl))
    feito.append(marca)
    print("✅ %s" % marca)

# ── sitemap com as seis ─────────────────────────────────────────────────────
import datetime
hoje = datetime.date.today().isoformat()
linhas = ['<?xml version="1.0" encoding="UTF-8"?>',
          '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
for lg in LINGUAS:
    url = BASE if lg == "en" else BASE + lg + "/"
    linhas.append('  <url><loc>%s</loc><lastmod>%s</lastmod><changefreq>weekly</changefreq>'
                  '<priority>%s</priority></url>' % (url, hoje, "1.0" if lg == "en" else "0.8"))
linhas.append("</urlset>")
io.open(os.path.join(RAIZ, "sitemap.xml"), "w", encoding="utf-8", newline="").write(nl.join(linhas) + nl)
print("✅ sitemap.xml · %d endereços · lastmod %s" % (len(LINGUAS), hoje))
