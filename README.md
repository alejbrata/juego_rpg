# Eclipse JRPG

Prototipo de combate 0.2 para Godot 4 (verificado con 4.7.2). Abrir `project.godot` y pulsar F6 en `scenes/battle.tscn` o F5 para ejecutar el proyecto.

Seleccionar una acción y un objetivo. Los botones de habilidades sin PM se desactivan. Resolver el turno enemigo con su botón. El registro muestra los resultados; Reiniciar permite repetir el combate.

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
```

El motor se puede instanciar con `BattleEngine.new()` sin SceneTree ni escenas; `start()` recibe arrays de CombatantData y devuelve error o cadena vacía. `act()` valida y devuelve un mensaje de error o cadena vacía; `step_enemy()` resuelve la IA mínima. La escena solo consulta estado y envía acciones. Los Resources originales no se modifican durante el combate. Las afinidades contradictorias se rechazan sin consumir recursos. Las pruebas crean ataques de área de prueba, sin incorporarlos al contenido jugable.

Reglas y decisiones: [docs/GDD.md](docs/GDD.md). Cambiar estadísticas y habilidades en los Resources de `data/` desde el inspector. No incluye representación 3D ni exportación móvil.
