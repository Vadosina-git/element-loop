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
signal character_changed(char_name: String)
signal dash_cooldown_changed(remaining: float, total: float)
signal dash_started()

# --- Константы ---
const FAIL_JOKES: Array[String] = [
	"Сначала книга!",
	"Руки пустые...",
	"Без стихии никак!",
	"Книгу бы почитать...",
	"Я забыл заклинание!",
	"Нужна стихия!",
	"Ловушка из чего?!",
	"Воздух не ловит!",
	"Эй, дай книгу!",
	"Мана кончилась!",
	"Чем кидаться-то?",
	"Пустые карманы...",
	"Сбегай за книгой!",
	"Не готов ещё!",
	"Без магии? Серьёзно?",
	"Хотя бы камень...",
	"Нужно зарядиться!",
	"Фокус не удался!",
	"Абракадабра... нет.",
	"Ищи книгу, лентяй!",
]

const CHARACTERS: Array[Dictionary] = [
	{"name": "Рыцарь", "path": "res://assets/kaykit_skeletons/Knight.glb"},
	{"name": "Скелет-Маг", "path": "res://assets/kaykit_skeletons/Skeleton_Mage_Full.glb"},
	{"name": "Варвар", "path": "res://assets/kaykit_skeletons/Barbarian.glb"},
	{"name": "Маг", "path": "res://assets/kaykit_skeletons/Mage.glb"},
	{"name": "Разбойник", "path": "res://assets/kaykit_skeletons/Rogue.glb"},
	{"name": "Скелет-Воин", "path": "res://assets/kaykit_skeletons/Skeleton_Warrior.glb"},
	{"name": "Скелет-Разбойник", "path": "res://assets/kaykit_skeletons/Skeleton_Rogue.glb"},
	{"name": "Скелет-Миньон", "path": "res://assets/kaykit_skeletons/Skeleton_Minion.glb"},
]

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
var _mesh_node: Node3D = null
var _anim_player: AnimationPlayer = null
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _damage_flash_timer: float = 0.0
var _is_dancing: bool = false
var _dance_timer: float = 0.0
var _original_color: Color = Color(0.3, 0.6, 0.9)
var _target_rotation_y: float = 0.0
var _character_index: int = 0
var _is_placing_zone: bool = false
var _place_zone_timer: float = 0.0
var _joke_bubble: Label3D = null
var _joke_timer: float = 0.0
var _is_joking: bool = false
const PLACE_ZONE_DURATION: float = 0.4
const JOKE_DURATION: float = 1.5
const ROTATION_SPEED: float = 12.0
const ACCELERATION: float = 15.0
const DECELERATION: float = 10.0
var _dash_start_pos: Vector3 = Vector3.ZERO
var _dash_particles: GPUParticles3D = null


# --- Встроенные колбеки ---

func _ready() -> void:
	_setup_collision()
	_setup_visual()
	_setup_dash_particles()
	_setup_ground_indicator()


func _physics_process(delta: float) -> void:
	# Победный танец
	if _is_dancing:
		_dance_timer += delta
		rotation.y += delta * 4.0
		_play_anim("Cheer", 1.0)
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

	# Плавный поворот
	if _move_direction.length() > 0.1:
		var angle_diff: float = wrapf(_target_rotation_y - rotation.y, -PI, PI)
		rotation.y += angle_diff * ROTATION_SPEED * delta

	# Анимация постановки ловушки — прыжок без остановки
	if _is_placing_zone:
		_place_zone_timer -= delta
		if _place_zone_timer <= 0.0:
			_is_placing_zone = false
			if _mesh_node != null:
				_mesh_node.position.y = 0.0
			# Проигрываем анимацию приземления для плавного перехода
			if _anim_player != null:
				if _anim_player.has_animation("Jump_Land"):
					var land_anim: Animation = _anim_player.get_animation("Jump_Land")
					if land_anim != null:
						land_anim.loop_mode = Animation.LOOP_NONE
					_anim_player.speed_scale = 3.0
					_anim_player.play("Jump_Land", 0.1)
		elif _mesh_node != null:
			# Параболический прыжок: быстро вверх, быстрее вниз
			var progress: float = 1.0 - (_place_zone_timer / PLACE_ZONE_DURATION)
			var jump_y: float = 1.2 * (1.0 - (2.0 * progress - 0.4) * (2.0 * progress - 0.4) / (0.6 * 0.6))
			_mesh_node.position.y = maxf(0.0, jump_y)

	# Таймер шуточного бабла
	if _is_joking:
		_joke_timer -= delta
		if _joke_bubble != null:
			# Всплывает вверх и затухает
			_joke_bubble.position.y += delta * 0.5
			if _joke_timer < 0.5:
				_joke_bubble.modulate.a = _joke_timer / 0.5
		if _joke_timer <= 0.0:
			_is_joking = false
			if _joke_bubble != null:
				_joke_bubble.queue_free()
				_joke_bubble = null

	# Обычное движение с инерцией
	var target_velocity: Vector3 = _move_direction * MOVE_SPEED
	if target_velocity.length() > 0.1:
		velocity = velocity.lerp(target_velocity, ACCELERATION * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, DECELERATION * delta)
	move_and_slide()
	_animate_walk(delta)
	_animate_damage_flash(delta)


