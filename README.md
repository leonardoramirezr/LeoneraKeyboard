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

El proyecto de Xcode no se guarda en el repositorio; se genera con XcodeGen
(herramienta de compilación únicamente, la app no tiene dependencias).

## Compilar

### GitHub Actions

`.github/workflows/build.yml` se ejecuta en **cada push** a cualquier rama (no en
los pull requests). Genera el proyecto, compila para `iphoneos` sin certificado,
firma los binarios *ad-hoc* con el App Group y publica el IPA:

| Origen | Etiqueta (tag) | Publicación |
| --- | --- | --- |
| Commit en `main` | `0.1.0`, `0.2.0`, `0.3.0`… (sube el número intermedio en cada push) | [Release](../../releases) estable, marcado como *Latest* |
| Commit en otra rama | `build-<número de ejecución>-<commit>` (p. ej. `build-7-9fb81b8`) | Pre-release |

Todas las etiquetas aparecen en [Tags](../../tags) y cada una tiene el IPA
(`LeoneraKeyboard-<etiqueta>-unsigned.ipa`) adjunto en su release. La versión de
la app (`CFBundleShortVersionString`) es la de la próxima release de `main`, y el
número de build es el número de ejecución del workflow.

Si un push a `main` incluye varios commits, se publica una sola release con el
último de ellos.

El IPA no está firmado con ningún certificado: para instalarlo hay que firmarlo
(por ejemplo con SideStore, AltStore, Sideloadly o tu propio certificado). La
firma *ad-hoc* solo sirve para que el IPA declare el App Group
(`com.apple.security.application-groups`): sin ella SideStore y AltStore no lo
registran. Asegúrate de que la herramienta conserve el App Group; si no, el teclado funcionará con la distribución por
defecto pero no verá los cambios hechos en la app ni la API key del dictado. Si la
herramienta cambia el nombre del App Group (AltStore y SideStore, por ejemplo,
le añaden el ID del equipo), la app y el teclado lo detectan solos a partir de
`ALTAppGroups` o del perfil de aprovisionamiento. En la app, **Dictado ›
Conexión con el teclado** indica si ambos comparten los ajustes.

### En local (macOS)

```sh
brew install xcodegen
xcodegen generate
open LeoneraKeyboard.xcodeproj
```

En Xcode selecciona tu equipo en *Signing & Capabilities* para ambos targets. Si
usas tu propio equipo, cambia los bundle id y `APP_GROUP_ID` en `project.yml`.
