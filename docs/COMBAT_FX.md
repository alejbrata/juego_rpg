# Iteración 1.7 — Presentación audiovisual del combate

Esta iteración es solo de presentación. No cambian la historia, los diálogos, la misión, las estadísticas, el daño, los costes, la Resonancia, los Guardianes, la IA, el orden de turnos, la selección de objetivos, la exploración ni los controles táctiles. Una prueba ejecuta los mismos comandos con la presentación completa y con la presentación omitida, y comprueba que el estado del motor queda idéntico en ambos casos.

## Cómo encaja en el flujo del combate

`BattleEngine` sigue emitiendo los mismos eventos (`action`, `damage`, `heal`, `intercept`, `summon_*`), y `battle_stage.gd` los reproduce en cola como antes. Lo nuevo:

- **`CombatCues`** ([scenes/fx/combat_cues.gd](../scenes/fx/combat_cues.gd)) contiene solo datos. Para cada acción existente fija el efecto, el sonido al empezar el gesto, el sonido de impacto, la intensidad de la sacudida, el acercamiento de cámara, el momento del contacto y la congelación del impacto (*hit-stop*). También define los estilos de los números. Lee la etiqueta, el efecto y el elemento del evento; no decide nada.
- **`CombatVFX`** ([scenes/fx/combat_vfx.gd](../scenes/fx/combat_vfx.gd)) reúne recetas reutilizables: tajos, chispas, fuego, hielo, curación, barrera, impulso, defensa, K.O. y la invocación. Todo se crea dentro de la capa de efectos. Las partes diferidas dependen de un nodo de esa misma capa, así que **omitir o reiniciar las elimina** y no reaparecen después.
- **`CombatNumbers`** ([scenes/fx/combat_numbers.gd](../scenes/fx/combat_numbers.gd)) dibuja los números en pantalla, no en 3D. Se escalan con la interfaz, son legibles en el móvil, se apilan si coinciden y duran menos de 1,2 s.
- **`CombatAudio`** ([scenes/fx/combat_audio.gd](../scenes/fx/combat_audio.gd)) usa seis voces como máximo, aplica una ligera variación de tono y lleva un registro para las pruebas.
- **Momento del impacto:** en los golpes físicos el daño aparece **cuando el arma contacta**, a mitad del ataque, y la cola espera a que el atacante vuelva a su sitio (`_hold`). En los hechizos, el proyectil sale al final del gesto y llega con el daño.
- **Sacudida de cámara:** se basa en un «trauma» que decae solo. Mueve la cámara de verdad en vez de desplazar la proyección, porque desplazarla hacía que el antialiasing temporal (TAA) duplicara los textos. Con «Cámara suave» desactivada no hay sacudidas.

## Efectos por habilidad

| Acción | Efecto visual | Sonido |
|---|---|---|
| Ataque | Breve anticipación y embestida. En el contacto: tajo, destello en estrella, chispas, lascas y polvo si el objetivo es de piedra, y congelación de 45 ms | `swing` → `hit` |
| Golpe potente | Dos tajos cruzados, chispas más largas, anillo en el suelo, acercamiento y 80 ms de congelación | `swing` → `hit_heavy` |
| Llama | Llamas que convergen en la mano y orbe creciente; bola de fuego en arco; explosión de lenguas de fuego naranjas, brasas, humo, grietas de lava en el suelo y luz cálida | `fire_cast` → `fire_impact` |
| Escarcha | Motas frías que convergen, cristal girando y sello de escarcha en el suelo; esquirla de hielo con estela; pinchos de cristal que brotan del suelo y estallan en esquirlas con niebla fría | `ice_cast` → `ice_impact` |
| Cura | Brillo en la mano; columna de luz verde y dorada, motas que suben, destellos y anillo | `heal` |
| Protección | Barrera hexagonal que se forma con un barrido de luz y luego se desvanece | `protect` |
| Impulso | Espiral de vetas doradas y tres flechas que suben | `haste` |
| Defender | Escudo hexagonal frontal y anillo | `guard` |
| Golpe enemigo | Embestida más pesada; chispas cálidas y anillo de polvo sobre el héroe | `enemy_swing` → `hit_hero` |
| Intercepción | Escudo en el punto de intercepción y «¡Protección!» | `guard` |
| K.O. | Polvo, anillo gris y «K.O.»; transición a la postura de derrota que ya existía | `knockout` |
| Invocación de Ignar | Círculo rúnico y grietas de lava; Ignar cae y aterriza, con núcleo y melena de brasas; golpe con impacto en el contacto | `summon`, `fire_impact` |

