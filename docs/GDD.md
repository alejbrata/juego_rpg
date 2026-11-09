# Eclipse JRPG

Piloto local del 9/11/2026: el diseñador autorizó un nuevo intento en Blender basado en su lámina de Kael antes de considerar Tripo. Se conserva como candidato `reference-study`, separado y seleccionable en combate/exploración; no está aprobado ni activado por defecto. [Informe y límites](KAEL_REFERENCE_STUDY.md). No se adoptan como canon los textos de personalidad o arma de la lámina. La estrategia definitiva sigue pendiente de revisión artística; no se modifican mecánicas ni historia.

Estudio posterior a la investigación 1.0: por petición del diseñador se probó una remodelación local de las proporciones del Kael existente, conservada por separado. [Resultado y capturas](KAEL_PROPORTION_STUDY.md). No alcanza la referencia de Final Fantasy VIII y no se adopta como modelo del juego. No revoca la decisión de abandonar la construcción de protagonistas finales desde primitivas ni autoriza servicios externos.

## Estado actual: cambio de estrategia artística e investigación (1.0)

Decisión confirmada: **dejar de generar los protagonistas desde cero mediante geometría procedural**. Se buscarán recursos con calidad artística y licencias verificables, adaptados en Blender/Godot. Se conservan versiones/fallback existentes; la funcionalidad no acredita calidad artística. La revisión 0.9 no alcanzó el acabado solicitado y sus valoraciones anteriores no constituyen aprobación del diseñador.

Entrega 1.0: [comparación y propuesta](ART_DIRECTION.md), [inventario de licencias](ASSET_LICENSES.md). Preferencia visual condicionada por los personajes Fantasy/Mage y Nature with Ruins de JustCreate; aún no autorizados para compra/adaptación. KayKit/Kenney tienen opciones gratuitas claras pero no se acreditó su ajuste al objetivo; Quaternius muestra condiciones CC0/QAL contradictorias; otras alternativas implican coste alto de retopología o dependencia de UE. No se declara inexistencia general de alternativas gratuitas.

No se ha descargado ni incorporado ningún modelo externo, ni se ha ejecutado una adaptación en Blender. No hay capturas en Godot ni métricas propias de candidatos externos; solo inspección de publicidad pública. El juego visual sigue en 0.9, por debajo de las referencias. Antes del piloto se requiere elegir dirección, presupuesto y una vía de licencia compatible con adquisición, colaboradores, herramientas y repositorio. No se compran ni aceptan términos por el usuario.

Única corrección de recurso existente: importación del atlas de Kael como imagen embebida (`gltf/embedded_image_handling=3`), evitando depender de un PNG extraído ausente. El arranque de la revisión reveló errores previos (517 comprobaciones alcanzadas, 2 fallos); tras recuperar la base y corregir importación, suite completa 576/576 headless y render real. Sin cambios de GLB/fuente, reglas, sesión, personajes restantes o historia. Se detalla la diferencia entre fallo inicial y resultado final en ART_DIRECTION.

Presupuestos futuros orientativos: protagonistas 8000–15000 triángulos, enemigos normales 5000–12000, texturas preferentemente 512–1024 y materiales acotados. Evaluar excepciones; no confundir esos límites con rendimiento medido. La historia 0.7 sigue provisional, no canon.

## Historial: revisión artística de Kael (0.9)

Entrega confirmada exclusivamente visual. Se abrió la fuente 0.8 en Blender 5.2.1 LTS, se capturaron cuerpo y rostro y se ejecutaron las 558 comprobaciones de partida. Cinco límites identificados: ojos/facciones salientes y planos, mechones en bloques, manos redondeadas, poca separación del vestuario y materiales planos en 17 superficies.

Dirección elegida: aventurero estilizado de fantasía original; azul marino, cuero cálido y metal discreto. Nueva geometría para mandíbula, mejillas, nariz y frente; ojos almendrados, párpados, cejas y boca; cabello barrido con crestas; mangas articuladas y guantes con palma/pulgar/nudillos, botas con suela/empeine, faldones separados, pechera curva, correa conformada y bolsa con solapa. Espada con guarda curva, agarre envuelto y canal. Atlas procedural determinista con matices, gradientes, trama, costuras y grano; no pintura manual ni servicio externo.

Se conserva exactamente el esqueleto de 17 huesos y las claves de las seis Actions de 0.8, usando su `.blend` archivado como fuente. No hay cambios de BattleEngine, PartyState, GameSession, historia, habilidades o estadísticas. Lyra, Nira y enemigos mantienen sus modelos. La historia de 0.7 continúa provisional y no canon.

