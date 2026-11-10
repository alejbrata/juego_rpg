# Eclipse JRPG

**Iteración 1.7 — Presentación audiovisual del combate:** [efectos, sonidos, números y cámara](docs/COMBAT_FX.md) · [comparativa de Llama](docs/previews/combat_fx/compare-llama.jpg) · [invocación de Ignar](docs/previews/combat_fx/after-invocacion.gif). Cada habilidad tiene su efecto y su sonido (19 SFX originales sintetizados), el golpe aterriza en el contacto, los números son legibles en móvil y la cámara se sacude con suavidad (desactivable). Ignar HD se monta con el mismo proceso que el grupo (paquetes Quaternius locales). Sin cambios de reglas. **1160 comprobaciones, cero fallos.** Rendimiento móvil sin medir.

**Iteración 1.6 — Prototipo Android táctil (APK de depuración):** [controles, herramientas, exportación, instalación, logs y estado real](docs/ANDROID.md) · [HUD táctil](docs/previews/touch/touch-joystick-held.png) · [combate en el emulador](docs/previews/touch/emulator-battle.png). Joystick analógico a la izquierda, acción contextual a la derecha, multitáctil (otro dedo puede pulsar botones mientras se mueve) y combate completo por toques. Funciona igual en PC; para simular el móvil, `godot --path . -- --touch`. Para generar el APK: `godot --headless --path . --export-debug "Android" build/android/eclipse-jrpg-debug.apk` (383 MB, arm64, firma de depuración, fuera de Git). Probado en el emulador Android: instala, arranca y se juega por toques. **No probado en un teléfono real, rendimiento móvil sin medir y no apto para publicar.** **1118 comprobaciones, cero fallos**, incluida la misión completa jugada solo con eventos táctiles.

**Iteración 1.5 — Interfaz renovada:** [diseño, componentes, resoluciones y límites](docs/UI.md) · [combate antes](docs/previews/ui/before-battle-16x9.png) / [después](docs/previews/ui/after-battle-16x9.png) · [exploración](docs/previews/ui/after-interact.png) · [diálogo](docs/previews/ui/after-dialogue.png). Combate con cabecera de turno y orden, Resonancia con aviso de invocación, tarjetas con retratos generados en el juego, barras PV/PM y estados, órdenes por categoría con coste y motivo de bloqueo, objetivos marcados por bando y cancelables, opciones en un menú. Exploración con lugar y objetivo, menú del grupo, avisos breves y botón de interacción; diálogos con placa de hablante. Fuentes Cinzel y Alegreya Sans (OFL). Mismas reglas y textos. 16:9, 19,5:9 y 960×540 comprobados. **1076 comprobaciones, cero fallos**; las 1043 anteriores se mantienen.

**Iteración 1.4 — Grupo HD (activo por defecto):** [cómo se monta, licencia y límites](docs/PARTY_HD.md) · [combate](docs/previews/party-hd/hd-battle-1280x720.png) · [grupo](docs/previews/party-hd/hd-party.png). Kael, Lyra y Nira semirrealistas, a juego con el bosque HD. Se montan con piezas gratuitas de Quaternius (cuerpo, traje, pelo y animaciones), recoloreadas, con espada y bastones propios. Por la licencia, esos archivos **no se suben a Git**: hay que descargarlos a mano y montarlos con `tools/install_quaternius.py` y `tools/blender/build_party_hd.py`. Sin ellos, el juego usa los modelos anteriores sin dar error. `party/style="current"` en `[visuals]` vuelve a los anteriores. Lyra y Nira siguen a Kael por el mapa (solo presentación) y la cámara de combate está más cerca. Mismas reglas, posiciones y física. **1043 comprobaciones, cero fallos** con los paquetes instalados (998 sin ellos); las 994 anteriores se mantienen. Mismo rendimiento que antes dentro del margen de medida; móvil no medido.

**Iteración 1.3 — Bosque HD (activo por defecto):** [qué cambia, licencias y límites](docs/FOREST_HD.md) · [capturas](docs/previews/forest-hd/). Renderer Forward+ con cielo HDRI, sombras suaves, SSAO/SSIL, niebla volumétrica, bloom y profundidad de campo; árboles, rocas, suelo y texturas fotoescaneados de Poly Haven (CC0); hierba instanciada con viento; Centinelas de roca escaneada y arena de batalla nueva. Misma jugabilidad, colliders, cámaras e historia. `forest/hd=false` en `[visuals]` vuelve a 1.1. **994 comprobaciones, cero fallos**; las 966 anteriores se mantienen. Personajes renovados en 1.4. En gráfica integrada: ~40 FPS en exploración y ~55 en batalla (1280×720); móvil no medido.

**Experimento: protagonistas estilo modelo de combate PS1 (1.2) — NO activo por defecto:** [guía, presupuestos, evaluación y límites](docs/PARTY_PS1.md) · [actual frente a experimental](docs/previews/party-ps1/comparison.png) · [caras](docs/previews/party-ps1/faces.png) · [movimiento](docs/previews/party-ps1/motion-strip.png). Variantes originales de Kael, Lyra y Nira inspiradas en los principios de los modelos de combate de FFVII/FFVIII: piezas rígidas esculpidas, ~5,7 cabezas, cara pintada, atlas 512 y 2 superficies (6,8–8k triángulos). Generadas por `tools/blender/build_ps1_party.py` en `assets/characters/*/ps1/`. Para probarlas, añadir `party/style="ps1"` en `[visuals]` de `project.godot`. Ganan en carisma facial y pelo y pierden en detalle de vestuario, así que **se recomienda mantener los modelos actuales**. **966 comprobaciones, cero fallos**; las 820 anteriores se mantienen. Rendimiento móvil no medido.

