# Eclipse JRPG

- Godot 4, GDScript; sin dependencias externas.
- En Windows, evitar la suspensión mientras se ejecutan tareas mediante una solicitud temporal de energía; liberarla al terminar y no modificar permanentemente el plan de energía.
- `combat/` no depende de nodos, escenas, entrada ni renderizado. Datos inmutables en Resources; estado de batalla separado.
- Recursos configurables en `data/`; interfaz provisional en `scenes/`.
- Mantener reglas y decisiones en `docs/GDD.md`. No ampliar alcance sin petición.
- Separar Defender de la interceptación de Protección. Cubrir expiración, autoprotección, inconsciencia y área con pruebas. No acumular sus reducciones.
- Elementos y afinidades son datos configurables; rechazar debilidad/resistencia simultáneas al mismo elemento antes de mutar la batalla. Mantener explícito el orden de multiplicadores y redondeos.
- Las decisiones futuras confirmadas en el GDD no autorizan a implementar esos sistemas.
- Ejecutar importación headless y `godot --headless --path . --script res://tests/test_battle.gd` tras cambios de lógica. Las pruebas deben terminar con código distinto de cero si fallan.
- No implementar inventario, progresión, Resonancia, Guardianes, exploración, animaciones complejas ni exportación móvil.
