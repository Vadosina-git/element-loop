class_name OutlineManager
extends RefCounted

## Управляет контурами (inverted hull через next_pass).
## Brawl Stars стиль: cull_front + расширение по нормалям.

var _outline_shader: Shader = null
var _outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
var _outline_width: float = 0.03

# {category: Array[MeshInstance3D]}
var _tracked: Dictionary = {}
# Запоминаем что мы добавили чтобы корректно удалить
var _modified_meshes: Array[MeshInstance3D] = []


func _init() -> void:
	_outline_shader = Shader.new()
	_outline_shader.code = "
shader_type spatial;
render_mode unshaded, cull_front;

uniform float outline_thickness : hint_range(0.0, 0.1) = 0.03;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
"


## Регистрирует ноду (и все MeshInstance3D внутри) для outline.
func register(node: Node, category: String) -> void:
	if not _tracked.has(category):
		_tracked[category] = []
	_find_meshes(node, _tracked[category] as Array)


## Включает/выключает outline для категории.
func set_category_enabled(category: String, enabled: bool) -> void:
	if not _tracked.has(category):
		return
	for mesh: MeshInstance3D in _tracked[category]:
		if not is_instance_valid(mesh):
			continue
		if enabled:
			_add_outline(mesh)
		else:
			_remove_outline(mesh)


## Обновляет ширину контура.
func set_width(width: float) -> void:
	_outline_width = width
	for mesh: MeshInstance3D in _modified_meshes:
		if not is_instance_valid(mesh):
			continue
		var outline_mat: ShaderMaterial = _get_outline_mat(mesh)
		if outline_mat != null:
			outline_mat.set_shader_parameter("outline_thickness", width)


## Обновляет цвет контура.
func set_color(color: Color) -> void:
	_outline_color = color
	for mesh: MeshInstance3D in _modified_meshes:
		if not is_instance_valid(mesh):
			continue
		var outline_mat: ShaderMaterial = _get_outline_mat(mesh)
		if outline_mat != null:
			outline_mat.set_shader_parameter("outline_color", color)


## Находит все видимые MeshInstance3D рекурсивно.
func _find_meshes(node: Node, result: Array) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_find_meshes(child, result)


## Создаёт outline ShaderMaterial.
func _create_outline_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _outline_shader
	mat.set_shader_parameter("outline_thickness", _outline_width)
	mat.set_shader_parameter("outline_color", _outline_color)
	return mat


## Добавляет outline через next_pass на каждый surface.
func _add_outline(mesh: MeshInstance3D) -> void:
	if mesh in _modified_meshes:
		return

	if mesh.mesh == null:
		return

	var outline_mat: ShaderMaterial = _create_outline_mat()

	if mesh.material_override != null:
		# Есть material_override — ставим next_pass на него
		if mesh.material_override.next_pass == null:
			mesh.material_override.next_pass = outline_mat
			_modified_meshes.append(mesh)
	else:
		# Нет override — работаем через surface материалы
		var added: bool = false
		for i: int in range(mesh.mesh.get_surface_count()):
			var active_mat: Material = mesh.get_active_material(i)
			if active_mat == null:
				continue
			# Клонируем surface материал чтобы не испортить общий ресурс
			var cloned: Material = active_mat.duplicate()
			cloned.next_pass = outline_mat
			mesh.set_surface_override_material(i, cloned)
			added = true
		if added:
			_modified_meshes.append(mesh)


## Удаляет outline.
func _remove_outline(mesh: MeshInstance3D) -> void:
	if mesh not in _modified_meshes:
		return

	if mesh.material_override != null:
		mesh.material_override.next_pass = null
	else:
		for i: int in range(mesh.mesh.get_surface_count()):
			var override_mat: Material = mesh.get_surface_override_material(i)
			if override_mat != null:
				override_mat.next_pass = null
				mesh.set_surface_override_material(i, null)

	_modified_meshes.erase(mesh)


## Получает outline ShaderMaterial из меша (для обновления параметров).
func _get_outline_mat(mesh: MeshInstance3D) -> ShaderMaterial:
	if mesh.material_override != null and mesh.material_override.next_pass is ShaderMaterial:
		return mesh.material_override.next_pass as ShaderMaterial
	if mesh.mesh != null:
		for i: int in range(mesh.mesh.get_surface_count()):
			var mat: Material = mesh.get_surface_override_material(i)
			if mat != null and mat.next_pass is ShaderMaterial:
				return mat.next_pass as ShaderMaterial
	return null