**Bosque del Eclipse renovado (1.1) — activo por defecto:** [informe, presupuestos y límites](docs/FOREST_ART.md) · [antes/después real en Godot](docs/previews/forest/comparison.png) · [vistas del claro](docs/previews/forest/views.png). El claro de pruebas pasa a ser un bosque estilizado compuesto: sendero que sigue la misión, árbol anciano sobre una plaza de ruinas como foco, columnas con hiedra, taludes, bosque denso con neblina, luz cálida y motas mágicas discretas. Kit original de Blender (`tools/blender/build_eclipse_clearing.py`), sin assets externos; MultiMesh y shaders opacos para móvil. Cámara fija en perspectiva moderada, mismos controles. Mismos 18 colliders, anclas, encuentros y narrativa. **F5** para jugarlo; `visuals/forest/renovated=false` recupera el escenario anterior. **820 comprobaciones, cero fallos**: las 777 anteriores se mantienen. Rendimiento móvil no medido.

**Lyra y Nira — GLB activos en batalla:** [diseño, pipeline, métricas y límites](docs/LYRA_NIRA.md) · [antes/después real en Godot](docs/previews/companions/comparison.png) · [animaciones](docs/previews/companions/motion.mp4). Dos modelos originales con siluetas propias, fuentes Blender, atlas 1024 y siete clips por personaje; Cast para Lyra y Support para Nira. Kael `retro`, escenario y reglas se conservan. **F8 y después F6 en `scenes/battle_3d.tscn`** para verlos. **777 comprobaciones, cero fallos**; las 647 anteriores se mantienen. Mejoran los modelos previos, con rostros y deformaciones todavía sencillos y rendimiento móvil pendiente de medir.

**Kael retro JRPG — versión activa:** [informe y límites](docs/KAEL_RETRO.md) · [rostro antes/después](docs/previews/kael-retro/face-comparison.png) · [comparación en juego](docs/previews/kael-retro/comparison.png) · [vídeo](docs/previews/kael-retro/motion.mp4). Se edita el modelo guardado: cabeza y ojos más legibles, rostro menos alargado y materiales más limpios. **F8 y después F5** para cargarlo; visor `scenes/kael_retro_preview.tscn` con F6. **647 comprobaciones, cero fallos** en headless y render real. La mejora en cámara lejana es moderada; aprobación artística y rendimiento móvil pendientes.

**Pulido anterior — conservado como comparación:** [cambios, pruebas y límites](docs/KAEL_POLISH.md) · [antes/después en Godot](docs/previews/kael-polish/comparison.png) · [vídeo](docs/previews/kael-polish/motion.mp4). Se conserva el diseño de referencia y se corrigen escala, atlas y animaciones. **F8 y después F5** para cargar la versión actual; visor `scenes/kael_polish_preview.tscn` con F6. **624 comprobaciones, cero fallos**, headless y render real. Objetivo móvil pendiente de dispositivo real.

**Piloto local anterior de Kael (9/11/2026):** [resultado, capturas y límites](docs/KAEL_REFERENCE_STUDY.md) · [comparación](docs/previews/kael-reference/comparison.png) · [vídeo de animaciones](docs/previews/kael-reference/motion.mp4). **Histórico: fue activado antes del pulido; ahora se conserva como comparación.** Para compararlo con 0.9, abrir `scenes/kael_reference_preview.tscn` y pulsar **F6**. Su activación permitió evaluarlo y no implicó aprobación artística definitiva. Validación de aquella entrega: **596 comprobaciones, cero fallos**, headless y render real.

**Estudio local posterior:** [comparación de proporciones de Kael](docs/KAEL_PROPORTION_STUDY.md). Se remodeló una copia de la malla 0.9 y se capturó en Godot. No alcanzó la referencia artística solicitada y **no está activada en el juego**; no se ha adquirido ni generado un modelo mediante servicios externos.

**Iteración 1.0 — investigación de assets:** [dirección artística y comparación](docs/ART_DIRECTION.md), [licencias y procedencia](docs/ASSET_LICENSES.md). Se deja de generar protagonistas desde cero mediante geometría procedural. No se ha incorporado ningún modelo externo: los candidatos más próximos requieren compra o aclaraciones de licencia. En aquella entrega se utilizaba Kael 0.9 y los modelos provisionales; las capturas antiguas no representan una renovación 1.0.

Se corrigió la importación de su atlas: `assets/characters/kael/kael.glb.import` usa `gltf/embedded_image_handling=3` (Embed as Uncompressed). El valor anterior 1 extraía una textura auxiliar; si faltaba, Kael podía caer al procedural. Reimportar con `godot --headless --path . --editor --import` para regenerar la caché. Mallas/GLB, combate, exploración y narrativa se conservan. Validación: 576 comprobaciones, cero fallos; detalle del fallo inicial y recuperación en el informe.

Prototipo 0.9 para Godot 4 (verificado con 4.7.2). Abrir `project.godot` y pulsar **F5** para jugar «La expedición perdida», o F6 con `scenes/forest_exploration.tscn` abierta. Para probar solo combate, abrir **`scenes/battle_3d.tscn` y pulsar F6**. El respaldo 2D `scenes/battle.tscn` también se puede ejecutar con F6.

