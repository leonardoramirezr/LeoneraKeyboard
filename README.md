# LeoneraKeyboard

Teclado personalizado para iOS escrito en SwiftUI, sin dependencias externas.

Cada tecla tiene una acción principal (el carácter grande) y, opcionalmente, una
acción secundaria que se muestra como un símbolo pequeño en la parte superior:

- **Tocar** la tecla escribe el carácter principal.
- **Deslizar hacia abajo** escribe el símbolo secundario o ejecuta su acción
  (emojis, pegar, borrar palabra…).

Mantener pulsadas las teclas de borrar o de mover el cursor repite la acción.
Pulsar dos veces mayúsculas activa el bloqueo de mayúsculas.

## Distribución por defecto

```
 1☺  2"  3#  4$  5%  6&  7/  8(  9)  0📋
 Q_  W\  Eé  R|  T<  Y>  Uú  Ií  Oó  P•
 Aá  S/  D:  F;  G[  H]  J¡  K!  L@  Ñ🎤(dictar)
 ⇧    Z+  X-  C*  V¿  B?  N,  M.    ⌫(borrar palabra)
 ⌨︎(ocultar)      espacio          ⏎
```

## Personalización

La app incluye un editor donde se puede:

- Editar cada tecla: acción principal, acción secundaria, etiqueta y ancho.
- Añadir, eliminar, reordenar y mover teclas entre filas; añadir, mover y eliminar filas.
- Ajustar mayúscula automática, minúsculas, sonido, alto de fila y la distancia
  de deslizamiento.
- Configurar la vibración: tipo (Ligero, Medio, Fuerte, Suave o Rígido), intensidad y duración.
  La vibración nunca hace esperar al teclado: se reproduce en segundo plano y cada
  pulsación corta la vibración anterior.
- Exportar e importar la configuración completa como JSON.
- Restablecer la distribución por defecto.

Acciones disponibles: texto, espacio, borrar, borrar palabra, mayúsculas, bloqueo
de mayúsculas, intro, tabulador, ocultar teclado, siguiente teclado, emojis, dictar,
pegar, copiar, cortar y mover el cursor.

## Dictado

La acción **Dictar** (en la distribución por defecto, deslizando hacia abajo la
tecla Ñ) cambia el teclado por una pantalla con un botón de grabar en el centro y
un interruptor **Mejorar texto con IA**:

1. Toca el botón para grabar y vuelve a tocarlo para terminar.
2. El audio se envía a Groq (`/audio/transcriptions`) para convertirlo en texto
   con el modelo de voz a texto elegido.
3. Con el interruptor activado, la transcripción se envía después al LLM elegido
   (`/chat/completions`) con un prompt que corrige la puntuación, los signos, la
   ortografía y que el texto tenga sentido.
4. El texto se escribe donde está el cursor.

En la app, **Dictado** permite configurar la API key, una URL de API personalizada
(cualquier servicio compatible con la API de OpenAI), los modelos de voz a texto y
LLM (se pueden escribir o elegir de la lista que devuelve la API), el idioma del
audio y el prompt. Por defecto se usan `whisper-large-v3-turbo` y
`openai/gpt-oss-120b`. Estos ajustes se guardan aparte y no se incluyen al exportar
la configuración, para no compartir la API key.

iOS normalmente no deja que un teclado use el micrófono, así que la app graba por
él: la primera vez que dictas, el teclado abre Leonera Keyboard, que activa el
micrófono y empieza a grabar; vuelve a la app anterior (botón «◀︎» de la barra de
estado) y termina la grabación desde el teclado. El micrófono queda activo en
segundo plano (con el indicador naranja) para los siguientes dictados y se
desactiva tras 5 minutos sin usarlo o desde la app. Si el sistema sí permite
grabar desde el teclado, se graba directamente sin abrir la app.

Dictar requiere **Permitir acceso completo** y permiso de micrófono. Si ya tenías
una distribución guardada, la tecla Ñ no cambia: añade la acción «Dictar» a la
tecla que quieras desde el editor o restablece la distribución por defecto.

La app guarda la configuración en un App Group compartido
(`group.com.leonera.keyboard`) y la extensión la vuelve a leer cada vez que
aparece el teclado, cuando la app que lo usa vuelve a primer plano y en cuanto la
app avisa de un cambio, así que los ajustes se aplican sin reiniciar el teclado.

## Activar el teclado

1. Instala la app.
2. Ajustes › General › Teclado › Teclados › Añadir teclado › **Leonera**.
3. Activa **Permitir acceso completo** para pegar, vibración/sonido, dictar y para
   que el teclado lea la distribución personalizada desde la app.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `Shared/` | Modelo, distribución por defecto, almacenamiento, vista de tecla, grabación y cliente de Groq (compartidos) |
