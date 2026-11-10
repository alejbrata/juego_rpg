# Iteración 1.3 — Bosque HD (Forward+ y escaneos CC0)

## Objetivo

El usuario consideró que todo el juego parecía «de hace 50 años», con escenario y personajes generados por script.
Esta iteración cambia de enfoque: el escenario usa recursos fotoescaneados de dominio público y un renderer
moderno. La jugabilidad, la historia y las reglas no cambian.

## Qué cambia

| Ámbito | Antes (1.1) | Ahora (1.3) |
|---|---|---|
| Renderer | GL Compatibility (móvil) | **Forward+** (PC); `mobile` como respaldo de exportación |
| Árboles, arbustos, rocas, troncos | Geometría procedural con color de vértice | Escaneos Poly Haven (CC0) reducidos con Blender |
| Suelo | Pintura procedural | 4 capas PBR (hojarasca, pradera, sendero, losas) mezcladas por máscara y altura |
| Ruinas y props narrativos | Color de vértice plano | Misma geometría con PBR triplanar (piedra/madera) y musgo en caras superiores |
| Hierba | Matas facetadas | ~7000 matas instanciadas con viento y apartado al paso de Kael |
| Cielo y luz | Color plano, sombra ortogonal | HDRI, luz ambiental del cielo, 4 cascadas de sombra suave, SSAO, SSIL, niebla volumétrica, bloom, AgX, TAA y profundidad de campo lejana |
| Cristal | Prisma plano | Racimo de cristal translúcido emisivo con luz propia |
| Centinelas | Bloques facetados | Rocas musgosas escaneadas con las mismas proporciones, grietas y ojos |
| Arena de batalla | Isla low-poly | Claro HD con ruinas, árboles, rocas, hierba y fondo de bosque |

## Qué no cambia

- Los 18 colliders, anclas, encuentros, radios, puntos narrativos, diálogos, cámara de exploración y cámara de batalla.
- Combate, Resonancia, Guardianes, PA y estado persistente.
- Personajes: siguen siendo los modelos actuales. Ver «Personajes» más abajo.

## Selector

En `project.godot`, sección `[visuals]`: `forest/hd=true` (predeterminado). Con `false` vuelve el bosque 1.1 y la arena
anterior, sin otros cambios. El renderer se selecciona en `[rendering]`. Volver a `gl_compatibility` también es posible,
pero el modo HD está pensado para Forward+.

## Recursos y licencias

