class_name CardData
extends Resource
## Данные одной карты. Ничего не знает про визуал: только ранг, масть, тип
## и имя файла текстуры (интерпретирует его CardCatalog).

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES, NONE }
enum Kind { NUMBER, ACE, JACK, QUEEN, KING, JOKER }

const TEXTURE_DIR := "res://Cards/512x"

const SUIT_NAME_RU := {
	Suit.CLUBS: "Трефы",
	Suit.DIAMONDS: "Бубны",
	Suit.HEARTS: "Черви",
	Suit.SPADES: "Пики",
	Suit.NONE: "—",
}

const KIND_NAME_RU := {
	Kind.NUMBER: "Число",
	Kind.ACE: "Туз",
	Kind.JACK: "Валет",
	Kind.QUEEN: "Дама",
	Kind.KING: "Король",
	Kind.JOKER: "Джокер",
}

@export var suit: int = Suit.NONE
@export var rank: int = 0          ## 1..10 — число, 11 J, 12 Q, 13 K, 0 — джокер.
@export var kind: int = Kind.NUMBER
@export var file: String = ""      ## Имя файла в res://Cards/512x/, например "Ac.png".
@export var brand: StringName = &"standard"  ## «Бренд» колоды: для правила «повторы только из разных колод».


## Числовая карта (ходит по правилам направления).
func is_numeric() -> bool:
	return kind == Kind.ACE or kind == Kind.NUMBER


## Карта-эффект, которая кладётся поверх другой карты (J/Q/K).
func is_face() -> bool:
	return kind == Kind.JACK or kind == Kind.QUEEN or kind == Kind.KING


func is_joker() -> bool:
	return kind == Kind.JOKER


## Числовой номинал карты: туз = 1, 2..10 = ранг, фигуры = 0.
func value() -> int:
	if kind == Kind.ACE:
		return 1
	if kind == Kind.NUMBER:
		return rank
	return 0


## Красная масть — для цвета подписи в UI.
func is_red() -> bool:
	return suit == Suit.DIAMONDS or suit == Suit.HEARTS


func texture_path() -> String:
	if file.is_empty():
		return ""
	return TEXTURE_DIR + "/" + file


func rank_label() -> String:
	match kind:
		Kind.ACE:
			return "A"
		Kind.JACK:
			return "J"
		Kind.QUEEN:
			return "Q"
		Kind.KING:
			return "K"
		Kind.JOKER:
			return "JOKER"
		_:
			return str(rank)


func suit_label_ru() -> String:
	return SUIT_NAME_RU.get(suit, "—")


func describe() -> String:
	if is_joker():
		return "Джокер (%s)" % file
	return "%s %s" % [rank_label(), suit_label_ru()]


## Независимая копия карты (сама карта неизменяемая, копия нужна для колод).
func duplicate_card() -> CardData:
	var c := CardData.new()
	c.suit = suit
	c.rank = rank
	c.kind = kind
	c.file = file
	c.brand = brand
	return c


func _to_string() -> String:
	return "[%s]" % describe()