Llama y Escarcha no comparten ninguna forma: el fuego son lenguas, brasas y humo, y el hielo son cristales, esquirlas y niebla. Así se distinguen aunque el color no se perciba bien.

## Números flotantes

| Estilo | Uso | Tamaño (base 960×640) |
|---|---|---|
| Daño | Blanco cálido con contorno oscuro; tono naranja con fuego, cian con hielo y más grande con Golpe potente | 44–52 |
| Daño recibido | Rojo claro (héroes) | 40 |
| Curación | Verde, con «+» | 42 |
| Estado | «Protección», «Impulso», «Defensa», «¡Protección!», «DEF ↓» | 22 |
| K.O. | Gris claro | 28 |

Animación: aparece con un pequeño rebote (55 % → 118 % → 100 % en 0,18 s), sube 46 px y se desvanece en el último 30 %. No existen fallos ni críticos en las reglas, así que no hay números para ellos.

## Sonidos

Hay 19 efectos **originales**, sintetizados por [tools/audio/make_combat_sfx.py](../tools/audio/make_combat_sfx.py) a partir de ondas, ruido filtrado y envolventes con una semilla fija. No contienen muestras ni grabaciones de terceros, así que no tienen licencias que verificar: son del proyecto. Están en `assets/audio/sfx/` (WAV mono a 44,1 kHz, 1,9 MB en total).

- Los golpes llevan energía entre 250 Hz y 1 kHz, porque los altavoces de los móviles casi no reproducen frecuencias más graves.
- **Interfaz:** `ui_select` al elegir una habilidad, `ui_confirm` al elegir el objetivo y `ui_cancel` al cancelar.
- **Resonancia:** `resonance_ready` suena una sola vez cuando la Resonancia llega a 100, no al empezar un combate que ya la tenga llena.
- No se añade música.

## Texturas de efectos

Las 11 texturas de `assets/fx/textures/` las genera [tools/fx/make_fx_textures.py](../tools/fx/make_fx_textures.py): punto suave, estrella, tajo, anillos, llama, flecha, columna, grietas de lava, escarcha y círculo rúnico. Son blancas, con la forma en el canal alfa. El **círculo de invocación** sigue la referencia del diseñador (anillos concéntricos, rombos y el emblema central de llama), dibujado con formas simples, no calcado de la imagen. La barrera es un shader propio ([scenes/fx/barrier.gdshader](../scenes/fx/barrier.gdshader)) que funciona en Forward+, Mobile y Compatibility.

## Ignar HD

Por petición del diseñador, Ignar se monta **con el mismo proceso que Kael, Lyra y Nira**, siguiendo su lámina. El montador es [tools/blender/build_ignar_hd.py](../tools/blender/build_ignar_hd.py), que reutiliza las utilidades de `build_party_hd.py`:

- **Esqueleto y animaciones:** el mismo esqueleto Quaternius de 65 huesos y la misma biblioteca de animaciones. Clips `Appear` (`Jump_Land`), `Idle` y `Attack` (`Punch_Cross`, con el contacto al 42 %).
- **Cuerpo:** el cuerpo base hace de **magma** emisivo.
- **Armadura:** placas de obsidiana generadas alrededor de cada hueso, cada una unida rígidamente a uno solo, que dejan vetas de lava entre ellas.
- **Detalles:** puños y pies de roca, púas en los hombros, cabeza con cejas, mandíbula, ojos encendidos, dos cuernos y cresta, y el núcleo de lava en el pecho.
- **Texturas:** generadas con numpy (obsidiana con mapa de normales y lava).
- **Tamaño:** 15 924 triángulos y 4,2 m de altura.
- **Dentro del juego:** la melena de brasas son partículas unidas al hueso de la cabeza, y el resplandor del núcleo sigue al del pecho.
- **Ubicación:** igual que el grupo HD, el resultado está en `assets/third_party/ignar_hd/`, fuera de Git. Solo se usa con `visuals/party/style="hd"`; sin el modelo, o con otro estilo, la invocación usa el gólem procedural.
- **Comportamiento:** ambas versiones producen el mismo efecto en el motor, y hay una prueba que lo compara.