### Presupuesto observado y versiones

- 6618 triángulos; 3591 vértices de autor, 8696 exportados por UV/normales/materiales. Dos mallas, dos materiales opacos y cuatro superficies, frente a 17 anteriores.
- Un atlas 1024×1024, PNG editable de 828.476 bytes, empaquetado en fuente y GLB sin rutas externas. GLB de 1.390.436 bytes (≈1,33 MiB); `.blend` de 1.066.258 bytes.
- Textura decodificada RGB8: 3 MiB CPU observados sin mipmaps; estimación conservadora RGBA8 de 4 MiB o 5,33 MiB con mipmaps. No es VRAM medida.
- Importación nativa `GLTFDocument` + generación de escena: 26,03 ms headless en el equipo de desarrollo; excluye arranque del editor y LOD. Sin mediciones de FPS o pruebas Android/iOS. El presupuesto preferido hasta 8000–12000 triángulos no obliga a consumirlo; no se necesita el máximo de evaluación de 15000.
- Por defecto se activa **0.9** tras inspeccionar [comparación real](previews/kael09-comparison.png). Hay mejora visible de facciones, capas y acabado respecto a 0.8; no se declara modelo comercial definitivo. Las fuentes y GLB 0.8 se conservan en `assets/characters/kael/v08/`; `visuals/kael/asset_version="0.8"` los activa en batalla y exploración. `use_imported=false` sigue recuperando el procedural original.

### Validación y límites artísticos

576/576 comprobaciones, headless y render real; las 558 previas se mantienen sin alterar expectativas. Nuevos casos verifican versiones, hashes de fuentes/atlas, reposo y claves del rig original, geometría importada, UV, pesos, materiales y textura embebida. Se reabrió y reexportó realmente la fuente nueva con los seis clips intactos y GLB coincidente. Capturas de [cuerpo anterior](previews/kael09-before-full.png), [cuerpo nuevo](previews/kael09-after-full.png), [rostro anterior](previews/kael09-before-face.png), [rostro nuevo](previews/kael09-after-face.png), [Attack](previews/kael09-attack.png) y [Walk](previews/kael09-walk.png); también Hurt, Defend y KO. Cámara, iluminación y escala iguales para las parejas. Comparación independiente de las pruebas.

Quedan planos visibles en mejillas/mentón, pelo simplificado, expresión fija, manos sin dedos articulados y atlas repetido sin pintura facial única. Se requiere ajuste manual de facciones, implantación del cabello, nudillos, ropa y pintura artística antes de fijar una referencia comercial para todo el reparto. Las poses inspeccionadas no muestran separaciones graves, pero no se revisan todos los fotogramas y cámaras. Sin IK, facial ni mezcla avanzada; posible deslizamiento de pies y cruces menores. Los pequeños detalles no siempre se leen en la cámara de combate. Pipeline válido como base técnica, no como sustituto de dirección artística/manual por personaje. Comandos de regeneración, exportación sin reconstrucción, comparación y medición en README.

## Historial: piloto visual y pipeline Blender (0.8)

Decisión confirmada de implementación: sustituir únicamente la representación de Kael mediante un asset original de Blender, sin modificar BattleEngine, PartyState, GameSession, balance ni sistemas narrativos. El contenido narrativo de 0.7 sigue siendo **provisional, no canon**; no se han añadido decisiones de historia.

### Entrega visual 0.8

