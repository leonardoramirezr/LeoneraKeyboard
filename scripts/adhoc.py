#!/usr/bin/env python3
"""Páginas de instalación Ad Hoc en GitHub Pages (las usa .github/workflows/build.yml).

Subcomandos:
  page          Genera la carpeta de un build (manifest.plist, index.html, build.json)
                para instalar el IPA desde Safari.
  index         Regenera la portada de GitHub Pages con todos los builds publicados.

Solo usa la biblioteca estándar.
"""

import argparse
import datetime
import html
import json
import pathlib
import plistlib
import shutil
import urllib.parse

STYLE = """
  :root {
    --bg: #f2f2f7; --card: #ffffff; --text: #1c1c1e; --muted: #6e6e73;
    --accent: #0a84ff; --border: #d1d1d6; --badge: #e5e5ea; --stable: #34c759;
  }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #000000; --card: #1c1c1e; --text: #f2f2f7; --muted: #98989f;
            --border: #38383a; --badge: #2c2c2e; --stable: #30d158; }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 32px 16px; background: var(--bg); color: var(--text);
    font: 17px/1.45 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
  }
  main { max-width: 560px; margin: 0 auto; }
  .card { background: var(--card); border-radius: 18px; padding: 20px; margin-bottom: 16px; }
  .app { display: flex; align-items: center; gap: 16px; }
  .app img { width: 72px; height: 72px; border-radius: 16px; border: 1px solid var(--border); }
  h1 { font-size: 22px; margin: 0; }
  h2 { font-size: 17px; margin: 0 0 8px; }
  .meta { color: var(--muted); font-size: 15px; margin: 2px 0 0; overflow-wrap: anywhere; }
  .install {
    display: block; margin-top: 16px; padding: 14px; border-radius: 12px; text-align: center;
    background: var(--accent); color: #fff; font-weight: 600; text-decoration: none;
  }
  .note { color: var(--muted); font-size: 15px; margin: 12px 0 0; }
  .warning { display: none; color: #ff9f0a; font-size: 15px; margin: 12px 0 0; }
  .builds { list-style: none; margin: 0; padding: 0; }
  .builds li { display: flex; align-items: center; gap: 12px; padding: 12px 0; border-top: 1px solid var(--border); }
  .builds li:first-child { border-top: 0; padding-top: 0; }
  .builds .info { flex: 1; min-width: 0; }
  .builds .tag { font-weight: 600; text-decoration: none; color: var(--text); overflow-wrap: anywhere; }
  .builds .message { font-size: 15px; margin: 2px 0 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .builds .get {
    flex: none; padding: 6px 16px; border-radius: 999px; background: var(--badge);
    color: var(--accent); font-weight: 600; font-size: 15px; text-decoration: none;
  }
  .badge {
    display: inline-block; padding: 1px 8px; border-radius: 999px; font-size: 13px;
    background: var(--badge); color: var(--muted); vertical-align: 1px; margin-left: 4px;
  }
  .badge.stable { background: var(--stable); color: #fff; }
  ol { margin: 0; padding-left: 20px; }
  li { margin: 4px 0; }
  a { color: var(--accent); }
  footer { color: var(--muted); font-size: 13px; text-align: center; }
"""

NOT_IOS_SCRIPT = """<script>
  if (!/iPhone|iPad|iPod/.test(navigator.userAgent) &&
      !(navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)) {
    document.getElementById("not-ios").style.display = "block";
  }
</script>"""

