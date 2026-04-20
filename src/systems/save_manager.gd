extends Node

## Менеджер сохранений с XOR-обфускацией.
##
## Хранит глобальное состояние между запусками: жизни, таймер регенерации,
## unlimited-флаг, прогресс комнат. Не блокирующий: если файл повреждён —
## стартуем с дефолтов.
## Автозагрузка.

# --- Константы ---

const SAVE_PATH: String = "user://save.json"
const _OBFUSCATION_KEY: int = 0x5A

# --- Публичные переменные (состояние) ---

var lives: int = 5
var last_life_regen_ts: int = 0  # Unix ms, когда последний раз начислили жизнь
var unlimited_lives: bool = false
var current_room: int = 1
var owned_products: Array[String] = []  # для учёта unlimited и т.п.

# --- Сигналы ---

signal state_loaded
signal state_saved


# --- Встроенные колбеки ---

func _ready() -> void:
	load_game()


# --- Публичные методы ---

## Сериализует состояние в словарь.
func to_dict() -> Dictionary:
	return {
		"lives": lives,
		"last_life_regen_ts": last_life_regen_ts,
		"unlimited_lives": unlimited_lives,
		"current_room": current_room,
		"owned_products": owned_products,
	}


## Восстанавливает состояние из словаря.
func from_dict(data: Dictionary) -> void:
	lives = int(data.get("lives", 5))
	last_life_regen_ts = int(data.get("last_life_regen_ts", 0))
	unlimited_lives = bool(data.get("unlimited_lives", false))
	current_room = int(data.get("current_room", 1))
	var raw_products: Array = data.get("owned_products", [])
	owned_products.clear()
	for p in raw_products:
		owned_products.append(String(p))


## Сохраняет состояние на диск (XOR-обфускация).
func save_game() -> void:
	var payload: String = JSON.stringify(to_dict())
	var obf: PackedByteArray = _obfuscate(payload)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return  # молча — не падаем, если запись невозможна
	file.store_buffer(obf)
	file.close()
	state_saved.emit()


## Загружает состояние с диска. Поддерживает миграцию со старого plaintext JSON.
func load_game() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		state_loaded.emit()
		return
	var raw: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	var text: String = _deobfuscate(raw)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		# миграция: старый plaintext JSON
		parsed = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY:
		from_dict(parsed as Dictionary)
	state_loaded.emit()


# --- Приватные методы ---

func _obfuscate(text: String) -> PackedByteArray:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	for i in bytes.size():
		bytes[i] = bytes[i] ^ _OBFUSCATION_KEY
	return bytes


func _deobfuscate(bytes: PackedByteArray) -> String:
	var copy: PackedByteArray = PackedByteArray(bytes)
	for i in copy.size():
		copy[i] = copy[i] ^ _OBFUSCATION_KEY
	return copy.get_string_from_utf8()
