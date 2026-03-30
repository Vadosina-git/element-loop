class_name ZoneLogic
extends RefCounted

## Логика зон: хранение, FIFO-удаление, определение эффекта.
##
## Управляет активными зонами игрока (максимум MAX_ZONES штук).
## При переполнении удаляет старейшую зону (FIFO).
## Определяет тип эффекта зоны на врага: контр, своя или нейтральная.

enum ZoneEffect {
	COUNTER,
	SAME,
	NEUTRAL,
}

const MAX_ZONES: int = 2

var _zones: Array[ZoneData] = []


class ZoneData extends RefCounted:
	## Данные одной зоны: стихия и позиция на карте.
	var element: ElementTable.Element
	var position: Vector3

	func _init(p_element: ElementTable.Element, p_position: Vector3) -> void:
		element = p_element
		position = p_position


## Добавить зону. При переполнении удаляется старейшая (FIFO).
func add_zone(element: ElementTable.Element, position: Vector3) -> ZoneData:
	var zone := ZoneData.new(element, position)
	_zones.append(zone)
	if _zones.size() > MAX_ZONES:
		_zones.remove_at(0)
	return zone


## Возвращает текущее количество активных зон.
func get_zone_count() -> int:
	return _zones.size()


## Возвращает массив всех активных зон.
func get_zones() -> Array[ZoneData]:
	return _zones


## Определить эффект зоны на врага.
static func check_effect(
	zone_element: ElementTable.Element,
	enemy_element: ElementTable.Element
) -> ZoneEffect:
	if ElementTable.is_counter(zone_element, enemy_element):
		return ZoneEffect.COUNTER
	elif ElementTable.is_same(zone_element, enemy_element):
		return ZoneEffect.SAME
	else:
		return ZoneEffect.NEUTRAL
