# Eclipse JRPG

## Combate y primer claro implementados (iteración 0.5)

JRPG de fantasía para Android e iOS, estética 3D inspirada en los clásicos de finales de los noventa, exploración con cámaras fijas o semiautomáticas. Proyecto para una persona con ayuda de Codex. El vertical slice futuro tendrá 20–30 minutos; esta entrega incluye combate 3D provisional, respaldo 2D y un primer claro explorable del Bosque del Eclipse, todavía sin una aventura completa.

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
- El campo `is_area` distingue ataques de área ofensivos: afectan a todos los rivales vivos, validando un objetivo inicial. Ignar utiliza esta ruta de daño sin seleccionar un enemigo individual. Protección no intercepta áreas.
- El registro indica el elemento, PV antes/después y pérdida real de PV (limitada por los PV restantes), PM antes/después e interceptaciones. No hay críticos, azar ni efectos secundarios de Llama/Escarcha.

## Resonancia implementada

- Recurso entero compartido del grupo protagonista, limitado a 0–100 RE. Pertenece a `PartyState`, no a los combatientes temporales. Se conserva tras victoria, derrota y abandono, siempre que se pase la misma instancia al siguiente combate. No hay persistencia en disco.
- Acción válida de héroe: Ataque +10, Defender +15, habilidad especial +10 (incluye Cura, Protección e Impulso). Aprovechar al menos una debilidad elemental añade +10 una vez por acción, aunque haya varios enemigos afectados.
- Cada impacto que disminuya los PV de un héroe añade +5 RE, incluso si resulta letal o está reducido por Defender. En interceptación solo cuenta el impacto a Kael; el aliado protegido no recibe otro impacto. Un área que alcance a tres héroes genera +15.
- Acciones inválidas no modifican RE, PV, PM, turno, estados, PA, registro ni eventos. Las acciones enemigas no generan RE por ejecución ni por aprovechar debilidades: solo cuentan los impactos realmente recibidos por el grupo. Las invocaciones no generan RE, ni siquiera por debilidades o por Resonancia Ardiente.
- La generación se aplica antes de resolver el final del combate; el golpe que concede victoria también genera RE. El registro muestra RE antes/después.

## Guardianes e Ignar implementados

### Datos, progreso y vínculo

- `GuardianData` es una definición Resource configurable. `GuardianProgress` contiene los PA mutables y calcula el nivel. `PartyState` mantiene definiciones, progreso y un mapa independiente de portadores por ID estable de personaje. No se modifican los Resources durante el combate.
- Cada personaje equipa como máximo un Guardián y cada Guardián solo tiene un portador. `PartyState.test_party()` crea Ignar vinculado a Lyra, nivel 1 y 0 PA; un `PartyState.new()` vacío permite probar combates sin Guardianes.
- Transferir fuera del combate mueve el vínculo, no el progreso. Las pasivas dejan de aplicarse al portador anterior. No se permite vincular, desvincular ni registrar Guardianes mientras la partida tenga un combate activo. Solo un motor puede usar esa partida a la vez; victoria, derrota y `abort()` liberan el bloqueo. El motor tampoco retiene bloqueos al destruirse.
- Para transferir estado entre combates se usa `engine.start(heroes, enemies, run)`, y al siguiente motor se le entrega el mismo `run`. Omitir el tercer argumento reutiliza el estado ya asociado a ese motor. `start()` limpia PV, PM, orden, estados temporales, eventos y registro, pero conserva RE/PA/vínculos.
- Reiniciar combate en la interfaz conserva RE y PA; abandonar no concede PA. «Nueva partida (RE/PA a cero)» crea una instancia nueva y restaura el vínculo inicial. Cerrar la aplicación termina la partida en memoria.

### Invocación: Juicio de Ceniza

