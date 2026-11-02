extends Node
## Звуковой менеджер: по одному AudioStreamPlayer на эффект.
## Все вызовы идут через play()/play_sfx(), поэтому питч рандомизируется в одном месте.

const SOUNDS := {
	"draw": "res://Sounds/sfx_card_draw.wav",
	"place": "res://Sounds/sfx_card_place.wav",
	"click": "res://Sounds/sfx_button_click.wav",
	"select": "res://Sounds/sfx_card_select.wav",
	"win": "res://Sounds/sfx_win.wav",
	"lose": "res://Sounds/sfx_lose.wav",
}

var _players := {}


func _ready() -> void:
	for key in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + str(key)
		var path: String = SOUNDS[key]
		if ResourceLoader.exists(path):
			player.stream = load(path)
		player.bus = &"Master"
		add_child(player)
		_players[key] = player


func play(key: String, min_pitch: float = 0.95, max_pitch: float = 1.05) -> void:
	if not _players.has(key):
		return
	var player: AudioStreamPlayer = _players[key]
	# Пока файла нет в проекте — тихо подстраховываемся другим звуком.
	if player.stream == null and key == "select":
		player = _players.get("place", null)
		min_pitch = 1.4
		max_pitch = 1.6
	play_sfx(player, min_pitch, max_pitch)


func play_sfx(player: AudioStreamPlayer, min_pitch: float = 0.95, max_pitch: float = 1.05) -> void:
	if player == null or player.stream == null:
		return
	player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.play()
