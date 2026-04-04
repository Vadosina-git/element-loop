class_name HUD
extends CanvasLayer

## Минимальный HUD: отображение HP, текущей стихии и кнопка постановки зоны.

# --- Сигналы ---

## Испускается при нажатии кнопки «Зона».
signal zone_button_pressed

## Испускается при нажатии кнопки «Рывок».
signal dash_button_pressed

## Испускается при нажатии кнопки «Перезапуск».
signal restart_pressed

## Испускается при выборе пресета камеры.
signal camera_preset_selected(preset_name: String)

signal next_character_pressed
signal prev_character_pressed

# --- Константы ---

const DASH_COOLDOWN_DEFAULT: float = 5.0
const ARROW_MARGIN: float = 100.0
const ARROW_SIZE: float = 60.0

# --- Приватные переменные ---

var _camera: Camera3D = null
var _book_arrows: Array[Control] = []
var _tracked_books: Array[Node3D] = []
var _tracked_enemies: Array[EnemyBase] = []
var _enemy_arrows: Array[Control] = []
var _current_element: int = -1
var _element_texture_rect: TextureRect = null
var _heart_labels: Array[Control] = []
var _dying_hearts: Array[Dictionary] = []
var _last_hp: int = 2

# --- @onready переменные ---

@onready var _hearts_row: HBoxContainer = %HeartsRow
@onready var _element_icon: Label = %ElementIcon
@onready var _element_name_label: Label = %ElementName
@onready var _element_slot: PanelContainer = %ElementSlot
@onready var _zone_button: Button = %ZoneButton
@onready var _dash_button: Button = %DashButton
@onready var _dash_cooldown_fill: ColorRect = %CooldownFill
@onready var _game_over_panel: PanelContainer = %GameOverPanel
@onready var _restart_button: Button = %RestartButton
@onready var _camera_bar: HBoxContainer = %CameraBar
@onready var _prev_char_btn: Button = %PrevChar
@onready var _next_char_btn: Button = %NextChar
@onready var _char_name_label: Label = %CharName
@onready var _enemy_count_label: Label = %EnemyCount
@onready var _element_wheel: ElementWheel = %ElementWheel

# --- Встроенные колбеки ---

func _ready() -> void:
	_zone_button.pressed.connect(_on_zone_button_pressed)
	_dash_button.pressed.connect(_on_dash_button_pressed)
	_restart_button.pressed.connect(_on_restart_button_pressed)
	_prev_char_btn.pressed.connect(func() -> void: prev_character_pressed.emit())
	_next_char_btn.pressed.connect(func() -> void: next_character_pressed.emit())
	update_hp(2)
	update_element(-1)
	_update_dash_cooldown_display(0.0, DASH_COOLDOWN_DEFAULT)


func _process(delta: float) -> void:
	_update_book_arrows()
	_update_enemy_arrows()
	_update_dying_hearts(delta)

# --- Публичные методы ---

## Обновляет отображение сердечек жизни.
func update_hp(hp: int) -> void:
	# Анимация потери сердечка
	if hp < _last_hp and _last_hp > 0:
		var lost: int = _last_hp - hp
		for i: int in range(lost):
			var idx: int = hp + i
			if idx < _heart_labels.size():
				_start_heart_death(_heart_labels[idx])

	_last_hp = hp

	# Пересоздаём сердечки
	for child: Control in _heart_labels:
		child.queue_free()
	_heart_labels.clear()
	var heart_tex: Texture2D = ElementIcons.get_heart_texture()
	for i: int in range(hp):
		var heart := TextureRect.new()
		heart.texture = heart_tex
		heart.custom_minimum_size = Vector2(70, 70)
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hearts_row.add_child(heart)
		_heart_labels.append(heart)


