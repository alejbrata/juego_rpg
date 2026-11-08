# Eclipse JRPG

Prototipo de combate 0.3 para Godot 4 (verificado con 4.7.2). Abrir `project.godot` y pulsar F6 en `scenes/battle.tscn` o F5 para ejecutar el proyecto.

Seleccionar una acción y un objetivo. Los botones de habilidades sin PM se desactivan. Resolver el turno enemigo con su botón. El registro muestra los resultados; Reiniciar permite repetir el combate.

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

El punto de entrada de pruebas conserva las 92 comprobaciones de 0.2 y ejecuta también `tests/guardian_checks.gd`: RE, persistencia entre motores, invocación múltiple, eventos, duración, no acumulación, PA, niveles, pasivas, vínculo y rechazos sin efectos secundarios, además del flujo de interfaz. No necesita un framework externo.

El motor se puede instanciar con `BattleEngine.new()` sin SceneTree ni escenas; `start()` recibe arrays de CombatantData y devuelve error o cadena vacía. `act()` valida y devuelve un mensaje de error o cadena vacía; `step_enemy()` resuelve la IA mínima. La escena solo consulta estado y envía acciones. Los Resources originales no se modifican durante el combate. Las afinidades contradictorias se rechazan sin consumir recursos. Ignar usa la ruta de daño de área y publica eventos para futuras animaciones.

Reglas y decisiones: [docs/GDD.md](docs/GDD.md). Cambiar estadísticas y habilidades en los Resources de `data/` desde el inspector. No incluye representación 3D ni exportación móvil.
