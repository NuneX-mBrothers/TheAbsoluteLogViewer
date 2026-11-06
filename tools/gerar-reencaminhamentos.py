# -*- coding: utf-8 -*-
"""Gera, em docs/, as páginas que o GitHub Pages passa a servir para reencaminhar o site antigo.

O site do LogViewer muda-se para https://intrepidparallel.com/logviewer/ (decisão de 06/11/2026). Quem chegar pelos
endereços antigos (https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/…) vai para a página equivalente no endereço
novo: a portuguesa para a portuguesa, o Aviso legal para o Aviso legal.

    docs/index.html, docs/<língua>/index.html, docs/legal.html
            reencaminham já (meta refresh + location.replace) e dizem ao Google qual é a página verdadeira (canonical).
    docs/404.html
            qualquer outro endereço antigo que não exista em docs/: troca /TheAbsoluteLogViewer/ por /logviewer/.
    docs/googlee….html
            o ficheiro de verificação da Search Console, para se continuar a ver o endereço antigo durante a mudança.

⛔ Em docs/ vivem TAMBÉM os ficheiros da app, que o publicador da engenharia lá põe e que têm de responder nos mesmos
   endereços de sempre: o LogViewer.application e o Application Files/ (o ClickOnce), o StandAlone/ (com o
   version.json das atualizações), o Portable/, o setup.exe e o Publish.html. Este gerador NUNCA apaga nada em docs/,
   e nunca escreve por cima de um ficheiro que não seja seu.
⛔ Sem nada de terceiros nestas páginas: só reencaminham.
⚠ O GitHub Pages só serve docs/ depois de a fonte passar para «main, /docs», o que se faz na ordem combinada com a
  engenharia e com o OK do João.

Corre-se da raiz do site:  python tools/gerar-reencaminhamentos.py
"""
import glob
import html as H
import os
import shutil
import sys

sys.stdout.reconfigure(encoding="utf-8")

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOVO = "https://intrepidparallel.com/logviewer/"
DOCS = os.path.join(RAIZ, "docs")
NAO_SAO_LINGUAS = {"docs", "tools", "i18n", "css", "js", "assets", "Application Files", "StandAlone", "Portable"}
# os ficheiros que este gerador escreve; tudo o resto em docs/ é da app e não se toca
DA_APP = ("LogViewer.application", "Application Files", "StandAlone", "Portable", "setup.exe", "Publish.html")

MODELO = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>The Absolute LogViewer</title>
<link rel="canonical" href="{url}">
<meta http-equiv="refresh" content="0; url={url}">
<script>location.replace({url_js} + location.search + location.hash);</script>
<style>body{{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#070b0f;color:#d7e2ec;font-family:Segoe UI,system-ui,sans-serif;padding:0 16px}}a{{color:#34d399}}</style>
</head>
<body>
<p>The Absolute LogViewer has moved to <a href="{url}">{mostrar}</a>.</p>
</body>
</html>
"""

PAGINA_404 = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>The Absolute LogViewer</title>
<meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0; url={novo}">
<script>
  /* /TheAbsoluteLogViewer/qualquer/coisa -> https://intrepidparallel.com/logviewer/qualquer/coisa */
  var resto = location.pathname.replace(/^\\/TheAbsoluteLogViewer\\/?/i, "");
  location.replace({novo_js} + resto + location.search + location.hash);
</script>
<style>body{{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#070b0f;color:#d7e2ec;font-family:Segoe UI,system-ui,sans-serif;padding:0 16px}}a{{color:#34d399}}</style>
</head>
<body>
<p>The Absolute LogViewer has moved to <a href="{novo}">{mostrar}</a>.</p>
</body>
</html>
"""


def escrever(rel, texto):
    if rel.replace("\\", "/").split("/")[0] in DA_APP:
        sys.exit("[ERRO] %s é da app, e este gerador não lhe toca" % rel)
    f = os.path.join(DOCS, rel)
    os.makedirs(os.path.dirname(f), exist_ok=True)
    with open(f, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(texto)


def mostrar(url):
    return H.escape(url.replace("https://", "").rstrip("/"))


def pagina(url):
    return MODELO.format(url=H.escape(url, quote=True), url_js='"%s"' % url, mostrar=mostrar(url))


def main():
    linguas = sorted(d for d in os.listdir(RAIZ)
                     if d not in NAO_SAO_LINGUAS and not d.startswith(".")
                     and os.path.isfile(os.path.join(RAIZ, d, "index.html")))
    escrever("index.html", pagina(NOVO))
    for d in linguas:
        escrever(os.path.join(d, "index.html"), pagina(NOVO + d + "/"))
    escrever("legal.html", pagina(NOVO + "legal.html"))
    escrever("404.html", PAGINA_404.format(novo=H.escape(NOVO, quote=True), novo_js='"%s"' % NOVO, mostrar=mostrar(NOVO)))
    escrever(".nojekyll", "")
    for g in glob.glob(os.path.join(RAIZ, "google*.html")):
        shutil.copyfile(g, os.path.join(DOCS, os.path.basename(g)))
    print("✅ docs/: entrada, %d línguas (%s), legal, 404, verificação da Search Console; os ficheiros da app não se tocam"
          % (len(linguas), " ".join(linguas)))


if __name__ == "__main__":
    main()
