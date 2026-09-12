# -*- coding: utf-8 -*-
"""Gera as páginas por idioma do site do LogViewer.

    /            inglês, a raiz
    /pt/ /fr/ /es/ /de/ /zh/ /zh-tw/ /ja/ /ko/ /ru/ /pl/ /it/
                 a MESMA página com o texto já traduzido no HTML (não por
                 JavaScript), com `lang`, título, descrição e canonical
                 próprios, e `hreflang` recíproco entre todas.

⛔ Isto não é conteúdo escrito à mão: é GERADO. Sempre que o texto do site
   mudar, correr outra vez — senão as páginas por idioma ficam para trás.
⛔ E corre DEPOIS da injecção da versão: as páginas são cópias do index.html
   e, geradas antes, anunciavam a versão anterior.

📌 Só gera as línguas cujo dicionário existe em i18n/. Acrescentar uma língua
   é acrescentar o ficheiro — não se mexe aqui.

Corre-se da raiz do LogViewer-dist:  python tools/gerar-linguas.py
Ponto de regresso: a etiqueta `antes-das-urls-por-idioma`.
"""
import datetime
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

# código do dicionário (i18n/<código>.js) → pasta, rótulo no selector,
# hreflang e og:locale. O inglês é a raiz e não tem pasta.
# ⚠ O rótulo é o ENDÓNIMO — é assim que alguém reconhece a sua língua.
LINGUAS = [
    ("en",    "",       "English",    "en",      "en_US"),
    ("pt",    "pt",     "Português",  "pt",      "pt_PT"),
    ("br",    "br",     "Português",  "pt-BR",   "pt_BR"),
    ("es",    "es",     "Español",    "es",      "es_ES"),
    ("fr",    "fr",     "Français",   "fr",      "fr_FR"),
    ("it",    "it",     "Italiano",   "it",      "it_IT"),
    ("de",    "de",     "Deutsch",    "de",      "de_DE"),
    ("pl",    "pl",     "Polski",     "pl",      "pl_PL"),
    ("ru",    "ru",     "Русский",    "ru",      "ru_RU"),
    ("ar",    "ar",     "العربية",     "ar",      "ar_AR"),
    ("hi",    "hi",     "हिन्दी",       "hi",      "hi_IN"),
    ("zh",    "zh",     "中文 (简体)",  "zh-Hans", "zh_CN"),
    ("zh-TW", "zh-tw",  "中文 (繁體)",  "zh-Hant", "zh_TW"),
    ("ja",    "ja",     "日本語",      "ja",      "ja_JP"),
    ("ko",    "ko",     "한국어",      "ko",      "ko_KR"),
]

# ⚠ O `pt` fica em `pt` GENÉRICO e o Brasil em `pt-BR`, de propósito: assim o
#   Brasil vai ao /br/ e Angola, Moçambique e Portugal vão ao /pt/. Se o /pt/
#   fosse `pt-PT`, os outros países lusófonos caíam no x-default, que é inglês.

# As línguas que se leem da direita para a esquerda. Só muda o `dir` do <html>
# e liga o bloco de CSS [dir="rtl"] — o resto da página é o mesmo.
RTL = {"ar"}


def existe(cod):
    return os.path.exists(os.path.join(RAIZ, "i18n", cod + ".js"))


def dicionario(cod):
    """O dicionário vem do próprio ficheiro .js, lido pelo node — assim não há
    um segundo parser a inventar o que o site lê de verdade."""
    js = ("global.window={I18N:{}};require(%s);"
          "process.stdout.write(JSON.stringify(window.I18N[%s]||null));"
          % (json.dumps(os.path.join(RAIZ, "i18n", cod + ".js").replace("\\", "/")),
             json.dumps(cod)))
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0 or not r.stdout or r.stdout.strip() == "null":
        sys.exit("⛔ não consegui ler o dicionário %s: %s" % (cod, (r.stderr or r.stdout).strip()[:200]))
    return json.loads(r.stdout)