## Обновляет отображение текущей стихии.
## Передать -1, чтобы показать пустую ячейку и заблокировать кнопку зоны.
func update_element(element: int) -> void:
	# Удаляем старую текстуру
	if _element_texture_rect != null:
		_element_texture_rect.queue_free()
		_element_texture_rect = null

	if element == -1:
		_element_icon.text = "?"
		_element_icon.visible = true
		_element_icon.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 0.6))
		_element_name_label.text = "—"
		_element_name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
		_set_slot_color(Color(0.15, 0.15, 0.15, 0.8))
		_zone_button.disabled = true
	else:
		var el: ElementTable.Element = element as ElementTable.Element
		var color: Color = _element_color(el)
		_element_icon.visible = false
		# PNG иконка стихии
		var tex: Texture2D = ElementIcons.get_texture(el)
		if tex != null:
			_element_texture_rect = TextureRect.new()
			_element_texture_rect.texture = tex
			_element_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_element_texture_rect.anchors_preset = Control.PRESET_FULL_RECT
			_element_slot.add_child(_element_texture_rect)
		_element_name_label.text = ElementIcons.get_element_name(el)
		_element_name_label.add_theme_color_override("font_color", color)
		_set_slot_color(Color(color.r, color.g, color.b, 0.3))
		_zone_button.disabled = false
	_current_element = element
	_element_wheel.set_active_element(element)
	_update_enemy_highlights()

## Обновляет имя текущего персонажа.
func update_character_name(char_name: String) -> void:
	_char_name_label.text = char_name


## Обновляет счётчик врагов.
func update_enemy_count(count: int) -> void:
	_enemy_count_label.text = "Враги: %d" % count


## Обновляет индикатор кулдауна рывка.
func update_dash_cooldown(remaining: float, total: float) -> void:
	_update_dash_cooldown_display(remaining, total)


## Настраивает индикаторы-стрелки для книг.
func setup_book_indicators(books: Array[BookObject], camera: Camera3D) -> void:
	_camera = camera
	_tracked_books.clear()
	for arrow: Control in _book_arrows:
		arrow.queue_free()
	_book_arrows.clear()

	for book: BookObject in books:
		_tracked_books.append(book)
		var arrow := _create_icon_arrow(ElementIcons.get_book_texture())
		add_child(arrow)
		_book_arrows.append(arrow)


## Настраивает отслеживание врагов для подсветки уязвимых.
func setup_enemy_tracking(enemies: Array[EnemyBase]) -> void:
	_tracked_enemies = enemies
	for arrow: Control in _enemy_arrows:
		arrow.queue_free()
	_enemy_arrows.clear()
	for i: int in range(enemies.size()):
		var arrow := _create_icon_arrow(ElementIcons.get_texture(enemies[i].element))
		arrow.visible = false
		add_child(arrow)
		_enemy_arrows.append(arrow)


## Показывает экран победы.
func show_victory() -> void:
	_game_over_panel.visible = true
	# Переиспользуем панель Game Over с другим текстом
	var label: Label = _game_over_panel.get_node("VBoxContainer/GameOverLabel") as Label
	if label != null:
		label.text = "*** ПОБЕДА! ***"


## Показывает экран Game Over.
func show_game_over() -> void:
	_game_over_panel.visible = true


## Создаёт кнопки пресетов камеры.
func setup_camera_presets(names: Array[String], current: String) -> void:
	for child: Node in _camera_bar.get_children():
		child.queue_free()
	for preset_name: String in names:
		var btn := Button.new()
		btn.text = preset_name
		btn.toggle_mode = true
		btn.button_pressed = (preset_name == current)
		btn.pressed.connect(_on_camera_preset_pressed.bind(preset_name))
		_camera_bar.add_child(btn)


## Обновляет выделение активной кнопки пресета.
func update_camera_preset(active_name: String) -> void:
	for child: Node in _camera_bar.get_children():
		if child is Button:
			var btn: Button = child as Button
			btn.button_pressed = (btn.text == active_name)

# --- Приватные методы ---

## Запускает анимацию смерти сердечка — плавающий вверх, увеличение + прозрачность.
func _start_heart_death(source_heart: Control) -> void:
	var dying := TextureRect.new()
	dying.texture = ElementIcons.get_heart_broken_texture()
	dying.custom_minimum_size = Vector2(70, 70)
	dying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dying.position = source_heart.global_position
	dying.z_index = 10
	add_child(dying)
	_dying_hearts.append({"label": dying, "timer": 0.0, "start_pos": source_heart.global_position})


## Обновляет анимации умирающих сердечек.
func _update_dying_hearts(delta: float) -> void:
	var to_remove: Array[int] = []
	for i: int in range(_dying_hearts.size()):
		var data: Dictionary = _dying_hearts[i]
		var ctrl: Control = data["label"] as Control
		data["timer"] += delta
		var progress: float = data["timer"] / 0.6
		if progress >= 1.0:
			ctrl.queue_free()
			to_remove.append(i)
			continue
		var s: float = lerpf(1.0, 2.5, progress)
		ctrl.scale = Vector2(s, s)
		ctrl.modulate.a = lerpf(1.0, 0.0, progress)
		ctrl.position.y = (data["start_pos"] as Vector2).y - progress * 40.0
	for i: int in range(to_remove.size() - 1, -1, -1):
		_dying_hearts.remove_at(to_remove[i])


