class_name KaravanEntry
extends RefCounted
## Одна позиция в караване: числовая карта-основа + прикреплённые к ней
## карты-эффекты (короли удваивают, дамы меняют направление/масть,
## джокер и валет карту удаляют и потому висеть не остаются).

var base: CardData
var attachments: Array[CardData] = []


func _init(p_base: CardData = null) -> void:
	base = p_base


func king_count() -> int:
	var n := 0
	for c in attachments:
		if c.kind == CardData.Kind.KING:
			n += 1
	return n


func queen_count() -> int:
	var n := 0
	for c in attachments:
		if c.kind == CardData.Kind.QUEEN:
			n += 1
	return n


## Номинал позиции с учётом королей: каждый король удваивает.
func value() -> int:
	if base == null or not base.is_numeric():
		return 0
	return base.value() * (1 << king_count())


func clone() -> KaravanEntry:
	var e := KaravanEntry.new(base)
	e.attachments = attachments.duplicate()
	return e


func describe() -> String:
	if base == null:
		return "<пусто>"
	var s := "%s (%d)" % [base.describe(), value()]
	if not attachments.is_empty():
		var names: Array[String] = []
		for a in attachments:
			names.append(a.rank_label())
		s += " +" + ",".join(names)
	return s
