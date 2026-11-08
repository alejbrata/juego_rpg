# Eclipse JRPG

- Godot 4, GDScript; sin dependencias externas.
- `combat/` no depende de nodos, escenas, entrada ni renderizado. Datos inmutables en Resources; estado de batalla separado.
- Recursos configurables en `data/`; interfaz provisional en `scenes/`.
- Mantener reglas y decisiones en `docs/GDD.md`. No ampliar alcance sin petición.
- Ejecutar importación headless y `godot --headless --path . --script res://tests/test_battle.gd` tras cambios de lógica. Las pruebas deben terminar con código distinto de cero si fallan.
- No implementar inventario, progresión, Resonancia, Guardianes, exploración, animaciones complejas ni exportación móvil.
