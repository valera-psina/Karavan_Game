class_name TableView
extends Control
## Чистый рендер стола: рисует MatchState и превращает клики в сигналы.
## Правила, очередь хода и звук живут в GameController.
##
## Раскладка адаптивная: в ландшафте караваны шире, в портрете делят ширину
## поровну и становятся выше; рука всегда снизу, кнопки — в правом нижнем углу.

signal play_requested(card: CardData, caravan_index: int, entry_index: int)
signal discard_requested(card: CardData)
signal draw_requested()
signal pass_requested()
signal caravan_discard_requested(caravan_index: int)
signal menu_requested()

const CARD_SCENE := preload("res://Scenes/CardView.tscn")
const HAND_CARD_SIZE := Vector2(92.0, 138.0)
const HAND_CARD_SIZE_PORTRAIT := Vector2(190.0, 285.0)
const HAND_BACK_SIZE := Vector2(50.0, 75.0)
const HAND_BACK_SIZE_PORTRAIT := Vector2(64.0, 96.0)
const CARAVAN_CARD_SIZE := Vector2(84.0, 126.0)
const CARAVAN_CARD_SIZE_PORTRAIT := Vector2(130.0, 195.0)
const FLIGHT_TIME := 0.24

var state: MatchState
var interactive := false
var caravan_discard_allowed := false

var selected_index := -1
var selected_card: CardData

var player_views: Array[CaravanView] = []
var enemy_views: Array[CaravanView] = []

var _hand_views: Array[CardView] = []
var _seen := {}
var _pending_sources := {}
var _first_render := true
var _portrait := false

@onready var enemy_hand: HBoxContainer = %EnemyHand
@onready var enemy_title: Label = %EnemyTitle
@onready var deck_art: TextureRect = %DeckArt
@onready var deck_label: Label = %DeckLabel
@onready var discard_label: Label = %DiscardLabel
@onready var enemy_row: GridContainer = %EnemyRow
@onready var player_row: GridContainer = %PlayerRow
@onready var player_hand: GridContainer = %PlayerHand
@onready var status_label: Label = %Status
@onready var turn_label: Label = %TurnLabel
@onready var btn_draw: Button = %BtnDraw
@onready var btn_end: Button = %BtnEnd
@onready var btn_discard: Button = %BtnDiscard
@onready var btn_menu: Button = %Menu
@onready var overlay: Control = %Overlay


