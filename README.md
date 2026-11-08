# Eclipse JRPG

Prototipo de combate para Godot 4 (verificado con 4.7.2). Abrir `project.godot` y pulsar F6 en `scenes/battle.tscn` o F5 para ejecutar el proyecto.

Seleccionar una acción y un objetivo. Los botones de habilidades sin PM se desactivan. Resolver el turno enemigo con su botón. El registro muestra los resultados; Reiniciar permite repetir el combate.

## Comprobaciones

Desde la raíz, sustituyendo `godot` por la ruta del ejecutable local si no está en PATH:

```powershell
godot --version
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_battle.gd
godot --headless --path . --quit-after 5
```

El motor se puede instanciar con `BattleEngine.new()` sin SceneTree ni escenas; `start()` recibe arrays de CombatantData. `act()` valida y devuelve un mensaje de error o cadena vacía; `step_enemy()` resuelve la IA mínima. La escena solo consulta estado y envía acciones. Los Resources originales no se modifican durante el combate.

Reglas y decisiones: [docs/GDD.md](docs/GDD.md). Cambiar estadísticas y habilidades en los Resources de `data/` desde el inspector. No incluye representación 3D ni exportación móvil.
