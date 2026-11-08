class_name ExpeditionStory
extends RefCounted

# Dialogue content is independent of flow, movement and mission conditions.
# Additional portrait/audio keys can be added to lines without changing progress.
const POINTS: Array[Dictionary] = [
	{"id": "camp", "title": "Campamento abandonado", "position": Vector3(-4.5, 0, 2), "radius": 1.6},
	{"id": "crystal", "title": "Fragmento de cristal", "position": Vector3(3.1, 0, -0.5), "radius": 1.5},
	{"id": "inscription", "title": "Inscripción antigua", "position": Vector3(-2.4, 0, -2.2), "radius": 1.7},
	{"id": "anomaly", "title": "Eco bajo las ruinas", "position": Vector3(0, 0, -2.9), "radius": 1.7}
]

const CONVERSATIONS: Dictionary = {
	"intro": [
		{"speaker": "Kael", "text": "La expedición debía regresar por este sendero. Buscaremos su rastro. Y nadie se separa del grupo."},
		{"speaker": "Lyra", "text": "Hay magia en las ruinas. No un hechizo… algo que repite la misma nota, una y otra vez."},
		{"speaker": "Nira", "text": "El bosque también la siente. Esas hojas se han secado por dentro. Ni siquiera se oyen pájaros."},
		{"speaker": "Kael", "text": "Y esos Centinelas no se han despertado solos. Primero averigüemos quién pasó por aquí."},
		{"speaker": "Lyra", "text": "Intentemos no romper la única pista antes de entenderla."},
		{"speaker": "Kael", "text": "Si la pista intenta aplastarnos, no prometo nada."}
	],
	"camp": [
		{"speaker": "Nira", "text": "Una taza, mantas… No recogieron nada. Quien durmió aquí pensaba volver."},
		{"speaker": "Kael", "text": "La insignia de la expedición. El broche está arrancado, pero no veo sangre."},
		{"speaker": "Lyra", "text": "La ceniza de la hoguera forma un círculo hacia las ruinas. ¿Lo habéis visto?"},
		{"speaker": "Kael", "text": "Sí. Y no me gusta. Sigamos el rastro con cuidado."}
	],
	"camp_repeat": [
		{"speaker": "Nira", "text": "Dejemos la insignia aquí, a la vista. Si alguien consigue volver, sabrá que lo estamos buscando."}
	],
	"crystal": [
		{"speaker": "Lyra", "text": "Este cristal no guarda energía: la recibe. El pulso viene de debajo de las ruinas."},
		{"speaker": "Kael", "text": "Entonces suéltalo antes de que quien lo envía note que estamos escuchando."},
		{"speaker": "Lyra", "text": "No conozco este patrón. Es demasiado preciso para ser una filtración natural… y demasiado antiguo para ser nuevo."},
		{"speaker": "Nira", "text": "Las raíces a su alrededor están negras. Podemos aprender de él sin tocarlo más."}
	],
	"crystal_repeat": [
		{"speaker": "Lyra", "text": "La misma nota. Hay algo al otro lado, pero el cristal no nos dice qué es."}
	],
	"inscription": [
		{"speaker": "Lyra", "text": "Sólo queda un fragmento: «Tres llamas sostienen el umbral. Mientras la piedra duerma…». El resto se ha borrado."},
		{"speaker": "Kael", "text": "Esto no era una puerta. Era un cerrojo. Los Centinelas debían impedir que algo saliera."},
		{"speaker": "Nira", "text": "Las raíces crecen hacia dentro, incluso donde no hay luz. Como si algo tirara de ellas."}
	],
	"inscription_repeat": [
		{"speaker": "Kael", "text": "Una barrera rota y guardianes despiertos. No parece una coincidencia."}
	],
	"anomaly": [
		{"speaker": "Nira", "text": "Esperad. La tierra sigue temblando, aunque los Centinelas ya no se mueven."},
		{"speaker": "Lyra", "text": "El cristal, la ceniza… Todo responde a este pulso. No despertó a los guardianes alguien que entró. Los llamó algo de abajo."},
		{"speaker": "Kael", "text": "Y la expedición siguió esa llamada. No desaparecieron en el bosque: llegaron hasta las ruinas."},
		{"speaker": "Nira", "text": "Puede que aún estén ahí. Pero lo que los llamó está enfermando al bosque."},
		{"speaker": "Lyra", "text": "Hay un paso bajo las raíces. La barrera cedió desde el interior."},
		{"speaker": "Kael", "text": "Entonces entraremos juntos. Encontraremos a la expedición antes de que ese pulso vuelva a llamar a nadie."}
	],
	"anomaly_repeat": [
		{"speaker": "Nira", "text": "El eco continúa bajo nuestros pies. La búsqueda seguirá en el interior de las ruinas."}
	]
}

static func lines(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(CONVERSATIONS.get(id, []).duplicate(true))
	return result