Regenerarlo:

```
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python-exit-code 1 --python tools/blender/build_ignar_hd.py
```

**Límites:** es una primera versión en la línea del grupo, **no arte final**.

- Las placas son facetas generadas, no esculpidas.
- La melena es de partículas, no geometría.
- No tiene animaciones propias de Guardián: los clips son de la biblioteca humanoide.

## Móvil

- **Calidad automática:** `visuals/combat_fx/quality` = `auto` (por defecto), `high` o `low`. En `auto`, los móviles usan **0,6×** las partículas del escritorio, con las mismas formas, colores y tiempos.
- **Caso más pesado (la explosión de Llama):** unas 59 partículas en escritorio y 35 en móvil, más 4 quads y una luz breve sin sombras.
- **Otros elementos:** los tajos y anillos son quads con un material sin iluminación. La barrera es una esfera de 24×12 segmentos.
- **Duración:** todos los efectos desaparecen en menos de 1,2 s.
- **Rendimiento:** **no se ha medido en un teléfono real**. Para medirlo, usa el registro `RENDIMIENTO` del APK de depuración ([ANDROID.md](ANDROID.md)).

## Evidencia visual

En [docs/previews/combat_fx/](previews/combat_fx/):

- **Vídeos con sonido** `after-*.mp4` y vídeos del estado anterior `before-*.mp4`, de cada caso: ataque, Golpe potente, Llama, Escarcha, Cura, Protección, Impulso, daño recibido, K.O. de héroe y de enemigo, selección de habilidad e invocación.
- **GIF** de cinco momentos clave.
- **Comparativas** `compare-*.jpg`.
- **Primeros planos** de Ignar HD (`ignar-hd-closeup.png`).

Los vídeos se graban con el Movie Maker de Godot a 30 fotogramas por segundo fijos ([tools/capture_combat_fx.gd](../tools/capture_combat_fx.gd)), se cortan con [tools/combat_fx_clips.py](../tools/combat_fx_clips.py) y los fotogramas de las comparativas se eligen automáticamente ([tools/combat_fx_stills.py](../tools/combat_fx_stills.py)).

## Pruebas

`tests/combat_fx_checks.gd` añade 42 comprobaciones con los paquetes de Quaternius instalados, 41 sin ellos (1160 en total). Cubren:

- recursos y la tabla de efectos por acción;
- voces de audio y calidad móvil;
- cada habilidad: efecto, sonidos, número y devolución del control;
- golpe enemigo y K.O.;
- momento del contacto;
- estado del motor idéntico con y sin presentación;
- sacudida y su desactivación;
- omitir a mitad de un hechizo;
- *hit-stop*;
- sonidos de interfaz y de Resonancia;
- números a tres resoluciones;
- Ignar HD y su respaldo procedural.

## Recomendaciones para la próxima iteración de Ignar

1. Esculpir o retocar a mano las placas principales (pecho, hombros, cabeza) en Blender, y conservar las generadas como relleno.
2. Hacer la melena de brasas con geometría ligera y un shader de desplazamiento, para que no dependa solo de partículas.
3. Crear animaciones propias de Guardián (aterrizaje con puño al suelo y un golpe a dos manos), retocadas sobre los clips actuales.
4. Lanzar una onda de fuego desde el puño hasta el objetivo, que hoy solo explota en el objetivo.
5. Escuchar los sonidos en un teléfono real y ajustar el volumen de `summon` y `fire_impact` si saturan el altavoz.