func _ready() -> void:
	deck_art.texture = CardArt.back()
	_style_buttons()
	_collect_views()

	btn_draw.pressed.connect(func(): _click(); draw_requested.emit())
	btn_end.pressed.connect(func(): _click(); pass_requested.emit())
	btn_discard.pressed.connect(_on_discard_pressed)
	btn_menu.pressed.connect(func(): _click(); menu_requested.emit())

	get_viewport().size_changed.connect(_apply_orientation)
	_apply_orientation()
	set_interactive(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_orientation()


# --------------------------------------------------------------- раскладка

func _apply_orientation() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var portrait := viewport_size.y > viewport_size.x
	_portrait = portrait

	# Холст подстраивается под форму окна: иначе ручное изменение размера окна
	# растягивает виртуальный экран и карты становятся мелкими.
	var window := get_viewport().get_window()
	if window != null:
		var canvas := Vector2i(1080, 1920) if portrait else Vector2i(1920, 1080)
		if window.content_scale_size != canvas:
			window.content_scale_size = canvas

	var caravan_card := CARAVAN_CARD_SIZE_PORTRAIT if portrait else CARAVAN_CARD_SIZE
	for view in player_views + enemy_views:
		view.set_card_size(caravan_card)
	player_hand.columns = 4 if portrait else 8
	player_hand.add_theme_constant_override("h_separation", -22 if portrait else -26)
	player_hand.add_theme_constant_override("v_separation", 8 if portrait else 0)

	# Верхняя панель: на узком экране подписи мельче и не наезжают друг на друга.
	enemy_title.clip_text = true
	turn_label.clip_text = true
	enemy_title.add_theme_font_size_override("font_size", 11 if portrait else 12)
	turn_label.add_theme_font_size_override("font_size", 17 if portrait else 20)
	btn_menu.custom_minimum_size = Vector2(96.0, 38.0) if portrait else Vector2(104.0, 42.0)
	_apply_ui_scale(portrait)

	_seen.clear()
	_first_render = true
	if state != null:
		_render_hand()


## Крупные пальцевые размеры: +25% на узких экранах (телефон в портрете).
func _apply_ui_scale(portrait: bool) -> void:
	var window := get_viewport().get_window()
	var width := float(window.size.x) if window != null else get_viewport_rect().size.x
	var scale := 1.25 if width < 1000.0 else 1.0
	if portrait and scale < 1.2:
		scale = 1.2

	var button_size := Vector2(168.0, 56.0) * scale
	for button in [btn_draw, btn_end, btn_discard]:
		button.custom_minimum_size = button_size
		button.add_theme_font_size_override("font_size", int(20.0 * scale))
	btn_menu.custom_minimum_size = Vector2(112.0, 46.0) * scale
	btn_menu.add_theme_font_size_override("font_size", int(16.0 * scale))
	status_label.add_theme_font_size_override("font_size", int(14.0 * scale))
	turn_label.add_theme_font_size_override("font_size", int((17.0 if portrait else 20.0) * scale))
	enemy_title.add_theme_font_size_override("font_size", int(11.0 * scale))


func _hand_card_size() -> Vector2:
	return HAND_CARD_SIZE_PORTRAIT if _portrait else HAND_CARD_SIZE


# ------------------------------------------------------------------ сцена

func _collect_views() -> void:
	player_views.clear()
	enemy_views.clear()

	for i in player_row.get_child_count():
		var view := player_row.get_child(i) as CaravanView
		if view == null:
			continue
		view.setup(i, "КАРАВАН %d" % (i + 1), false)
		view.entry_pressed.connect(_on_entry_pressed)
		view.slot_pressed.connect(_on_slot_pressed)
		view.discard_pressed.connect(_on_caravan_discard_pressed)
		player_views.append(view)

	for i in enemy_row.get_child_count():
		var view := enemy_row.get_child(i) as CaravanView
		if view == null:
			continue
		view.setup(MatchState.CARAVAN_COUNT + i, "КАРАВАН %d" % (i + 1), true)
		view.entry_pressed.connect(_on_entry_pressed)
		view.slot_pressed.connect(_on_slot_pressed)
		enemy_views.append(view)


func _style_buttons() -> void:
	btn_draw.text = "Взять"
	btn_end.text = "Ход"
	btn_discard.text = "Сброс"
	btn_menu.text = "Меню"
	btn_menu.clip_text = true
	btn_menu.custom_minimum_size = Vector2(104.0, 42.0)

	for b in [btn_draw, btn_end, btn_discard]:
		var btn := b as Button
		btn.custom_minimum_size = Vector2(156.0, 50.0)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.88, 0.96, 0.82))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.45))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.7))
		btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.52, 0.42))
		btn.add_theme_stylebox_override("normal", _button_style(Color(0.05, 0.28, 0.08, 0.95), Color(0.12, 0.5, 0.17)))
		btn.add_theme_stylebox_override("hover", _button_style(Color(0.07, 0.38, 0.11, 0.95), Color(0.3, 0.75, 0.3)))
		btn.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.2, 0.06, 0.95), Color(0.5, 0.85, 0.4)))
		btn.add_theme_stylebox_override("disabled", _button_style(Color(0.04, 0.12, 0.05, 0.8), Color(0.08, 0.16, 0.08)))

	btn_menu.add_theme_font_size_override("font_size", 14)
	btn_menu.add_theme_color_override("font_color", Color(0.8, 0.9, 0.75))
	btn_menu.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.45))
	btn_menu.add_theme_stylebox_override("normal", _button_style(Color(0.04, 0.24, 0.07, 0.9), Color(0.12, 0.42, 0.15)))
	btn_menu.add_theme_stylebox_override("hover", _button_style(Color(0.07, 0.36, 0.1, 0.95), Color(0.3, 0.7, 0.3)))
	btn_menu.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.18, 0.05, 0.95), Color(0.5, 0.85, 0.4)))


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	return sb