## Обновляет стрелку-индикатор на ближайшую книгу за экраном.
func _update_book_arrows() -> void:
	if _camera == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = ARROW_MARGIN
	var cam_pos: Vector3 = _camera.global_position

	# Скрываем все стрелки
	for arrow: Control in _book_arrows:
		arrow.visible = false

	# Проверяем, есть ли хоть одна книга на экране
	var any_on_screen: bool = false
	var closest_idx: int = -1
	var closest_dist: float = INF
	for i: int in range(_tracked_books.size()):
		var book: Node3D = _tracked_books[i]
		if not is_instance_valid(book) or not book.visible:
			continue
		var screen_pos: Vector2 = _camera.unproject_position(book.global_position)
		var is_behind: bool = _camera.is_position_behind(book.global_position)
		var on_screen: bool = not is_behind and screen_pos.x > margin and screen_pos.x < viewport_size.x - margin and screen_pos.y > margin and screen_pos.y < viewport_size.y - margin
		if on_screen:
			any_on_screen = true
			break

	# Если книга видна на экране — стрелка не нужна
	if any_on_screen:
		return

	# Ищем ближайшую книгу за экраном
	for i: int in range(_tracked_books.size()):
		var book: Node3D = _tracked_books[i]
		if not is_instance_valid(book) or not book.visible:
			continue
		var dist: float = cam_pos.distance_to(book.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	if closest_idx < 0 or closest_idx >= _book_arrows.size():
		return

	# Показываем стрелку только на ближайшую
	var book: Node3D = _tracked_books[closest_idx]
	var arrow: Control = _book_arrows[closest_idx]
	var screen_pos: Vector2 = _camera.unproject_position(book.global_position)
	var is_behind: bool = _camera.is_position_behind(book.global_position)

	arrow.visible = true
	if is_behind:
		screen_pos = viewport_size - screen_pos

	var center: Vector2 = viewport_size / 2.0
	var dir: Vector2 = (screen_pos - center).normalized()
	var edge_pos: Vector2 = center
	var half: Vector2 = (viewport_size / 2.0) - Vector2(margin, margin)
	if absf(dir.x) > 0.001:
		var t_x: float = half.x / absf(dir.x)
		var t_y: float = half.y / absf(dir.y) if absf(dir.y) > 0.001 else INF
		var t: float = minf(t_x, t_y)
		edge_pos = center + dir * t
	elif absf(dir.y) > 0.001:
		edge_pos = center + dir * (half.y / absf(dir.y))

	arrow.rotation = dir.angle()
	arrow.position = edge_pos - arrow.size / 2.0


## Создаёт стрелку-указатель: стрелка на краю экрана, иконка ближе к центру.
func _create_icon_arrow(tex: Texture2D) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(46, 24)
	container.size = Vector2(46, 24)
	container.pivot_offset = Vector2(23, 12)
	container.visible = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Иконка (ближе к центру экрана, т.е. слева в контейнере)
	var icon := TextureRect.new()
	if tex != null:
		icon.texture = tex
	icon.anchor_left = 0.0
	icon.anchor_top = 0.0
	icon.anchor_right = 0.0
	icon.anchor_bottom = 0.0
	icon.offset_left = 0.0
	icon.offset_top = 0.0
	icon.offset_right = 24.0
	icon.offset_bottom = 24.0
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon)

	# Стрелка (на краю, т.е. справа)
	var arrow_label := Label.new()
	arrow_label.text = ">"
	arrow_label.add_theme_font_size_override("font_size", 20)
	arrow_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	arrow_label.position = Vector2(26, 0)
	arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(arrow_label)

	return container


## Обновляет подсветку уязвимых врагов на поле.
func _update_enemy_highlights() -> void:
	for enemy: EnemyBase in _tracked_enemies:
		if not is_instance_valid(enemy):
			continue
		if _current_element >= 0:
			var el: ElementTable.Element = _current_element as ElementTable.Element
			if ElementTable.is_counter(el, enemy.element):
				enemy.set_highlighted(true)
			else:
				enemy.set_highlighted(false)
		else:
			enemy.set_highlighted(false)


