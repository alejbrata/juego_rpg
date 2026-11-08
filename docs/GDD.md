# Eclipse JRPG

## Decisiones confirmadas

JRPG de fantasía para Android e iOS, estética 3D inspirada en los clásicos de finales de los noventa, exploración con cámaras fijas o semiautomáticas. Proyecto para una persona con ayuda de Codex. El prototipo futuro tendrá 20–30 minutos; esta entrega solo incluye combate con interfaz 2D provisional.

Tres protagonistas: Kael (guerrero), Lyra (maga), Nira (sanadora). Combate por turnos puros, sin ATB. Cada combatiente vivo actúa una vez por ronda, en orden descendente de Velocidad. Esperar entrada no avanza la simulación. Inconscientes a 0 PV; victoria al caer todos los enemigos y derrota al caer todos los héroes.

| Personaje | PV | PM | FUE | MAG | DEF | RES | VEL | Habilidades |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Kael | 120 | 12 | 24 | 5 | 16 | 8 | 12 | Golpe potente: 4 PM, físico +15; Protección: 5 PM |
| Lyra | 75 | 35 | 8 | 28 | 7 | 15 | 18 | Llama: 8 PM, mágico +10; Escarcha: 7 PM, mágico +6 |
| Nira | 90 | 30 | 12 | 20 | 10 | 14 | 10 | Cura: 7 PM, MAG +20 PV; Impulso: 6 PM, +5 VEL durante dos rondas |

Daño físico: `max(1, FUE + potencia - DEF objetivo)`. Daño mágico: `max(1, MAG + potencia - RES objetivo)`. Defender reduce el daño un 50 % hasta el inicio de la siguiente actuación del defensor.

## Decisiones mínimas sobre ambigüedades

- Ataque básico: físico, potencia 0, coste 0. Defender: coste 0, objetivo propio.
- Protección aplica el mismo estado defensivo a un aliado vivo, incluido uno mismo. No se acumula con Defender; expira al comenzar el turno del receptor.
- Daño reducido por defensa redondeado hacia arriba, con mínimo 1.
- Cura no revive y no supera los PV máximos. Todas las habilidades requieren objetivo vivo y del bando correcto. Un intento inválido no consume PM ni turno.
- Impulso no se acumula: renueva duración. Afecta a la siguiente ordenación y a las dos rondas completas posteriores a su aplicación. También está activo el resto de la ronda en curso, cuyo orden ya está fijado. Se decrementa al final de ronda y expira tras esas dos rondas completas.
- Orden calculado al inicio de cada ronda. Empates por posición inicial estable: Kael, Lyra, Nira, enemigo. Se omiten combatientes caídos sin reemplazar sus turnos.
- Enemigo provisional configurable: Centinela de piedra, PV 280, PM 0, FUE 30, MAG 0, DEF 12, RES 10, VEL 11. Ataca al primer héroe vivo en el orden inicial. La interfaz ofrece un botón para resolver su turno, sin temporizadores.
- No hay elementos, críticos, azar ni efectos secundarios de Llama/Escarcha.

## Ideas futuras, fuera de esta entrega

Guardianes originales con invocaciones espectaculares; progresión híbrida de personajes y Guardianes. Su diseño y reglas siguen pendientes. También quedan fuera inventario, Resonancia, mundo abierto, exploración, animaciones complejas y exportación móvil. No se anticipan sistemas para estas ideas.

## Estructura

`combat/`: motor RefCounted, estados y tipos Resource. `data/`: personajes y habilidades editables. `scenes/`: escena y presentación. `tests/`: pruebas sin framework. `docs/`: reglas y alcance.
