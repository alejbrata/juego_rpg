# Kael — estudio local de la lámina

Entrega: **9 de noviembre de 2026**. Petición expresa del diseñador: intentar producir el modelo en Blender con la lámina aportada, sin utilizar Tripo, y conservar el resultado en Git. Es una excepción para este piloto a la decisión anterior de abandonar la construcción local mediante scripts; no implica aprobar el resultado ni cambiar la estrategia artística definitiva.

## Resultado y revisión

Se ha construido **una malla nueva**, no otra deformación de Kael 0.9. Se aproxima al diseño mediante proporciones adultas, rostro de superficie continua con nariz integrada, ojos almendrados, cabello en mechones, abrigo azul abierto, capucha/capa, correas, hebillas, guantes, botas, hombrera asimétrica y espada con núcleo azul. La referencia orienta la apariencia: sus nombres de arma, personalidad y otros textos no se incorporan al canon.

**Es un candidato funcional, no un personaje comercial aprobado.** Las formas y el atlas se construyen localmente mediante scripts de Blender. El atlas es pintura algorítmica, no pintura manual ni una textura generada por un servicio externo. El rostro sigue simplificado, la expresión es fija, los mechones aún son rígidos y la ropa carece de pliegues y desgaste suficientemente naturales. El entorno y los demás personajes conservan su estilo anterior, por lo que el conjunto todavía no es coherente.

La versión predeterminada permanece en **0.9**. La fuente y GLB anteriores, el experimento de proporciones y el código de combate permanecen intactos. El candidato se puede activar en ambas presentaciones mediante el selector existente.

- [Comparación de cuerpo y retrato](previews/kael-reference/comparison.png).
- [Cuerpo del candidato](previews/kael-reference/after-full.png) y [rostro](previews/kael-reference/after-face.png).
- [Vídeo real de Godot: seis clips, 12 segundos](previews/kael-reference/motion.mp4).
- [Batalla a 1280×720](previews/kael-reference/after-battle-1280x720.png), [960×640](previews/kael-reference/after-battle-960x640.png) y [800×450](previews/kael-reference/after-battle-800x450.png).
- [Exploración con la cámara del juego](previews/kael-reference/after-exploration.png) y [detalle con cámara acercada](previews/kael-reference/after-exploration-detail.png).

Las parejas `before`/`after` de cuerpo, batalla y exploración comparten cámara y luz. Los retratos de la lámina comparativa se **reencuadran** para que las dos cabezas se vean completas: la cabeza anterior es considerablemente mayor. También se conservan [antes con cámara idéntica](previews/kael-reference/before-face-same-camera.png) y [después con cámara idéntica](previews/kael-reference/after-face-same-camera.png), sin ocultar esa diferencia de tamaño. Los PNG y el vídeo son renderizados por Godot, no ilustraciones del resultado esperado.

## Cómo revisarlo sin sustituir el juego

1. Abrir `project.godot` en Godot **4.7.2** y esperar la importación.
2. Abrir `scenes/kael_reference_preview.tscn` y pulsar **F6**.
3. Utilizar los botones **Cuerpo**, **Rostro**, **Girar / parar** y **Anterior / candidato**. Los botones de animación permiten revisar los seis clips; Attack/Hurt regresan a Idle y Defend/KO mantienen su pose final.
4. **Probar combate** o **Probar exploración** carga el modo correspondiente con la versión que se está viendo. La selección solo afecta a ese proceso; el visor no guarda ajustes de proyecto.

Para seleccionarlo de manera persistente, cambiar `visuals/kael/asset_version` a `"reference-study"` en Ajustes del proyecto. Volver a `"0.9"` restaura el modelo anterior; `"0.8"` conserva su comportamiento previo. El ajuste `visuals/kael/use_imported=false` sigue ofreciendo el respaldo antiguo. Una ruta de GLB personalizada sigue teniendo prioridad.

## Archivos y funciones

| Archivo | Responsabilidad |
|---|---|
| `assets/characters/kael/reference_study/kael.blend` | Fuente editable con mallas, rig y seis Actions |
| `kael.glb`, `kael_atlas.png`, `kael_manifest.json`, en esa carpeta | Recurso de juego, atlas editable y métricas/hashes |
| `tools/blender/kael_reference_mesh.py` | `head`, `hair`, `torso`, `limbs`, `garments`, `sword`: superficies y detalles; `materials`: atlas y materiales |
| `tools/blender/build_kael_reference.py` | `adjust_rig`: reposo adulto; `export`: exportación GLB y manifiesto; `--export-only`: reutiliza la fuente guardada |
| `scenes/battle_actor_visual.gd` | `_build_imported_kael`: añade exclusivamente el valor `reference-study` al selector; la exploración reutiliza ese mismo adaptador |
| `scenes/kael_reference_preview.gd/.tscn` | Visor independiente; `load_character`, `_preview_clip`, `_play`; nunca guarda ajustes |
| `tools/capture_kael_reference.gd` | Capturas de estudio, juego y comparación con verificaciones para no confundir un fallback con el candidato |
| `tools/capture_kael_motion.gd` | Captura de los clips importados mediante AnimationPlayer y Movie Maker de Godot |
| `tests/kael_reference_checks.gd` | 20 comprobaciones nuevas ejecutadas desde `tests/test_battle.gd` |