Versiones: **0.5**, primer claro explorable; **0.6**, renovación visual; **0.7**, primera misión narrativa. Esta numeración corrige el título repetido de la entrega visual anterior.

## Kael: revisión artística y atlas (0.9)

Dirección: aventurero original de fantasía, azul marino y cuero cálido, metal discreto, silueta ligeramente caricaturesca. Cambios frente a 0.8: mandíbula/mejillas/frente construidas con anillos compartidos, ojos almendrados poco salientes con párpado y cejas, nariz con puente y punta, boca cerrada; cabello en mechones barridos con cresta longitudinal; mangas con codos, guantes con palma/pulgar/nudillos, botas con empeine/suela/caña; faldones separados, pechera curva, correa conformada sobre ella, hebilla y bolsa con solapa; espada con guarda curva, agarre envuelto y canal de hoja.

El análisis inicial se hizo abriendo el `.blend` real y capturando cuerpo/rostro antes de modificarlo. Cinco problemas prioritarios: facciones planas y ojos salientes, cabello en bloques, manos redondeadas, vestuario sin suficiente separación y materiales planos en demasiadas superficies. El nuevo atlas añade gradientes, sombras suaves, trama de tela, variación de cuero, costuras, vetas de cabello y matices metálicos. Es pintura **procedural determinista**, no una textura pintada manualmente por un artista ni un servicio de generación externo.

**Histórico: 0.9 fue la versión predeterminada** en batalla y exploración. Actualmente se utiliza `polished`. Esta revisión histórica no alcanzó el objetivo artístico del usuario y no es una referencia comercial aprobada. Se conserva como respaldo funcional mientras se evalúan recursos externos según la investigación 1.0. No se han cambiado otros personajes, mecánicas ni historia. La narrativa de 0.7 continúa provisional, no canon.

### Comparación y selección de versiones

- [Lámina 0.8 / 0.9](docs/previews/kael09-comparison.png), compuesta dentro de Godot a partir de capturas reales.
- Cuerpo: [0.8](docs/previews/kael09-before-full.png) / [0.9](docs/previews/kael09-after-full.png).
- Rostro: [0.8](docs/previews/kael09-before-face.png) / [0.9](docs/previews/kael09-after-face.png).
- Batalla: [0.8](docs/previews/kael09-before-battle.png) / [0.9](docs/previews/kael09-after-battle.png).
- Poses nuevas: [Attack](docs/previews/kael09-attack.png), [Walk](docs/previews/kael09-walk.png), [Hurt](docs/previews/kael09-hurt.png), [Defend](docs/previews/kael09-defend.png), [KO](docs/previews/kael09-ko.png).

El encuadre, iluminación y escala son iguales para cada pareja. En Ajustes del proyecto, cambiar `visuals/kael/asset_version` de `"0.9"` a `"0.8"` para volver al GLB anterior en **ambos modos**. Sus `.blend`, GLB y manifiesto se conservan en `assets/characters/kael/v08/`. Cambiar `visuals/kael/use_imported` a `false` recupera, por separado, el modelo procedural de 0.6. Un `kael_asset_path` personalizado tiene prioridad sobre el selector de versión.

### Pipeline reproducible y edición

Se ejecutó realmente Blender **5.2.1 LTS** local después de comprobar que MCP no estaba operativo. `build_kael.py` abre la fuente archivada 0.8, conserva exactamente rig y Actions y sustituye únicamente cuerpo/espada. `kael_art.py` define geometría y atlas; `MeshBuilder` asigna las UV y agrupa las 14 zonas de color en dos materiales glTF sencillos (tela/cuero y metal). No se regeneran ni retocan las animaciones para adaptar gameplay.

Desde la raíz, PowerShell:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$godot = 'C:\Users\aleja\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_kael.py
& $godot --headless --path . --editor --import
& $godot --headless --path . --script res://tests/test_battle.gd
& $godot --path . --script res://tools/capture_kael09.gd
& $godot --headless --path . --script res://tools/measure_kael.gd
```

Revisar código de salida 0 en cada comando. **Regenerar sobrescribe el Kael actual y el atlas**; no modifica la copia 0.8. Para editar formas, modificar `build_body`, `head`, `hair`, `lock` y `build_sword` en `kael_art.py`; la paleta base permanece en `build_kael.py`. Para editar matices/costuras, usar `painted_materials()` o pintar `kael_atlas.png` manualmente y recargar/empaquetar la imagen dentro del `.blend`. El atlas usa una cuadrícula 4×4 en el orden de `PALETTE`; UV con margen para evitar sangrado. No hay transparencias ni shaders específicos de Blender.

Para preservar retoques manuales: guardar `assets/characters/kael/kael.blend` y ejecutar solo:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/export_kael.py
& $godot --headless --path . --editor --import
```

Se ha comprobado reapertura y reexportación del `.blend`: conserva las seis Actions, UV, materiales e imagen empaquetada; el GLB reexportado coincide con el generado. El GLB incluye un PNG en su buffer, sin rutas externas. El PNG separado es fuente editable; el runtime no depende de su ruta ni de Blender. El manifiesto registra hashes de ambas fuentes Python, atlas, `.blend`, GLB y fuente 0.8, además de los recuentos reales.

### Presupuesto y comprobaciones