- Malla perfilada con anatomía y vestuario coherentes, rostro sencillo con volumen, mechones castaños, armadura ligera azul, correas, guantes, botas y espada. Dos mallas con skin y pesos normalizados, un Armature de 17 huesos; espada vinculada a la mano derecha.
- Fuente `assets/characters/kael/kael.blend` y exportación autocontenida `kael.glb`. Generación reproducible y exportación de fuente editada en `tools/blender/`; manifiesto con hashes. Ejecutados con Blender 5.2.1 LTS local tras comprobar que MCP no respondía. Importación nativa de GLB en Godot 4.7.2, sin importación directa de `.blend` ni configuración global.
- Clips: Idle, Walk, Attack, Hurt, Defend, KO. El adaptador visual usa eventos ya resueltos; no calcula daño, recursos o turnos. Defensa e inconsciencia mantienen pose hasta sincronizar otro estado. Reinicio/omisión cancelan presentación y recuperan el estado del motor.
- El mismo asset se utiliza en batalla y exploración; Walk depende del movimiento horizontal real y vuelve a Idle al detenerse/bloquearse. Se mantienen formación, colisiones y velocidad. Lyra, Nira, Centinela e Ignar conservan sus modelos anteriores.
- Fallback configurable global o por escena. Un recurso ausente o incompleto genera aviso comprensible y recupera el Kael procedural. Las bibliotecas de animación y efectos se aíslan por instancia.
- Presupuesto actual: 3528 triángulos, 1892 vértices de autor, 17 huesos y 17 superficies entre cuerpo/espada; sin texturas externas. El rig añade coste de skinning y las superficies varias llamadas de dibujo. Límite preventivo 7000 triángulos; no se dispone de mediciones de FPS ni validación en móviles.
- Verificación: 507 comprobaciones previas conservadas, 51 nuevas, **558/558** headless y render real. Reapertura y reexportación real del `.blend`, comprobación de contrato y hashes, inspección de comparaciones y poses. [Antes](previews/kael-before-detail.png) / [después](previews/kael-after-detail.png) con igual cámara. La valoración visual se apoya en estas imágenes, no solo en las pruebas.

Limitaciones confirmadas: piloto artístico, manos simplificadas sin dedos articulados, sin expresión facial animada, sin IK de pies ni mezcla avanzada; posible deslizamiento al andar. La silueta y el vestuario mejoran frente al procedural, pero el rostro/cabello requieren más dirección artística. No se han observado deformaciones graves en las poses revisadas; no equivale a revisión exhaustiva de todos los fotogramas. Mejoras artísticas posteriores y otros personajes son ideas futuras, no implementadas ni autorizadas por este pipeline. Comandos, contrato de sustitución y edición en README.

### Base jugable conservada (0.7)

Numeración corregida: 0.5 = primer claro explorable; 0.6 = renovación visual del combate; 0.7 = «La expedición perdida». Las reglas de combate y sus Resources se mantienen.

JRPG de fantasía para Android e iOS, estética 3D inspirada en los clásicos de finales de los noventa, exploración con cámaras fijas o semiautomáticas. Proyecto para una persona con ayuda de Codex. El vertical slice futuro tendrá 20–30 minutos; la aventura actual es un comienzo narrativo breve de 5–10 minutos objetivo que reutiliza el claro y dos encuentros. Su duración depende de lectura/decisiones y aún no se ha medido con jugadores.

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

## Presentación 3D implementada (0.6)

- Escena de combate `scenes/battle_3d.tscn`: arena autocontenida de ruinas olvidadas en el Bosque del Eclipse. Pavimento irregular, musgo, hierba, rocas, columnas quebradas y fondo de árboles facetados. La composición central queda despejada; no es una nueva zona explorable.
- Héroes a la izquierda y enemigos a la derecha con formación escalonada, orientados hacia el bando contrario y separados para poder leer sus siluetas. Se mantiene la formación para varios enemigos. Los modelos se asocian a IDs existentes, nunca a nombres de nodos para resolver lógica.
- Dirección artística: fantasía original low-poly, ligeramente caricaturesca; proporciones expresivas, piel y cabello facetados, colores cohesionados de cuero/metal, azul oscuro, violeta/dorado y verde/crema. Kael tiene anatomía robusta, armadura y espada; Lyra, silueta esbelta, capa y bastón ornamental; Nira, cabello cobrizo, atuendo de sanadora y vara natural. Todos tienen rostro esquemático, cabeza, torso, brazos, piernas y accesorios. El Centinela tiene roca irregular, brazos grandes, pies pesados, musgo, ojos luminosos y grietas de energía.
- Nombres mínimos en 3D; PV/PM del grupo en tarjetas de HUD y PV enemigos junto a su nombre. Aro dorado para el actor activo, escudo azul persistente para Defender, enlace para Protección y aro turquesa para preselección de objetivo. El texto detallado de estados sigue disponible para diagnóstico sin superponerse a los modelos; las tarjetas indican defensa/vínculo y las señales 3D indican protección/DEF reducida.
- Ataque físico: avance corto y retorno; magia: pulso de lanzamiento y destello según elemento; daño: reacción, destello y cifra de pérdida real; curación: verde y cifra de PV recuperados; defensa/protección: postura y pulso azul; inconsciencia: figura tumbada y oscurecida.
- Protección reproduce un evento explícito de interceptación: Kael se desplaza hacia la trayectoria del ataque, aparece «¡Protección!» y el impacto se representa sobre el receptor real indicado por el motor. Autoprotección utiliza el mismo flujo.
- Reposo con respiración y oscilación de capa. Físicos con avance/gesto de arma y retorno; magia de fuego con proyectil cálido; hielo con cristal y fragmentos; curación con motas ascendentes. Daño/caída, Defender y Protección mantienen sus eventos y estados existentes.
- Ignar es un titán grande de roca oscura con lava luminosa, cuernos, brazos masivos, círculo de materialización y una luz puntual sin sombras. Aparece con cambio breve de encuadre, ejecuta Juicio de Ceniza con impactos volcánicos por objetivo y desaparece; la cámara retorna suavemente. La secuencia sigue siendo aproximadamente 1,3 s con un enemigo y 1,7 s con dos a velocidad normal; no modifica efectos lógicos.
- UI superpuesta compacta: cabecera con turno/RE/Guardián, tres tarjetas de PV/PM y comandos inferiores. Elegir habilidad sustituye comandos por objetivos; «Atrás» cancela. Registro completo en panel opcional, disponible mediante «Registro». Transición breve de opacidad al seleccionar objetivos. Se conservan reinicio/nueva partida y el respaldo 2D.

