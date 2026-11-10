class_name CombatCues
extends RefCounted
## Iteration 1.7: presentation data for every existing combat action. Pure data:
## which effect, sounds, camera emphasis and timing each action uses. It reads the
## event the engine already emitted (label/effect/element) and never decides any
## rule: damage, targets, costs and order come only from BattleEngine.
##
## Keys: vfx (CombatVFX recipe), cast (sound when the gesture starts),
## release (sound at launch/contact), impact (sound on the target),
## shake (0..1 camera trauma on impact), zoom (FOV push during the action, 0 = none),
## contact (fraction of the attack clip at which the blow lands, physical only),
## hit_stop (seconds the attacker and target freeze on contact).

const ACTIONS := {
	"Ataque": {"vfx": "slash", "cast": "swing", "impact": "hit", "shake": 0.32, "zoom": 0.0, "contact": 0.48, "hit_stop": 0.045},
	"Golpe potente": {"vfx": "slash_heavy", "cast": "swing", "impact": "hit_heavy", "shake": 0.62, "zoom": 39.0, "contact": 0.5, "hit_stop": 0.08},
	"Llama": {"vfx": "fire", "cast": "fire_cast", "impact": "fire_impact", "shake": 0.5, "zoom": 39.5},
	"Escarcha": {"vfx": "ice", "cast": "ice_cast", "impact": "ice_impact", "shake": 0.42, "zoom": 39.5},
	"Cura": {"vfx": "heal", "cast": "", "impact": "heal", "shake": 0.0, "zoom": 0.0},
	"Protección": {"vfx": "protect", "cast": "", "impact": "protect", "shake": 0.0, "zoom": 0.0},
	"Impulso": {"vfx": "haste", "cast": "", "impact": "haste", "shake": 0.0, "zoom": 0.0},
	"Defender": {"vfx": "guard", "cast": "", "impact": "guard", "shake": 0.0, "zoom": 0.0},
}
## Enemy blows (the Sentinel's attack): heavier wind-up, hits read as "received".
const ENEMY_PHYSICAL := {"vfx": "slam", "cast": "enemy_swing", "impact": "hit_hero", "shake": 0.5, "zoom": 0.0, "contact": 0.55, "hit_stop": 0.06}
## Fallbacks by effect/element, so new data with the same effect still has a cue.
const BY_EFFECT := {"physical": "Ataque", "heal": "Cura", "protect": "Protección", "haste": "Impulso", "guard": "Defender"}
const BY_ELEMENT := {"fire": "Llama", "ice": "Escarcha"}

## Floating number styles: fill, outline, size (logical px at the 960x640 base).
const NUMBER_STYLES := {
	"damage": {"fill": Color("fff4dc"), "outline": Color("2a1608"), "size": 44},
	"damage_fire": {"fill": Color("ffc977"), "outline": Color("5a1800"), "size": 46},
	"damage_ice": {"fill": Color("d9f4ff"), "outline": Color("0b3a57"), "size": 46},
	"damage_heavy": {"fill": Color("fff0c2"), "outline": Color("3a1a00"), "size": 52},
	"received": {"fill": Color("ff9c8a"), "outline": Color("3b0a08"), "size": 40},
	"heal": {"fill": Color("a8ffc6"), "outline": Color("0b3a22"), "size": 42},
	"status": {"fill": Color("e9f2ff"), "outline": Color("0d1720"), "size": 22},
	"ko": {"fill": Color("e6dfd2"), "outline": Color("1a0d0d"), "size": 28},
	"summon": {"fill": Color("ffd08a"), "outline": Color("3a1200"), "size": 30},
}
## Short labels for support effects (shown under the target, small).
const STATUS_TEXT := {"protect": "Protección", "haste": "Impulso", "guard": "Defensa"}
const STATUS_COLORS := {"protect": Color("8fd8ff"), "haste": Color("ffe07a"), "guard": Color("b9d6ff")}

static func for_action(event: Dictionary, actor_is_enemy: bool) -> Dictionary:
	var label := String(event.get("label", ""))
	var effect := String(event.get("effect", ""))
	if actor_is_enemy and effect == "physical":
		return ENEMY_PHYSICAL
	if ACTIONS.has(label):
		return ACTIONS[label]
	if effect == "magic":
		return ACTIONS[BY_ELEMENT.get(String(event.get("element", "")), "Llama")]
	return ACTIONS.get(BY_EFFECT.get(effect, "Ataque"), ACTIONS["Ataque"])

## Style of the number for a damage event (presentation only: element and side).
static func damage_style(element: String, target_is_enemy: bool, heavy: bool) -> String:
	if not target_is_enemy:
		return "received"
	if element == "fire":
		return "damage_fire"
	if element == "ice":
		return "damage_ice"
	return "damage_heavy" if heavy else "damage"