| Medida | Kael 0.8 | Kael 0.9 |
|---|---:|---:|
| Triángulos | 3528 | **6618** |
| Vértices de autor | 1892 | **3591** |
| Vértices exportados, tras UV/normales/material | — | **8696** |
| Mallas / huesos / clips | 2 / 17 / 6 | **2 / 17 / 6** |
| Superficies | 17 | **4** |
| Materiales compartidos | 14 | **2** |
| Atlas | ninguno | **1 × 1024²** |
| GLB | 195.020 bytes | **1.390.436 bytes ≈1,33 MiB** |

El atlas PNG ocupa 828.476 bytes; la fuente `.blend`, 1.066.258 bytes. Medición con `GLTFDocument.append_from_file()` + `generate_scene()` en Godot headless: **26,03 ms** en este equipo, excluyendo arranque del editor, generación de LOD y cualquier prueba móvil. El atlas decodificado observado es RGB8, **3 MiB CPU sin mipmaps**; como presupuesto conservador GPU, RGBA8 serían 4 MiB, o aproximadamente 5,33 MiB con cadena completa de mipmaps. No se ha medido VRAM real, FPS en dispositivo ni equivalencia entre menos superficies y mejor rendimiento global.

El modelo queda por debajo de 8000–12000 triángulos preferidos y no necesita acercarse al límite de evaluación de 15000. Las 558 comprobaciones previas se conservan sin cambiar expectativas; **576 totales, 0 fallos**, en headless y con render real. Las 18 nuevas verifican fuentes/hashes, comparación de versiones, poses y claves originales, atlas embebido, UV, pesos, materiales opacos y presupuesto de geometría realmente importada. Los seis clips siguen siendo Idle, Walk, Attack, Hurt, Defend y KO. Las duraciones importadas incluyen el fotograma adicional de 30 fps ya presente en 0.8; no se cambia el tempo de combate.

### Límites y trabajo artístico manual pendiente

La cara aún tiene planos visibles en mejillas/mentón, expresión fija y detalles finos poco legibles desde la cámara de batalla. Cabello de mechones simplificados; manos sin dedos articulados; ropa por secciones y atlas reutilizado, sin UV facial pintada de forma única. Falta esculpir/ajustar manualmente mejillas, comisuras, transición de nariz, implantación del cabello, nudillos y caída de faldones, además de una pasada de pintura de textura con intención artística. El rig básico no incorpora IK, facial ni mezcla avanzada; sigue siendo posible el deslizamiento de pies y pequeños cruces entre secciones en poses no inspeccionadas.

Se inspeccionaron hombros, codos, rodillas y espada en las capturas de reposo, ataque, caminar, daño, defensa y KO; no se observaron separaciones graves. También se ejecutó la suite con render real, incluyendo eventos, reinicio, exploración y las resoluciones existentes. Esto no es una certificación fotograma a fotograma. No se han corregido aquí detalles de presentación previos ajenos al arte, como el oscurecimiento procedural que no tiñe los materiales del GLB.

El pipeline es adecuado como **base técnica reproducible** para los próximos personajes. No conviene replicar automáticamente las fórmulas de cara/cabello y esperar calidad comercial: cada diseño necesita silueta propia, modelado/pintura manual y aprobación artística. Esta entrega mejora Kael; el conjunto de personajes sigue pendiente.

## Historial: primer pipeline Blender → GLB → Godot (0.8)

Los recuentos y ausencia de texturas de esta sección describen la entrega 0.8. Para regenerar y editar la revisión vigente, utilizar la sección 0.9 anterior.

Piloto visual original construido con mallas de secciones perfiladas, pesos normalizados y un Armature de 17 huesos. Cuerpo y espada son dos mallas deformadas por el mismo esqueleto; la espada tiene sus vértices vinculados a `hand.R`. Armadura azul, correas, guantes, botas, rostro con volumen y mechones sustituyen al Kael procedural en batalla y exploración. Lyra, Nira, Centinela, reglas e historia permanecen como estaban. **La historia de 0.7 es provisional y no constituye canon.**

Blender MCP no estaba accesible; se ejecutó realmente **Blender 5.2.1 LTS local**, en un proceso independiente. Se generaron y comprobaron `assets/characters/kael/kael.blend` y `kael.glb`; también se reabrió el `.blend` y se reexportaron correctamente las seis acciones. Godot **4.7.2** importa el GLB por su importador nativo. El juego no necesita Blender instalado: la importación automática de `.blend` está desactivada solo en este proyecto, para evitar dos pipelines distintos.

