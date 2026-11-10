# Android (iteración 1.6): controles táctiles y APK de depuración

Primer prototipo Android: la misión provisional se puede recorrer entera con la pantalla táctil, y se genera un **APK de depuración** instalable. **No está preparado para publicarse:** no tiene firma de publicación, no se ha medido el rendimiento en un teléfono real y el APK pesa 383 MB.

## Controles

| Acción | PC | Android (táctil) |
|---|---|---|
| Moverse | WASD o flechas | Joystick abajo a la izquierda: aparece donde apoyas el pulgar, es analógico en 360° y tiene zona muerta |
| Examinar o hablar | E, o clic en la píldora | Botón «Examinar · …» abajo a la derecha (solo cuando hay algo cerca) |
| Avanzar diálogo | Espacio, Enter o clic | «Continuar ›» o tocar la ventana de texto |
| Menú del grupo | Tab o ☰ | ☰ arriba a la derecha |
| Combate | Clic o Esc para cancelar | Tocar orden → tocar objetivo; «Atrás» cancela; ☰ para opciones |

En el teléfono la interfaz se amplía hasta un 30 % (`content_scale_factor`), de modo que un botón de 48 unidades mida unos 6 mm reales; en el Pixel 7 emulado la escala es ×1,22. Con 7 mm (×1,43) el panel de Resonancia tapaba el nombre del Centinela, así que se ajustó tras verlo en el emulador. El 3D no se ve afectado.

## Simular la interfaz táctil en PC

- **Una vez:** lanza el juego con `godot --path . -- --touch`. El ratón actúa como un dedo y aparecen el joystick y el botón de acción a la derecha. Con `-- --no-touch` se fuerza el modo de escritorio.
- **Siempre:** en `project.godot`, `[visuals] touch/mode="on"`. Los valores posibles son `auto` (predeterminado: táctil solo si la pantalla lo es), `on` y `off`.
- **Desde el editor:** *Proyecto → Ejecutar → Argumentos principales* = `-- --touch`.

## Implementación

- `scenes/ui/touch_joystick.gd` (`TouchJoystick`): sigue un dedo por su índice de toque, convierte la posición en un vector y llama a `set_movement_input()` del `CharacterBody3D` existente, sin una segunda física ni otra velocidad. Se libera al soltar el dedo (aunque sea fuera de su área), al ocultarse (diálogo, menú, combate) y al salir de la escena.
  - Godot 4.7 trae un `VirtualJoystick` nativo, pero ese convierte el gesto en acciones del InputMap y permite poco control sobre su aspecto. Este entrega el vector directamente a la API de movimiento del proyecto y se dibuja con la paleta de EclipseUI.
- `scenes/ui/touch_controls.gd` (`TouchControls`):
  - decide el modo y la escala;
  - con `SecondaryFingers`, hace que un segundo dedo pueda pulsar botones (por ejemplo, Examinar mientras el pulgar sigue en el joystick). Godot solo convierte en ratón el dedo 0;
  - los botones de tipo interruptor cambian de estado igual que con un clic.
- `world/forest_zone.gd`:
  - en modo táctil coloca el joystick a la izquierda, la acción a la derecha y los avisos arriba;
  - oculta el joystick en diálogos, en el menú y fuera de la exploración.
- `world/game_flow.gd` llama a `TouchControls.configure()` al arrancar.
- `narrative/dialogue_box.gd`: se puede tocar la ventana para avanzar, y muestra «Toca para continuar».

## Herramientas utilizadas (detectadas en este equipo)