# --- Публичные методы ---

## Задаёт направление движения. Нормализует, если длина > 0.1.
## Также поворачивает персонажа в сторону движения.
func set_move_direction(direction: Vector3) -> void:
	if direction.length() > 0.1:
		_move_direction = direction.normalized()
		_target_rotation_y = atan2(_move_direction.x, _move_direction.z) + PI
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
	# Анимация постановки (только если не прыгаем)
	if not _is_placing_zone:
		_is_placing_zone = true
		_place_zone_timer = PLACE_ZONE_DURATION
		_start_jump_anim()
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


## Шуточная анимация при попытке поставить ловушку без стихии.
func play_fail_joke() -> void:
	if _is_placing_zone:
		return
	_is_joking = true
	_is_placing_zone = true
	_place_zone_timer = PLACE_ZONE_DURATION
	_start_jump_anim()
	_joke_timer = JOKE_DURATION

	# Бабл с фразой — заменяем старый
	if _joke_bubble != null:
		_joke_bubble.queue_free()
	_joke_bubble = Label3D.new()
	_joke_bubble.text = FAIL_JOKES[randi() % FAIL_JOKES.size()]
	_joke_bubble.font_size = 36
	_joke_bubble.position = Vector3(0.0, 2.0, 0.0)
	_joke_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_joke_bubble.no_depth_test = true
	_joke_bubble.modulate = Color(1.0, 1.0, 0.6, 1.0)
	_joke_bubble.outline_size = 8
	_joke_bubble.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	add_child(_joke_bubble)


## Переключает на следующего персонажа.
func next_character() -> void:
	_character_index = (_character_index + 1) % CHARACTERS.size()
	_reload_character()


## Переключает на предыдущего персонажа.
func prev_character() -> void:
	_character_index = (_character_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
	_reload_character()


## Возвращает имя текущего персонажа.
func get_character_name() -> String:
	return CHARACTERS[_character_index]["name"] as String


## Перезагружает модель текущего персонажа.
func _reload_character() -> void:
	if _mesh_node != null:
		_mesh_node.queue_free()
		_mesh_node = null
		_anim_player = null
	_setup_visual()
	character_changed.emit(get_character_name())


## Возвращает true, если рывок на кулдауне.
func is_dash_on_cooldown() -> bool:
	return _dash_cooldown_timer > 0.0


# --- Приватные методы ---

## Мигание красным при получении урона (модуляция всей модели).
func _animate_damage_flash(delta: float) -> void:
	if _damage_flash_timer <= 0.0:
		return
	_damage_flash_timer -= delta
	if _mesh_node == null:
		return
	if _damage_flash_timer <= 0.0:
		_damage_flash_timer = 0.0
		_set_model_visibility(true)
	else:
		var blink: bool = fmod(_damage_flash_timer * 10.0, 1.0) > 0.5
		_set_model_visibility(blink)


## Запускает анимацию прыжка один раз.
func _start_jump_anim() -> void:
	if _anim_player == null:
		return
	if not _anim_player.has_animation("Jump_Full_Short"):
		return
	var anim: Animation = _anim_player.get_animation("Jump_Full_Short")
	if anim != null:
		anim.loop_mode = Animation.LOOP_NONE
	_anim_player.speed_scale = 3.0
	_anim_player.play("Jump_Full_Short", 0.15)


## Переключает видимость модели (для мигания при уроне).
func _set_model_visibility(vis: bool) -> void:
	if _mesh_node != null:
		_mesh_node.visible = vis


## Создаёт индикатор под ногами персонажа (Brawl Stars style).
func _setup_ground_indicator() -> void:
	var indicator := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.8, 2.8)
	indicator.mesh = plane
	indicator.position = Vector3(0.0, 0.02, 0.0)

	var shader := Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 indicator_color : source_color = vec4(0.2, 1.0, 0.33, 1.0);