Desde la raíz del repositorio, en PowerShell:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$godot = 'C:\Users\aleja\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_kael.py
& $godot --headless --path . --editor --import
& $godot --headless --path . --script res://tests/test_battle.gd
```

Cada comando debe terminar con código 0. `build_kael.py` **regenera y sustituye** la fuente y el GLB: guardar primero cualquier edición artística que se quiera conservar. No abre ni reemplaza una sesión interactiva de Blender, no instala complementos y no cambia preferencias globales. Para editar manualmente, abrir `kael.blend`, guardar los cambios en ese archivo y exportar sin reconstruir geometría:

```powershell
& $blender --background --factory-startup --python-exit-code 1 --python tools/blender/export_kael.py
& $godot --headless --path . --editor --import
```

`kael_manifest.json` registra geometría, huesos, clips y SHA-256 del generador, fuente y GLB. El exportador valida pesos y presupuesto. Las Actions tienen usuario persistente para sobrevivir al guardado/reapertura. GLB lleva materiales y animaciones, sin texturas ni rutas externas.

- **Materiales/geometría:** editar `PALETTE`, `build_body()` y `build_sword()` del generador; las secciones se ensamblan en las dos mallas con skin. Se puede trabajar en Blender y usar solo el exportador para preservar cambios manuales.
- **Animaciones:** el generador histórico creó `Idle`, `Walk`, `Attack`, `Hurt`, `Defend` y `KO` a 30 fps; 0.9 conserva esas Actions desde la fuente archivada. Idle/Walk son ciclos; Defend/KO mantienen su pose final. Para añadir un clip en otra entrega, conservar su Action al guardar, incluirlo en el contrato del exportador y conectarlo explícitamente en `KaelModel`/presentación, con una prueba. No crear una habilidad ni regla para justificarlo.
- **Sustituir el asset:** guardar la fuente y exportar sobre la misma ruta, manteniendo `KaelRig`, `KaelBody`, `KaelSword`, nombres de huesos y seis clips; después reimportar. `scenes/kael_model.gd` es el adaptador, sin dependencia del motor de combate. El campo `kael_asset_path` de `BattleActorVisual` permite probar otra exportación compatible.
- **Fallback:** cambiar `visuals/kael/use_imported` a `false` en Ajustes del proyecto (o en la sección `[visuals]` de `project.godot`). Para una escena, desmarcar `use_imported_kael` en el nodo raíz de batalla o en Player. Si falta el GLB o su contrato de esqueleto/clips/espada, se informa mediante advertencia comprensible y se crea el modelo anterior; no se sustituyen los otros personajes.
- **Replicar con otro personaje posteriormente:** usar el patrón fuente + exportación + adaptador por instancia, con su propia malla, pesos y clips. Reutilizar el contrato de eventos existente, sin copiar reglas ni construir ahora un framework de personajes. Esta entrega solo genera Kael.

### Comparar y probar

Comparaciones de render real con idéntico encuadre: [antes](docs/previews/kael-before.png), [después](docs/previews/kael-after.png), [detalle anterior](docs/previews/kael-before-detail.png), [detalle nuevo](docs/previews/kael-after-detail.png). Se pueden regenerar sin `--headless`:

```powershell
& $godot --path . --script res://tools/capture_kael.gd -- --output docs/previews
```

En F6 sobre la batalla, Defender con Lyra deja actuar a Kael: usar Ataque/Golpe potente para ver Attack, Defender para Defend y resolver el enemigo para Hurt. KO se reproduce al caer; reiniciar durante una acción restaura Idle. Omitir animación presenta el estado ya calculado. En F5, omitir/cerrar la introducción, caminar con WASD/flechas y detenerse para alternar Walk/Idle. Los diálogos siguen bloqueando movimiento. Alternar fallback permite comparar también dentro del juego.

Validación: **507 comprobaciones previas conservadas; 558 totales, 0 fallos**, tanto headless como con render real. Las 51 nuevas verifican importación, hashes, contrato, skin de espada, poses, independencia de instancias, fallback, reinicio, invariancia de PV/PM/RE/estados y movimiento. También se inspeccionaron capturas reales de Attack, Walk, Hurt, Defend y KO, además del antes/después; las pruebas técnicas por sí solas no certifican calidad artística.

Coste aproximado: **3528 triángulos**, **1892 vértices de autor** (el importador puede duplicarlos por materiales/normales), 17 huesos, 6 clips, dos mallas y 17 superficies de material en total. GLB ≈190 KiB, fuente ≈197 KiB. La animación ósea añade trabajo frente a los gestos procedurales; el número de superficies implica varias llamadas de dibujo, aunque no hay texturas ni sistemas nuevos. Presupuesto preventivo de 7000 triángulos, no una garantía de rendimiento móvil: **todavía no se han medido FPS ni probado dispositivos Android/iOS**.

Limitaciones: arte piloto, manos sin dedos articulados, rostro sin animación facial, locomoción sin IK y posible deslizamiento de pies; no hay mezcla avanzada ni transiciones específicas entre todos los clips. La mejora se aprecia en proporciones, silueta y ropa frente al anterior, pero no es un modelo artístico definitivo. No se observaron separaciones ni deformaciones graves en las poses inspeccionadas; falta QA exhaustiva de todos los fotogramas y cámaras.

## Jugar «La expedición perdida» de principio a fin (0.7)

1. Lee la introducción «El Bosque del Eclipse». Avanza con **Continuar, Espacio o Enter**, o pulsa **Omitir introducción** para empezar directamente. El movimiento permanece bloqueado mientras se conversa.
2. Camina con **WASD/flechas**. El objetivo inicial es «Investiga el claro». Acércate a un objeto hasta que aparezca su nombre y pulsa **E** o el botón **Examinar**.
3. Encuentra las tres pistas, en cualquier orden: **campamento abandonado** justo al norte del inicio, **fragmento de cristal** a la derecha del sendero e **inscripción antigua** junto a la columna izquierda del fondo. Las conversaciones revelan una insignia, un pulso desconocido y una barrera antigua; no hay objetos de inventario ni premios por examinarlas.
4. Derrota a los **dos Centinelas** existentes, antes, después o entre las investigaciones. Escarcha aprovecha su debilidad al hielo; usa Golpe potente, Cura e Ignar cuando corresponda. Al volver, las pistas y la posición se conservan. Una derrota permite reintentar o regresar al inicio sin borrar la misión.
5. Con las tres pistas y las dos victorias, el objetivo pasa a **«Examina la anomalía junto a las ruinas»**. Aparece un resplandor entre las columnas, al fondo del claro. Acércate y examínalo para la revelación breve.
6. Al terminar la conversación aparece **«La expedición perdida · Completada»** y el anuncio de continuación bajo las ruinas. No se entra todavía en otra zona. Se pueden volver a examinar las pistas y la anomalía con textos breves, sin repetir el final ni sus efectos.
7. **Nueva partida** reinicia misión, introducción, encuentros, RE y PA. Todo el progreso vive en memoria; no existe guardado en disco.

El seguimiento del objetivo es discreto y no obliga a seguir un orden de flechas. La anomalía exige las tres pistas y los dos encuentros; su conversación se inicia por interacción cercana, no desde cualquier punto del mapa. El cierre no concede recompensas: los +50 PA por cada victoria siguen siendo los únicos premios existentes. PV/PM máximos por encuentro/reintento se conservan como simplificación de 0.5.

Contenido y posiciones: `narrative/expedition_story.gd`. Condiciones/progreso: `ExpeditionMission` dentro de `GameSession`. `DialogueBox` presenta y avanza líneas; `NarrativeInterest` gestiona alcance e indicador. El claro conecta estas piezas mediante señales locales, sin un framework de quests ni dependencias narrativas en `BattleEngine`. Los datos de diálogo admiten ampliar campos para retratos/audio posteriormente; todavía no se implementan.

Duración objetivo: 5–10 minutos según lectura y decisiones de combate, sin esperas artificiales. Las pruebas aceleradas no equivalen a una medición de duración con jugadores. No hay ramas de diálogo, localización completa, retratos, voces, nueva zona ni resolución de la identidad de la fuerza.

Capturas reales: [introducción](docs/previews/mission-intro.png), [revelación](docs/previews/mission-revelation.png).

## Renovación visual de la batalla (0.6)

- Héroes originales completos con rostros, cabello, extremidades, vestuario y armas: Kael con armadura/espada, Lyra con capa violeta/bastón y Nira con atuendo crema/verde y vara natural. El Centinela es un gólem facetado con piernas, grandes brazos, musgo, ojos y grietas luminosas.
- Arena de ruinas en el bosque: pavimento irregular, musgo, hierba, rocas, árboles y columnas. Cámara diagonal en perspectiva, luz cálida, ambiente suave y una sombra direccional acotada.
- PV/PM en tres tarjetas inferiores, nombres mínimos en 3D y comandos de 48 unidades lógicas de altura. Elegir una habilidad sustituye el panel de comandos por los objetivos; el aro azul indica el objetivo y «Atrás» cancela sin gastar recursos.
- **Registro** abre todo el historial del motor en un panel con desplazamiento; **Cerrar registro** recupera la arena.
- **Cámara suave** activa/desactiva acercamientos e impactos. **Omitir animación** presenta inmediatamente el resultado ya resuelto por el motor, incluso durante una invocación. La velocidad también se configura con `animation_time_scale` en el nodo de la batalla.
- Fuego: proyectil cálido; hielo: cristal y fragmentos; curación: luz y motas ascendentes; físicos: avance y gesto de arma. Reposo con respiración/capas, defensa persistente, interceptación y caída simple siguen conectados a eventos.
- Ignar es un titán de roca volcánica con grietas de lava, gran tamaño, círculo de aparición y Juicio de Ceniza sobre todos los enemigos. No cambian su coste ni los efectos de gameplay.

Para invocarlo sin trucos: usar Defender con los tres héroes durante dos rondas, resolver al enemigo y pulsar **Invocar** con Lyra al alcanzar 100 RE. Véanse también las instrucciones de curación y Protección más abajo.

Capturas reales del prototipo: [batalla](docs/previews/battle.png), [Ignar](docs/previews/ignar.png). El arte, poses y efectos siguen siendo provisionales; faltan modelos y animaciones definitivos, rigging, audio y pruebas móviles reales. No se han añadido mecánicas, assets externos ni servicios de generación.

## Primera zona explorable (0.5)

1. Cerrar u omitir la nueva introducción y mover a Kael con **WASD o flechas**. El resto del grupo participa en los combates, pero no tiene seguidores visuales todavía. No hay salto ni cámara libre.
2. Acercarse al círculo naranja del **Centinela I** o **Centinela II**. La detección es local; abre la batalla 3D existente. Los árboles, rocas, columnas y muros tienen colisión; no se puede salir del claro.
3. Elegir acciones y objetivos normalmente. Para ganar, aprovechar Escarcha contra la debilidad al hielo, Golpe potente de Kael, Cura de Nira e Ignar cuando alcance 100 RE. Resolver los turnos enemigos con su botón.
4. Tras ganar, se vuelve automáticamente al claro al terminar la animación. Se conserva la posición, desaparece ese Centinela y permanecen RE, vínculos y PA. Combatir contra el segundo permite comprobar la continuidad y alcanzar nivel 2 de Ignar tras dos victorias.
5. En derrota, elegir **Reintentar combate** o **Volver al claro**. Volver deja al grupo en el punto inicial y mantiene al enemigo disponible; no concede PA. El botón de retorno se habilita solo después de resolver la derrota y su presentación.
6. Tras vencer a los dos enemigos el claro queda despejado, pero en 0.7 todavía hay que reunir las pistas y examinar la anomalía para completar la misión. **Nueva partida** reinicia también su introducción. En los encuentros integrados no aparece el botón que creaba una partida de combate independiente.

**Simplificación de recursos:** cada encuentro y cada reintento comienzan con PV/PM máximos; no se conserva desgaste entre combates. Esta decisión usa la estructura actual del motor y evita añadir de forma implícita curación de campo, inventario o progresión de personajes. RE/PA/vínculos sí se conservan con el mismo `PartyState`. Todo vive en memoria; cerrar el juego lo reinicia.

`GameSession` guarda el grupo configurado, `PartyState`, modo actual, posición de retorno y encuentros derrotados. `game_flow.gd` retira temporalmente el claro del árbol y configura la escena 3D existente con esos datos. Después recupera el mismo claro: no hay un segundo motor ni un sistema de guardado.

Los dos encuentros están definidos como Resources `EncounterData` dentro de `scenes/forest_zone.tscn`: ID, etiqueta, posición, radio y array de enemigos. Pueden editarse en el inspector; la prueba de combate sigue aceptando varios enemigos. Cada ID debe ser único dentro de la zona.

La velocidad se configura en `world/exploration_player.gd`. `set_movement_input(Vector2)` permite alimentar el movimiento desde futuros controles táctiles; `clear_movement_input()` vuelve al teclado. Todavía no hay joystick táctil, exploración entre varias zonas, más misiones, guardado real ni recursos definitivos.

Seleccionar una acción y un objetivo. Los botones de habilidades sin PM se desactivan. Resolver el turno enemigo con su botón. El registro muestra los resultados; Reiniciar permite repetir el combate.

## Comprobar la batalla 3D (0.4)

- La arena usa geometría low-poly nativa y cámara diagonal en perspectiva. Kael (azul, espada), Lyra (violeta, bastón) y Nira (verde/crema) están a la izquierda; el Centinela está a la derecha. Tarjetas muestran PV/PM; nombres e indicadores mínimos quedan en 3D. El aro dorado identifica al actor activo.
- **Ataque:** seleccionar Ataque y Centinela. El actor avanza brevemente, aparece un impacto y se muestra la pérdida real de PV enviada por el motor.
- **Magia y debilidades:** Llama produce destellos naranjas y causa 14 contra el Centinela resistente; Escarcha produce destellos azules y causa 36 contra su debilidad. Comparar tras «Nueva partida» para mantener nivel 1 y los mismos datos.
- **Curación:** después del ataque enemigo, usar Cura de Nira sobre Kael. Ver reacción verde, texto de PV recuperados y actualización de la etiqueta.
- **Defender:** elegirlo y seleccionar al propio actor. Su escudo azul y etiqueta persisten hasta que el motor retire la defensa al comenzar su siguiente turno.
- **Protección:** con Kael, seleccionar Protección y a Kael. Al resolver al enemigo, ver desplazamiento de interceptación, «¡Protección!» y daño de 7. Al proteger a otra aliada, las etiquetas y un enlace azul identifican protector y objetivo. La IA sigue atacando al primer héroe vivo: la interceptación contra Lyra se verifica por API en las pruebas, sin cambiar esa regla.
- **Inconsciencia:** al llegar a 0 PV el modelo queda tumbado y su etiqueta lo indica. Victoria/derrota siguen dependiendo exclusivamente del motor.
- **Ignar:** completar las dos rondas de Defender descritas abajo y pulsar Invocar. Una manifestación naranja con cuernos aparece entre ambos bandos; Juicio de Ceniza produce impactos sobre cada enemigo vivo, texto de daño y `DEF ↓`, y luego se retira. El estado de Defensa reducida permanece en las etiquetas.

La cabecera indica la acción que se está presentando y después el turno siguiente. Los botones de acción/objetivo se bloquean durante la secuencia breve; reiniciar y crear partida siguen disponibles. Reiniciar cancela cualquier secuencia pendiente. No hay decisiones lógicas en las animaciones.

La UI conserva controles de al menos 48 unidades lógicas de altura y registro completo opcional. La renovación se revisa con render real en 960×640, 1280×720 y 800×450, además de comprobar los límites de botones automáticamente. Orientación, controles y rendimiento en dispositivos Android/iOS reales quedan pendientes; no se ha exportado a móvil.

## Comprobar Resonancia e Ignar (0.3)

1. Pulsar «Nueva partida (RE/PA a cero)»: RE 0, Ignar vinculado a Lyra, nivel 1 y 0 PA.
2. Elegir Defender con los tres héroes y resolver al enemigo durante dos rondas. Cada ronda genera 45 RE por Defender y 5 por el impacto enemigo: al comenzar la tercera ronda hay 100 RE.
3. Con Lyra pulsar «Invocar · 100 RE». Juicio de Ceniza causa 20 de fuego al Centinela resistente, reduce su DEF de 12 a 9 y deja RE en cero. Lyra conserva sus PM y termina su turno. El registro y el mensaje muestran la invocación.
4. Golpear con Kael: Ataque causa 15 en vez de 12 mientras siga la reducción. Expira al finalizar las dos rondas completas posteriores a invocar.
5. Ganar un combate usando habilidades y Cura: Ignar gana 50 PA aunque no haya sido invocado. «Reiniciar combate» inicia otro combate conservando RE, PA y vínculo; tras dos victorias tiene 100 PA y nivel 2. No concede PA abandonar un combate con ese botón.
6. «Nueva partida» vuelve a cero RE/PA y restaura el vínculo a Lyra. No se escribe guardado en disco.

La barra y la etiqueta muestran RE, portador, nivel y PA. Los cuatro niveles de Ignar y sus cálculos están en [docs/GDD.md](docs/GDD.md). No hay selector visual de portador todavía: el cambio fuera de combate y las pasivas están disponibles en la API y cubiertos por pruebas.

### Estado entre combates y vínculos

```gdscript
var run := PartyState.test_party() # Ignar -> Lyra; RE/PA cero
var battle := BattleEngine.new()
battle.start(heroes, enemies, run)
# Después de victoria/derrota, o de battle.abort():
run.equip("ignar", "kael") # conserva PA, desactiva pasivas de Lyra
var next_battle := BattleEngine.new()
next_battle.start(heroes, enemies, run) # misma RE y progreso
```

`heroes` y `enemies` son arrays de `CombatantData`; los héroes tienen IDs estables. `equip()` y `unequip()` devuelven errores durante combate sin alterar el vínculo. `summon()` valida turno, portador, RE y datos antes de cualquier efecto. Las definiciones se registran mediante `GuardianData`, su progreso se guarda aparte en `GuardianProgress`. `PartyState.new()` crea una partida vacía para pruebas sin Guardianes.

## Comprobar la iteración 0.2

- Con Lyra, usar Llama (`fire`): el Centinela resiste y pierde 14 PV. Reiniciar y usar Escarcha (`ice`): es débil y pierde 36 PV. Los botones indican los elementos.
- Después del turno de Lyra, usar Protección de Kael sobre sí mismo y resolver al enemigo: Kael pierde 7 PV en lugar de 14. El registro identifica la interceptación y los cambios de PV/PM. Protección gasta 5 PM; Defender es una acción diferente.
- También se puede elegir a Lyra o Nira como objetivo de Protección. La IA provisional ataca siempre al primer héroe vivo, por lo que no atacará a esas aliadas mientras Kael siga vivo. La interceptación de ataques contra otras aliadas, la magia, la expiración y la exclusión de área están cubiertas por pruebas automatizadas.

## Comprobaciones

Desde la raíz, sustituyendo `godot` por la ruta del ejecutable local si no está en PATH:

```powershell
godot --version
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_battle.gd
godot --headless --path . --quit-after 5
godot --path . --quit-after 60
```

El punto de entrada conserva las 348 comprobaciones anteriores y añade `tests/visual_refresh_checks.gd`: asociación de modelos, agrupación geométrica, orientación, UI en tres resoluciones, objetivo/cancelación, registro completo, cámara y omisión/reinicio durante Ignar sin modificar resultados. También siguen ejecutándose los casos de motor, Guardianes, presentación, respaldo 2D y exploración (dos combates completos, RE/PA, victorias y derrota). No necesita un framework externo. Los datos que las pruebas modifican se copian con `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` para aislar también las habilidades externas precargadas.

Resultado local de esta renovación: **348 comprobaciones antes; 385 después, 0 fallos**, tanto headless como con OpenGL. Importación sin errores y revisión de capturas reales en las tres resoluciones indicadas.

La iteración 0.7 conserva esas **385** comprobaciones y añade `tests/narrative_checks.gd`: introducción/cierre/omisión, teclado real sin doble avance, bloqueo de movimiento, distancia, seis órdenes de pistas, revisitas, victoria/derrota, persistencia, dos combates completos, revelación única y nueva partida. Las pruebas de exploración anteriores ahora omiten la introducción mediante su API para seguir verificando el mismo recorrido, sin retirar ni debilitar sus comprobaciones.

Resultado final de 0.7: **507 comprobaciones, 0 fallos** en headless y con OpenGL. Importación sin errores y capturas revisadas en 960×640, 1280×720 y 800×450. No se han cambiado reglas ni archivos del motor de combate o sus Resources.

El motor se puede instanciar con `BattleEngine.new()` sin SceneTree ni escenas; `start()` recibe arrays de CombatantData y devuelve error o cadena vacía. `act()` valida y devuelve un mensaje de error o cadena vacía; `step_enemy()` resuelve la IA mínima. La escena solo consulta estado y envía acciones. Los Resources originales no se modifican durante el combate. Las afinidades contradictorias se rechazan sin consumir recursos. Ignar usa la ruta de daño de área y publica eventos para futuras animaciones.

Presentación: `battle_stage.gd` consume eventos y administra cámara/cola/VFX; `battle_actor_visual.gd` representa combatientes; `battle_hud_3d.gd` reutiliza el controlador 2D. `stylized_models.gd` construye modelos y agrupa geometría estática por material; `battle_environment.gd` compone la arena. El motor no conoce nodos, materiales, cámara, tweens ni duración de animaciones. Se mantiene Compatibility, una sola sombra direccional y luces de acento sin sombras; no hay postprocesado pesado. Una lectura puntual en este escritorio Intel Arc a 960×640 dio 60 FPS, 176 llamadas de dibujo y 46.592 primitivas (incluidas pasadas de render); no constituye una medición móvil ni una garantía de rendimiento.

Reglas y decisiones: [docs/GDD.md](docs/GDD.md). Cambiar estadísticas y habilidades en los Resources de `data/` desde el inspector. El claro es una zona de prueba autocontenida; no incluye una aventura completa, modelos definitivos, audio ni exportación móvil.
