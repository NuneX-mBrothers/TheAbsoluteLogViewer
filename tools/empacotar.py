# -*- coding: utf-8 -*-
r"""Faz o pacote .tar.gz do SITE do LogViewer que a porta de publicação do servidor recebe, e escreve-o no stdout.

    python tools\empacotar.py | ssh … sites@136.144.201.147 publicar logviewer

Leva só as páginas do site (https://intrepidparallel.com/logviewer/). Ficam de fora:
- os ficheiros da APP, que continuam no GitHub Pages nos mesmos endereços (o LogViewer.application, o
  Application Files/, o StandAlone/, o Portable/, o setup.exe, o Publish.html);
- o .git, as ferramentas, o docs/ (as páginas que reencaminham no GitHub), os .cmd, o README e as configurações de
  outros alojamentos (_headers, netlify.toml).

⛔ Porque não o tar do Windows (06/11/2026, na mBrothers): as pastas iam «só de leitura» (o OneDrive põe esse atributo
   às pastas) e o servidor não conseguia escrever nelas. Aqui as permissões são sempre as normais (pastas 755,
   ficheiros 644), sem dono, e no formato GNU, sem extensões.
⛔ Sem ligações nem ficheiros especiais: a porta recusa-os, e este script não os põe.
"""
import os
import sys
import tarfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORA_NO_TOPO = {
    ".git", ".gitignore", ".gitattributes", ".claude", ".nojekyll", "tools", "docs", "README.md", "_headers",
    "netlify.toml",
    "LogViewer.application", "Application Files", "StandAlone", "Portable", "setup.exe", "Publish.html",
}


def normal(ti):
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = ""
    ti.mode = 0o755 if ti.isdir() else 0o644
    return ti


def juntar(tar, caminho, nome):
    ti = tar.gettarinfo(caminho, arcname=nome)
    if not (ti.isfile() or ti.isdir()):
        sys.exit("[ERRO] %s não é um ficheiro nem uma pasta normal" % caminho)
    ti = normal(ti)
    if ti.isfile():
        with open(caminho, "rb") as fh:
            tar.addfile(ti, fh)
    else:
        tar.addfile(ti)


def main():
    if sys.stdout.isatty():
        sys.exit("[ERRO] o pacote é binário: liga-o ao ssh com |, ou manda-o para um ficheiro com >")
    if not os.path.isfile(os.path.join(RAIZ, "index.html")):
        sys.exit("[ERRO] falta o index.html na raiz do site")
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|gz", format=tarfile.GNU_FORMAT) as tar:
        juntar(tar, RAIZ, ".")
        for pasta, pastas, ficheiros in os.walk(RAIZ):
            rel = os.path.relpath(pasta, RAIZ)
            if rel == ".":
                pastas[:] = [p for p in pastas if p not in FORA_NO_TOPO]
                ficheiros = [f for f in ficheiros if f not in FORA_NO_TOPO and not f.lower().endswith(".cmd")]
            pastas.sort()
            for p in pastas:
                caminho = os.path.join(pasta, p)
                if os.path.islink(caminho):
                    sys.exit("[ERRO] ligação: %s" % caminho)
                juntar(tar, caminho, "./" + os.path.relpath(caminho, RAIZ).replace(os.sep, "/"))
            for f in sorted(ficheiros):
                caminho = os.path.join(pasta, f)
                juntar(tar, caminho, "./" + os.path.relpath(caminho, RAIZ).replace(os.sep, "/"))
    sys.stdout.buffer.flush()


if __name__ == "__main__":
    main()