## Обновляет стрелки на уязвимых врагов за экраном.
func _update_enemy_arrows() -> void:
	if _camera == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	for i: int in range(_tracked_enemies.size()):
		if i >= _enemy_arrows.size():
			break
		var enemy: EnemyBase = _tracked_enemies[i]
		var arrow: Control = _enemy_arrows[i]

		if not is_instance_valid(enemy):
			arrow.visible = false
			continue

		# Показываем стрелку только для уязвимых врагов
		var is_vulnerable: bool = false
		if _current_element >= 0:
			var el: ElementTable.Element = _current_element as ElementTable.Element
			is_vulnerable = ElementTable.is_counter(el, enemy.element)

		if not is_vulnerable:
			arrow.visible = false
			continue

		var screen_pos: Vector2 = _camera.unproject_position(enemy.global_position)
		var is_behind: bool = _camera.is_position_behind(enemy.global_position)
		var margin: float = ARROW_MARGIN
		var on_screen: bool = not is_behind and screen_pos.x > margin and screen_pos.x < viewport_size.x - margin and screen_pos.y > margin and screen_pos.y < viewport_size.y - margin

		if on_screen:
			arrow.visible = false
			continue

		arrow.visible = true
		if is_behind:
			screen_pos = viewport_size - screen_pos

		var center: Vector2 = viewport_size / 2.0
		var dir: Vector2 = (screen_pos - center).normalized()
		var edge_pos: Vector2 = center
		var half: Vector2 = (viewport_size / 2.0) - Vector2(margin, margin)
		if absf(dir.x) > 0.001:
			var t_x: float = half.x / absf(dir.x)
			var t_y: float = half.y / absf(dir.y) if absf(dir.y) > 0.001 else INF
			var t: float = minf(t_x, t_y)
			edge_pos = center + dir * t
		elif absf(dir.y) > 0.001:
			edge_pos = center + dir * (half.y / absf(dir.y))

		arrow.rotation = dir.angle()
		arrow.position = edge_pos - arrow.size / 2.0


## Обновляет визуал кулдауна — заливка растёт снизу вверх на кнопке.
func _update_dash_cooldown_display(remaining: float, total: float) -> void:
	_dash_button.disabled = remaining > 0.0
	if total <= 0.0:
		_dash_cooldown_fill.anchor_top = 1.0
		return
	var progress: float = 1.0 - (remaining / total)  # 0 → 1 по мере готовности
	_dash_cooldown_fill.anchor_top = 1.0 - progress
	if remaining > 0.0:
		_dash_button.text = "Рывок\n%1.0f" % ceilf(remaining)
	else:
		_dash_button.text = "Рывок\n(SHIFT)"


## Возвращает русское название стихии.
func _element_name(element: ElementTable.Element) -> String:
	match element:
		ElementTable.Element.FIRE:
			return "Огонь"
		ElementTable.Element.WATER:
			return "Вода"
		ElementTable.Element.TREE:
			return "Дерево"
		ElementTable.Element.EARTH:
			return "Земля"
		ElementTable.Element.METAL:
			return "Металл"
	return "—"


## Окрашивает фон ячейки стихии.
func _set_slot_color(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_element_slot.add_theme_stylebox_override("panel", style)


## Возвращает цвет стихии.
func _element_color(element: ElementTable.Element) -> Color:
	match element:
		ElementTable.Element.FIRE:
			return Color(0.9, 0.2, 0.1)
		ElementTable.Element.WATER:
			return Color(0.1, 0.4, 0.9)
		ElementTable.Element.TREE:
			return Color(0.2, 0.7, 0.2)
		ElementTable.Element.EARTH:
			return Color(0.6, 0.4, 0.2)
		ElementTable.Element.METAL:
			return Color(0.7, 0.7, 0.7)
	return Color.WHITE



# --- Колбеки сигналов ---

func _on_zone_button_pressed() -> void:
	zone_button_pressed.emit()


func _on_dash_button_pressed() -> void:
	dash_button_pressed.emit()


func _on_restart_button_pressed() -> void:
	restart_pressed.emit()


func _on_camera_preset_pressed(preset_name: String) -> void:
	camera_preset_selected.emit(preset_name)
