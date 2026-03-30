extends GutTest

## Тесты логики зон.

var _zone_logic: ZoneLogic


func before_each() -> void:
	_zone_logic = ZoneLogic.new()


func test_initial_zone_count_is_zero() -> void:
	assert_eq(_zone_logic.get_zone_count(), 0)


func test_add_zone_increases_count() -> void:
	_zone_logic.add_zone(ElementTable.Element.FIRE, Vector3.ZERO)
	assert_eq(_zone_logic.get_zone_count(), 1)


func test_max_zones_is_two() -> void:
	_zone_logic.add_zone(ElementTable.Element.FIRE, Vector3.ZERO)
	_zone_logic.add_zone(ElementTable.Element.WATER, Vector3(1, 0, 0))
	_zone_logic.add_zone(ElementTable.Element.TREE, Vector3(2, 0, 0))
	assert_eq(_zone_logic.get_zone_count(), 2)


func test_fifo_removes_oldest_zone() -> void:
	_zone_logic.add_zone(ElementTable.Element.FIRE, Vector3.ZERO)
	_zone_logic.add_zone(ElementTable.Element.WATER, Vector3(1, 0, 0))
	_zone_logic.add_zone(ElementTable.Element.TREE, Vector3(2, 0, 0))
	var zones: Array = _zone_logic.get_zones()
	assert_eq(zones[0].element, ElementTable.Element.WATER)
	assert_eq(zones[1].element, ElementTable.Element.TREE)


func test_check_zone_counter() -> void:
	var result: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(
		ElementTable.Element.WATER, ElementTable.Element.FIRE
	)
	assert_eq(result, ZoneLogic.ZoneEffect.COUNTER)


func test_check_zone_same() -> void:
	var result: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(
		ElementTable.Element.FIRE, ElementTable.Element.FIRE
	)
	assert_eq(result, ZoneLogic.ZoneEffect.SAME)


func test_check_zone_neutral() -> void:
	var result: ZoneLogic.ZoneEffect = ZoneLogic.check_effect(
		ElementTable.Element.TREE, ElementTable.Element.FIRE
	)
	assert_eq(result, ZoneLogic.ZoneEffect.NEUTRAL)