### Decisiones técnicas y límites de esta presentación

- El motor solo amplía sus notificaciones: `action` (actor, objetivo, efecto, elemento y nombre), `damage` (receptor real y PV antes/después/perdidos), `heal` (PV y recuperación), `intercept` (atacante, protector y objetivo original), más los eventos de invocación existentes. Acciones rechazadas no emiten eventos. No se cambian daño, turnos, RE, PA ni condiciones de victoria/derrota.
- `battle_stage.gd` escucha la señal y reproduce una cola de eventos. No interpreta texto del registro ni calcula daño. Al finalizar, sincroniza poses, etiquetas e indicadores con el estado resuelto del motor. Los valores flotantes proceden de los eventos.
- La resolución lógica es inmediata; solo se bloquea la entrada de acciones/objetivos mientras se presenta el resultado. La cabecera indica la acción en curso y luego el siguiente turno. Reinicio y nueva partida permanecen disponibles; una generación de presentación cancela colas anteriores para evitar efectos tardíos sobre una batalla nueva.
- `battle_hud_3d.gd` hereda el controlador de `battle.gd`: cambia la distribución, no la selección ni validación de acciones. `battle_actor_visual.gd` contiene únicamente geometría, poses y tweens.
- Cámara de perspectiva diagonal y elevada, FOV base 42°. Golpe potente hace un acercamiento leve, impactos un desplazamiento de 0,035 unidades y la invocación un FOV de 38°; siempre retorna al encuadre principal. «Cámara suave» permite desactivarlo y cancela también movimientos en curso.
- «Omitir animación» consume la cola solo en presentación y sincroniza el estado ya resuelto; no ejecuta acciones ni repite daño/costes. Puede activarse durante Ignar y libera VFX, cámara y controles. Esta ruta no espera temporizadores reales. `animation_time_scale` mantiene la aceleración configurable. Reiniciar invalida secuencias anteriores y limpia efectos, poses, menús y cámara.
- Renderizador Compatibility, ambiente suave, luz principal cálida con una sombra direccional limitada a 30 unidades, acentos emisivos y una luz local de Ignar sin sombras. Sin texturas externas, partículas complejas ni postprocesado pesado. Se agrupa geometría estática por material conservando armas/capas como nodos animables y se comparten materiales inmutables.
- Revisión con render real en 960×640, 1280×720 y 800×450. Lectura puntual en el escritorio Intel Arc disponible: 60 FPS, 176 llamadas de dibujo y 46.592 primitivas en reposo a 960×640; incluye pasadas de sombra y no equivale a un perfil exhaustivo. Rendimiento y accesibilidad táctil reales en Android/iOS quedan pendientes.
- Todo el arte sigue siendo provisional: modelos, animaciones sin esqueleto, arena, iluminación, efectos e interfaz. Quedan para después modelos definitivos, rigs, audio, cámaras elaboradas y cinemáticas. No se añaden nuevas mecánicas ni otros Guardianes.
- Esta renovación no cambia `BattleEngine`, Resources ni `PartyState`, costes, afinidades, duraciones o balance. El arranque de exploración y sus transiciones existentes se conservan; no se añaden zonas ni exploración. Los modelos compartidos mejoran también los marcadores que ya los utilizaban, sin cambiar su comportamiento.
- Referencia real previa: 348 comprobaciones, no 306 (ya existía el primer claro). Se conservan todas y se añaden casos de asociación/orientación, agrupación, UI responsive, registro, objetivo, cámara y omisión/reinicio de Ignar. Capturas de la presentación actual en `docs/previews/`.
- Resultado final local: 385 comprobaciones y 0 fallos tanto en headless como con OpenGL, importación correcta y revisión de capturas renderizadas; no se afirma una validación móvil real.
- Las pruebas conservan todas las comprobaciones de 0.3 y añaden carga e integración de la presentación. La precarga de las escenas requiere aislar los Resources externos que se modifican en pruebas mediante copias profundas; así no dependen de que Godot descargue o mantenga recursos en caché.