# -------------------------------------------------------------------- API

func setup(p_state: MatchState) -> void:
	state = p_state
	selected_index = -1
	selected_card = null
	_seen.clear()
	_first_render = true
	render_all()


func set_interactive(value: bool) -> void:
	interactive = value
	player_hand.modulate = Color(1, 1, 1, 1) if value else Color(1, 1, 1, 0.65)
	if not value:
		_clear_selection()
	_render_buttons()


func set_status(text: String) -> void:
	status_label.text = text


func set_turn_text(text: String) -> void:
	turn_label.text = text


func set_caravan_discard_allowed(value: bool) -> void:
	caravan_discard_allowed = value
	for view in player_views:
		view.set_discard_enabled(value)
	for view in enemy_views:
		view.set_discard_enabled(false)


# ------------------------------------------------------------------ рендер

func render_all() -> void:
	if state == null:
		return

	for i in mini(player_views.size(), state.player_caravans.size()):
		player_views[i].render(state.player_caravans[i])
	for i in mini(enemy_views.size(), state.dealer_caravans.size()):
		enemy_views[i].render(state.dealer_caravans[i])

	if selected_card != null and not state.player_hand.has(selected_card):
		selected_index = -1
		selected_card = null

	_render_hand()
	_render_enemy_hand()

	deck_label.text = "Колода: %d" % state.deck.remaining()
	discard_label.text = "%d" % state.deck.discard_size()
	_render_buttons()
	_apply_targets()
	_animate_new_cards()


func _render_hand() -> void:
	for child in player_hand.get_children():
		player_hand.remove_child(child)
		child.queue_free()
	_hand_views.clear()

	var cards := state.player_hand
	var card_size := _hand_card_size()

	for i in cards.size():
		var view: CardView = CARD_SCENE.instantiate()
		view.custom_minimum_size = card_size
		player_hand.add_child(view)
		view.setup(cards[i])
		view.set_selected(i == selected_index)
		view.pressed.connect(_on_hand_pressed.bind(i))
		_hand_views.append(view)


func _render_enemy_hand() -> void:
	for child in enemy_hand.get_children():
		enemy_hand.remove_child(child)
		child.queue_free()

	var count := state.dealer_hand.size()
	var back_size := HAND_BACK_SIZE_PORTRAIT if _portrait else HAND_BACK_SIZE
	for i in count:
		var view: CardView = CARD_SCENE.instantiate()
		view.custom_minimum_size = back_size
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_hand.add_child(view)
		view.setup(null, true)

	enemy_title.text = "ДИЛЕР · %d карт" % count


func _render_buttons() -> void:
	btn_draw.disabled = not interactive
	btn_end.disabled = not interactive
	btn_discard.disabled = not interactive or selected_card == null


# ------------------------------------------------------- полёт карт (tween)

func _animate_new_cards() -> void:
	var current := {}
	for view in _hand_views:
		if view.card != null:
			current[view.card.get_instance_id()] = view
	for caravan in player_views + enemy_views:
		for view in caravan.card_views():
			if view.card != null:
				current[view.card.get_instance_id()] = view

	if _first_render:
		_first_render = false
		_seen = current
		return

	for id in current:
		if not _seen.has(id) or _pending_sources.has(id):
			_fly_card(current[id], id)
	_seen = current