| Herramienta | Versión | Ruta |
|---|---|---|
| Godot | 4.7.2.stable (official) | `C:\Users\aleja\Downloads\Godot_v4.7.2-stable_win64.exe\` |
| Plantillas de exportación | 4.7.2.stable. Descargadas de `github.com/godotengine/godot-builds/releases/download/4.7.2-stable/`, SHA-512 comprobado contra `SHA512-SUMS.txt`; solo se instalaron las de Android y Windows x86_64 | `%APPDATA%\Godot\export_templates\4.7.2.stable\` |
| JDK | Oracle JDK 21.0.10. La documentación de Godot 4.7 recomienda el 17 pero admite versiones superiores, y con la plantilla precompilada funciona | `C:\Program Files\Java\jdk-21.0.10` |
| Android SDK | build-tools 35.0.0, 36.1.0 y 37.0.0; platforms android-36; platform-tools (adb 37.0.0); emulador 36.4.10 | `%LOCALAPPDATA%\Android\Sdk` |
| Ajustes del editor | `export/android/java_sdk_path`, `android_sdk_path` y `debug_keystore` (keystore de depuración generado por Godot) | `%APPDATA%\Godot\editor_settings-4.7.tres` |

No se usa Gradle (`gradle_build/use_gradle_build=false`), así que no hacen falta NDK, CMake ni cmdline-tools. Solo serían necesarios para generar un AAB destinado a Google Play.

## Preset y exportación

- **`export_presets.cfg` (en Git, sin contraseñas):**
  - preset «Android»;
  - paquete `org.eclipsejrpg.dev`, nombre «Eclipse JRPG (dev)», versión 0.16-dev;
  - solo arm64-v8a;
  - sin permisos;
  - pantalla inmersiva;
  - firmado con la clave de **depuración**;
  - excluye `docs/`, `tests/`, `tools/` y los `.blend`.
- **`project.godot`:**
  - `display/window/handheld/orientation=4`, horizontal con sensor;
  - `rendering/textures/vram_compression/import_etc2_astc=true`, porque Android necesita ETC2/ASTC;
  - en Android el renderizador es **Mobile**: ya estaba configurado así en `rendering_method.mobile` y no se ha tocado.

Para generar el APK:

```
godot --headless --path . --import
godot --headless --path . --export-debug "Android" build/android/eclipse-jrpg-debug.apk
```

Salida: `build/android/eclipse-jrpg-debug.apk`. La carpeta `build/` y los `*.apk` están en `.gitignore`.

### Cambio técnico necesario: texturas del bosque HD

Una prueba real con la plantilla de exportación demostró que **los compresores de textura no existen fuera del editor**: `Image.compress()` devolvió `ERR_UNAVAILABLE` para S3TC, ETC2, ASTC y BPTC. El bosque HD comprimía en tiempo de ejecución las texturas incrustadas en sus GLB, así que en un APK habrían quedado sin comprimir, con más de 1 GB de VRAM.

Los 24 GLB del kit pasan a `gltf/embedded_image_handling=2`, **Basis Universal incrustado**. Las texturas siguen dentro del recurso importado y ahora llegan comprimidas y con mipmaps; se transcodifican a BC en PC y a ETC2/ASTC en Android. `ForestArtHD._with_mips` las usa tal cual, y solo procesa (en el editor) las que lleguen sin comprimir. Todas las pruebas siguen pasando.

## Instalar en un móvil (dispositivo autorizado)

1. En el teléfono, activa *Opciones de desarrollador → Depuración por USB* y conéctalo por USB. Cuando aparezca el aviso, acepta la huella del equipo.
2. Comprueba que adb lo ve como `device` y no como `unauthorized`: `"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices -l`
3. Instala: `adb install -r build\android\eclipse-jrpg-debug.apk`. Si da error de firma por una versión anterior instalada, primero `adb uninstall org.eclipsejrpg.dev`.
4. Abre «Eclipse JRPG (dev)» y gira el teléfono en horizontal.
5. Para ver los registros: `adb logcat -s godot:V GodotRenderer:V AndroidRuntime:E *:F`. Para ver el uso de memoria: `adb shell dumpsys meminfo org.eclipsejrpg.dev`.
6. Para medir los FPS, activa *Proyecto → Ajustes → Depuración → Monitor de FPS*. Otra opción es lanzar desde el editor con «Depuración remota» y mirar Depurador → Monitores.

## Estado real de las pruebas

- **Automáticas (headless, en PC):** 1117 comprobaciones y ninguna falla.
  - Las 1076 anteriores se mantienen.
  - `tests/touch_checks.gd` suma 33. Cubren:
    - conversión del joystick, zona muerta, magnitud y 360°;
    - multitáctil por índices, segundo dedo, soltar fuera, teclado en modo táctil;
    - bloqueo en diálogo y en el menú;
    - cambio de escena con el dedo puesto;
    - combate por toques;
    - distribución en tres resoluciones con escala 1 y 1,3.
  - `tests/touch_playthrough_checks.gd` suma 8: **la misión completa jugada solo con eventos táctiles**. Eso incluye la introducción, tres pistas, dos Centinelas vencidos con órdenes, objetivos e invocación de Ignar tocados, y la anomalía final. Son eventos táctiles simulados en PC y **no sustituyen una prueba en un teléfono real**.