## Primera zona explorable implementada (0.5)

### Bosque del Eclipse: Claro de las ruinas

- Nuevo arranque `scenes/forest_exploration.tscn`, coordinado por `world/game_flow.gd`. La geometría y controles del claro están en `scenes/forest_zone.tscn` y `world/forest_zone.gd`.
- Claro autocontenido de 18×14 unidades: suelo, sendero, árboles, rocas, dos columnas en ruinas y muros perimetrales con colisión. Arte procedural coherente con las primitivas del combate, sin assets externos, audio ni postprocesado pesado.
- Cámara ortográfica fija lejana, inclinada y sin giro libre. Se muestra el espacio completo. Kael es el único líder visible; Lyra y Nira siguen formando parte del grupo de combate. Esta representación sin seguidores es provisional.
- Movimiento con WASD/flechas mediante `CharacterBody3D`, velocidad configurable, normalización de diagonal, gravedad y colisión por `move_and_slide()`. El modelo gira hacia su desplazamiento. No hay salto, carrera ni navegación automática.
- Entrada desacoplada mediante `set_movement_input(Vector2)` y `clear_movement_input()`, preparada para un futuro control táctil, todavía no implementado.
- Dos Centinelas estáticos y visibles. Cada encuentro tiene ID, etiqueta, posición, radio de detección y enemigos configurables con `EncounterData`. Una `Area3D` próxima al marcador detecta al líder; el círculo naranja representa su proximidad. No hay encuentros aleatorios, persecución ni activación remota. Los IDs deben ser únicos dentro del claro.
- HUD: área, grupo, RE, portador/nivel/PA de Ignar, contador de encuentros, controles, resultado del último encuentro y nueva partida. Desde 0.7 añade objetivo e interacción cercana. Eliminar ambos Centinelas despeja el claro, pero no sustituye las condiciones narrativas.

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

Este claro valida el bucle explorar → encuentro visible → combate → victoria → explorar. Desde 0.7 incorpora la primera misión narrativa descrita debajo; sigue siendo una base pequeña y no el vertical slice completo de 20–30 minutos.

Siguen pendientes otras zonas conectadas, navegación táctil real, seguidores, persistencia de PV/PM, guardado real, conversaciones ramificadas, más misiones, secretos, puzzles, inventario, tiendas, progresión de personajes y presentación final. No se implementan Guardianes adicionales. La compatibilidad/rendimiento móvil no se afirma sin pruebas en dispositivos reales.

## La expedición perdida: misión implementada (0.7)

### Intención y personajes

Una expedición enviada a estudiar las ruinas no ha regresado. Kael, Lyra y Nira siguen su rastro. Kael es pragmático, protector y desconfiado: sospecha una activación deliberada de los Centinelas. Lyra es curiosa y se acerca a una magia que no comprende. Nira observa el silencio del bosque, hojas enfermas y raíces ennegrecidas, y aporta prudencia. Sus intervenciones son cortas, con desacuerdos leves y sin convertirlos en explicadores de mecánicas.

La revelación vincula las pistas y la desaparición con un pulso que procede de debajo de las ruinas y altera a sus guardianes de piedra. No revela la identidad, origen o naturaleza completa de esa fuerza. La historia es original y solo usa los tres protagonistas existentes.

### Estructura y decisiones mínimas