Todos los modelos, texturas y el cielo proceden de [Poly Haven](https://polyhaven.com/license), con licencia CC0 1.0.
El registro por recurso (URL, autoría y licencia) está en `assets/environments/eclipse_forest_hd/sources.json`.
Las descargas originales no se guardan en el repositorio.

`tools/blender/prepare_forest_hd.py` reduce cada escaneo. Separa las variantes de cada colección, pone el origen en la
base, escala a la altura objetivo y diezma a un máximo de 90 000 triángulos por variante. El resultado y sus cifras
quedan en `kit_manifest.json`. `tools/forest_hd_mask.py` genera la máscara del suelo a partir de los mismos senderos del
claro 1.1.

Se descartaron los abetos (`fir_tree_01`): al reducirlos al 2 % de sus 7 millones de triángulos desaparecen las ramitas
y solo quedan los troncos.

## Código

- `world/forest_art_hd.gd`: `ForestArtHD` hereda de `ForestArt`. Reutiliza la composición 1.1 (mismas transformaciones)
  y sustituye cada kit por su escaneo. También construye la arena de batalla (`build_battle`), los Centinelas
  (`rock_variants`) y el cristal (`crystal_cluster`).
- `world/shaders/forest_hd_{ground,stone,foliage,grass}.gdshader`.
- `scenes/battle_environment.gd`: rama HD con la misma cámara.
- `scenes/stylized_models.gd`: `golem()` usa rocas escaneadas en modo HD.
- `tools/blender/thin_trees_hd.py`: versión «lejana» de cada árbol (ver Rendimiento).
- `tools/capture_forest_hd.gd`: capturas reales y métricas.

## Pruebas

`tests/forest_hd_checks.gd` comprueba:
- licencias y presencia de cada recurso usado, y su presupuesto;
- colliders idénticos y ningún cuerpo físico añadido;
- cámara y encuadre;
- anclas narrativas;
- cristal, sustituciones de kit y hierba fuera de los senderos;
- texturas con mipmaps, árboles lejanos aligerados y sombras con la versión ligera;
- transparencia de copas;
- recorrido físico, Centinelas escaneados, arena de batalla sin física y con la misma cámara y posiciones;
- restauración de 1.1 al desactivar el modo HD.

En total, 28 comprobaciones nuevas: 994 con las 966 anteriores, cero fallos.

Las suites anteriores a 1.3 se ejecutan con `forest/hd=false`, conservando todas sus aserciones, porque validan la
presentación previa (gólems agrupados y bosque 1.1).

## Rendimiento

Medido en el PC de desarrollo (Intel Arc integrada, portátil con calentamiento) sin vsync. Hay ruido de ±20 % entre
ejecuciones.

| Escena | Primera versión HD | Ahora | Bosque 1.1 |
|---|---|---|---|
| Exploración 1280×720 | ~10 FPS (30 M primitivas) | **~40 FPS** (4,7 M) | ~150–200 FPS |
| Exploración 960×640 | — | **~49 FPS** | ~270–320 FPS |
| Batalla 1280×720 | — | **~55 FPS** | ~320–390 FPS |

Qué se corrigió:
- **Mipmaps y compresión**. Las texturas de suelo se importaban sin mipmaps ni compresión: el `.import` usa ahora
  compresión VRAM y mipmaps. Las imágenes incrustadas en los GLB (`embedded_image_handling=3`) también llegan sin mipmaps,
  así que `ForestArtHD._with_mips` genera los mipmaps y comprime en S3TC cada textura al cargar, una sola vez por sesión.
  La compresión BPTC tardaba más de 2 minutos y se descartó. La primera carga del bosque tarda unos 11 s en este PC.
- **Árboles lejanos**. El LOD automático de Godot colapsa las tarjetas de hojas y deja los árboles sin copa. Por eso
  `thin_trees_hd.py` crea `<árbol>_far.glb`: conserva el 22 % de los grupos de hojas, agranda los supervivientes para
  mantener la cobertura y diezma la corteza. El resultado son 13–19 k triángulos en vez de 90 k. Estos GLB no incluyen
  texturas: Godot reutiliza los materiales del modelo completo y los importa sin LOD automático.
- **Sombras**. El anillo lejano usa la versión ligera y no proyecta sombra. Los árboles cercanos se dibujan completos, pero
  la sombra la proyecta su versión ligera (`*Shadow`, solo sombra). El sol pasa a 2 cascadas hasta 32 m con un mapa de
  4096. Se desactiva el SSIL.
- Probado sin ganancia apreciable: niebla volumétrica, profundidad de campo, glow, PCSS y sombra de la hierba. Se
  mantienen.

Para ir más rápido en equipos modestos, `forest/hd=false` vuelve al bosque 1.1. Móvil: no medido, y el modo HD no está
pensado para móvil.

## Límites conocidos

- **Personajes**: Kael, Lyra y Nira siguen siendo los modelos estilizados actuales y desentonan con el escenario. Los
  personajes gratuitos más adecuados (Quaternius) tienen una licencia contradictoria: las fichas dicen CC0 y la página
  de licencia (QAL v1.0) prohíbe redistribuir los archivos. Además, itch.io no permite descargarlos de forma
  automatizada. Hace falta que el usuario los descargue a mano. Se instalarían con `tools/install_quaternius.py` en
  `assets/third_party/` (ignorado por Git, porque el repositorio es público).
- **Rendimiento**: ver la sección anterior. En gráfica integrada no llega a 60 FPS en exploración.
- **Tamaño**: el kit ocupa unos 190 MB (modelos con texturas 1k–2k incrustadas, texturas de suelo 2k y HDRI 2k).
- Los escaneos reducidos pierden detalle fino de cerca. Con la cámara de juego no se nota, pero sí en primeros planos.
