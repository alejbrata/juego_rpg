# Dirección artística — investigación 1.0

Fecha: **8 de noviembre de 2026**. Resultado: comparación de candidatos y propuesta pendiente, **sin renovación visual integrada**. El juego mantiene los modelos de 0.9 y sus alternativas. La corrección de importación descrita al final resuelve un fallo de textura; no constituye una mejora artística.

## Decisiones confirmadas por el diseñador

Se abandona la generación desde cero de protagonistas mediante geometría procedural. Se preserva como respaldo lo ya construido. Las referencias del usuario apuntan a fantasía estilizada orgánica: anatomía creíble con exageración moderada, ojos/párpados expresivos, cabello con continuidad, ropa con espesor/pliegues y superficies trabajadas. Para el bosque: árboles/raíces curvos, vegetación agrupada, ruinas integradas, luz cálida y profundidad. Ni siluetas de juguete ni cambiar a fotorealismo.

Las referencias orientan acabado y lenguaje visual; no convierten sus atuendos, espada, estatua o expresión en canon. La historia de 0.7 sigue provisional. No se retocan diálogos, enemigos, reglas ni progresión para justificar assets.

## Comparación de rutas

La calidad es una valoración de las imágenes del proveedor, **no una prueba en Godot**. Coste de adaptación: estimación cualitativa de trabajo, no presupuesto profesional. Todos los candidatos están detallados con condiciones y enlaces en [ASSET_LICENSES.md](ASSET_LICENSES.md).

