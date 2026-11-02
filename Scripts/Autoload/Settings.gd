extends Node
## Глобальные настройки между сценами (меню -> партия).

enum Difficulty { EASY, HARD }

const LANDSCAPE_SIZE := Vector2i(1600, 900)
const PORTRAIT_SIZE := Vector2i(900, 1600)
const LANDSCAPE_CANVAS := Vector2i(1920, 1080)
const PORTRAIT_CANVAS := Vector2i(1080, 1920)

var difficulty: int = Difficulty.EASY


func set_difficulty(value: int) -> void:
	difficulty = Difficulty.HARD if value == Difficulty.HARD else Difficulty.EASY


func toggle_difficulty() -> void:
	set_difficulty(Difficulty.EASY if difficulty == Difficulty.HARD else Difficulty.HARD)


func difficulty_name() -> String:
	return "Сложно" if difficulty == Difficulty.HARD else "Легко"


func is_portrait() -> bool:
	var size := DisplayServer.window_get_size()
	return size.y > size.x


## Переключает окно 1600×900 ↔ 900×1600, центрируя его на экране,
## и подбирает виртуальный холст под форму окна.
func toggle_orientation() -> void:
	var current := DisplayServer.window_get_size()
	var to_portrait := current.y <= current.x
	var target: Vector2i = PORTRAIT_SIZE if to_portrait else LANDSCAPE_SIZE

	DisplayServer.window_set_size(target)
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var centered := Vector2i(
		maxi(0, (screen.x - target.x) / 2),
		maxi(0, (screen.y - target.y) / 2))
	DisplayServer.window_set_position(centered)

	var window := get_viewport().get_window()
	if window != null:
		window.content_scale_size = PORTRAIT_CANVAS if to_portrait else LANDSCAPE_CANVAS
