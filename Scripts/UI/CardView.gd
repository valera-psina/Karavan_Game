class_name CardView
extends Control
## Одна карта на столе. Только визуал: не знает ни правил, ни чей это ход.

signal pressed(card: CardData)

const BASE_SIZE := Vector2(120.0, 180.0)

var card: CardData
var face_down := false
var selected := false
var targeted := false

var _hovered := false
var _fading_in := false
var _style: StyleBoxFlat

@onready var art: TextureRect = $Art
@onready var highlight: Panel = $Highlight
@onready var badge: Label = $Badge


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0, 0, 0, 0)
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(8)
	_style.border_color = Color(0.98, 0.8, 0.2, 1.0)
	highlight.add_theme_stylebox_override("panel", _style)

	_refresh()


func setup(p_card: CardData, p_face_down := false) -> void:
	card = p_card
	face_down = p_face_down
	_refresh()


func set_selected(value: bool) -> void:
	selected = value
	_refresh()


func set_targeted(value: bool) -> void:
	targeted = value
	_refresh()


## Бейдж в углу: "K", "Q", "K×2" — прикреплённые карты.
func set_badge(text: String) -> void:
	badge.text = text
	badge.visible = not text.is_empty() and not face_down


func _refresh() -> void:
	if art == null:
		return

	if face_down:
		art.texture = CardArt.back()
	elif card != null:
		art.texture = CardArt.face(card)
	else:
		art.texture = null

	highlight.visible = selected or targeted
	if highlight.visible and _style != null:
		if selected:
			_style.border_color = Color(0.98, 0.8, 0.2, 1.0)
			_style.set_border_width_all(3)
		else:
			_style.border_color = Color(0.45, 0.95, 1.0, 0.9)
			_style.set_border_width_all(2)

	modulate = Color(1.12, 1.12, 1.12, 1.0) if _hovered else Color.WHITE
	if _fading_in:
		modulate.a = 0.0


## Появление карты: масштаб + прозрачность, при offset — ещё и подлёт.
func pop_in(offset: Vector2 = Vector2.ZERO, duration: float = 0.24) -> void:
	var base_size := size if size.x > 1.0 else custom_minimum_size
	pivot_offset = base_size * 0.5
	_fading_in = true
	modulate.a = 0.0
	scale = Vector2(0.88, 0.88)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.7)
	tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): _fading_in = false)

	if offset != Vector2.ZERO:
		position += offset
		tween.tween_property(self, "position", position - offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_hover(hovered: bool) -> void:
	_hovered = hovered
	_refresh()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card != null and not face_down:
			pressed.emit(card)
			accept_event()
