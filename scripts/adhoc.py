#!/usr/bin/env python3
"""Utilidades para firmar y publicar el IPA Ad Hoc (las usa .github/workflows/build.yml).

Subcomandos:
  check         Valida el certificado y los perfiles Ad Hoc y obtiene de ellos el
                equipo, los bundle id y el App Group con los que hay que compilar.
  entitlements  Genera los entitlements de un bundle a partir de su perfil.
  site          Genera manifest.plist e index.html para instalar el IPA desde Safari.

Solo usa la biblioteca estándar: los perfiles se leen extrayendo el plist que llevan
dentro (igual que hace ConfigurationStorage en la app), sin `security cms`.
"""

import argparse
import datetime
import hashlib
import html
import plistlib
import sys
import urllib.parse

GROUPS_KEY = "com.apple.security.application-groups"


def fail(message):
    print(f"::error::{message}")
    sys.exit(1)


def load_profile(path):
    with open(path, "rb") as f:
        data = f.read()
    start = data.find(b"<?xml")
    end = data.find(b"</plist>", start)
    if start < 0 or end < 0:
        fail(f"{path} no parece un perfil de aprovisionamiento (.mobileprovision).")
    return plistlib.loads(data[start:end + len(b"</plist>")])


def profile_summary(label, profile):
    """Valida que el perfil sea Ad Hoc y devuelve sus datos principales."""
    name = profile.get("Name", "?")
    entitlements = profile.get("Entitlements", {})
    team = (profile.get("TeamIdentifier") or [""])[0]
    app_identifier = entitlements.get("application-identifier", "")
    prefix = (profile.get("ApplicationIdentifierPrefix") or [team])[0]
    bundle_id = app_identifier[len(prefix) + 1:] if app_identifier.startswith(prefix + ".") else ""

    if profile.get("ProvisionsAllDevices"):
        fail(f"El perfil de la {label} («{name}») es Enterprise (In-House); hace falta uno Ad Hoc.")
    if entitlements.get("get-task-allow"):
        fail(f"El perfil de la {label} («{name}») es de desarrollo; hace falta uno de distribución Ad Hoc.")
    devices = profile.get("ProvisionedDevices") or []
    if not devices:
        fail(f"El perfil de la {label} («{name}») no tiene dispositivos: es de App Store, no Ad Hoc.")
    if not bundle_id or "*" in bundle_id:
        fail(f"El perfil de la {label} («{name}») usa el App ID «{app_identifier}»; "
             "hace falta un App ID explícito (sin *) con App Groups.")

    expiration = profile.get("ExpirationDate")
    expiration_text = f"{expiration:%Y-%m-%d}" if expiration else "?"
    if expiration:
        now = datetime.datetime.now(datetime.timezone.utc)
        if expiration.tzinfo is None:
            expiration = expiration.replace(tzinfo=datetime.timezone.utc)
        if expiration <= now:
            fail(f"El perfil de la {label} («{name}») caducó el {expiration_text}.")
        if expiration - now < datetime.timedelta(days=30):
            print(f"::warning::El perfil de la {label} («{name}») caduca el {expiration_text}.")

    certificates = {hashlib.sha1(der).hexdigest().upper() for der in profile.get("DeveloperCertificates", [])}
    print(f"Perfil de la {label}: «{name}» · {bundle_id} · equipo {team} · "
          f"{len(devices)} dispositivo(s) · caduca {expiration_text}")
    return {
        "name": name,
        "team": team,
        "bundle_id": bundle_id,
        "groups": list(entitlements.get(GROUPS_KEY) or []),
        "devices": set(devices),
        "certificates": certificates,
    }


def command_check(args):
    app = profile_summary("app", load_profile(args.app_profile))
    ext = profile_summary("extensión", load_profile(args.extension_profile))

    if app["team"] != ext["team"]:
        fail(f"Los perfiles son de equipos distintos ({app['team']} y {ext['team']}).")
    if not ext["bundle_id"].startswith(app["bundle_id"] + "."):
        fail(f"El bundle id de la extensión ({ext['bundle_id']}) debe empezar por el de la app "
             f"seguido de un punto ({app['bundle_id']}.…).")

    identity = args.identity.upper()
    for label, summary in (("app", app), ("extensión", ext)):
        if identity not in summary["certificates"]:
            fail(f"El perfil de la {label} («{summary['name']}») no incluye el certificado del .p12 "
                 f"(SHA-1 {identity}). Vuelve a generar el perfil con ese certificado.")

    common = [group for group in app["groups"] if group in ext["groups"]]
    if args.preferred_group in common:
        group = args.preferred_group
    elif len(common) == 1:
        group = common[0]
    elif not common:
        fail("La app y la extensión no comparten ningún App Group. Activa App Groups en ambos App ID, "
             "asígnales el mismo grupo y vuelve a generar los perfiles.")
    else:
        fail(f"La app y la extensión comparten varios App Groups ({', '.join(common)}); "
             "deja solo uno o usa el de APP_GROUP_ID en project.yml.")

    only_app = app["devices"] - ext["devices"]
    only_ext = ext["devices"] - app["devices"]
    if only_app or only_ext:
        print("::warning::Los perfiles de la app y de la extensión no tienen los mismos dispositivos; "
              "solo se podrá instalar en los que estén en ambos.")
    devices = len(app["devices"] & ext["devices"])
    print(f"App Group: {group} · se puede instalar en {devices} dispositivo(s)")

    with open(args.github_output, "a") as out:
        out.write(f"team_id={app['team']}\n")
        out.write(f"app_bundle_id={app['bundle_id']}\n")
        out.write(f"extension_bundle_id={ext['bundle_id']}\n")
        out.write(f"app_group={group}\n")
        out.write(f"devices={devices}\n")