- Nueva partida abre el título «El Bosque del Eclipse» y seis intervenciones. Continuar/Espacio/Enter avanzan; «Omitir introducción» marca la introducción como vista sin investigar pistas ni conceder premios. Después se entrega control con «Investiga el claro».
- Tres puntos nativos integrados en el mapa existente: campamento con manta, hoguera apagada e insignia; cristal con raíces oscuras; inscripción junto a una columna. No se añaden enemigos, mapas, inventario ni recogida física de objetos. La insignia se observa y se deja en el campamento.
- Las pistas pueden examinarse en cualquier orden, antes, entre o después de los dos combates. Se registran al cerrar por completo la primera conversación. Revisitar muestra texto breve; no vuelve a registrar una pista ni genera RE, PA u otros premios.
- Condición explícita: las **tres** pistas y los **dos IDs de Centinelas existentes** derrotados. No hay secuencia rígida ni una pista que pueda saltarse. Los objetivos se derivan del estado: investigar → encontrar pistas → neutralizar Centinelas → examinar anomalía → completada, pudiendo omitir fases ya satisfechas por otro orden.
- Al cumplir condiciones aparece un círculo/fragmentos de energía tenue entre las ruinas y el objetivo invita a examinarlo. **Decisión de interacción:** el jugador debe acercarse y pulsar E/botón; no se teletransporta ni se dispara la conversación desde lejos.
- Al iniciarla se reclama `revelation_started` una sola vez y se amplifica el resplandor. Seis intervenciones deducen que la expedición entró bajo las ruinas; al cerrar, `completed` queda marcado. Un mensaje anuncia que la aventura continuará en el interior, sin crear esa zona.
- El final no concede recompensa adicional. Los +50 PA por victoria y todas las reglas de RE, Ignar, recursos y balance siguen intactos. La anomalía puede revisarse después con una sola intervención, sin repetir la revelación ni su efecto único.

### Diálogos e interacción

- `ExpeditionStory` contiene líneas `speaker`/`text`, títulos y posiciones; no hay grandes bloques de historia en GameFlow. El formato admite campos adicionales para retratos/audio, aún no usados.
- `DialogueBox` solo presenta y avanza. Rechaza aperturas simultáneas, vacías o sin campos requeridos. Consume presión y liberación de Espacio/Enter antes del botón de GUI para evitar doble avance, e ignora repetición de tecla. No hay temporizadores de lectura obligatorios, elecciones, voces ni localización completa.
- El claro coordina el bloqueo de movimiento y encuentros, y oculta interacción/Nueva partida/pistas de controles mientras el diálogo modal está abierto. Al cerrarlo devuelve el control. El mismo E que abre un diálogo no lo avanza.
- `NarrativeInterest` valida distancia horizontal y altura; el alcance oscila entre 1,5 y 1,7 unidades. Solo el punto cercano más próximo muestra etiqueta/aro discreto y el botón Examinar/Revisar. No hay flechas gigantes ni interacción remota. El botón ofrece una vía compatible con futura entrada táctil, sin afirmar pruebas móviles reales.
- UI con interlocutor, texto, contador, avance de 48 unidades lógicas, omisión de intro y título. Anclajes/contenedores para 960×640, 1280×720 y 800×450; no se superponen controles de exploración activos al panel.

### Estado y continuidad

- `GameSession.mission` contiene un `ExpeditionMission` independiente: introducción vista, IDs investigados, revelación iniciada y completada. Sus condiciones no dependen de nodos ni de la presentación del diálogo. Se usa el array de encuentros derrotados existente; no se duplica el resultado del combate.
- Victoria y derrota conservan la misma misión, RE, PA y vínculos. Volver tras derrota sigue situando al líder en el inicio y mantiene enemigos pendientes; no repite la introducción ni borra pistas. PV/PM máximos por encuentro siguen siendo la simplificación documentada.
- Nueva partida crea estado de misión nuevo y restaura introducción, encuentros, RE y PA. No se añade guardado en disco ni un sistema genérico de quests/eventos globales.
- `BattleEngine` y la presentación 0.6 no incorporan dependencias ni cambios narrativos. Solo cambian los mensajes de retorno del controlador para mantener el tono de aventura.

### Validación y límites

La referencia antes de 0.7 fue de 385 comprobaciones. Se conservan y se añaden casos de diálogos, pulsación real, bloqueo de entrada, distancia, seis órdenes de pistas, revisitas, victoria/derrota, dos combates completos, persistencia, cierre único y nueva partida. El objetivo de duración de 5–10 minutos no se demuestra con pruebas aceleradas: requiere sesiones de lectura y decisiones con jugadores.

Resultado final: 507 comprobaciones y 0 fallos en headless y OpenGL; importación correcta, revisión de capturas renderizadas a 960×640, 1280×720 y 800×450 y ninguna modificación en `combat/` ni sus datos configurables.

Arte/objetos y efectos narrativos siguen siendo provisionales. No hay retratos, doblaje, elecciones, siguiente mapa, jefe ni revelación completa de la fuerza. El interior de las ruinas y la continuación quedan para después.

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
