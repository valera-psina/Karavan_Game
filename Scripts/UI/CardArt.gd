class_name CardArt
extends RefCounted
## Отдаёт готовую к отрисовке текстуру карты.
##
## PNG в res://Cards/512x/ — квадратные 512×512 с прозрачными полями:
## контент карты у всех 55 файлов лежит в одном месте (проверено попиксельно),
## поэтому обрезаем его AtlasTexture'ом, а не растягиваем квадрат в UI.

const REGION := Rect2(90, 7, 332, 498)

static var _faces: Dictionary = {}
static var _back: Texture2D


static func face(card: CardData) -> Texture2D:
	if card == null or card.file.is_empty():
		return null
	if _faces.has(card.file):
		return _faces[card.file]

	var src := load(card.texture_path()) as Texture2D
	if src == null:
		push_error("CardArt: не загрузилась текстура %s" % card.texture_path())
		return null

	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.region = REGION
	atlas.filter_clip = true
	_faces[card.file] = atlas
	return atlas


static func back() -> Texture2D:
	if _back != null:
		return _back

	var src := load(CardCatalog.back_texture_path()) as Texture2D
	if src == null:
		push_error("CardArt: не загрузилась рубашка")
		return null

	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.region = REGION
	atlas.filter_clip = true
	_back = atlas
	return _back
