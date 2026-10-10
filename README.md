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
 Aá  S/  D:  F;  G[  H]  J¡  K!  L@  Ñ~
 ⇧    Z+  X-  C*  V¿  B?  N,  M.    ⌫(borrar palabra)
 ⌨︎(ocultar)      espacio          ⏎
```

## Personalización

La app incluye un editor donde se puede:

- Editar cada tecla: acción principal, acción secundaria, etiqueta y ancho.
- Añadir, eliminar, reordenar y mover teclas entre filas; añadir, mover y eliminar filas.
- Ajustar mayúscula automática, minúsculas, sonido, alto de fila y la distancia
  de deslizamiento.
- Configurar la vibración: tipo (Original, Suave o Rígido), intensidad y duración.
  La vibración nunca hace esperar al teclado: se reproduce en segundo plano y cada
  pulsación corta la vibración anterior.
- Exportar e importar la configuración completa como JSON.
- Restablecer la distribución por defecto.

Acciones disponibles: texto, espacio, borrar, borrar palabra, mayúsculas, bloqueo
de mayúsculas, intro, tabulador, ocultar teclado, siguiente teclado, emojis, pegar,
copiar, cortar y mover el cursor.

La app guarda la configuración en un App Group compartido
(`group.com.leonera.keyboard`) y la extensión la vuelve a leer cada vez que
aparece el teclado, cuando la app que lo usa vuelve a primer plano y en cuanto la
app avisa de un cambio, así que los ajustes se aplican sin reiniciar el teclado.

## Activar el teclado

1. Instala la app.
2. Ajustes › General › Teclado › Teclados › Añadir teclado › **Leonera**.
3. Activa **Permitir acceso completo** para pegar, vibración/sonido y para que el
   teclado lea la distribución personalizada desde la app.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `Shared/` | Modelo, distribución por defecto, almacenamiento y vista de tecla (compartidos) |
| `KeyboardExtension/` | Extensión de teclado (`UIInputViewController` + SwiftUI) |
| `App/` | App contenedora: instrucciones, prueba y editor |
| `project.yml` | Definición del proyecto para [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

El proyecto de Xcode no se guarda en el repositorio; se genera con XcodeGen
(herramienta de compilación únicamente, la app no tiene dependencias).

## Compilar

### GitHub Actions

`.github/workflows/build.yml` se ejecuta en **cada push** a cualquier rama (no en
los pull requests). Genera el proyecto, compila para `iphoneos` sin firmar y
publica el IPA:

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

El IPA no está firmado: para instalarlo hay que firmarlo (por ejemplo con
AltStore, Sideloadly o tu propio certificado). Asegúrate de que la herramienta
conserve el App Group; si no, el teclado funcionará con la distribución por
defecto pero no verá los cambios hechos en la app.

### En local (macOS)

```sh
brew install xcodegen
xcodegen generate
open LeoneraKeyboard.xcodeproj
```

En Xcode selecciona tu equipo en *Signing & Capabilities* para ambos targets. Si
usas tu propio equipo, cambia los bundle id y `APP_GROUP_ID` en `project.yml`.