## Medidas del recurso final

| Medida | Valor |
|---|---:|
| Triángulos exportados/importados | **12.297** |
| Vértices de autor / exportados | 8.184 / 14.830 |
| Huesos | 17 |
| Materiales compartidos / superficies | 3 / 5 |
| Atlas compartido | 1024×1024, embebido en GLB |
| GLB | 1.698.344 bytes, aproximadamente 1,62 MiB |
| Fuente `.blend` | 1.124.089 bytes |
| Atlas PNG | 781.157 bytes |

La malla supera el objetivo preferido de 12.000 triángulos en 297, dentro del límite de evaluación de 15.000. Se conservan el agarre de dedos, la cubierta de cabello posterior y los ribetes tras inspección visual; no se aumenta el presupuesto de otros personajes. El atlas inicial de 2048 se redujo a 1024 y se volvieron a capturar cuerpo y rostro. El coste orientativo de una textura RGBA8 de 1024 es 4 MiB sin mipmaps y unos 5,33 MiB con ellos; **no es una medición de VRAM**.

No hay prueba en Android/iOS ni certificación de rendimiento móvil. La cámara de batalla muestra al personaje bastante pequeño y oscuro; la mejora de encuadre, iluminación y coherencia del resto del elenco queda fuera de este piloto.

## Animaciones y limitaciones

Idle, Walk, Attack, Hurt, Defend y KO provienen de las Actions provisionales de la fuente 0.8, con un nuevo esqueleto de reposo ajustado a la geometría. No se ha exigido mantener las posiciones de huesos antiguas. La espada comparte skin y hueso de mano con el cuerpo; el agarre se ha modelado cerrado.

Se verifica movimiento finito de las seis animaciones y se muestran en vídeo. Eso no equivale a animación final: falta refinamiento de peso, apoyo de pies y transiciones; dedos y rostro no tienen rig propio. La capa y los faldones usan pesos óseos simples, sin simulación de tela ni colisiones secundarias. Puede haber penetraciones en poses extremas; no se declara una validación exhaustiva de todos los contactos.

## Verificaciones ejecutadas

- **Blender 5.2.1 LTS ejecutado realmente**, en proceso local de fondo. La conexión MCP no estaba operativa; no fue necesaria para ejecutar los scripts.
- Exportación inicial y **reexportación al reabrir el `.blend` guardado**, sin regenerar la malla en la segunda operación. El GLB final y su manifiesto son los de esa reexportación.
- Importación real en **Godot 4.7.2**, con `gltf/embedded_image_handling=3`. La fuente Blender usa `importer="keep"`; Godot no intenta importarla además del GLB.
- **576 comprobaciones originales conservadas + 20 nuevas = 596**, cero fallos en headless y con render real (Compatibility, Intel Arc).
- Nuevas comprobaciones: hashes, GLB autosuficiente, skin/pesos/UV/materiales, presupuesto, movimiento de clips, selector en batalla y exploración, reinicio, Walk/Idle y ausencia de cambios de estado de combate por presentación.
- Capturas inspeccionadas: cuerpo, rostro, vistas giradas, poses, batalla en tres resoluciones y exploración. El vídeo contiene 361 fotogramas a 30 FPS; también se inspeccionó una hoja de muestras de movimiento.
- Sin API de generación, compras, descargas de modelos ni envío de la lámina a servicios externos. La prevención temporal de suspensión no equivale a bloquear un cierre de sesión manual o un reinicio.

## Reproducción local

Desde la raíz, usando las rutas de los ejecutables instalados o sus alias:

```powershell
# Reconstruye SOLO el candidato: sobrescribe sus posibles ediciones manuales.
blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_kael_reference.py

# Reexporta el candidato editado/guardado sin reconstruirlo.
blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_kael_reference.py -- --export-only

godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_battle.gd
godot --path . --script res://tests/test_battle.gd
godot --path . --script res://tools/capture_kael_reference.gd

godot --path . --script res://tools/capture_kael_motion.gd --write-movie "$env:TEMP\eclipse-kael-reference-motion.avi" --fixed-fps 30 --audio-driver Dummy
ffmpeg -i "$env:TEMP\eclipse-kael-reference-motion.avi" -an -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart docs/previews/kael-reference/motion.mp4
```

FFmpeg solo codifica el vídeo de revisión; no es una dependencia del juego ni del modelo. El AVI intermedio se guarda fuera del repositorio.
