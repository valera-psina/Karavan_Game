extends Control
## Главное меню: «Играть», переключатель сложности и «Выход».

@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var play_button: Button = %Play
@onready var difficulty_button: Button = %Difficulty
@onready var quit_button: Button = %Quit
@onready var footer: Label = %Footer


func _ready() -> void:
	_apply_canvas()
	get_viewport().size_changed.connect(_apply_canvas)
	_style()
	_refresh_difficulty()
	play_button.pressed.connect(_on_play_pressed)
	difficulty_button.pressed.connect(_on_difficulty_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()


func _style() -> void:
	title_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.35, 1.0))
	title_label.add_theme_font_size_override("font_size", 78)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.66, 0.9))
	subtitle_label.add_theme_font_size_override("font_size", 17)
	footer.add_theme_color_override("font_color", Color(0.55, 0.68, 0.52, 0.8))
	footer.add_theme_font_size_override("font_size", 12)

	for button in [play_button, difficulty_button, quit_button]:
		var btn := button as Button
		btn.custom_minimum_size = Vector2(360, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.9, 0.97, 0.84))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.45))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.7))
		btn.add_theme_stylebox_override("normal", _box(Color(0.05, 0.28, 0.08, 0.95), Color(0.12, 0.5, 0.17)))
		btn.add_theme_stylebox_override("hover", _box(Color(0.08, 0.4, 0.12, 0.95), Color(0.35, 0.8, 0.33)))
		btn.add_theme_stylebox_override("pressed", _box(Color(0.03, 0.2, 0.06, 0.95), Color(0.55, 0.9, 0.45)))
		btn.add_theme_stylebox_override("focus", _box(Color(0.06, 0.33, 0.1, 0.95), Color(0.8, 0.72, 0.3)))


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb


func _refresh_difficulty() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		difficulty_button.text = "Сложность: Сложно"
		return
	difficulty_button.text = "Сложность: %s" % settings.difficulty_name()


func _on_play_pressed() -> void:
	_click()
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")


func _on_difficulty_pressed() -> void:
	_click()
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.toggle_difficulty()
	_refresh_difficulty()


func _apply_canvas() -> void:
	var window := get_viewport().get_window()
	if window == null:
		return
	var size := get_viewport_rect().size
	var canvas := Vector2i(1080, 1920) if size.y > size.x else Vector2i(1920, 1080)
	if window.content_scale_size != canvas:
		window.content_scale_size = canvas


func _on_quit_pressed() -> void:
	_click()
	get_tree().quit()





func _click() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("click", 0.92, 1.08)
