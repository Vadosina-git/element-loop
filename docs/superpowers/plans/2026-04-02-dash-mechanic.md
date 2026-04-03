# Механика рывка (Dash) — План реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить рывок с прыжком вперёд, кулдауном 5 сек, индикатором кулдауна, мобильной кнопкой и эффектом дыма.

**Architecture:** Логика рывка живёт в `PlayerCharacter` (состояние `_is_dashing`, таймеры, интерполяция). Ввод — через `PlayerInput` (Shift + сигнал). HUD получает новую кнопку «Рывок» и индикатор кулдауна (TextureProgressBar). Дым — GPUParticles3D, дочерний узел персонажа.

**Tech Stack:** Godot 4.x, GDScript 2.0, GPUParticles3D

---

## Структура файлов

| Файл | Действие | Ответственность |
|------|----------|-----------------|
| `src/player/player_character.gd` | Изменить | Логика рывка: старт, интерполяция, кулдаун, частицы |
| `src/player/player_input.gd` | Изменить | Обработка Shift, сигнал `dash_pressed` |
| `src/ui/hud/hud.gd` | Изменить | Кнопка рывка, индикатор кулдауна |
| `src/ui/hud/hud.tscn` | Изменить | Новые UI-ноды: кнопка + прогрессбар кулдауна |
| `src/main/game_controller.gd` | Изменить | Связка сигналов dash |

---

### Task 1: Логика рывка в PlayerCharacter

**Files:**
- Modify: `src/player/player_character.gd`

- [ ] **Step 1: Добавить константы и переменные рывка**

В `player_character.gd` добавить после существующих констант и переменных:

```gdscript
# --- Константы --- (добавить к существующим)
const DASH_DISTANCE: float = 3.0
const DASH_DURATION: float = 0.25
const DASH_JUMP_HEIGHT: float = 0.5
const DASH_COOLDOWN: float = 5.0

# --- Сигналы --- (добавить к существующим)
signal dash_cooldown_changed(remaining: float, total: float)
signal dash_started()

# --- Приватные переменные --- (добавить к существующим)
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _dash_start_pos: Vector3 = Vector3.ZERO
var _dash_particles: GPUParticles3D = null
```

- [ ] **Step 2: Добавить метод создания частиц дыма**

В секцию приватных методов `player_character.gd` добавить:

```gdscript
## Создаёт систему частиц дыма для рывка.
func _setup_dash_particles() -> void:
	_dash_particles = GPUParticles3D.new()
	_dash_particles.emitting = false
	_dash_particles.amount = 10
	_dash_particles.lifetime = 0.4
	_dash_particles.one_shot = true
	_dash_particles.explosiveness = 0.8
	_dash_particles.position = Vector3(0.0, 0.2, 0.3)  # Сзади персонажа

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.5, 1.0)  # Вверх и назад
	material.spread = 30.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0.0, -2.0, 0.0)
	material.scale_min = 0.2
	material.scale_max = 0.5
	material.color = Color(0.85, 0.85, 0.85, 0.7)

	# Затухание через цветовую кривую
	var color_curve := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.85, 0.85, 0.85, 0.7))
	gradient.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	color_curve.gradient = gradient
	material.color_ramp = color_curve

	_dash_particles.process_material = material

	# Меш частицы — сфера
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.1
	sphere_mesh.height = 0.2
	var mesh_material := StandardMaterial3D.new()
	mesh_material.albedo_color = Color(0.85, 0.85, 0.85, 0.7)
	mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mesh.material = mesh_material
	_dash_particles.draw_pass_1 = sphere_mesh

	add_child(_dash_particles)
```

- [ ] **Step 3: Добавить вызов `_setup_dash_particles()` в `_ready()`**

В `_ready()` добавить вызов после `_setup_visual()`:

```gdscript
func _ready() -> void:
	_setup_collision()
	_setup_visual()
	_setup_dash_particles()
```

- [ ] **Step 4: Добавить публичный метод `try_dash()`**

В секцию публичных методов `player_character.gd`:

```gdscript
## Начинает рывок, если кулдаун готов.
## Возвращает true при успехе.
func try_dash() -> bool:
	if _is_dashing or _dash_cooldown_timer > 0.0:
		return false

	_is_dashing = true
	_dash_timer = 0.0
	_dash_start_pos = global_position

	# Направление: текущее движение или взгляд вперёд
	if _move_direction.length() > 0.1:
		_dash_direction = _move_direction.normalized()
	else:
		_dash_direction = -global_transform.basis.z.normalized()

	# Запускаем частицы дыма
	if _dash_particles != null:
		_dash_particles.restart()
		_dash_particles.emitting = true

	dash_started.emit()
	return true


## Возвращает true, если рывок на кулдауне.
func is_dash_on_cooldown() -> bool:
	return _dash_cooldown_timer > 0.0
```

- [ ] **Step 5: Добавить обработку рывка в `_physics_process()`**

Заменить текущий `_physics_process()`:

```gdscript
func _physics_process(delta: float) -> void:
	# Обновляем кулдаун рывка
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
		if _dash_cooldown_timer < 0.0:
			_dash_cooldown_timer = 0.0
		dash_cooldown_changed.emit(_dash_cooldown_timer, DASH_COOLDOWN)

	# Рывок в процессе
	if _is_dashing:
		_dash_timer += delta
		var progress: float = _dash_timer / DASH_DURATION
		if progress >= 1.0:
			# Рывок завершён
			_is_dashing = false
			_dash_cooldown_timer = DASH_COOLDOWN
			dash_cooldown_changed.emit(_dash_cooldown_timer, DASH_COOLDOWN)
			# Финальная позиция на земле
			global_position = _dash_start_pos + _dash_direction * DASH_DISTANCE
			global_position.y = 0.0
			velocity = Vector3.ZERO
		else:
			# Интерполяция позиции + параболический прыжок
			var target_pos: Vector3 = _dash_start_pos + _dash_direction * DASH_DISTANCE * progress
			var jump_y: float = DASH_JUMP_HEIGHT * 4.0 * progress * (1.0 - progress)
			target_pos.y = jump_y
			global_position = target_pos
			velocity = Vector3.ZERO
		_animate_walk(delta)
		return

	# Обычное движение
	velocity = _move_direction * MOVE_SPEED
	move_and_slide()
	_animate_walk(delta)
```

- [ ] **Step 6: Запустить проект, убедиться что ничего не сломалось**

Запустить: `godot --path . --debug`
Ожидание: игрок двигается как раньше, рывок пока не вызывается.

- [ ] **Step 7: Коммит**

```bash
git add src/player/player_character.gd
git commit -m "feat: логика рывка в PlayerCharacter (дистанция, прыжок, кулдаун, частицы дыма)"
```

---

### Task 2: Ввод рывка в PlayerInput

**Files:**
- Modify: `src/player/player_input.gd`

- [ ] **Step 1: Добавить сигнал `dash_pressed`**

В секцию сигналов `player_input.gd`:

```gdscript
# --- Сигналы ---
signal zone_button_pressed()
signal dash_pressed()
```

- [ ] **Step 2: Добавить обработку Shift в `_unhandled_input()`**

В `_unhandled_input()`, после блока обработки пробела, добавить:

```gdscript
	# Shift — рывок
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SHIFT:
			dash_pressed.emit()
			get_viewport().set_input_as_handled()
			return
```

**Важно:** убрать дублирование проверки `event is InputEventKey`. Итоговый блок клавиатуры:

```gdscript
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_SPACE:
				zone_button_pressed.emit()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_SHIFT:
				dash_pressed.emit()
				get_viewport().set_input_as_handled()
				return
```

- [ ] **Step 3: Блокировка ввода движения во время рывка**

В `_process()`, в начале (после проверки `_player == null`), добавить:

```gdscript
	# Во время рывка — не обрабатываем движение
	if _player._is_dashing:
		return
```

- [ ] **Step 4: Коммит**

```bash
git add src/player/player_input.gd
git commit -m "feat: обработка Shift для рывка в PlayerInput"
```

---

### Task 3: Кнопка рывка и индикатор кулдауна в HUD

**Files:**
- Modify: `src/ui/hud/hud.tscn`
- Modify: `src/ui/hud/hud.gd`

- [ ] **Step 1: Добавить ноды в hud.tscn**

Добавить в `hud.tscn` кнопку рывка и контейнер кулдауна. Кнопка размещается выше кнопки «Зона» (справа внизу). Индикатор кулдауна — в левом нижнем углу.