def traduzir(pagina, d, cod):
    faltas, feitas = [], 0

    def troca(m, escapar):
        nonlocal feitas
        abre, chave, fecha = m.group(1), m.group(3), m.group(5)
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
    if faltas:
        sys.exit("⛔ [%s] chaves sem tradução: %s" % (cod, sorted(set(faltas))[:8]))
    return pagina, feitas


def prefixar(pagina):
    """Numa subpasta, os caminhos relativos passam a ../ — menos as âncoras,
    o mailto: e tudo o que já é absoluto.
    ⛔ `../` e `./` ficam como estão: são os do selector de línguas, que já vem
       escrito relativo à pasta certa."""
    def f(m):
        v = m.group(2)
        if re.match(r'^(https?:|//|#|mailto:|data:|/|\.\./|\./)', v):
            return m.group(0)
        return m.group(1) + "../" + v + m.group(3)
    return re.sub(r'(\s(?:src|href|data-full)=")([^"]+)(")', f, pagina)


def url_de(pasta):
    return BASE + (pasta + "/" if pasta else "")


def bloco_hreflang(activas):
    l = ['  <link rel="alternate" hreflang="x-default" href="%s" />' % BASE]
    for cod, pasta, _rot, hl, _loc in activas:
        l.append('  <link rel="alternate" hreflang="%s" href="%s" />' % (hl, url_de(pasta)))
    return "\n".join(l)


# ── A BARRA DA APP, espelhada no site ───────────────────────────────────────
# Decisão do João (12/09): o selector mostra **as 16 línguas que existem dentro
# das apps**, pela ordem da barra da app, mesmo que algumas levem à mesma
# página. E é igual nos dois sites: mesmas bandeiras, mesma ordem, mesma
# disposição.
#   (bandeira, endónimo, código da língua do site ou None)
# ⚠ Sem marcador de variante no nome: a bandeira já o diz — é a regra que o
#   ExplorerFocus já tinha escrita para a grelha das 16.
# ⚠ Emoji de bandeira NÃO: o Windows não tem glifos para elas e sai um par de
#   letras numa caixa — exactamente no único sistema que nos importa.
BARRA_DA_APP = [
    ("pt", "Português",   "pt"),
    ("br", "Português",   "br"),
    ("gb", "English",     "en"),
    ("us", "English",     "en"),      # a única que ainda leva à mesma página
    ("es", "Español",     "es"),
    ("fr", "Français",    "fr"),
    ("it", "Italiano",    "it"),
    ("de", "Deutsch",     "de"),
    ("pl", "Polski",      "pl"),
    ("ru", "Русский",     "ru"),
    ("sa", "العربية",      "ar"),
    ("in", "हिन्दी",        "hi"),
    ("cn", "中文 (简体)",   "zh"),
    ("tw", "中文 (繁體)",   "zh-TW"),
    ("jp", "日本語",       "ja"),
    ("kr", "한국어",        "ko"),
]


def bandeira(fl):
    return ('<svg class="lang-fl" viewBox="0 0 20 14" aria-hidden="true"><use href="#fl-%s"/></svg>' % fl)