PAGE_TEMPLATE = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="apple-touch-icon" href="{icon}">
<style>{style}</style>
</head>
<body>
<main>
{body}
</main>
{script}
</body>
</html>
"""

BUILD_BODY = """  <section class="card">
    <div class="app">
      <img src="icon-512.png" alt="">
      <div>
        <h1>{title} {tag}{badge}</h1>
        <p class="meta">Versión {version} ({build}) · {date}</p>
        <p class="meta">{message}</p>
      </div>
    </div>
    <a class="install" href="{install_url}">Instalar</a>
    <p class="warning" id="not-ios">Abre esta página en Safari desde el iPhone o iPad para instalar la app.</p>
    <p class="note">Solo se instala en los dispositivos registrados en el perfil Ad Hoc.</p>
  </section>
  <section class="card">
    <h2>Instalación</h2>
    <ol>
      <li>Toca <strong>Instalar</strong> y confirma.</li>
      <li>Espera a que el icono termine de descargarse en la pantalla de inicio.</li>
      <li>Ajustes › General › Teclado › Teclados › Añadir teclado › <strong>Leonera</strong>.</li>
      <li>Activa <strong>Permitir acceso completo</strong>.</li>
    </ol>
    <p class="note">Si aparece «No se puede instalar la app», el dispositivo no está en el perfil.</p>
  </section>
  <footer>
    <a href="../">Todos los builds</a> ·
    <a href="{repo_url}/releases/tag/{tag_url}">Release</a> ·
    <a href="{repo_url}/commit/{commit}">{short_commit}</a>
  </footer>"""

HOME_BODY = """  <section class="card">
    <div class="app">
      <img src="{icon}" alt="">
      <div>
        <h1>{title}</h1>
        <p class="meta">{latest_meta}</p>
      </div>
    </div>
    {latest_install}
    <p class="warning" id="not-ios">Abre esta página en Safari desde el iPhone o iPad para instalar la app.</p>
    <p class="note">Solo se instala en los dispositivos registrados en el perfil Ad Hoc.</p>
  </section>
  <section class="card">
    <h2>Builds</h2>
    <ul class="builds">
{rows}
    </ul>
  </section>
  <footer>
    <a href="{repo_url}/tags">Tags</a> · <a href="{repo_url}/releases">Releases</a>
  </footer>"""

BUILD_ROW = """      <li>
        <div class="info">
          <a class="tag" href="{tag_url}/">{tag}</a>{badge}
          <p class="meta message">{message}</p>
          <p class="meta">{date} · {short_commit}</p>
        </div>
        <a class="get" href="{install_url}">Instalar</a>
      </li>"""


def install_link(manifest_url):
    return "itms-services://?action=download-manifest&url=" + urllib.parse.quote(manifest_url, safe="")


def badge(info):
    if info["release"]:
        return ' <span class="badge stable">estable</span>'
    return f' <span class="badge">{html.escape(info["branch"])}</span>'


def display_date(info):
    date = datetime.datetime.fromisoformat(info["date"])
    return f"{date:%Y-%m-%d %H:%M} UTC"


def command_page(args):
    """Escribe la carpeta de un build: manifest.plist, index.html y build.json."""
    base = args.base_url.rstrip("/") + "/"
    folder = urllib.parse.urljoin(base, urllib.parse.quote(args.tag) + "/")
    ipa_url = urllib.parse.urljoin(folder, urllib.parse.quote(args.ipa_name))
    manifest_url = urllib.parse.urljoin(folder, "manifest.plist")

    manifest = {
        "items": [{
            "assets": [
                {"kind": "software-package", "url": ipa_url},
                {"kind": "display-image", "needs-shine": False, "url": urllib.parse.urljoin(folder, "icon-57.png")},
                {"kind": "full-size-image", "needs-shine": False, "url": urllib.parse.urljoin(folder, "icon-512.png")},
            ],
            "metadata": {
                "bundle-identifier": args.bundle_id,
                "bundle-version": args.version,
                "kind": "software",
                "title": args.title,
            },
        }],
    }
    with open(f"{args.out_dir}/manifest.plist", "wb") as f:
        plistlib.dump(manifest, f)

    info = {
        "tag": args.tag,
        "version": args.version,
        "build": args.build,
        "branch": args.branch,
        "commit": args.commit,
        "message": args.message.splitlines()[0] if args.message else "",
        "release": args.release,
        "date": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "manifest_url": manifest_url,
    }
    with open(f"{args.out_dir}/build.json", "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=2)

    body = BUILD_BODY.format(
        title=html.escape(args.title),
        tag=html.escape(args.tag),
        badge=badge(info),
        version=html.escape(args.version),
        build=html.escape(args.build),
        date=display_date(info),
        message=html.escape(info["message"]),
        install_url=html.escape(install_link(manifest_url)),
        repo_url=html.escape(args.repo_url),
        tag_url=html.escape(urllib.parse.quote(args.tag)),
        commit=html.escape(args.commit),
        short_commit=html.escape(args.commit[:7]),
    )
    page = PAGE_TEMPLATE.format(title=html.escape(f"{args.title} {args.tag}"), icon="icon-512.png",
                                style=STYLE, body=body, script=NOT_IOS_SCRIPT)
    with open(f"{args.out_dir}/index.html", "w", encoding="utf-8") as f:
        f.write(page)
    print(f"Página: {folder}\nManifest: {manifest_url}\nIPA: {ipa_url}")


def command_index(args):
    """Regenera la portada con todos los builds y borra los de ramas más antiguos."""
    site = pathlib.Path(args.site_dir)
    builds = []
    for path in site.glob("*/build.json"):
        with open(path, encoding="utf-8") as f:
            builds.append(json.load(f))
    builds.sort(key=lambda info: (info["date"], int(info["build"])), reverse=True)

    branch_builds = [info for info in builds if not info["release"]]
    for info in branch_builds[args.keep_branch_builds:]:
        print(f"Se borra el build antiguo {info['tag']}")
        shutil.rmtree(site / info["tag"])
        builds.remove(info)

    rows = "\n".join(BUILD_ROW.format(
        tag=html.escape(info["tag"]),
        tag_url=html.escape(urllib.parse.quote(info["tag"])),
        badge=badge(info),
        message=html.escape(info["message"]),
        date=display_date(info),
        short_commit=html.escape(info["commit"][:7]),
        install_url=html.escape(install_link(info["manifest_url"])),
    ) for info in builds)

    latest = next((info for info in builds if info["release"]), None)
    if latest:
        latest_meta = f"Última versión estable: {html.escape(latest['tag'])} · {display_date(latest)}"
        latest_install = f'<a class="install" href="{html.escape(install_link(latest["manifest_url"]))}">Instalar {html.escape(latest["tag"])}</a>'
    else:
        latest_meta = "Todavía no hay versión estable: instala un build de la lista."
        latest_install = ""
    icon = f"{urllib.parse.quote(builds[0]['tag'])}/icon-512.png" if builds else ""

    body = HOME_BODY.format(
        title=html.escape(args.title),
        icon=html.escape(icon),
        latest_meta=latest_meta,
        latest_install=latest_install,
        rows=rows,
        repo_url=html.escape(args.repo_url),
    )
    page = PAGE_TEMPLATE.format(title=html.escape(args.title), icon=html.escape(icon),
                                style=STYLE, body=body, script=NOT_IOS_SCRIPT)
    (site / "index.html").write_text(page, encoding="utf-8")
    # Sin Jekyll: GitHub Pages sirve los archivos tal cual.
    (site / ".nojekyll").touch()
    print(f"Portada con {len(builds)} build(s)")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    page = commands.add_parser("page")
    page.add_argument("--out-dir", required=True)
    page.add_argument("--base-url", required=True)
    page.add_argument("--tag", required=True)
    page.add_argument("--ipa-name", required=True)
    page.add_argument("--bundle-id", required=True)
    page.add_argument("--version", required=True)
    page.add_argument("--build", required=True)
    page.add_argument("--title", required=True)
    page.add_argument("--branch", required=True)
    page.add_argument("--commit", required=True)
    page.add_argument("--message", default="")
    page.add_argument("--release", action="store_true", help="release estable de main")
    page.add_argument("--repo-url", required=True)
    page.set_defaults(func=command_page)

    index = commands.add_parser("index")
    index.add_argument("--site-dir", required=True)
    index.add_argument("--keep-branch-builds", type=int, default=50)
    index.add_argument("--title", required=True)
    index.add_argument("--repo-url", required=True)
    index.set_defaults(func=command_index)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