def command_entitlements(args):
    profile = load_profile(args.profile)
    entitlements = profile.get("Entitlements", {})
    team = (profile.get("TeamIdentifier") or [""])[0]
    result = {
        "application-identifier": entitlements["application-identifier"],
        "com.apple.developer.team-identifier": team,
        "get-task-allow": False,
        GROUPS_KEY: [args.app_group],
    }
    with open(args.out, "wb") as f:
        plistlib.dump(result, f)


INDEX_TEMPLATE = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="apple-touch-icon" href="icon-512.png">
<style>
  :root {{
    --bg: #f2f2f7; --card: #ffffff; --text: #1c1c1e; --muted: #6e6e73;
    --accent: #0a84ff; --border: #d1d1d6;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --bg: #000000; --card: #1c1c1e; --text: #f2f2f7; --muted: #98989f; --border: #38383a; }}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 32px 16px; background: var(--bg); color: var(--text);
    font: 17px/1.45 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
  }}
  main {{ max-width: 480px; margin: 0 auto; }}
  .card {{ background: var(--card); border-radius: 18px; padding: 24px; margin-bottom: 16px; }}
  .app {{ display: flex; align-items: center; gap: 16px; }}
  .app img {{ width: 72px; height: 72px; border-radius: 16px; border: 1px solid var(--border); }}
  h1 {{ font-size: 22px; margin: 0; }}
  h2 {{ font-size: 17px; margin: 0 0 8px; }}
  .meta {{ color: var(--muted); font-size: 15px; margin: 2px 0 0; }}
  .install {{
    display: block; margin-top: 20px; padding: 14px; border-radius: 12px; text-align: center;
    background: var(--accent); color: #fff; font-weight: 600; text-decoration: none;
  }}
  .note {{ color: var(--muted); font-size: 15px; margin: 12px 0 0; }}
  .warning {{ display: none; color: #ff9f0a; font-size: 15px; margin: 12px 0 0; }}
  ol {{ margin: 0; padding-left: 20px; }}
  li {{ margin: 4px 0; }}
  a {{ color: var(--accent); }}
  footer {{ color: var(--muted); font-size: 13px; text-align: center; }}
</style>
</head>
<body>
<main>
  <section class="card">
    <div class="app">
      <img src="icon-512.png" alt="">
      <div>
        <h1>{title}</h1>
        <p class="meta">Versión {version} ({build}) · {date}</p>
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
    <a href="{repo_url}/releases/tag/{tag}">Release {tag}</a> ·
    <a href="{repo_url}/commit/{commit}">{short_commit}</a>
  </footer>
</main>
<script>
  if (!/iPhone|iPad|iPod/.test(navigator.userAgent) &&
      !(navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)) {{
    document.getElementById("not-ios").style.display = "block";
  }}
</script>
</body>
</html>
"""


def command_site(args):
    base = args.base_url.rstrip("/") + "/"
    # El número de build en la URL evita que la caché de GitHub Pages sirva una versión anterior.
    query = f"?build={urllib.parse.quote(args.build)}"
    ipa_url = urllib.parse.urljoin(base, urllib.parse.quote(args.ipa_name)) + query
    manifest_url = urllib.parse.urljoin(base, "manifest.plist") + query

    manifest = {
        "items": [{
            "assets": [
                {"kind": "software-package", "url": ipa_url},
                {"kind": "display-image", "needs-shine": False, "url": urllib.parse.urljoin(base, "icon-57.png")},
                {"kind": "full-size-image", "needs-shine": False, "url": urllib.parse.urljoin(base, "icon-512.png")},
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

    install_url = "itms-services://?action=download-manifest&url=" + urllib.parse.quote(manifest_url, safe="")
    page = INDEX_TEMPLATE.format(
        title=html.escape(args.title),
        version=html.escape(args.version),
        build=html.escape(args.build),
        date=datetime.date.today().isoformat(),
        install_url=html.escape(install_url),
        repo_url=html.escape(args.repo_url),
        tag=html.escape(urllib.parse.quote(args.tag)),
        commit=html.escape(args.commit),
        short_commit=html.escape(args.commit[:7]),
    )
    with open(f"{args.out_dir}/index.html", "w", encoding="utf-8") as f:
        f.write(page)
    print(f"Página: {base}\nManifest: {manifest_url}\nIPA: {ipa_url}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    check = commands.add_parser("check")
    check.add_argument("--app-profile", required=True)
    check.add_argument("--extension-profile", required=True)
    check.add_argument("--identity", required=True, help="SHA-1 del certificado de firma")
    check.add_argument("--preferred-group", default="")
    check.add_argument("--github-output", required=True)
    check.set_defaults(func=command_check)

    entitlements = commands.add_parser("entitlements")
    entitlements.add_argument("--profile", required=True)
    entitlements.add_argument("--app-group", required=True)
    entitlements.add_argument("--out", required=True)
    entitlements.set_defaults(func=command_entitlements)

    site = commands.add_parser("site")
    site.add_argument("--out-dir", required=True)
    site.add_argument("--base-url", required=True)
    site.add_argument("--ipa-name", required=True)
    site.add_argument("--bundle-id", required=True)
    site.add_argument("--version", required=True)
    site.add_argument("--build", required=True)
    site.add_argument("--title", required=True)
    site.add_argument("--tag", required=True)
    site.add_argument("--commit", required=True)
    site.add_argument("--repo-url", required=True)
    site.set_defaults(func=command_site)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
