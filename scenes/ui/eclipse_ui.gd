class_name EclipseUI
extends RefCounted
## Shared look of the 1.5 interface: palette, fonts, panels, buttons, bars and small
## motion helpers. Presentation only: nothing here reads or changes game rules.
## Fonts: Cinzel (titles) and Alegreya Sans (text), SIL OFL 1.1, in assets/ui/fonts/.

# Palette: night blue, petrol green, ivory, muted gold, distinct state colours.
const NIGHT := Color("0d1720")
const NIGHT_SOFT := Color("15232d")
const PETROL := Color("1d3b3f")
const PETROL_LIGHT := Color("2c5458")
const IVORY := Color("efe7d4")
const IVORY_DIM := Color("b9b2a1")
const MUTED := Color("7f8a86")
const GOLD := Color("c9a961")
const GOLD_BRIGHT := Color("ecd08a")
const HP := Color("7fb86a")
const HP_LOW := Color("d9a441")
const HP_CRITICAL := Color("d8644f")
const MP := Color("5f9fd6")
const RESONANCE := Color("d99a3c")
const ENEMY := Color("e07a5f")
const ALLY := Color("7cc6b6")
const HERO_COLORS := {"kael": Color("6f9ccf"), "lyra": Color("a58ad8"), "nira": Color("8fbf7f")}

# Categories are presentation only: they group existing abilities by effect.
const CATEGORY := {
	"attack": {"name": "Ataque", "glyph": "⚔", "color": Color("d9cfb8")},
	"technique": {"name": "Técnica", "glyph": "◆", "color": Color("e2b866")},
	"magic": {"name": "Magia", "glyph": "✦", "color": Color("9fb7f0")},
	"support": {"name": "Apoyo", "glyph": "✚", "color": Color("8fd3a0")},
	"guard": {"name": "Defender", "glyph": "⛨", "color": Color("b8c6c9")},
	"guardian": {"name": "Guardián", "glyph": "✺", "color": Color("f0a64a")},
}
const ELEMENT_NAMES := {"fire": "Fuego", "ice": "Hielo", "none": ""}
const ELEMENT_COLORS := {"fire": Color("ef8a5a"), "ice": Color("8fd0ef")}

const TOUCH := 48.0
static var _fonts := {}

static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {
		"title": "res://assets/ui/fonts/Cinzel-Variable.ttf",
		"text": "res://assets/ui/fonts/AlegreyaSans-Regular.ttf",
		"medium": "res://assets/ui/fonts/AlegreyaSans-Medium.ttf",
		"bold": "res://assets/ui/fonts/AlegreyaSans-Bold.ttf",
	}[kind]
	var result: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	if kind == "title" and result is FontFile:
		var variation := FontVariation.new()
		variation.base_font = result
		variation.variation_opentype = {"wght": 600}
		result = variation
	_fonts[kind] = result
	return result