- Ignar, Guardián de las Brasas, es una criatura volcánica de fuego. Su portador vivo puede invocarlo exclusivamente durante su turno, con 100 RE. Consume exactamente 100 RE y el turno, sin PM. Ignar aparece, actúa y se retira; nunca ocupa una plaza de combatiente.
- Cálculo provisional explícito: **base fija 40**, tratada como daño mágico de fuego. No se suma MAG del portador ni se resta RES enemiga. Esta elección interpreta los «40 puntos antes de afinidades» como daño base independiente de atributos; permite evaluar el balance del Guardián de forma aislada.
- Se multiplica la base por la afinidad del enemigo, redondeando hacia abajo y con mínimo 1. Si el objetivo está defendiendo, después se aplica su reducción del 50 %, redondeando hacia arriba. Sin Defender: resistencia al fuego 20, neutral 40, debilidad al fuego 60.
- Al nivel 4 la base pasa a `floor(40 × 1,20) = 48`; provoca 24/48/72 según afinidad. Corazón de Brasas mejora las acciones de fuego del portador, no el daño propio del Guardián; no se añade otro ×1,10 a la invocación.
- Afecta una vez a cada enemigo vivo al comenzar la invocación. Omite caídos y nunca afecta aliados.
- A cada enemigo afectado le aplica Defensa física −25 %, aunque resista al fuego. `DEF efectiva = floor(DEF original × 0,75)` (12 → 9; 11 → 8). No modifica RES ni el Resource original.
- La reducción está activa inmediatamente en la ronda de invocación y durante las dos rondas completas siguientes. Se almacena duración 3 al aplicar, decrementa al final de cada ronda y expira al terminar la segunda ronda completa posterior. Reaplicar renueva la duración y deja la reducción en 25 %; no se acumula.
- Eventos ordenados en `engine.events` y señal `battle_event`: `summon_appear` (Guardián y actor), un `summon_effect` por enemigo (objetivo, elemento, PV antes/después, PV perdidos y reducción), `summon_disappear`. La resolución lógica sigue siendo síncrona; la escena 3D reproduce estos eventos después, sin volver a aplicar sus efectos.

### Afinidad y pasivas

Cada victoria concede +50 PA a los Guardianes equipados por héroes participantes, incluso si el portador termina inconsciente. No exige haber invocado. Se concede una sola vez por combate; derrota, abandono y un inicio sin enemigos no conceden PA.

| Nivel | PA acumulados | Pasiva de Ignar |
|---|---:|---|
| 1 | 0 | Sangre de Fuego: daño de fuego recibido por el portador ×0,90 |
| 2 | 100 | Corazón de Brasas: daño de fuego de las acciones del portador ×1,10 |
| 3 | 250 | Resonancia Ardiente: aprovechar debilidad al fuego añade +5 RE una vez por acción |
| 4 | 500 | Furia de Ignar: base de su invocación +20 % |

- Las pasivas son acumulativas por nivel y solo se aplican mientras Ignar esté equipado. Nivel máximo 4; PA pueden seguir acumulándose.
- Bonificaciones ofensivas y resistencias pasivas son multiplicativas respecto a la afinidad. Se redondea una vez hacia abajo tras el producto, con mínimo 1, y después se aplica Defender/interceptación si corresponde. Ejemplos: `floor(28 × 0,5 × 1,10) = 15`; `floor(25 × 0,90) = 22`; resistencia natural y pasiva `floor(25 × 0,5 × 0,90) = 11`.
- Resonancia Ardiente no se activa con hielo, sin debilidad ni al invocar. Los valores, elemento, nombres de pasivas, umbrales, daño y reducción están en `data/ignar.tres`. Solo se implementa este conjunto básico de efectos, sin un framework genérico de habilidades pasivas.

## Presentación 3D implementada (0.4)

- Escena de combate `scenes/battle_3d.tscn`: arena autocontenida de losas y pilares de ruinas, iluminación ambiental y una luz direccional, cámara ortográfica fija inclinada. El movimiento de esta escena se limita a las animaciones; la exploración utiliza su propia escena.
- Héroes a la izquierda y enemigos a la derecha, con formación escalonada y posiciones calculadas por número de combatientes. Se valida también una formación con varios enemigos. Primitivas geométricas, colores, armas provisionales, escala y etiquetas distinguen a cada actor.
- Etiquetas 3D: nombre, PV/PM, inconsciencia, Defender, vínculo con Ignar, protector/protegido, Impulso y Defensa reducida. Disco dorado para actor activo, escudo azul persistente para Defender y enlace azul para Protección sobre un aliado diferente.
- Ataque físico: avance corto y retorno; magia: pulso de lanzamiento y destello según elemento; daño: reacción, destello y cifra de pérdida real; curación: verde y cifra de PV recuperados; defensa/protección: postura y pulso azul; inconsciencia: figura tumbada y oscurecida.
- Protección reproduce un evento explícito de interceptación: Kael se desplaza hacia la trayectoria del ataque, aparece «¡Protección!» y el impacto se representa sobre el receptor real indicado por el motor. Autoprotección utiliza el mismo flujo.
- Ignar es una manifestación naranja con núcleo luminoso, cuernos y una luz puntual sin sombras. Aparece escalando, produce un impacto y texto `DEF ↓` por enemigo afectado y se retira. No es un nuevo combatiente. La secuencia dura aproximadamente 1,3 s con un enemigo y 1,7 s con dos, a velocidad normal.
- UI superpuesta con cabecera de turno/acción, RE y Guardián; panel inferior de acciones, objetivos y registro; reinicio de combate y nueva partida. Se conserva `scenes/battle.tscn` como respaldo funcional 2D.

