class_name CardCatalog
extends RefCounted
## Каталог карт: единственное место, где имена файлов из res://Cards/512x/
## превращаются в игровые данные (ранг, масть, тип).
##
## Имена в паке неконсистентны: "2c" и "2D", "A spade" и "Ac", "K club" и
## "Kspade", "Joker cardv1". Поэтому:
##   1) есть явная таблица FILES — источник истины;
##   2) есть resolve_file() — терпимый к регистру/пробелам разбор имени,
##      чтобы переименование файла не ломало игру молча.

const ROOT := CardData.TEXTURE_DIR

const BACK_FILE := "Cardback.png"
const JOKER_FILES: Array[String] = ["Joker cardv1.png", "Joker cardv2.png"]

## file -> [Kind, rank, Suit]
const FILES := {
	# --- числа 2..10 ---
	"2c.png": [CardData.Kind.NUMBER, 2, CardData.Suit.CLUBS],
	"2D.png": [CardData.Kind.NUMBER, 2, CardData.Suit.DIAMONDS],
	"2h.png": [CardData.Kind.NUMBER, 2, CardData.Suit.HEARTS],
	"2s.png": [CardData.Kind.NUMBER, 2, CardData.Suit.SPADES],
	"3c.png": [CardData.Kind.NUMBER, 3, CardData.Suit.CLUBS],
	"3d.png": [CardData.Kind.NUMBER, 3, CardData.Suit.DIAMONDS],
	"3h.png": [CardData.Kind.NUMBER, 3, CardData.Suit.HEARTS],
	"3s.png": [CardData.Kind.NUMBER, 3, CardData.Suit.SPADES],
	"4c.png": [CardData.Kind.NUMBER, 4, CardData.Suit.CLUBS],
	"4d.png": [CardData.Kind.NUMBER, 4, CardData.Suit.DIAMONDS],
	"4h.png": [CardData.Kind.NUMBER, 4, CardData.Suit.HEARTS],
	"4s.png": [CardData.Kind.NUMBER, 4, CardData.Suit.SPADES],
	"5c.png": [CardData.Kind.NUMBER, 5, CardData.Suit.CLUBS],
	"5d.png": [CardData.Kind.NUMBER, 5, CardData.Suit.DIAMONDS],
	"5h.png": [CardData.Kind.NUMBER, 5, CardData.Suit.HEARTS],
	"5s.png": [CardData.Kind.NUMBER, 5, CardData.Suit.SPADES],
	"6c.png": [CardData.Kind.NUMBER, 6, CardData.Suit.CLUBS],
	"6d.png": [CardData.Kind.NUMBER, 6, CardData.Suit.DIAMONDS],
	"6h.png": [CardData.Kind.NUMBER, 6, CardData.Suit.HEARTS],
	"6s.png": [CardData.Kind.NUMBER, 6, CardData.Suit.SPADES],
	"7c.png": [CardData.Kind.NUMBER, 7, CardData.Suit.CLUBS],
	"7d.png": [CardData.Kind.NUMBER, 7, CardData.Suit.DIAMONDS],
	"7h.png": [CardData.Kind.NUMBER, 7, CardData.Suit.HEARTS],
	"7s.png": [CardData.Kind.NUMBER, 7, CardData.Suit.SPADES],
	"8c.png": [CardData.Kind.NUMBER, 8, CardData.Suit.CLUBS],
	"8d.png": [CardData.Kind.NUMBER, 8, CardData.Suit.DIAMONDS],
	"8h.png": [CardData.Kind.NUMBER, 8, CardData.Suit.HEARTS],
	"8s.png": [CardData.Kind.NUMBER, 8, CardData.Suit.SPADES],
	"9c.png": [CardData.Kind.NUMBER, 9, CardData.Suit.CLUBS],
	"9d.png": [CardData.Kind.NUMBER, 9, CardData.Suit.DIAMONDS],
	"9h.png": [CardData.Kind.NUMBER, 9, CardData.Suit.HEARTS],
	"9s.png": [CardData.Kind.NUMBER, 9, CardData.Suit.SPADES],
	"10c.png": [CardData.Kind.NUMBER, 10, CardData.Suit.CLUBS],
	"10d.png": [CardData.Kind.NUMBER, 10, CardData.Suit.DIAMONDS],
	"10h.png": [CardData.Kind.NUMBER, 10, CardData.Suit.HEARTS],
	"10s.png": [CardData.Kind.NUMBER, 10, CardData.Suit.SPADES],
	# --- тузы ---
	"Ac.png": [CardData.Kind.ACE, 1, CardData.Suit.CLUBS],
	"AD.png": [CardData.Kind.ACE, 1, CardData.Suit.DIAMONDS],
	"Ah.png": [CardData.Kind.ACE, 1, CardData.Suit.HEARTS],
	"A spade.png": [CardData.Kind.ACE, 1, CardData.Suit.SPADES],
	# --- валеты ---
	"Jclub.png": [CardData.Kind.JACK, 11, CardData.Suit.CLUBS],
	"Jdiamond.png": [CardData.Kind.JACK, 11, CardData.Suit.DIAMONDS],
	"Jheart.png": [CardData.Kind.JACK, 11, CardData.Suit.HEARTS],
	"Jspade.png": [CardData.Kind.JACK, 11, CardData.Suit.SPADES],
	# --- дамы ---
	"Qclub.png": [CardData.Kind.QUEEN, 12, CardData.Suit.CLUBS],
	"Qdiamond.png": [CardData.Kind.QUEEN, 12, CardData.Suit.DIAMONDS],
	"Qheart.png": [CardData.Kind.QUEEN, 12, CardData.Suit.HEARTS],
	"QSpade.png": [CardData.Kind.QUEEN, 12, CardData.Suit.SPADES],
	# --- короли ---
	"K club.png": [CardData.Kind.KING, 13, CardData.Suit.CLUBS],
	"K diamond.png": [CardData.Kind.KING, 13, CardData.Suit.DIAMONDS],
	"K heart.png": [CardData.Kind.KING, 13, CardData.Suit.HEARTS],
	"Kspade.png": [CardData.Kind.KING, 13, CardData.Suit.SPADES],
	# --- джокеры ---
	"Joker cardv1.png": [CardData.Kind.JOKER, 0, CardData.Suit.NONE],
	"Joker cardv2.png": [CardData.Kind.JOKER, 0, CardData.Suit.NONE],
}