def selector(activas, pasta_actual, rot_actual):
    """Dezasseis línguas não cabem numa fila de botões: é um menu que abre.
    <details> porque funciona sem JavaScript nenhum, e as ligações ficam no
    HTML — que é o que os motores de busca leem.
    ⚠ Sem `hreflang` nas ligações: quem diz a verdade aos motores é o bloco
      <link rel="alternate"> do cabeçalho. Aqui há entradas que levam à mesma
      página, e um hreflang errado seria um sinal errado."""
    pasta_de = {c: p for c, p, *_ in activas}
    # ⛔ O `lang` da ligação é a etiqueta BCP-47, nunca o código do dicionário
    #    (ver a nota do <html>: o `br` do Brasil é o bretão em BCP-47).
    etiqueta_de = {c: h for c, _p, _r, h, _l in activas}
    para = lambda p: (("../" + p + "/") if p else "../") if pasta_actual else ((p + "/") if p else "./")
    cod_actual = next(c for c, p, *_ in activas if p == pasta_actual)
    fl_actual = next((fl for fl, _r, c in BARRA_DA_APP if c == cod_actual), "us")
    itens = []
    for fl, rot, cod in BARRA_DA_APP:
        destino = pasta_de.get(cod) if cod else ""      # sem página → o inglês
        actual = ' aria-current="true"' if cod == cod_actual and fl == fl_actual else ""
        itens.append('          <a class="lang-btn" href="%s" lang="%s"%s>%s<span>%s</span></a>'
                     % (para(destino), etiqueta_de.get(cod, "en"), actual, bandeira(fl), rot))
    return ('      <details class="lang-picker">\n'
            '        <summary class="lang-cur" title="Language">%s<span>%s</span></summary>\n'
            '        <div class="lang-list">\n%s\n        </div>\n'
            '      </details>\n' % (bandeira(fl_actual), rot_actual, "\n".join(itens)))


def uma_vez(pagina, velho, novo, rot):
    n = pagina.count(velho)
    if n != 1:
        sys.exit("⛔ [%s] «%s…» aparece %d vezes" % (rot, velho[:50], n))
    return pagina.replace(velho, novo)