- **Render real en PC:**
  - capturas del HUD táctil en [previews/touch/](previews/touch/): `touch-*`, el [joystick sujeto](previews/touch/touch-joystick-held.png), la [acción a la derecha en 960×540](previews/touch/touch-interact-960x540.png) y en 19,5:9;
  - con el renderizador Mobile: [bosque](previews/touch/mobile-renderer-forest.png) y [combate](previews/touch/mobile-renderer-battle.png).
- **Dispositivo real:** no había ningún teléfono conectado (adb no lista dispositivos), así que **no se ha probado en hardware real**.
- **Emulador Android** (AVD `Pixel_7` ya existente: Android 17, x86_64, 2400×1080 a 420 dpi, con traducción ARM `libndk_translation`; arrancado con `-no-snapshot -memory 6144 -gpu host` sin modificar su configuración guardada):
  - El APK se instala (`adb install -r`, «Success») y arranca: `Vulkan 1.3.0 - Forward Mobile - Goldfish GFXStream`, en horizontal y a pantalla completa.
  - Con 2 GB de RAM, el valor por defecto de ese AVD, el sistema mató el proceso por memoria baja (*lowmemorykiller*). Con 6 GB funcionó.
  - Con toques reales de Android (`adb shell input tap/swipe`), sin teclado:
    - la introducción avanzó con «Continuar»;
    - el joystick movió a Kael, seguido por Lyra y Nira, hasta el Centinela I;
    - el combate se abrió;
    - «Llama» → «Centinela de piedra» ejecutó la acción: PV 280→266, PM de Lyra 35→27, RE 10, turno de Kael.
    - [Captura del combate en el emulador](previews/touch/emulator-battle.png).
  - Memoria del proceso (`dumpsys meminfo`): unos 830 MB de PSS y 1,0 GB de RSS. Registro del juego: 99–119 MB de memoria estática, 623–674 MB de vídeo, de ellos 471–496 MB de texturas.
  - FPS en el emulador: 7–24 en exploración y en combate. **No representa un teléfono**: todo el código ARM se traduce a x86 y la GPU es emulada (unos 150 ms por fotograma de CPU). Solo demuestra que funciona, no el rendimiento.
- **Registro de rendimiento:** en las compilaciones de depuración para móvil, `game_flow` escribe cada 5 s una línea `RENDIMIENTO fps=… frame_ms=… mem_static_mb=… video_mb=… tex_mb=… prims=… escena=…`. Para leerla: `adb logcat -s godot:I | findstr RENDIMIENTO`. Las compilaciones de publicación no la incluyen.

## Rendimiento: línea base (PC, no móvil)

Medido en un portátil con Intel Arc integrada, a 1560×720, con la interfaz táctil:

| | Renderizador Mobile | Forward+ |
|---|---|---|
| Bosque | 62 FPS (16,2 ms); 4,9 M primitivas; 475 MB de texturas en VRAM | 34 FPS |
| Combate | 111 FPS (9 ms); 2,2 M primitivas | 47 FPS |
| Primera carga del bosque | 16 s (compilación de shaders) | 7,4 s |

El objetivo de 30 FPS en un Android de gama media **no está medido**. Los riesgos más probables son las 4,9 M de primitivas del bosque HD y los ~475 MB de texturas. Si en el teléfono va lento, la primera prueba sin tocar código es usar el bosque anterior: `forest/hd=false`, o `forest/hd.mobile=false` para que solo afecte a Android. Otras optimizaciones propuestas, pendientes de medir:
- texturas a 1K en móvil;
- menos hierba instanciada;
- árboles lejanos solo como versión ligera.

## Limitaciones conocidas

- APK de 383 MB: texturas 2K en ETC2 y todos los modelos. Es aceptable para pruebas, no para una tienda.
- Firma de depuración: no sirve para Google Play. No se ha creado ninguna clave de publicación ni se han guardado credenciales.
- Los modelos HD de los personajes (Quaternius) se incluyen en el APK local porque están instalados en este equipo. En un clon sin los paquetes, el APK lleva los personajes anteriores.
- Sin pruebas en hardware real, sin medición de FPS ni de memoria en un móvil, y sin iOS.
