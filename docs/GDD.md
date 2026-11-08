# Eclipse JRPG

## Combate implementado (iteración 0.2)

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
- Protección (5 PM y turno de Kael) elige un aliado vivo, incluido Kael. Intercepta el siguiente ataque individual de un enemigo contra ese aliado. Se calcula el daño con DEF o RES de Kael, se aplica el elemento del golpe y después una única reducción del 50 %. Kael pierde los PV y el aliado no recibe daño; no se transfiere daño sobrante si Kael cae.
- Protección se consume al interceptar o expira al comenzar el siguiente turno de Kael, lo primero que suceda. No expira con el turno del aliado ni al cambiar de ronda. Kael inconsciente no intercepta. Los ataques de área no se interceptan ni consumen Protección.
- La autoprotección sigue la misma ruta de interceptación y reducción única. Si coexiste con Defender, se reduce un 50 % una sola vez, nunca un 75 %. Defender conserva su duración propia y no se consume por un golpe. Protección es un estado separado; no concede Defender al aliado.
- Daño reducido por defensa redondeado hacia arriba, con mínimo 1.
- Cura no revive y no supera los PV máximos. Todas las habilidades requieren objetivo vivo y del bando correcto. Un intento inválido no consume PM ni turno.
- Impulso no se acumula: renueva duración. Afecta a la siguiente ordenación y a las dos rondas completas posteriores a su aplicación. También está activo el resto de la ronda en curso, cuyo orden ya está fijado. Se decrementa al final de ronda y expira tras esas dos rondas completas.
- Orden calculado al inicio de cada ronda. Empates por posición inicial estable: Kael, Lyra, Nira, enemigo. Se omiten combatientes caídos sin reemplazar sus turnos.
- Enemigo provisional configurable: Centinela de piedra, PV 280, PM 0, FUE 30, MAG 0, DEF 12, RES 10, VEL 11. Ataca al primer héroe vivo en el orden inicial. La interfaz ofrece un botón para resolver su turno, sin temporizadores.
- Elementos implementados: `physical`, `fire`, `ice`, `neutral`. Ataque y Golpe potente son `physical`; Llama es `fire`; Escarcha es `ice`. El tipo físico/mágico determina FUE/DEF o MAG/RES independientemente del elemento.
- Afinidades configurables en Resources (`weaknesses`, `resistances`): debilidad ×1,5, resistencia ×0,5, resto ×1. Neutral siempre ×1. Un mismo elemento no puede aparecer en ambas listas; datos contradictorios o elementos desconocidos se rechazan antes de iniciar una batalla o consumir turno/PM. `start()` devuelve el error sin sustituir la batalla existente.
- Tras calcular el daño base se aplica el multiplicador elemental, se redondea hacia abajo y se mantiene un mínimo de 1. Después, si corresponde, se aplica Defensa o interceptación con su redondeo hacia arriba y mínimo 1.
- El Centinela es débil a hielo y resistente a fuego. Llama causa 14 PV (base 28 ×0,5); Escarcha causa 36 PV (base 24 ×1,5) sin defensa activa.
- El campo `is_area` distingue ataques de área ofensivos: afectan a todos los rivales vivos, validando un objetivo inicial. Solo existe soporte mínimo del motor para verificar la exclusión de interceptación; no se ha añadido ninguna habilidad de área al contenido jugable.
- El registro indica el elemento, PV antes/después y pérdida real de PV (limitada por los PV restantes), PM antes/después e interceptaciones. No hay críticos, azar ni efectos secundarios de Llama/Escarcha.

## Decisiones de diseño futuras, no implementadas

Estas decisiones están confirmadas para el juego futuro. No describen funcionalidades disponibles en el prototipo de combate ni autorizan su implementación en esta iteración.

### Identidad

- JRPG para móvil con exploración 3D de estética fantástica inspirada en los clásicos de finales de los noventa.
- Cámara fija o semiautomática; combates por turnos puros, sin ATB (estos turnos sí están implementados en el prototipo).
- Historia propia, sin reutilizar personajes, diseños, música ni recursos protegidos de Final Fantasy.
- Primer vertical slice de 20–30 minutos.

### Guardianes

- Invocaciones originales: aparecen, ejecutan un ataque o efecto espectacular y desaparecen.
- Resonancia compartida de 0 a 100. Invocar consume el turno del personaje y la Resonancia acumulada. La Resonancia se conserva entre combates.
- Los Guardianes se vinculan a personajes y proporcionan habilidades pasivas. Cada personaje puede equipar un Guardián.
- Progresan mediante puntos de Afinidad (PA), independientes de la EXP del personaje. El progreso del Guardián permanece al cambiar de portador.
- Primer Guardián jugable: Ignar, criatura volcánica de fuego. Otros previstos: Nivara (hielo) y Sylvan (naturaleza).
- Dos Guardianes legendarios secretos: Astrael y Elyra. Se obtienen mediante misiones secundarias de exploración y desafíos importantes; no se venden ni se entregan automáticamente durante la historia.

### Personajes

- Tres protagonistas iniciales: Kael, Lyra y Nira (ya presentes como combatientes en el prototipo).
- Progresión híbrida: niveles, aumento automático de atributos y pequeñas decisiones de especialización.
- Equipamiento: arma, armadura y accesorio.
- Experiencia del personaje y Afinidad del Guardián independientes.

### Exploración

- Escenarios 3D compactos y conectados, con enemigos visibles y sin encuentros aleatorios.
- Controles adaptados a pantalla táctil.
- Guardado automático y sesiones cortas.
- Secretos y misiones secundarias que recompensen explorar.

No se implementan todavía Guardianes, Resonancia, progresión, inventario, exploración 3D ni guardado. Mundo abierto, animaciones complejas y exportación móvil también quedan fuera de esta entrega.

## Estructura

`combat/`: motor RefCounted, estados y tipos Resource. `data/`: personajes y habilidades editables. `scenes/`: escena y presentación. `tests/`: pruebas sin framework. `docs/`: reglas y alcance.