# ── a página de origem ──────────────────────────────────────────────────────
origem = io.open(os.path.join(RAIZ, "index.html"), encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in origem else "\n"
base_lf = origem.replace("\r\n", "\n")

activas = [l for l in LINGUAS if existe(l[0])]
print("línguas com dicionário: %s" % ", ".join(c for c, *_ in activas))

# o selector (fila de botões antiga OU o menu novo) sai inteiro
m_sel = re.search(r' *<(div|details) class="lang-picker"[^>]*>\n(?:.*?\n)*? *</\1>\n', base_lf)
if not m_sel:
    sys.exit("⛔ não achei o bloco do selector de línguas")
SEL_ANTIGO = m_sel.group(0)

# ⚠ O gerador tem de aceitar a SUA PRÓPRIA saída como entrada: à segunda
#   corrida o cabeçalho já é o novo. O padrão apanha os dois.
m_hl = re.search(r'(?: *<!--(?:(?!-->).)*?-->\n)? *<link rel="alternate" hreflang="x-default"[^>]*/>\n'
                 r'(?: *<link rel="alternate" hreflang="[a-zA-Z-]+"[^>]*/>\n)*', base_lf, re.S)
if not m_hl:
    sys.exit("⛔ não achei o bloco hreflang")
HL_ANTIGO = m_hl.group(0)

COMENTARIO = (
    "  <!-- Uma porta por lingua. Cada pagina tem canonical propria e hreflang\n"
    "       reciproco; o texto vai JA TRADUZIDO no HTML, sem JavaScript.\n"
    "       As pastas por idioma sao GERADAS por tools/gerar-linguas.py -- mexer\n"
    "       no texto do site obriga a correr o gerador outra vez, e os dois .cmd\n"
    "       ja o fazem depois de injectarem a versao.\n"
    "       Regresso: etiqueta antes-das-urls-por-idioma. -->\n")

for cod, pasta, rot, hl, loc in activas:
    d = dicionario(cod)
    pag = base_lf
    url = url_de(pasta)

    if pasta:
        # ⛔ O `lang` do <html> leva a ETIQUETA BCP-47 (`hl`), não o código do
        #    dicionário. Não é cosmético: o código do dicionário do Brasil é
        #    `br`, e `br` em BCP-47 é o BRETÃO. Com `lang="br"` a página dizia
        #    aos motores e aos leitores de ecrã que estava escrita numa língua
        #    da Bretanha. Vale para todos: `zh` → `zh-Hans`, `zh-TW` → `zh-Hant`.
        direccao = ' dir="rtl"' if cod in RTL else ""
        pag = uma_vez(pag, '<html lang="en">',
                      '<html lang="%s"%s data-lang-fixa="%s">' % (hl, direccao, cod), cod)
    pag = uma_vez(pag, HL_ANTIGO, COMENTARIO + bloco_hreflang(activas) + "\n", cod)
    pag = uma_vez(pag, '<link rel="canonical" href="%s" />' % BASE,
                  '<link rel="canonical" href="%s" />' % url, cod)
    pag = uma_vez(pag, '<meta property="og:url" content="%s" />' % BASE,
                  '<meta property="og:url" content="%s" />' % url, cod)

    if pasta:
        pag, feitas = traduzir(pag, d, cod)
        for padrao, valor in [(r'<title>.*?</title>', '<title>%s</title>' % H.escape(d["meta.title"], quote=False)),
                              (r'(<meta name="description" content=")[^"]*(")', None),
                              (r'(<meta property="og:title" content=")[^"]*(")', None),
                              (r'(<meta property="og:description" content=")[^"]*(")', None),
                              (r'(<meta name="twitter:title" content=")[^"]*(")', None),
                              (r'(<meta name="twitter:description" content=")[^"]*(")', None)]:
            if valor is not None:
                pag = re.sub(padrao, lambda _m: valor, pag, count=1, flags=re.S)
            else:
                chave = "meta.title" if "title" in padrao else "meta.desc"
                pag = re.sub(padrao, lambda m: m.group(1) + H.escape(d[chave], quote=True) + m.group(2), pag, count=1)
        pag = uma_vez(pag, '<meta property="og:locale" content="en_US" />',
                      '<meta property="og:locale" content="%s" />' % loc, cod)
        pag = uma_vez(pag, '"url": "%s",' % BASE, '"url": "%s",' % url, cod)

    # os dicionários deixam de ser precisos EM TODAS as páginas: o texto está
    # no HTML e o selector navega. Ficam em i18n/ como fonte do gerador.
    pag = re.sub(r' *<script src="(\.\./)?i18n/[a-zA-Z-]+\.js"></script>\n', "", pag)
    # ⛔ O selector troca-se ANTES do prefixar. Ao contrário, o prefixar mexia
    #    nos href do selector ANTIGO (`pt/` → `../pt/`) e o bloco deixava de
    #    casar à segunda corrida — foi exactamente o que aconteceu.
    #    O selector novo não sofre: o prefixar salta `../` e `./`.
    pag = uma_vez(pag, SEL_ANTIGO, selector(activas, pasta, rot), cod)
    if pasta:
        pag = prefixar(pag)

    destino = os.path.join(RAIZ, pasta, "index.html") if pasta else os.path.join(RAIZ, "index.html")
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    io.open(destino, "w", encoding="utf-8", newline="").write(pag.replace("\n", nl))
    print("✅ %-6s %s" % (pasta + "/" if pasta else "raiz", ("%d textos" % feitas) if pasta else "inglês, sem tradução"))

# ── sitemap ─────────────────────────────────────────────────────────────────
hoje = datetime.date.today().isoformat()
linhas = ['<?xml version="1.0" encoding="UTF-8"?>',
          '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
for cod, pasta, *_ in activas:
    linhas.append('  <url><loc>%s</loc><lastmod>%s</lastmod><changefreq>weekly</changefreq>'
                  '<priority>%s</priority></url>' % (url_de(pasta), hoje, "1.0" if not pasta else "0.8"))
linhas.append("</urlset>")
io.open(os.path.join(RAIZ, "sitemap.xml"), "w", encoding="utf-8", newline="").write(nl.join(linhas) + nl)
print("✅ sitemap.xml · %d endereços · lastmod %s" % (len(activas), hoje))
