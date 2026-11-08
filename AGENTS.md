# Eclipse JRPG

- Godot 4, GDScript; sin dependencias externas.
- En Windows, evitar la suspensión mientras se ejecutan tareas mediante una solicitud temporal de energía; liberarla al terminar y no modificar permanentemente el plan de energía.
- `combat/` no depende de nodos, escenas, entrada ni renderizado. Datos inmutables en Resources; estado de batalla separado.
- Recursos configurables en `data/`; interfaz provisional en `scenes/`.
- Mantener reglas y decisiones en `docs/GDD.md`. No ampliar alcance sin petición.
- Separar Defender de la interceptación de Protección. Cubrir expiración, autoprotección, inconsciencia y área con pruebas. No acumular sus reducciones.
- Elementos y afinidades son datos configurables; rechazar debilidad/resistencia simultáneas al mismo elemento antes de mutar la batalla. Mantener explícito el orden de multiplicadores y redondeos.
- Las decisiones futuras confirmadas en el GDD no autorizan a implementar esos sistemas.
- Iteración 0.3: RE, vínculo y PA pertenecen a `PartyState`; compartir explícitamente esa instancia entre combates. Resources de Guardianes inmutables, progreso separado. No cambiar vínculos en combate ni conceder PA dos veces por victoria.
- Conservar las 92 comprobaciones de 0.2 y ejecutar también los casos de `tests/guardian_checks.gd` mediante el mismo punto de entrada. Invocaciones generan eventos, sin nodos ni cinemáticas en el motor.
- Iteración 0.4: `scenes/battle_3d.tscn` es la escena principal; conservar `scenes/battle.tscn` como respaldo 2D. La presentación consume eventos estructurados, nunca recalcula daño ni interpreta el texto del registro. Mantener cámara, materiales, tweens y bloqueo temporal de controles fuera de `combat/`.
- Conservar las 257 comprobaciones de 0.3 y ejecutar `tests/presentation_checks.gd` desde el punto de entrada existente. Aislar los datos mutados en pruebas con copias profundas de Resources externos. Verificar render, reinicios durante animaciones y resoluciones reducidas tras cambios de presentación.
- Ejecutar importación headless y `godot --headless --path . --script res://tests/test_battle.gd` tras cambios de lógica. Las pruebas deben terminar con código distinto de cero si fallan.
- Alcance actual: combate, Resonancia, Ignar y PA, presentación 3D con primitivas y animaciones simples. No implementar inventario, progresión de personajes, especializaciones, otros Guardianes, exploración, guardado, modelos/rigs definitivos, audio final, animaciones complejas ni exportación móvil.
