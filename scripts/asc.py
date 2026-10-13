#!/usr/bin/env python3
"""Cliente mínimo de la API de App Store Connect (lo usa .github/workflows/build.yml).

Subcomandos:
  check         Comprueba que la clave de API funciona y que hay dispositivos iOS
                registrados (sin ellos no se puede crear un perfil Ad Hoc).
  revoke-certs  Revoca los certificados de desarrollo con los números de serie
                indicados. xcodebuild crea uno nuevo en cada ejecución de CI para
                firmar el archive; si no se revocan, se llega al límite de Apple.

Lee la clave de ASC_KEY_ID, ASC_ISSUER_ID y ASC_KEY_PATH (el archivo .p8). Solo usa
la biblioteca estándar y `openssl` para firmar el token (ES256).
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"


def fail(message):
    print(f"::error::{message}")
    sys.exit(1)


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(signature):
    """Convierte una firma ECDSA en DER (la que da openssl) al formato r||s de JWT."""
    def read_int(data, offset):
        assert data[offset] == 0x02
        length = data[offset + 1]
        value = data[offset + 2:offset + 2 + length]
        return value.lstrip(b"\0").rjust(32, b"\0"), offset + 2 + length

    assert signature[0] == 0x30
    offset = 3 if signature[1] & 0x80 else 2
    r, offset = read_int(signature, offset)
    s, _ = read_int(signature, offset)
    return r + s


def token():
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ["ASC_KEY_PATH"]
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({
        "iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1",
    }).encode())
    message = f"{header}.{payload}".encode()
    result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                            input=message, capture_output=True)
    if result.returncode != 0:
        fail("No se pudo firmar el token con ASC_KEY_P8: " + result.stderr.decode().strip())
    return f"{header}.{payload}.{b64url(der_to_raw(result.stdout))}"


def request(method, path):
    req = urllib.request.Request(API + path, method=method,
                                 headers={"Authorization": f"Bearer {token()}"})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        if error.code == 401:
            fail("App Store Connect rechazó la clave (401): revisa ASC_KEY_ID, ASC_ISSUER_ID y ASC_KEY_P8.")
        if error.code == 403:
            fail("La clave de API no tiene permisos suficientes (403): debe ser una Team Key con rol Admin.")
        fail(f"App Store Connect respondió {error.code} a {method} {path}: {detail}")
    return json.loads(body) if body else {}


def command_check(args):
    devices = request("GET", "/devices?filter[status]=ENABLED&limit=200")["data"]
    ios = [d for d in devices if d["attributes"].get("platform") == "IOS"]
    if not ios:
        fail("No hay iPhone/iPad registrados en Certificates, Identifiers & Profiles › Devices: "
             "registra el UDID antes de compilar.")
    print(f"Clave de API válida. Dispositivos iOS registrados ({len(ios)}):")
    for device in ios:
        attributes = device["attributes"]
        print(f"  - {attributes.get('name')} ({attributes.get('deviceClass')}, {attributes.get('udid')})")


def normalize_serial(serial):
    return serial.strip().upper().lstrip("0")


def command_revoke(args):
    wanted = {normalize_serial(s) for s in args.serials if s.strip()}
    if not wanted:
        print("No hay certificados que revocar.")
        return
    certificates = request("GET", "/certificates?limit=200")["data"]
    revoked = 0
    for certificate in certificates:
        attributes = certificate["attributes"]
        if normalize_serial(attributes.get("serialNumber", "")) not in wanted:
            continue
        if "DEVELOPMENT" not in attributes.get("certificateType", ""):
            print(f"::warning::No se revoca {attributes.get('name')}: no es de desarrollo.")
            continue
        request("DELETE", f"/certificates/{certificate['id']}")
        print(f"Revocado el certificado temporal {attributes.get('name')} ({attributes.get('serialNumber')})")
        revoked += 1
    if revoked == 0:
        print("::warning::No se encontró en App Store Connect el certificado de desarrollo temporal.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check").set_defaults(func=command_check)
    revoke = commands.add_parser("revoke-certs")
    revoke.add_argument("serials", nargs="*")
    revoke.set_defaults(func=command_revoke)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
