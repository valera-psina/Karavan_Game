class_name CaravanView
extends PanelContainer
## Зона одного каравана: заголовок, сумма, направление, масть и стопка карт.
## Визуал + клики; правила применяет TableView/контроллер.

signal entry_pressed(caravan_index: int, entry_index: int)
signal slot_pressed(caravan_index: int)
signal discard_pressed(caravan_index: int)

const CARD_SCENE := preload("res://Scenes/CardView.tscn")
var card_size := Vector2(92.0, 138.0)
var step_y := 26.0
var att_step := 24.0

var index := 0
var is_enemy := false
var title := "КАРАВАН"
var state: CaravanState

var _entry_targets: Array[int] = []
var _slot_target := false
var _entry_ids := {}
var _style_normal: StyleBoxFlat
var _style_target: StyleBoxFlat

@onready var title_label: Label = $VBox/Header/Title
@onready var value_label: Label = $VBox/Header/Value
@onready var dir_label: Label = $VBox/Header/Dir
@onready var suit_dot: ColorRect = $VBox/Header/Dot
@onready var card_area: Control = $VBox/Cards
@onready var hint: Label = $VBox/Cards/Hint
@onready var discard_button: Button = $VBox/Header/Discard
@onready var header: HBoxContainer = $VBox/Header


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_normal = _make_style(Color(0.14, 0.46, 0.18, 1.0), 2)
	_style_target = _make_style(Color(0.98, 0.8, 0.2, 1.0), 3)
	add_theme_stylebox_override("panel", _style_normal)
	title_label.text = title
	discard_button.pressed.connect(func(): discard_pressed.emit(index))
	discard_button.modulate.a = 0.0
	discard_button.disabled = true


func setup(p_index: int, p_title: String, p_is_enemy: bool) -> void:
	index = p_index
	title = p_title
	is_enemy = p_is_enemy
	discard_button.visible = true
	discard_button.modulate.a = 0.0 if is_enemy else 1.0
	discard_button.disabled = is_enemy
	discard_button.disabled = true


func set_discard_enabled(value: bool) -> void:
	discard_button.visible = true
	discard_button.modulate.a = 0.0 if is_enemy else 1.0
	discard_button.disabled = is_enemy
	discard_button.disabled = not value or is_enemy


## Размер карты задаёт стол: от него зависит и высота зоны каравана.
func set_card_size(size: Vector2) -> void:
	card_size = size
	step_y = roundf(size.y * 0.19)
	att_step = roundf(size.x * 0.26)
	if card_area != null:
		card_area.custom_minimum_size = Vector2(0.0, size.y + 2.0 * step_y)
	# Всё в шапке растёт вместе с картой: на телефоне крестик роспуска
	# должен быть пальце-доступным.
	if discard_button != null:
		discard_button.custom_minimum_size = Vector2(
			roundf(size.x * 0.34), roundf(size.x * 0.34))
		discard_button.add_theme_font_size_override("font_size", int(roundf(size.x * 0.22)))
	if header != null:
		# Одинаковая шапка у всех караванов: крестик не делает панель шире.
		header.custom_minimum_size = Vector2(roundf(size.x * 1.55), roundf(size.y * 0.22))
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", int(roundf(size.y * 0.085)))
	if value_label != null:
		value_label.add_theme_font_size_override("font_size", int(roundf(size.y * 0.095)))
	if dir_label != null:
		dir_label.add_theme_font_size_override("font_size", int(roundf(size.y * 0.085)))
	if hint != null:
		hint.add_theme_font_size_override("font_size", int(roundf(size.y * 0.10)))
	if state != null:
		render(state)