func _fly_card(target: CardView, id: int) -> void:
	if target == null or overlay == null:
		return

	var from: Vector2 = _pending_sources.get(id, _deck_point())
	_pending_sources.erase(id)

	var flight: CardView = CARD_SCENE.instantiate()
	overlay.add_child(flight)
	var card_size: Vector2 = target.size if target.size.x > 1.0 else _hand_card_size()
	flight.size = card_size
	flight.custom_minimum_size = card_size
	flight.pivot_offset = card_size * 0.5
	flight.setup(target.card)
	flight.global_position = from
	flight.rotation = deg_to_rad(randf_range(-4.0, 4.0))

	var tween := create_tween()
	tween.tween_property(flight, "global_position", target.global_position, FLIGHT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flight, "rotation", 0.0, FLIGHT_TIME)
	tween.tween_property(flight, "modulate:a", 0.0, 0.06)
	tween.tween_callback(flight.queue_free)


func _deck_point() -> Vector2:
	if deck_art == null:
		return Vector2(1600.0, 100.0)
	return deck_art.global_position + deck_art.size * 0.5 - _hand_card_size() * 0.5


## Откуда карта полетит: запоминаем позицию выбранной карты в руке.
func _remember_source(card: CardData, index: int) -> void:
	if card == null:
		return
	if index >= 0 and index < _hand_views.size():
		var view := _hand_views[index]
		_pending_sources[card.get_instance_id()] = view.global_position


# --------------------------------------------------------------- выделение

func _on_hand_pressed(card: CardData, index: int) -> void:
	if not interactive or state == null:
		return
	_select()

	if selected_index == index:
		selected_index = -1
		selected_card = null
	else:
		selected_index = index
		selected_card = card
		# Позиция карты в руке — отсюда она полетит на стол.
		_remember_source(card, index)

	_update_hand_selection()
	_apply_targets()
	_render_buttons()


func _update_hand_selection() -> void:
	for i in _hand_views.size():
		_hand_views[i].set_selected(i == selected_index)


func _on_discard_pressed() -> void:
	if selected_card == null:
		return
	_click()
	discard_requested.emit(selected_card)


func _clear_selection() -> void:
	selected_index = -1
	selected_card = null
	_clear_targets()
	if not _hand_views.is_empty():
		_update_hand_selection()
	_render_buttons()


func _clear_targets() -> void:
	for view in player_views:
		view.clear_targets()
	for view in enemy_views:
		view.clear_targets()


func _apply_targets() -> void:
	_clear_targets()
	if selected_card == null or state == null:
		return

	var targets := KaravanRules.legal_targets(selected_card, state.all_caravans())
	var slot_hits: Array[int] = []
	var entry_hits := {}

	for target in targets:
		if target.y < 0:
			if not slot_hits.has(target.x):
				slot_hits.append(target.x)
		else:
			if not entry_hits.has(target.x):
				entry_hits[target.x] = []
			entry_hits[target.x].append(target.y)

	for ci in slot_hits:
		var view := _view_for(ci)
		if view != null:
			view.set_slot_target(true)
	for ci in entry_hits:
		var view := _view_for(ci)
		if view != null:
			var list: Array[int] = []
			for e in entry_hits[ci]:
				list.append(int(e))
			view.set_entry_targets(list)


func _view_for(index: int) -> CaravanView:
	if index < 0:
		return null
	if index < MatchState.CARAVAN_COUNT:
		return player_views[index] if index < player_views.size() else null
	var enemy_index := index - MatchState.CARAVAN_COUNT
	return enemy_views[enemy_index] if enemy_index < enemy_views.size() else null


func _on_slot_pressed(caravan_index: int) -> void:
	if not interactive or selected_card == null:
		return
	_remember_source(selected_card, selected_index)
	play_requested.emit(selected_card, caravan_index, -1)


func _on_entry_pressed(caravan_index: int, entry_index: int) -> void:
	if not interactive or selected_card == null:
		return
	_remember_source(selected_card, selected_index)
	play_requested.emit(selected_card, caravan_index, entry_index)


func _on_caravan_discard_pressed(caravan_index: int) -> void:
	if not interactive:
		return
	_click()
	caravan_discard_requested.emit(caravan_index)


func _click() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("click", 0.92, 1.08)


## Выбор карты в руке: отдельный звук, не кнопочный.
func _select() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("select", 0.95, 1.05)