const DECK_SIZE := 54  ## 52 + 2 джокера.


static func texture_path(file: String) -> String:
	return ROOT + "/" + file


static func back_texture_path() -> String:
	return texture_path(BACK_FILE)


static func joker_file(variant: int) -> String:
	return JOKER_FILES[1] if variant == 2 else JOKER_FILES[0]


## Создаёт CardData по имени файла. Возвращает null, если файл не распознан.
static func card_from_file(file: String) -> CardData:
	var resolved := resolve_file(file)
	if resolved.is_empty():
		push_error("CardCatalog: неизвестный файл карты '%s'" % file)
		return null
	var spec: Array = FILES[resolved]
	var card := CardData.new()
	card.kind = spec[0]
	card.rank = spec[1]
	card.suit = spec[2]
	card.file = resolved
	return card


## Все 54 карты колоды (52 + 2 джокера), в стабильном порядке таблицы.
static func all_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for file in FILES:
		var card := card_from_file(file)
		if card != null:
			out.append(card)
	return out


## Готовая перемешанная колода. seed_value = 0 → случайная раздача.
static func standard_deck(seed_value: int = 0) -> DeckData:
	var deck := DeckData.new()
	deck.brand = &"standard"
	deck.setup(all_cards())
	deck.shuffle(seed_value)
	return deck


## Терпимый поиск файла: точное имя → нормализованное → разбор по смыслу.
static func resolve_file(file: String) -> String:
	if FILES.has(file):
		return file

	var norm := _normalize(file)
	for candidate in FILES:
		if _normalize(candidate) == norm:
			return candidate

	return _resolve_fuzzy(norm)


static func _normalize(file: String) -> String:
	var stem := file.get_basename()
	var out := ""
	for i in stem.length():
		var ch := stem[i].to_lower()
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


## "aspade" -> "A spade.png", "kclub" -> "K club.png", "jokercardv2" -> "Joker cardv2.png".
static func _resolve_fuzzy(norm: String) -> String:
	if norm.is_empty():
		return ""
	if norm.begins_with("cardback"):
		return BACK_FILE
	if norm.begins_with("joker"):
		return JOKER_FILES[1] if norm.contains("v2") else JOKER_FILES[0]

	var rank := 0
	var rest := ""
	if norm[0] >= "0" and norm[0] <= "9":
		var digits := ""
		var i := 0
		while i < norm.length() and norm[i] >= "0" and norm[i] <= "9":
			digits += norm[i]
			i += 1
		rank = digits.to_int()
		rest = norm.substr(i)
	else:
		match norm[0]:
			"a":
				rank = 1
			"j":
				rank = 11
			"q":
				rank = 12
			"k":
				rank = 13
			_:
				return ""
		rest = norm.substr(1)

	var suit := _suit_from_token(rest)
	if suit == CardData.Suit.NONE:
		return ""
	if rank < 1 or rank > 13:
		return ""

	for candidate in FILES:
		var spec: Array = FILES[candidate]
		if spec[1] == rank and spec[2] == suit:
			return candidate
	return ""


static func _suit_from_token(token: String) -> int:
	if token.contains("club"):
		return CardData.Suit.CLUBS
	if token.contains("diamond"):
		return CardData.Suit.DIAMONDS
	if token.contains("heart"):
		return CardData.Suit.HEARTS
	if token.contains("spade"):
		return CardData.Suit.SPADES
	match token:
		"c":
			return CardData.Suit.CLUBS
		"d":
			return CardData.Suit.DIAMONDS
		"h":
			return CardData.Suit.HEARTS
		"s":
			return CardData.Suit.SPADES
	return CardData.Suit.NONE


## Самопроверка каталога: файлы на месте, дублей нет, лишних PNG нет.
## Возвращает список проблем (пустой = всё хорошо).
static func validate() -> Array[String]:
	var problems: Array[String] = []

	if FILES.size() != DECK_SIZE:
		problems.append("в таблице %d карт, ожидалось %d" % [FILES.size(), DECK_SIZE])

	for file in FILES:
		if not FileAccess.file_exists(texture_path(file)):
			problems.append("нет файла: " + file)
		if not ResourceLoader.exists(texture_path(file)):
			problems.append("файл не импортирован Godot: " + file)

	if not FileAccess.file_exists(back_texture_path()):
		problems.append("нет рубашки: " + BACK_FILE)

	# Уникальность (rank, suit) среди не-джокеров.
	var seen := {}
	for file in FILES:
		var spec: Array = FILES[file]
		if spec[0] == CardData.Kind.JOKER:
			continue
		var key := "%d/%d" % [spec[1], spec[2]]
		if seen.has(key):
			problems.append("дубль карты %s: %s и %s" % [key, seen[key], file])
		seen[key] = file

	# Лишние PNG в папке.
	var dir := DirAccess.open(ROOT)
	if dir == null:
		problems.append("не открывается папка " + ROOT)
	else:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.get_extension().to_lower() == "png":
				if name != BACK_FILE and not FILES.has(name):
					problems.append("неизвестный файл в папке: " + name)
			name = dir.get_next()
		dir.list_dir_end()

	return problems
