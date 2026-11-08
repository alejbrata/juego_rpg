# Eclipse JRPG

Prototipo 0.5 con renovación visual del combate para Godot 4 (verificado con 4.7.2). Abrir `project.godot` y pulsar **F5** para el Bosque del Eclipse, o F6 con `scenes/forest_exploration.tscn` abierta. Para ver directamente la batalla renovada, abrir **`scenes/battle_3d.tscn` y pulsar F6**. La escena original `scenes/battle.tscn` se conserva como respaldo 2D y también puede ejecutarse con F6.

## Renovación visual de la batalla

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

1. Mover a Kael con **WASD o flechas**. El resto del grupo participa en los combates, pero no tiene seguidores visuales todavía. No hay salto ni cámara libre.
2. Acercarse al círculo naranja del **Centinela I** o **Centinela II**. La detección es local; abre la batalla 3D existente. Los árboles, rocas, columnas y muros tienen colisión; no se puede salir del claro.
3. Elegir acciones y objetivos normalmente. Para ganar, aprovechar Escarcha contra la debilidad al hielo, Golpe potente de Kael, Cura de Nira e Ignar cuando alcance 100 RE. Resolver los turnos enemigos con su botón.
4. Tras ganar, se vuelve automáticamente al claro al terminar la animación. Se conserva la posición, desaparece ese Centinela y permanecen RE, vínculos y PA. Combatir contra el segundo permite comprobar la continuidad y alcanzar nivel 2 de Ignar tras dos victorias.
5. En derrota, elegir **Reintentar combate** o **Volver al claro**. Volver deja al grupo en el punto inicial y mantiene al enemigo disponible; no concede PA. El botón de retorno se habilita solo después de resolver la derrota y su presentación.
6. Tras vencer a los dos enemigos aparece «Claro despejado». **Nueva partida** en exploración reinicia mapa, RE y PA. En los encuentros integrados no aparece el botón que creaba una partida de combate independiente.

**Simplificación de recursos:** cada encuentro y cada reintento comienzan con PV/PM máximos; no se conserva desgaste entre combates. Esta decisión usa la estructura actual del motor y evita añadir de forma implícita curación de campo, inventario o progresión de personajes. RE/PA/vínculos sí se conservan con el mismo `PartyState`. Todo vive en memoria; cerrar el juego lo reinicia.

`GameSession` guarda el grupo configurado, `PartyState`, modo actual, posición de retorno y encuentros derrotados. `game_flow.gd` retira temporalmente el claro del árbol y configura la escena 3D existente con esos datos. Después recupera el mismo claro: no hay un segundo motor ni un sistema de guardado.

Los dos encuentros están definidos como Resources `EncounterData` dentro de `scenes/forest_zone.tscn`: ID, etiqueta, posición, radio y array de enemigos. Pueden editarse en el inspector; la prueba de combate sigue aceptando varios enemigos. Cada ID debe ser único dentro de la zona.

La velocidad se configura en `world/exploration_player.gd`. `set_movement_input(Vector2)` permite alimentar el movimiento desde futuros controles táctiles; `clear_movement_input()` vuelve al teclado. Todavía no hay joystick táctil, exploración entre varias zonas, misiones, guardado real ni recursos definitivos.

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

El motor se puede instanciar con `BattleEngine.new()` sin SceneTree ni escenas; `start()` recibe arrays de CombatantData y devuelve error o cadena vacía. `act()` valida y devuelve un mensaje de error o cadena vacía; `step_enemy()` resuelve la IA mínima. La escena solo consulta estado y envía acciones. Los Resources originales no se modifican durante el combate. Las afinidades contradictorias se rechazan sin consumir recursos. Ignar usa la ruta de daño de área y publica eventos para futuras animaciones.

Presentación: `battle_stage.gd` consume eventos y administra cámara/cola/VFX; `battle_actor_visual.gd` representa combatientes; `battle_hud_3d.gd` reutiliza el controlador 2D. `stylized_models.gd` construye modelos y agrupa geometría estática por material; `battle_environment.gd` compone la arena. El motor no conoce nodos, materiales, cámara, tweens ni duración de animaciones. Se mantiene Compatibility, una sola sombra direccional y luces de acento sin sombras; no hay postprocesado pesado. Una lectura puntual en este escritorio Intel Arc a 960×640 dio 60 FPS, 176 llamadas de dibujo y 46.592 primitivas (incluidas pasadas de render); no constituye una medición móvil ni una garantía de rendimiento.

Reglas y decisiones: [docs/GDD.md](docs/GDD.md). Cambiar estadísticas y habilidades en los Resources de `data/` desde el inspector. El claro es una zona de prueba autocontenida; no incluye una aventura completa, modelos definitivos, audio ni exportación móvil.