func render(p_state: CaravanState) -> void:
	state = p_state
	if state == null or card_area == null:
		return

	title_label.text = title
	var v := state.value()
	value_label.text = str(v)
	value_label.add_theme_color_override("font_color", _value_color(state))
	dir_label.text = KaravanRules.direction_label(state.direction)
	suit_dot.color = _suit_color(state.suit)
	hint.visible = state.entries.is_empty()

	for child in card_area.get_children():
		if child == hint:
			continue
		card_area.remove_child(child)
		child.queue_free()

	var count := state.entries.size()
	var stack_height := card_size.y + maxf(0.0, float(count - 1)) * step_y
	var top := maxf(0.0, (card_area.size.y - stack_height) * 0.5)

	var next_ids := {}
	var z := 1
	for i in count:
		var entry := state.entries[i]
		var y := top + i * step_y

		# Числовая карта — вертикальная стопка: виден левый верхний угол.
		var view := _add_card(entry.base, Vector2(0.0, y), z)
		view.set_badge(_badge_for(entry))
		view.pressed.connect(_on_card_pressed.bind(i))
		view.set_meta("entry_index", i)
		if _entry_targets.has(i):
			view.set_targeted(true)
		z += 1

		var card_id := entry.base.get_instance_id()
		next_ids[card_id] = true
		if not _entry_ids.has(card_id):
			view.pop_in(Vector2(0.0, 14.0))

		# Валет / дама / король — веер вправо поверх своей карты.
		for j in entry.attachments.size():
			var attachment := _add_card(entry.attachments[j], Vector2((j + 1) * att_step, y), z)
			attachment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			z += 1
	_entry_ids = next_ids


func _add_card(card: CardData, pos: Vector2, order: int) -> CardView:
	var view: CardView = CARD_SCENE.instantiate()
	view.custom_minimum_size = Vector2.ZERO
	card_area.add_child(view)
	view.size = card_size
	view.position = pos
	view.pivot_offset = card_size * 0.5
	view.rotation = deg_to_rad(randf_range(-3.0, 3.0))
	view.z_index = order
	# Карта не должна съедать клик: он уходит на панель каравана.
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.setup(card)
	return view


func set_entry_targets(targets: Array[int]) -> void:
	_entry_targets = targets.duplicate()
	_apply_entry_targets()


## Все карты, которые сейчас лежат в зоне (для анимации полёта).
func card_views() -> Array[CardView]:
	var out: Array[CardView] = []
	for child in card_area.get_children():
		if child is CardView:
			out.append(child as CardView)
	return out


func clear_targets() -> void:
	_entry_targets.clear()
	set_slot_target(false)
	_apply_entry_targets()


func set_slot_target(value: bool) -> void:
	_slot_target = value
	if _style_normal == null:
		return
	add_theme_stylebox_override("panel", _style_target if value else _style_normal)


func _apply_entry_targets() -> void:
	for child in card_area.get_children():
		if child is CardView:
			var idx: int = child.get_meta("entry_index", -1)
			(child as CardView).set_targeted(_entry_targets.has(idx))


## По карте под точкой — играем в её позицию, по пустому полю — новая база.
func _emit_zone_click(point: Vector2) -> void:
	var entry_index := _entry_at(point)
	if entry_index >= 0:
		entry_pressed.emit(index, entry_index)
	else:
		slot_pressed.emit(index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_emit_zone_click(get_global_transform() * event.position)
		accept_event()


## Индекс позиции, чья карта лежит под глобальной точкой (или -1).
func _entry_at(point: Vector2) -> int:
	for child in card_area.get_children():
		if child is CardView:
			var view := child as CardView
			if view.has_meta("entry_index") and view.get_global_rect().has_point(point):
				return int(view.get_meta("entry_index"))
	return -1


func _on_card_pressed(_card: CardData, entry_index: int) -> void:
	entry_pressed.emit(index, entry_index)


func _badge_for(entry: KaravanEntry) -> String:
	var parts: Array[String] = []
	var kings := entry.king_count()
	var queens := entry.queen_count()
	if kings > 0:
		parts.append("K" if kings == 1 else "K×%d" % kings)
	if queens > 0:
		parts.append("Q" if queens == 1 else "Q×%d" % queens)
	return " ".join(parts)


func _value_color(s: CaravanState) -> Color:
	if s.is_busted():
		return Color(1.0, 0.42, 0.38, 1.0)
	if s.is_in_range():
		return Color(0.55, 0.95, 0.5, 1.0)
	return Color(0.92, 0.92, 0.88, 1.0)


func _suit_color(suit: int) -> Color:
	match suit:
		CardData.Suit.DIAMONDS, CardData.Suit.HEARTS:
			return Color(0.9, 0.35, 0.32, 1.0)
		CardData.Suit.CLUBS, CardData.Suit.SPADES:
			return Color(0.85, 0.87, 0.85, 1.0)
		_:
			return Color(0.45, 0.5, 0.45, 1.0)


func _make_style(border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.19, 0.055, 0.85)
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	return sb