| `KeyboardExtension/` | Extensión de teclado (`UIInputViewController` + SwiftUI) |
| `App/` | App contenedora: instrucciones, prueba y editor |
| `project.yml` | Definición del proyecto para [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| `scripts/adhoc.py` | Validación de los perfiles Ad Hoc y generación de las páginas de instalación |
| `scripts/publish-pages.sh` | Publicación de cada build en la rama `gh-pages` |

El proyecto de Xcode no se guarda en el repositorio; se genera con XcodeGen
(herramienta de compilación únicamente, la app no tiene dependencias).

## Compilar

### GitHub Actions

`.github/workflows/build.yml` se ejecuta en **cada push** a cualquier rama (no en
los pull requests ni en `gh-pages`). Genera el proyecto, compila para `iphoneos`,
firma la app y publica el IPA. Ningún build se cancela: los de `main` se ejecutan
de uno en uno (para no repetir versión) y los de otras ramas en paralelo.

| Origen | Etiqueta (tag) | Publicación |
| --- | --- | --- |
| Commit en `main` (p. ej. al hacer merge) | `0.1.0`, `0.2.0`, `0.3.0`… (sube el número intermedio en cada push) | [Release](../../releases) estable, marcado como *Latest* |
| Commit en otra rama | `build-<número de ejecución>-<commit>` (p. ej. `build-7-9fb81b8`) | Pre-release |

Con firma Ad Hoc, además, cada build (de `main` y de las demás ramas) se publica en
GitHub Pages en una carpeta con el nombre de su etiqueta
(`https://<usuario>.github.io/<repositorio>/<etiqueta>/`); ver
[Instalación Ad Hoc](#instalación-ad-hoc-github-pages).

Todas las etiquetas aparecen en [Tags](../../tags) y cada una tiene el IPA
adjunto en su release: `LeoneraKeyboard-<etiqueta>-adhoc.ipa` si están configurados
los secrets de firma (ver [Instalación Ad Hoc](#instalación-ad-hoc-github-pages)) o
`LeoneraKeyboard-<etiqueta>-unsigned.ipa` si no. La versión de la app
(`CFBundleShortVersionString`) es la de la próxima release de `main`, y el número
de build es el número de ejecución del workflow.

Si un push a `main` incluye varios commits, se publica una sola release con el
último de ellos.

#### IPA sin firmar

Sin los secrets de firma, el IPA no está firmado con ningún certificado: para
instalarlo hay que firmarlo (por ejemplo con SideStore, AltStore o Sideloadly). Se
firma sin certificado (`codesign --sign -`) solo para que declare el App Group
(`com.apple.security.application-groups`): sin ello SideStore y AltStore no lo
registran. Asegúrate de que la herramienta conserve el App Group; si no, el teclado funcionará con la distribución por
defecto pero no verá los cambios hechos en la app ni la API key del dictado. Si la
herramienta cambia el nombre del App Group (AltStore y SideStore, por ejemplo,
le añaden el ID del equipo), la app y el teclado lo detectan solos a partir de
`ALTAppGroups` o del perfil de aprovisionamiento. En la app, **Dictado ›
Conexión con el teclado** indica si ambos comparten los ajustes.

### Instalación Ad Hoc (GitHub Pages)

Con una cuenta del Apple Developer Program, el workflow firma el IPA con un
certificado **Apple Distribution** y dos perfiles **Ad Hoc** (uno para la app y
otro para la extensión del teclado) y publica **cada build** en GitHub Pages, con
la misma nomenclatura que [Tags](../../tags):

| Página | Contenido |
| --- | --- |
| `https://<usuario>.github.io/<repositorio>/` | Portada: botón para instalar la última versión estable de `main` y lista de todos los builds |
| `…/0.3.0/` | Build de `main` (release estable) |
| `…/build-7-9fb81b8/` | Build de otra rama |

Cada carpeta tiene un botón **Instalar** que, abierto en Safari desde el iPhone,
instala la app directamente (`itms-services`), además de su `manifest.plist` y el
IPA `LeoneraKeyboard-<etiqueta>-adhoc.ipa`. Solo se instala en los dispositivos
incluidos en los perfiles y no hace falta activar el modo de desarrollador. El
enlace de cada build aparece también en el resumen de la ejecución en *Actions* y
en las notas de los pre-releases.

Las páginas se guardan en la rama `gh-pages` (`scripts/publish-pages.sh`), que
tiene un solo commit que se reemplaza en cada publicación para que los IPA no se
acumulen en el historial. Se conservan todas las versiones de `main` y los 50
builds de otras ramas más recientes (los anteriores siguen en su release). Si dos
builds publican a la vez, el segundo reintenta sobre la versión del primero.

Los bundle id y el App Group se toman de los perfiles, así que no hay que tocar
`project.yml`. `scripts/adhoc.py` comprueba antes de compilar que los perfiles sean
Ad Hoc, que no hayan caducado, que incluyan el certificado del `.p12` y que la app
y la extensión compartan el App Group.

#### 1. Apple Developer ([Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources))

1. **Identifiers › App Groups**: registra un grupo, p. ej.
   `group.com.<tu-nombre>.leonerakeyboard`.
2. **Identifiers › App IDs** (tipo *App*, *Explicit*): registra dos, ambos con la
   capacidad **App Groups** activada y configurada con el grupo anterior:
   - App: p. ej. `com.<tu-nombre>.leonerakeyboard`.
   - Teclado: el mismo seguido de `.extension`, p. ej.
     `com.<tu-nombre>.leonerakeyboard.extension` (debe empezar por el de la app).
3. **Devices**: registra el UDID de cada iPhone/iPad (con el dispositivo conectado
   al Mac, en Finder haz clic en el texto bajo el nombre del dispositivo hasta ver
   el UDID; clic derecho para copiarlo).
4. **Certificates**: crea un certificado **Apple Distribution** (en el Mac:
   *Acceso a Llaveros › Asistente de certificados › Solicitar un certificado de
   una autoridad de certificación*, guardado en disco). Descárgalo, ábrelo para
   añadirlo al llavero y, en *Mis certificados*, expórtalo junto con su clave
   privada como `.p12` con una contraseña.
5. **Profiles**: crea dos perfiles **Ad Hoc** (en *Distribution*), uno con el App
   ID de la app y otro con el del teclado, ambos con el certificado anterior y
   los mismos dispositivos. Descarga los dos `.mobileprovision`.

#### 2. Secrets del repositorio

En *Settings › Secrets and variables › Actions › New repository secret*:

| Secret | Valor |
| --- | --- |
| `ADHOC_CERTIFICATE_P12` | El `.p12` en base64: `base64 -i certificado.p12 \| pbcopy` |
| `ADHOC_CERTIFICATE_PASSWORD` | La contraseña del `.p12` |
| `ADHOC_PROFILE_APP` | El perfil de la app en base64: `base64 -i App_AdHoc.mobileprovision \| pbcopy` |
| `ADHOC_PROFILE_EXTENSION` | El perfil del teclado en base64 |

Si falta alguno (pero no todos), el workflow falla para no publicar sin firma por
error.

#### 3. GitHub Pages

El primer build firmado crea la rama `gh-pages`. Después, en *Settings › Pages ›
Build and deployment*, elige **Source: Deploy from a branch** y **Branch:
`gh-pages` / `(root)`**. Solo hay que hacerlo una vez; GitHub Pages se actualiza
solo (en un par de minutos) con cada build.

#### 4. Instalar

Haz push a cualquier rama o merge a `main` y abre en **Safari** desde el iPhone la
portada o la carpeta del build. La portada puede tardar unos minutos en mostrar el
build nuevo por la caché de GitHub Pages; la carpeta de cada build es nueva, así
que no le afecta.

Al tener otros bundle id, la app firmada Ad Hoc se instala aparte de la que
hubieras instalado con SideStore/AltStore: exporta la configuración desde la app
anterior e impórtala en la nueva, y vuelve a escribir la API key del dictado.

#### Añadir un dispositivo o renovar

1. Registra el UDID en **Devices**.
2. En **Profiles**, edita los dos perfiles Ad Hoc, marca el dispositivo, guarda y
   descárgalos de nuevo.
3. Actualiza `ADHOC_PROFILE_APP` y `ADHOC_PROFILE_EXTENSION` y vuelve a ejecutar
   el workflow.

Los perfiles caducan al año y el certificado Apple Distribution también; el
workflow avisa 30 días antes. Al renovar el certificado, regenera los perfiles con
él y actualiza los cuatro secrets.

### En local (macOS)

```sh
brew install xcodegen
xcodegen generate
open LeoneraKeyboard.xcodeproj
```

En Xcode selecciona tu equipo en *Signing & Capabilities* para ambos targets. Si
usas tu propio equipo, cambia `APP_BUNDLE_ID` y `APP_GROUP_ID` en `project.yml`.
