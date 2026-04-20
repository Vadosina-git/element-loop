extends Node

## Менеджер конфигов приложения.
##
## Читает конфиги из res://configs/ на старте. Даёт безопасный доступ
## с дефолтами через init_config.get(key, default).
## Автозагрузка.

# --- Константы ---

const INIT_CONFIG_PATH: String = "res://configs/init_config.json"

# --- Публичные переменные ---

var init_config: Dictionary = {}


# --- Встроенные колбеки ---

func _ready() -> void:
	init_config = _read_json(INIT_CONFIG_PATH)


# --- Публичные методы ---

## Возвращает дефолтное число жизней.
func get_lives_initial() -> int:
	return int(init_config.get("lives_initial", 5))


## Возвращает максимум жизней (капа регенерации).
func get_lives_max() -> int:
	return int(init_config.get("lives_max", 5))


## Возвращает интервал регенерации жизни в секундах.
func get_life_regen_seconds() -> float:
	return float(init_config.get("life_regen_seconds", 600.0))


## Возвращает длительность splash screen в секундах.
func get_splash_duration() -> float:
	return float(init_config.get("splash_duration_sec", 4.0))


## Возвращает список SKU IAP-паков и сколько жизней они дают.
## Формат элемента: {id: String, lives: int, unlimited: bool}.
func get_iap_packs() -> Array:
	var packs: Variant = init_config.get("iap_packs", [])
	if packs is Array:
		return packs as Array
	return []


# --- Приватные методы ---

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("ConfigManager: %s не найден" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	push_warning("ConfigManager: %s содержит не-объект JSON" % path)
	return {}