## Theme for a whole UI root: every Label/Button below inherits the fonts.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("text")
	t.default_font_size = 17
	t.set_color("font_color", "Label", IVORY)
	t.set_color("font_color", "Button", IVORY)
	t.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	t.set_color("font_focus_color", "Button", GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", GOLD_BRIGHT)
	t.set_color("font_disabled_color", "Button", Color(IVORY_DIM, 0.45))
	t.set_font("font", "Button", font("medium"))
	t.set_stylebox("normal", "Button", button_box(Color(PETROL, 0.55), Color(GOLD, 0.0)))
	t.set_stylebox("hover", "Button", button_box(Color(PETROL_LIGHT, 0.75), Color(GOLD, 0.5)))
	t.set_stylebox("pressed", "Button", button_box(Color(PETROL_LIGHT, 0.95), GOLD))
	t.set_stylebox("focus", "Button", focus_box())
	t.set_stylebox("disabled", "Button", button_box(Color(NIGHT, 0.4), Color(GOLD, 0.0)))
	t.set_color("font_color", "CheckButton", IVORY)
	t.set_color("font_hover_color", "CheckButton", GOLD_BRIGHT)
	t.set_color("font_focus_color", "CheckButton", GOLD_BRIGHT)
	t.set_font("font", "CheckButton", font("medium"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(state, "CheckButton", button_box(Color(PETROL, 0.0 if state == "normal" else 0.45), Color(GOLD, 0.0)))
	t.set_stylebox("focus", "CheckButton", focus_box())
	t.set_color("default_color", "RichTextLabel", IVORY)
	t.set_font("normal_font", "RichTextLabel", font("text"))
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	var soft_focus := focus_box()
	soft_focus.border_color = Color(GOLD, 0.35)
	soft_focus.set_border_width_all(1)
	t.set_stylebox("focus", "RichTextLabel", soft_focus)
	var text_area := StyleBoxEmpty.new()
	text_area.set_content_margin_all(6)
	t.set_stylebox("normal", "RichTextLabel", text_area)
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(GOLD, 0.35)
	scroll.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", scroll)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(NIGHT, 0.4)
	track.set_corner_radius_all(3)
	t.set_stylebox("scroll", "VScrollBar", track)
	return t

## Main window: deep night blue, thin muted-gold rim, soft rounded corners.
static func panel_box(alpha: float = 0.93, rim: Color = Color(GOLD, 0.55), radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(NIGHT, alpha)
	box.border_color = rim
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(12)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	return box

static func button_box(fill: Color, rim: Color, radius: int = 9) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

## Keyboard/gamepad focus: a gold ring drawn over the button (no fill change).
static func focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = GOLD_BRIGHT
	box.set_border_width_all(2)
	box.set_corner_radius_all(9)
	box.expand_margin_left = 1
	box.expand_margin_right = 1
	box.expand_margin_top = 1
	box.expand_margin_bottom = 1
	return box

static func panel(parent: Node, alpha: float = 0.93, rim: Color = Color(GOLD, 0.55)) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", panel_box(alpha, rim))
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(result)
	return result

static func label(parent: Node, text: String, size: int = 17, color: Color = IVORY, kind: String = "text") -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", font(kind))
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

## Small-caps caption used above values ("RESONANCIA", "OBJETIVO").
static func caption(parent: Node, text: String, color: Color = GOLD) -> Label:
	var result := label(parent, text.to_upper(), 12, color, "title")
	result.add_theme_constant_override("outline_size", 0)
	return result

static func bar(parent: Node, fill: Color, height: float = 8.0) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.custom_minimum_size.y = height
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.55, 0.6, 0.62, 0.16)
	back.border_color = Color(0, 0, 0, 0.35)
	back.set_border_width_all(1)
	back.set_corner_radius_all(int(height * 0.5))
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(int(height * 0.5))
	result.add_theme_stylebox_override("background", back)
	result.add_theme_stylebox_override("fill", front)
	parent.add_child(result)
	return result

static func set_bar_color(bar: ProgressBar, fill: Color) -> void:
	var front := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if front != null and front.bg_color != fill:
		front = front.duplicate()
		front.bg_color = fill
		bar.add_theme_stylebox_override("fill", front)

static func hp_color(hp: int, max_hp: int) -> Color:
	var ratio := float(hp) / maxf(1.0, max_hp)
	return HP if ratio > 0.5 else (HP_LOW if ratio > 0.25 else HP_CRITICAL)

## Circular emblem with the hero's initial (fallback portrait, never stretched art).
static func emblem(parent: Node, hero_id: String, title: String, diameter: float = 44.0) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var box := StyleBoxFlat.new()
	box.bg_color = Color(HERO_COLORS.get(hero_id, PETROL_LIGHT)).darkened(0.45)
	box.border_color = Color(HERO_COLORS.get(hero_id, GOLD))
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(diameter))
	holder.add_theme_stylebox_override("panel", box)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initial := label(holder, title.substr(0, 1), int(diameter * 0.5), IVORY, "title")
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.name = "Initial"
	var picture := TextureRect.new()
	picture.name = "Portrait"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.visible = false
	holder.add_child(picture)
	parent.add_child(holder)
	return holder

static func set_portrait(holder: PanelContainer, texture: Texture2D) -> void:
	var picture := holder.get_node_or_null("Portrait") as TextureRect
	if picture == null or texture == null:
		return
	picture.texture = texture
	picture.visible = true
	(holder.get_node("Initial") as Label).visible = false

## Safe-area margins (notches, rounded corners) in viewport units, at least `minimum`.
static func safe_margins(viewport: Viewport, minimum: float = 16.0) -> Dictionary:
	var result := {"left": minimum, "right": minimum, "top": minimum, "bottom": minimum}
	if DisplayServer.get_name() == "headless":
		return result
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or safe.size.x <= 0:
		return result
	var view := viewport.get_visible_rect().size
	var scale := view / Vector2(screen)
	result.left = maxf(minimum, safe.position.x * scale.x)
	result.top = maxf(minimum, safe.position.y * scale.y)
	result.right = maxf(minimum, (screen.x - safe.end.x) * scale.x)
	result.bottom = maxf(minimum, (screen.y - safe.end.y) * scale.y)
	return result

## Short, interruptible tween; instant when animations are skipped.
static func tween_to(node: Node, object: Object, property: String, value: Variant, seconds: float, instant: bool = false) -> Tween:
	if instant or not node.is_inside_tree():
		object.set(property, value)
		return null
	var tween := node.create_tween()
	tween.tween_property(object, property, value, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween
