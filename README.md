# Eclipse JRPG

Prototipo 0.8 para Godot 4 (verificado con 4.7.2). Abrir `project.godot` y pulsar **F5** para jugar «La expedición perdida», o F6 con `scenes/forest_exploration.tscn` abierta. Para probar solo combate, abrir **`scenes/battle_3d.tscn` y pulsar F6**. El respaldo 2D `scenes/battle.tscn` también se puede ejecutar con F6.

Versiones: **0.5**, primer claro explorable; **0.6**, renovación visual; **0.7**, primera misión narrativa. Esta numeración corrige el título repetido de la entrega visual anterior.

## Kael: Blender → GLB → Godot (0.8)

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
- **Animaciones:** `animate()` crea `Idle`, `Walk`, `Attack`, `Hurt`, `Defend` y `KO` a 30 fps. Idle/Walk son ciclos; Defend/KO mantienen su pose final. Para añadir un clip, conservar su Action al guardar, incluirlo en el contrato del exportador y conectarlo explícitamente en `KaelModel`/presentación, con una prueba. No crear una habilidad ni regla para justificarlo.
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