### Decisiones técnicas y límites de esta presentación

- El motor solo amplía sus notificaciones: `action` (actor, objetivo, efecto, elemento y nombre), `damage` (receptor real y PV antes/después/perdidos), `heal` (PV y recuperación), `intercept` (atacante, protector y objetivo original), más los eventos de invocación existentes. Acciones rechazadas no emiten eventos. No se cambian daño, turnos, RE, PA ni condiciones de victoria/derrota.
- `battle_stage.gd` escucha la señal y reproduce una cola de eventos. No interpreta texto del registro ni calcula daño. Al finalizar, sincroniza poses, etiquetas e indicadores con el estado resuelto del motor. Los valores flotantes proceden de los eventos.
- La resolución lógica es inmediata; solo se bloquea la entrada de acciones/objetivos mientras se presenta el resultado. La cabecera indica la acción en curso y luego el siguiente turno. Reinicio y nueva partida permanecen disponibles; una generación de presentación cancela colas anteriores para evitar efectos tardíos sobre una batalla nueva.
- `battle_hud_3d.gd` hereda el controlador de `battle.gd`: cambia la distribución, no la selección ni validación de acciones. `battle_actor_visual.gd` contiene únicamente geometría, poses y tweens.
- Renderizador Compatibility para escritorio y futura prueba móvil, sin sombras, partículas complejas, texturas externas ni postprocesado. Revisión visual en 960×640 y 800×600; no se afirma rendimiento ni compatibilidad real en teléfonos sin exportarlos y medirlos.
- Todo el arte sigue siendo provisional: modelos, animaciones sin esqueleto, arena, iluminación, efectos e interfaz. Quedan para después modelos definitivos, rigs, audio, cámaras elaboradas y cinemáticas. No se añaden nuevas mecánicas ni otros Guardianes.
- Las pruebas conservan todas las comprobaciones de 0.3 y añaden carga e integración de la presentación. La precarga de las escenas requiere aislar los Resources externos que se modifican en pruebas mediante copias profundas; así no dependen de que Godot descargue o mantenga recursos en caché.

## Primera zona explorable implementada (0.5)

### Bosque del Eclipse: Claro de las ruinas

- Nuevo arranque `scenes/forest_exploration.tscn`, coordinado por `world/game_flow.gd`. La geometría y controles del claro están en `scenes/forest_zone.tscn` y `world/forest_zone.gd`.
- Claro autocontenido de 18×14 unidades: suelo, sendero, árboles, rocas, dos columnas en ruinas y muros perimetrales con colisión. Arte procedural coherente con las primitivas del combate, sin assets externos, audio ni postprocesado pesado.
- Cámara ortográfica fija lejana, inclinada y sin giro libre. Se muestra el espacio completo. Kael es el único líder visible; Lyra y Nira siguen formando parte del grupo de combate. Esta representación sin seguidores es provisional.
- Movimiento con WASD/flechas mediante `CharacterBody3D`, velocidad configurable, normalización de diagonal, gravedad y colisión por `move_and_slide()`. El modelo gira hacia su desplazamiento. No hay salto, carrera ni navegación automática.
- Entrada desacoplada mediante `set_movement_input(Vector2)` y `clear_movement_input()`, preparada para un futuro control táctil, todavía no implementado.
- Dos Centinelas estáticos y visibles. Cada encuentro tiene ID, etiqueta, posición, radio de detección y enemigos configurables con `EncounterData`. Una `Area3D` próxima al marcador detecta al líder; el círculo naranja representa su proximidad. No hay encuentros aleatorios, persecución ni activación remota. Los IDs deben ser únicos dentro del claro.
- HUD mínimo: área, grupo, RE, portador/nivel/PA de Ignar, contador de encuentros, controles, resultado del último encuentro y nueva partida. Tras eliminar ambos Centinelas, informa que el claro está despejado.

### Flujo y estado persistente en memoria

