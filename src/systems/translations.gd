extends Node

## Менеджер локализаций.
##
## Читает src/data/translations.json в формате {lang: {key: value}}.
## Язык по умолчанию определяется OS.get_locale_language(), fallback — "en".
## Автозагрузка.

# --- Константы ---

const TRANSLATIONS_PATH: String = "res://src/data/translations.json"
const DEFAULT_LANG: String = "en"
const SUPPORTED_LANGS: Array = ["en", "ru", "es"]

# --- Приватные переменные ---

var _data: Dictionary = {}
var _current_lang: String = DEFAULT_LANG


# --- Встроенные колбеки ---

func _ready() -> void:
	_data = _read_json(TRANSLATIONS_PATH)
	_current_lang = _detect_lang()


# --- Публичные методы ---

## Возвращает текущий язык.
func get_lang() -> String:
	return _current_lang


## Явно задаёт язык. Должен быть в SUPPORTED_LANGS.
func set_lang(lang: String) -> void:
	if lang in SUPPORTED_LANGS:
		_current_lang = lang


## Возвращает перевод по ключу. Если ключа нет — возвращает сам ключ.
func tr_key(key: String) -> String:
	var lang_table: Dictionary = _data.get(_current_lang, {}) as Dictionary
	if lang_table.has(key):
		return String(lang_table[key])
	# fallback на английский
	var en: Dictionary = _data.get(DEFAULT_LANG, {}) as Dictionary
	if en.has(key):
		return String(en[key])
	return key


# --- Приватные методы ---

func _detect_lang() -> String:
	var locale: String = OS.get_locale_language().to_lower()
	if locale in SUPPORTED_LANGS:
		return locale
	return DEFAULT_LANG


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Translations: %s не найден" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}
