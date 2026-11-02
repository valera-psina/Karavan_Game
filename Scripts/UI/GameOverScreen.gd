extends CanvasLayer
## Экран окончания партии: затемнение, крупный итог, «Заново» / «В меню».

signal restart_requested()
signal menu_requested()

var _tween: Tween

@onready var dim: ColorRect = %Dim
@onready var box: VBoxContainer = %Box
@onready var title: Label = %Title
@onready var detail: Label = %Detail
@onready var btn_restart: Button = %BtnRestart
@onready var btn_menu: Button = %BtnMenu


func _ready() -> void:
	visible = false
	btn_restart.pressed.connect(func(): _click(); restart_requested.emit())
	btn_menu.pressed.connect(func(): _click(); menu_requested.emit())


## Итог партии: «ПОБЕДА!» зелёным, «ПОРАЖЕНИЕ» красным, «НИЧЬЯ» серым.
func show_result(player_won: bool, is_draw: bool, p_detail: String) -> void:
	if is_draw:
		title.text = "НИЧЬЯ"
		title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	elif player_won:
		title.text = "ПОБЕДА!"
		title.add_theme_color_override("font_color", Color(0.55, 0.94, 0.35))
	else:
		title.text = "ПОРАЖЕНИЕ"
		title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.32))
	detail.text = p_detail

	visible = true
	dim.modulate.a = 0.0
	box.modulate.a = 0.0
	box.scale = Vector2(0.92, 0.92)
	box.pivot_offset = box.size * 0.5
	title.scale = Vector2(0.5, 0.5)
	title.pivot_offset = title.size * 0.5

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(dim, "modulate:a", 1.0, 0.22)
	_tween.tween_property(box, "modulate:a", 1.0, 0.25)
	_tween.tween_property(box, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(title, "scale", Vector2.ONE, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_result() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false


func _click() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("click", 0.92, 1.08)