- `GameSession` separa el modo (`EXPLORING`, `BATTLE`, `DEFEAT`), área, posición de retorno, definiciones del grupo, encuentros derrotados y `PartyState`. No hay singleton/autoload ni serialización: el controlador entrega explícitamente la misma instancia de estado a cada escena.
- Al contacto se bloquea el movimiento inmediatamente. La transición se difiere fuera del vaciado de consultas físicas, se retira el claro del árbol de escenas y se instancia la batalla 3D existente. Esto desactiva su física, cámara, entorno y HUD sin destruir la zona.
- Se configura la batalla antes de entrar en el árbol: héroes, enemigos del encuentro y el mismo `PartyState`. El motor de combate no se modifica en 0.5. RE, Guardianes, vínculo y PA siguen usando sus reglas existentes.
- **Decisión provisional de PV/PM:** no hay persistencia de esos recursos en `PartyState`; por tanto cada encuentro o reintento comienza con sus máximos configurados, independientemente del desgaste o inconsciencia anteriores. No se añade curación de campo ni inventario. Persistir PV/PM se deja para una decisión posterior explícita.
- Victoria: una señal de la presentación informa al controlador cuando termina la cola visual. Se registra el ID derrotado, se vuelve automáticamente al mismo claro y posición, se retira su marcador/detección y se recupera el control. El motor ya ha concedido los +50 PA; el controlador no duplica premios. RE se conserva exactamente como quedó en combate.
- Derrota: la batalla permanece visible, permite reintentar con PV/PM completos o volver al punto inicial del claro. El enemigo continúa disponible, sin PA por derrota. RE, vínculos y progreso anteriores se conservan. No hay pantalla de game over definitiva.
- El botón de partida independiente se sustituye en encuentros integrados por «Volver al claro», habilitado solo tras una derrota ya presentada. Las escenas de combate abiertas solas conservan sus controles de prueba originales.
- Nueva partida desde exploración restablece posición, enemigos, RE y PA. Las solicitudes diferidas de una partida anterior se descartan; la zona retirada se libera al cerrar el controlador. Los datos solo duran mientras está abierta la partida.
- Transiciones mediante corte directo, sin fundidos ni cinemáticas. Se conservan ambas escenas de combate para pruebas independientes con F6.

### Encaje en el vertical slice y pendientes

Este claro valida el primer bucle explorar → encuentro visible → combate → victoria → explorar. Es una base pequeña para el futuro vertical slice de 20–30 minutos del Bosque del Eclipse; no pretende tener todavía esa duración ni contenido narrativo.

Siguen pendientes otras zonas conectadas, navegación táctil real, seguidores, persistencia de PV/PM, guardado real, diálogos, quests, secretos, puzzles, inventario, tiendas, progresión de personajes y presentación final. No se implementan Guardianes adicionales. La compatibilidad/rendimiento móvil no se afirma sin pruebas en dispositivos reales.

## Decisiones de diseño futuras, no implementadas

Estas decisiones están confirmadas para el juego futuro. No describen funcionalidades disponibles en el prototipo de combate ni autorizan su implementación en esta iteración.

### Identidad

- JRPG para móvil con exploración 3D de estética fantástica inspirada en los clásicos de finales de los noventa.
- Cámara fija o semiautomática; combates por turnos puros, sin ATB (estos turnos sí están implementados en el prototipo).
- Historia propia, sin reutilizar personajes, diseños, música ni recursos protegidos de Final Fantasy.
- Primer vertical slice de 20–30 minutos.

### Guardianes

- Las reglas básicas de invocación, RE persistente entre combates, vínculo único, PA independientes de EXP y progreso conservado al cambiar de portador ya están implementadas para Ignar, según las secciones anteriores.
- Pendientes: representación definitiva con modelos 3D, efectos y cinemáticas; Ignar ya tiene una manifestación geométrica provisional. Otros Guardianes previstos: Nivara (hielo) y Sylvan (naturaleza).
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

No se implementan todavía otros Guardianes, progresión de personajes, especializaciones, inventario, exploración fuera del primer claro ni guardado. Mundo abierto, animaciones complejas y exportación móvil también quedan fuera de esta entrega. Solo la progresión por PA de Ignar está implementada.

## Estructura

`combat/`: motor RefCounted, estados y tipos Resource. `data/`: personajes, Guardianes y habilidades editables. `scenes/`: escenas y presentación del combate. `world/`: estado de sesión, controlador de flujo, exploración y encuentros. `tests/`: pruebas sin framework. `docs/`: reglas y alcance.
