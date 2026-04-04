class_name PlayerCharacter
extends CharacterBody3D

## Персонаж игрока.
##
## Управляет здоровьем, зарядами зон, движением и взаимодействием
## со стихиями. Не наносит урон напрямую — использует зоны.

# --- Сигналы ---
signal hp_changed(new_hp: int)
signal element_changed(new_element: int)
signal zone_placed(element: int, position: Vector3)
signal died()
signal dash_cooldown_changed(remaining: float, total: float)
signal dash_started()

# --- Константы ---
const MOVE_SPEED: float = 3.33
const MAX_HP: int = 2
const DASH_DISTANCE: float = 3.0
const DASH_DURATION: float = 0.25
const DASH_JUMP_HEIGHT: float = 0.5
const DASH_COOLDOWN: float = 5.0

# --- Публичные переменные ---
var hp: int = MAX_HP
## Текущая выбранная стихия. -1 означает «нет стихии».
var current_element: int = -1
var has_zone_charge: bool = false

# --- Приватные переменные ---
var _move_direction: Vector3 = Vector3.ZERO
var _anim_time: float = 0.0
var _mesh_node: MeshInstance3D = null
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _damage_flash_timer: float = 0.0
var _is_dancing: bool = false
var _dance_timer: float = 0.0
var _original_color: Color = Color(0.3, 0.6, 0.9)
var _dash_start_pos: Vector3 = Vector3.ZERO
var _dash_particles: GPUParticles3D = null


# --- Встроенные колбеки ---

func _ready() -> void:
	_setup_collision()
	_setup_visual()
	_setup_dash_particles()


func _physics_process(delta: float) -> void:
	# Победный танец
	if _is_dancing:
		_dance_timer += delta
		# Вращение вокруг оси
		rotation.y += delta * 8.0
		# Прыжки
		if _mesh_node != null:
			var jump: float = absf(sin(_dance_timer * 5.0)) * 0.4
			_mesh_node.position.y = jump
			_mesh_node.rotation.z = sin(_dance_timer * 3.0) * 0.15
		return

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
			velocity = Vector3.ZERO
		else:
			# Рывок через velocity — учитывает коллизии
			var dash_speed: float = DASH_DISTANCE / DASH_DURATION
			velocity = _dash_direction * dash_speed
			velocity.y = 0.0
		move_and_slide()
		_animate_walk(delta)
		_animate_damage_flash(delta)
		return

	# Обычное движение
	velocity = _move_direction * MOVE_SPEED
	move_and_slide()
	_animate_walk(delta)
	_animate_damage_flash(delta)


# --- Публичные методы ---

## Задаёт направление движения. Нормализует, если длина > 0.1.
## Также поворачивает персонажа в сторону движения.
func set_move_direction(direction: Vector3) -> void:
	if direction.length() > 0.1:
		_move_direction = direction.normalized()
		var look_target: Vector3 = global_position + _move_direction
		look_target.y = global_position.y
		look_at(look_target, Vector3.UP)
	else:
		_move_direction = Vector3.ZERO


## Подбирает стихию из книги. Устанавливает заряд зоны.
func pickup_element(element: int) -> void:
	current_element = element
	has_zone_charge = true
	element_changed.emit(current_element)


## Ставит зону текущей стихии под собой.
## Возвращает true при успехе, false если нет заряда.
func place_zone() -> bool:
	if not has_zone_charge:
		return false
	var placed_element: int = current_element
	var placed_position: Vector3 = global_position
	has_zone_charge = false
	current_element = -1
	zone_placed.emit(placed_element, placed_position)
	element_changed.emit(current_element)
	return true


## Наносит урон игроку. При 0 HP эмитит сигнал смерти.
func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp)
	_damage_flash_timer = 0.6
	if hp <= 0:
		died.emit()


## Лечит игрока. HP не превышает MAX_HP.
func heal(amount: int) -> void:
	hp = mini(MAX_HP, hp + amount)
	hp_changed.emit(hp)


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


## Запускает анимацию победного танца.
func start_victory_dance() -> void:
	_is_dancing = true
	_dance_timer = 0.0
	_move_direction = Vector3.ZERO
	velocity = Vector3.ZERO


## Возвращает true, если рывок на кулдауне.
func is_dash_on_cooldown() -> bool:
	return _dash_cooldown_timer > 0.0


# --- Приватные методы ---

## Мигание красным при получении урона.
func _animate_damage_flash(delta: float) -> void:
	if _damage_flash_timer <= 0.0:
		return
	_damage_flash_timer -= delta
	if _mesh_node == null or _mesh_node.material_override == null:
		return
	var mat: StandardMaterial3D = _mesh_node.material_override as StandardMaterial3D
	if _damage_flash_timer <= 0.0:
		_damage_flash_timer = 0.0
		mat.albedo_color = _original_color
	else:
		var blink: bool = fmod(_damage_flash_timer * 10.0, 1.0) > 0.5
		mat.albedo_color = Color(1.0, 0.1, 0.1) if blink else _original_color


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


## Анимация ходьбы: покачивание и подпрыгивание.
func _animate_walk(delta: float) -> void:
	if _mesh_node == null:
		return
	var is_moving: bool = _move_direction.length() > 0.1
	if is_moving:
		_anim_time += delta * 10.0
		# Подпрыгивание
		var bounce: float = absf(sin(_anim_time)) * 0.15
		_mesh_node.position.y = bounce
		# Наклон вперёд-назад (покачивание)
		_mesh_node.rotation.x = sin(_anim_time) * 0.1
		# Покачивание влево-вправо
		_mesh_node.rotation.z = sin(_anim_time * 0.5) * 0.05
	else:
		# Плавный возврат в исходное положение
		_mesh_node.position.y = lerpf(_mesh_node.position.y, 0.0, delta * 10.0)
		_mesh_node.rotation.x = lerpf(_mesh_node.rotation.x, 0.0, delta * 10.0)
		_mesh_node.rotation.z = lerpf(_mesh_node.rotation.z, 0.0, delta * 10.0)


## Создаёт коллизию: капсула (radius=0.3, height=1.2).
func _setup_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.6, 0.0)
	add_child(collision)


## Создаёт визуал: капсула-меш (синий цвет).
func _setup_visual() -> void:
	var dummy_mesh: Mesh = load("res://assets/kaykit_prototype/Dummy_Base_Dummy_Body_Dummy_Head.obj") as Mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.9)
	var mesh_instance := MeshInstance3D.new()

	if dummy_mesh != null:
		mesh_instance.mesh = dummy_mesh
		mesh_instance.scale = Vector3(0.5, 0.5, 0.5)
		mesh_instance.position = Vector3(0.0, 0.0, 0.0)
		mesh_instance.material_override = material
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.2
		capsule.material = material
		mesh_instance.mesh = capsule
		mesh_instance.position = Vector3(0.0, 0.6, 0.0)

	_mesh_node = mesh_instance
	add_child(mesh_instance)