uniform float gradient_radius : hint_range(0.1, 1.0) = 0.45;
uniform float rotation_speed : hint_range(0.0, 5.0) = 0.17;
uniform float star_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float ring_width : hint_range(0.05, 0.5) = 0.15;

// Шестиконечная звезда (два наложенных треугольника)
float triangle(vec2 p, float size) {
	float k = sqrt(3.0);
	p.x = abs(p.x) - size;
	p.y = p.y + size / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * size, 0.0);
	return -length(p) * sign(p.y);
}

float hexagram(vec2 p, float size) {
	float d1 = triangle(p, size);
	float d2 = triangle(vec2(p.x, -p.y), size);
	return min(d1, d2);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;

	// Вращение
	float angle = TIME * rotation_speed;
	float ca = cos(angle);
	float sa = sin(angle);
	vec2 ruv = vec2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca);

	// Круг-маска
	float circle = 1.0 - smoothstep(0.9, 1.0, dist);

	// Тонкое неоновое кольцо
	float edge = 0.44;
	float ring = exp(-pow((dist - edge) * 8.0, 2.0)) * 0.6;
	float inner_fill = (1.0 - smoothstep(0.0, 0.44, dist)) * 0.05;
	float alpha = (ring + inner_fill) * step(dist, 0.5);

	// Звезда
	float star = hexagram(ruv, 0.15);
	float star_mask = 1.0 - smoothstep(-0.01, 0.01, star);
	float center_hole = smoothstep(0.08, 0.10, length(ruv));
	star_mask *= center_hole;
	alpha += star_mask * star_alpha * step(dist, 0.5);

	// Общая прозрачность
	alpha *= 0.56;

	ALBEDO = indicator_color.rgb;
	ALPHA = alpha;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	indicator.material_override = mat
	indicator.set_as_top_level(false)
	add_child(indicator)


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


## Анимация ходьбы через AnimationPlayer.
func _animate_walk(_delta: float) -> void:
	if _anim_player == null:
		return
	var is_moving: bool = _move_direction.length() > 0.1

	if _is_dancing:
		return

	if _is_placing_zone:
		# Не перезапускаем — анимация играется один раз при старте прыжка
		return

	if is_moving:
		_play_anim("Walking_A", 3.0)
	else:
		_play_anim("Unarmed_Idle", 1.0)


## Проигрывает анимацию с заданной скоростью и плавным переходом.
func _play_anim(anim_name: String, speed: float) -> void:
	if _anim_player == null:
		return
	if not _anim_player.has_animation(anim_name):
		return
	_anim_player.speed_scale = speed
	# Устанавливаем loop
	var anim: Animation = _anim_player.get_animation(anim_name)
	if anim != null and anim.loop_mode == Animation.LOOP_NONE:
		anim.loop_mode = Animation.LOOP_LINEAR
	if _anim_player.current_animation != anim_name:
		_anim_player.play(anim_name, 0.15)


## Создаёт коллизию: капсула (radius=0.3, height=1.2).
func _setup_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.6, 0.0)
	add_child(collision)


## Создаёт визуал: скелет-маг из KayKit Skeletons (GLB с анимациями).
func _setup_visual() -> void:
	var char_path: String = CHARACTERS[_character_index]["path"] as String
	var scene: PackedScene = load(char_path) as PackedScene
	if scene != null:
		var model: Node3D = scene.instantiate() as Node3D
		model.scale = Vector3(0.5, 0.5, 0.5)
		model.rotation.y = PI
		_mesh_node = model
		add_child(model)

		_anim_player = _find_anim_player(model)
		if _anim_player != null:
			# Скрываем оружие в руках
			_hide_equipment(model)
			# Устанавливаем blend time для плавных переходов
			_anim_player.speed_scale = 1.0
	else:
		# Фоллбек
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.2
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.6, 0.9)
		capsule.material = material
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = capsule
		mesh_instance.position = Vector3(0.0, 0.6, 0.0)
		_mesh_node = mesh_instance
		add_child(mesh_instance)


## Ищет AnimationPlayer рекурсивно в дереве нод.
func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_anim_player(child)
		if found != null:
			return found
	return null


## Скрывает оружие/предметы в руках.
func _hide_equipment(node: Node) -> void:
	if node is BoneAttachment3D:
		var bone_name: String = node.name.to_lower()
		if bone_name.contains("handslot") or bone_name.contains("hand_slot"):
			for child: Node in node.get_children():
				if child is MeshInstance3D:
					(child as MeshInstance3D).visible = false
	for child: Node in node.get_children():
		_hide_equipment(child)