Добавить в конец файла `hud.tscn`:

```
[node name="DashButton" type="Button" parent="."]
unique_name_in_owner = true
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -120.0
offset_top = -230.0
offset_right = -20.0
offset_bottom = -130.0
grow_horizontal = 0
grow_vertical = 0
text = "Рывок"

[node name="DashCooldownContainer" type="MarginContainer" parent="."]
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = -80.0
offset_right = 80.0
offset_bottom = -10.0
grow_vertical = 0

[node name="DashCooldownBar" type="TextureProgressBar" parent="DashCooldownContainer"]
unique_name_in_owner = true
layout_mode = 2
max_value = 5.0
value = 5.0
fill_mode = 4
nine_patch_stretch = true

[node name="DashCooldownLabel" type="Label" parent="DashCooldownContainer"]
unique_name_in_owner = true
layout_mode = 2
horizontal_alignment = 1
vertical_alignment = 1
text = "Рывок"
```

- [ ] **Step 2: Обновить hud.gd — добавить переменные и сигнал**

Добавить сигнал:

```gdscript
signal dash_button_pressed
```

Добавить @onready переменные:

```gdscript
@onready var _dash_button: Button = %DashButton
@onready var _dash_cooldown_bar: TextureProgressBar = %DashCooldownBar
@onready var _dash_cooldown_label: Label = %DashCooldownLabel
```

- [ ] **Step 3: Подключить кнопку рывка в `_ready()`**

В `_ready()` добавить:

```gdscript
	_dash_button.pressed.connect(_on_dash_button_pressed)
	_update_dash_cooldown_display(0.0, DASH_COOLDOWN_DEFAULT)
```

Добавить константу:

```gdscript
const DASH_COOLDOWN_DEFAULT: float = 5.0
```

- [ ] **Step 4: Добавить публичный метод обновления кулдауна**

```gdscript
## Обновляет индикатор кулдауна рывка.
func update_dash_cooldown(remaining: float, total: float) -> void:
	_update_dash_cooldown_display(remaining, total)


## Обновляет визуал кулдауна.
func _update_dash_cooldown_display(remaining: float, total: float) -> void:
	_dash_cooldown_bar.max_value = total
	_dash_cooldown_bar.value = total - remaining
	_dash_button.disabled = remaining > 0.0
	if remaining > 0.0:
		_dash_cooldown_label.text = "%1.0f" % ceilf(remaining)
	else:
		_dash_cooldown_label.text = "Рывок"
```

- [ ] **Step 5: Добавить колбек кнопки**

```gdscript
func _on_dash_button_pressed() -> void:
	dash_button_pressed.emit()
```

- [ ] **Step 6: Коммит**

```bash
git add src/ui/hud/hud.gd src/ui/hud/hud.tscn
git commit -m "feat: кнопка рывка и индикатор кулдауна в HUD"
```

---

### Task 4: Связка всех систем в GameController

**Files:**
- Modify: `src/main/game_controller.gd`

- [ ] **Step 1: Подключить сигналы рывка в `_ready()`**

В `_ready()`, после строки подключения `_player_input.zone_button_pressed`:

```gdscript
	# Подключаем рывок
	_hud.dash_button_pressed.connect(_on_dash_button_pressed)
	_player_input.dash_pressed.connect(_on_dash_button_pressed)
	_player.dash_cooldown_changed.connect(_hud.update_dash_cooldown)
```

- [ ] **Step 2: Добавить колбек рывка**

В секцию колбеков `game_controller.gd`:

```gdscript
## Нажата кнопка рывка (UI или Shift).
func _on_dash_button_pressed() -> void:
	_player.try_dash()
```

- [ ] **Step 3: Запустить проект и протестировать**

Запустить: `godot --path . --debug`

Проверить:
1. Shift → рывок вперёд с прыжком
2. Во время рывка появляются клубы дыма сзади
3. После рывка — 5 сек кулдаун
4. Индикатор кулдауна в левом нижнем углу отсчитывает
5. Кнопка «Рывок» справа заблокирована во время кулдауна
6. Повторный Shift во время кулдауна не работает

- [ ] **Step 4: Коммит**

```bash
git add src/main/game_controller.gd
git commit -m "feat: связка рывка — GameController соединяет PlayerInput, PlayerCharacter и HUD"
```