| Familia / candidato | Ajuste artístico y proporciones | Godot / animación | Licencia y coste observado | Adaptación / móvil | Decisión |
|---|---|---|---|---|---|
| [JustCreate Fantasy Characters](https://justcreate3d.itch.io/stylized-fantasy-characters) | Rostro, cabello y ropa más próximos a la referencia; menos infantil; masculino/femenino coherentes | FBX, rig; sin clips incluidos | Propietaria itch.io; 49,99 USD; permisos pendientes | Media/alta: retarget, materiales y medidas reales | **Preferido visual para Kael**, condicionado |
| [JustCreate Mage Characters](https://justcreate3d.itch.io/stylized-fantasy-mage-characters) | Misma familia; candidata para Lyra, con ropa y facciones trabajadas | FBX sin clips; revisar falda/capa | Propietaria; 49,99 USD | Media/alta; shader de otra plataforma no se porta literalmente | Compañero potencial de Kael |
| [JustCreate Nature with Ruins](https://justcreate3d.itch.io/stylized-nature-with-ruins) | Ruinas, masas verdes y siluetas orgánicas; continuidad editorial potencial | FBX; demos no nativas de Godot | Propietaria; 15 USD | Media/alta: reconstruir composición/materiales y medir follaje | Entorno preferido para prueba pequeña |
| [Polyart Adventurer](https://www.fab.com/listings/8ecc05ee-7447-4a8a-af10-1adccc7e8bd2) | Alternativa modular con facial | Anunciado UE; no confirmar FBX independiente | Licencia/tier/precio de adquisición pendientes | Alta dependencia del motor de origen | Reserva, no primera compra |
| [TriForge Fantasy Worlds Forest](https://www.fab.com/listings/7c1ba1b0-8bd3-4af1-9fd3-b7adfc42f908) | Bosque/ruinas ricos y orgánicos | UE, sistemas de materiales específicos | Precio de catálogo desde 69,99 USD; licencia concreta pendiente | Alta: no trasladar Lumen/virtual texturing al móvil | Referencia ambiental; no compra prioritaria |
| Quaternius [bases](https://quaternius.com/packs/universalbasecharacters.html) + [atuendos](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html) + [naturaleza](https://quaternius.com/packs/stylizednaturemegakit.html) | Familia económica coherente; hay que validar facciones/ropa frente al objetivo, no basta reunir piezas | Formatos de intercambio anunciados; retarget necesario | Standard gratuito; contradicción publicada CC0/QAL | Media; métricas de archivos no verificadas | Reserva hasta resolver licencia y evaluar arte |
| [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) | Diseño consistente y acabado cuidado, pero facciones y proporciones de miniatura | FBX/glTF; rig/movimiento | Free CC0 | Menor adaptación, atlas ligero anunciado | Legalmente viable; **no es la dirección solicitada** |
| [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | No acreditado el acabado buscado; no sustituir un blockout con otro | Archivos no inspeccionados | CC0, gratuito | Sin medidas propias | No elegido como renovación final |
| [Uricaro97 Stylized Warrior](https://sketchfab.com/3d-models/stylized-warrior-2ed26f7a03a044e69858c83e26cf368a) | Personaje trabajado; no evaluado en motor | Rig/archivos no verificados | CC BY 4.0, gratuito | **Muy alta**: 292.178 triángulos anunciados | No piloto móvil inmediato |
| [piacenti Earth Elemental / Golem](https://opengameart.org/content/earth-elemental-golem) | Alternativa pétrea para enemigo; coherencia por revisar | Blender/FBX y 10 clips anunciados | CC BY 3.0, gratuito | Media; 3872–3882 triángulos del proveedor | Evaluar después de fijar protagonistas |

## Propuesta concreta para decidir

Primera opción artística: familia **JustCreate Fantasy Characters + Mage Characters**, con **Nature with Ruins** para una muestra compacta. Kael usaría la base masculina; Nira podría partir de la aventurera femenina diferenciada en silueta y tonos; Lyra tendría su atuendo de maga. Son propuestas, no diseños aprobados. El gólem permanece abierto: no comprar un monstruo que rompa el conjunto solo por completar la lista.

Precios itch.io consultados: **49,99 + 49,99 + 15 = 114,98 USD**, antes de impuestos y sin animaciones/trabajo. La **primera compra eventual sería solo el piloto de 49,99 USD**, no el conjunto entero. La semejanza con las referencias debe juzgarse mirando las imágenes originales enlazadas; sus renders promocionales no garantizan ese resultado en nuestro motor.

Hay dos bloqueos separados: autorización del propietario para gasto/dirección y aclaración del **editor** sobre el flujo asistido por IA, colaboradores y contrato completo. La licencia itch.io prohíbe usar sus assets como entrada de programas de IA/ML sin permiso escrito. No se interpreta una autorización de gasto como ese permiso, ni la etiqueta general de Fab como una excepción. No se ha contactado a nadie ni se han aceptado condiciones. Si no se obtiene una vía compatible, elegir otra familia o adaptación manual legítima; no comprar primero y resolver después.

No se encontró en esta revisión un candidato gratuito que pudiera calificarse a la vez como Kael adecuado, listo para obtener por el flujo permitido y con licencia despejada. KayKit no se degrada ni se presenta como malo: responde a otro objetivo visual. Quaternius requiere resolver condiciones contradictorias; Uricaro97 requiere una intervención mucho mayor. **La entrega 1.0 es el informe alternativo permitido por la tarea, no un piloto completado.**

## Plan de piloto una vez despejados los bloqueos

1. Obtener solo el asset aprobado de su fuente autorizada, con licencia/versionado y hashes; mantener archivos propietarios fuera de un repositorio público.
2. Inspeccionar malla, materiales, UV, rig y clips en Blender. Medir antes de optimizar. Conservar el rig de calidad si requiere otro adaptador; no reducirlo al de 17 huesos solo para pasar los tests antiguos.
3. Adaptar color/escala/orientación y materiales exportables, sin crear de nuevo el personaje desde primitivas. Guardar fuentes y GLB en una carpeta de candidato separada, sin sobrescribir Kael 0.9.
4. Retarget de fuentes cuya licencia se haya comprobado. Idle/Walk/Attack/Hurt/Defend/KO son el contrato de acciones visuales; cada clip provisional debe identificarse. No se han descargado animaciones ni se presupone permiso para usar Mixamo por mencionarse en una ficha.
5. Integrar únicamente presentación y selector con fallback; mantener motor, sesión, narrativa y colisiones. Reusar la misma exportación en combate y exploración.
6. Comparar en Godot cuerpo, rostro, batalla, exploración y ataque con misma cámara/luz/escala, junto a Lyra/Nira/entorno. No retocar las expectativas de combate para aceptar otro rig ni activar el candidato por defecto sin mejora apreciable.
7. Registrar métricas reales y las pruebas nuevas del candidato; solo después extender la familia. No trasladar automáticamente escenas o shaders de Unity/UE.

Presupuesto orientativo del futuro piloto: protagonista 8000–15000 triángulos, enemigos 5000–12000, atlas 512–1024 cuando suficiente; materiales y transparencias acotados. Se permiten evaluar excepciones justificadas. Se medirán vértices exportados, superficies/materiales, textura/mipmaps/memoria aproximada, tamaño GLB, importación y frame time en dispositivo. **No hay medidas de rendimiento de ningún candidato externo.**

## Inspección técnica y validación de esta entrega

Estado de partida: rama `dev`, commit `8ce8c2e`, sin cambios. Leídos README/GDD/AGENTS y revisados modelos/escenas/adaptadores:

- Kael actual: `assets/characters/kael/kael.blend`, `kael.glb`, atlas y manifiesto 0.9; respaldo `v08/`.
- `scenes/kael_model.gd`: `load_asset`, `play_action`, `set_pose`, `set_walking`, `_on_finished`; valida seis clips y espada por nombre. Duplicación de bibliotecas por instancia. Ese contrato requiere adaptación para otros assets; no se ha reescrito anticipadamente.
- `BattleActorVisual.build` / `_build_imported_kael`: selector 0.8/0.9 y fallback a `StylizedModels.hero`; `animate` y `sync` separan eventos/poses del motor.
- `StylizedModels.hero`, `golem` y `_cape`: representaciones actuales de Lyra/Nira/Centinela y respaldo Kael. Ignar también usa presentación procedural existente; no se toca.
- Batalla: `battle_3d.tscn`, `battle_stage.gd` y `BattleEnvironment.build`; respaldo 2D `battle.tscn`.
- Exploración: `forest_exploration.tscn` → `game_flow.gd` / `forest_zone.tscn`; `forest_zone.gd._build_environment` sigue usando el escenario básico con cámara ortográfica. `exploration_player.gd._ready` / `_physics_process` reutiliza Kael y alterna Walk/Idle.

**Fallo inicial real:** la primera ejecución llegó a 517 comprobaciones, 2 fallos y errores de dependencia: la escena importada de Kael esperaba `kael_KaelPaintedAtlas.png`, un archivo auxiliar no conservado. El GLB contiene la imagen, pero `gltf/embedded_image_handling=1` significa **Extract Textures**, no conservarla embebida. Esto puede activar el fallback aun existiendo el modelo. No se atribuye el problema a assets nuevos.

La reimportación local regeneró el auxiliar y permitió recuperar la base de **576 comprobaciones, 0 fallos**. Para eliminar esa dependencia frágil se corrigió una sola opción en `assets/characters/kael/kael.glb.import`: **3 = Embed as Uncompressed**. [Código oficial del importador Godot 4.7](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/modules/gltf/editor/editor_scene_importer_gltf.cpp). Se reimportó, se eliminaron los dos auxiliares generados y se volvió a comprobar la carga. Ninguna malla, fuente `.blend`, GLB, estadística o mecánica se modifica. La caché `.godot` no se sube a Git.

Validación final: suite existente **576 comprobaciones / 0 fallos** headless y con render real. No se añaden pruebas de assets inexistentes ni se debilitan las anteriores. La suite ya comprueba atlas, rutas, skin/clips, versiones/fallback, eventos, reinicio y exploración. No se ha ejecutado Blender para adaptar ningún recurso externo: no hay un piloto adquirido.

No hay capturas comparativas anterior/nuevo externo, ni un GLB externo exportado, ni medidas propias de esos candidatos. Las capturas históricas `docs/previews/kael09-*.png` describen 0.9 y **no prueban la renovación 1.0**. La inspección comercial se hizo sobre cuatro imágenes del proveedor fuera del repositorio. El resultado visual del juego continúa provisional y por debajo del objetivo del usuario.
