class_name PostProcessing
extends CanvasLayer

## Полноэкранная пост-обработка: blur vignette + десатурация + тёплый сдвиг.

# --- Публичные переменные ---

var vignette_intensity: float = 0.3:
	set(value):
		vignette_intensity = value
		_update_shader()

var desaturation: float = 0.15:
	set(value):
		desaturation = value
		_update_shader()

var warm_shift: float = 0.12:
	set(value):
		warm_shift = value
		_update_shader()

var contrast: float = 1.1:
	set(value):
		contrast = value
		_update_shader()

var blur_vignette_enabled: bool = true:
	set(value):
		blur_vignette_enabled = value
		_update_shader()

var vignette_brightness: float = 0.0:
	set(value):
		vignette_brightness = value
		_update_shader()

var blur_amount: float = 1.5:
	set(value):
		blur_amount = value
		_update_shader()

var outline_enabled: bool = false:
	set(value):
		outline_enabled = value
		if _outline_rect != null:
			_outline_rect.visible = value

var outline_thickness: float = 1.0:
	set(value):
		outline_thickness = value
		_update_outline()

var outline_color: Color = Color(0.12, 0.1, 0.08, 1.0):
	set(value):
		outline_color = value
		_update_outline()

# --- Приватные переменные ---

var _color_rect: ColorRect = null
var _material: ShaderMaterial = null
var _outline_rect: ColorRect = null
var _outline_material: ShaderMaterial = null


func _ready() -> void:
	layer = 0  # Ниже HUD (layer=1), поверх 3D
	_setup_shader()
	_setup_outline()


## Создаёт outline шейдер (контуры по depth).
func _setup_outline() -> void:
	_outline_rect = ColorRect.new()
	_outline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline_rect.size = get_viewport().get_visible_rect().size
	_outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_rect.visible = outline_enabled

	var shader := Shader.new()
	shader.code = "
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;
uniform vec3 outline_color : source_color = vec3(0.12, 0.1, 0.08);
uniform float edge_threshold : hint_range(0.01, 0.5) = 0.1;

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * outline_thickness;

	// Sobel по яркости
	float tl = luminance(texture(screen_texture, SCREEN_UV + vec2(-px.x, -px.y)).rgb);
	float t  = luminance(texture(screen_texture, SCREEN_UV + vec2(0.0, -px.y)).rgb);
	float tr = luminance(texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y)).rgb);
	float l  = luminance(texture(screen_texture, SCREEN_UV + vec2(-px.x, 0.0)).rgb);
	float r  = luminance(texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)).rgb);
	float bl = luminance(texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y)).rgb);
	float b  = luminance(texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)).rgb);
	float br = luminance(texture(screen_texture, SCREEN_UV + vec2(px.x, px.y)).rgb);

	float sx = -tl - 2.0*l - bl + tr + 2.0*r + br;
	float sy = -tl - 2.0*t - tr + bl + 2.0*b + br;
	float edge = sqrt(sx*sx + sy*sy);
	float is_edge = smoothstep(edge_threshold, edge_threshold * 2.0, edge);

	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	col = mix(col, outline_color, is_edge);
	COLOR = vec4(col, 1.0);
}
"
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = shader
	_outline_material.set_shader_parameter("outline_thickness", outline_thickness)
	_outline_rect.material = _outline_material
	add_child(_outline_rect)


## Обновляет параметры outline.
func _update_outline() -> void:
	if _outline_material == null:
		return
	_outline_material.set_shader_parameter("outline_thickness", outline_thickness)
	_outline_material.set_shader_parameter("outline_color", Vector3(outline_color.r, outline_color.g, outline_color.b))


## Создаёт единый полноэкранный шейдер.
func _setup_shader() -> void:
	_color_rect = ColorRect.new()
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.size = get_viewport().get_visible_rect().size
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = "
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float desaturation : hint_range(0.0, 1.0) = 0.15;
uniform float warm_shift : hint_range(0.0, 0.5) = 0.12;
uniform float contrast_amount : hint_range(0.5, 2.0) = 1.1;
uniform float vignette_brightness : hint_range(0.0, 1.0) = 0.0;
uniform float blur_amount : hint_range(0.0, 5.0) = 1.5;
uniform bool blur_enabled = true;
uniform float blur_inner : hint_range(0.0, 1.0) = 0.5;
uniform float blur_outer : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;

	// Blur vignette — размытие краёв
	if (blur_enabled) {
		vec3 blur_col = textureLod(screen_texture, SCREEN_UV, blur_amount).rgb;
		float dist = length(SCREEN_UV - vec2(0.5));
		float blur_factor = smoothstep(blur_inner, blur_outer, dist);
		col = mix(col, blur_col, blur_factor);
	}

	// Контраст
	col = ((col - 0.5) * contrast_amount) + 0.5;
	col = clamp(col, 0.0, 1.0);

	// Десатурация
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), desaturation);

	// Тёплый сдвиг
	col.r += warm_shift * 0.8;
	col.g += warm_shift * 0.3;
	col.b -= warm_shift * 0.4;
	col = clamp(col, 0.0, 1.0);

	// Виньетка — затемнение/осветление краёв
	vec2 uv_centered = SCREEN_UV - vec2(0.5);
	float vignette = 1.0 - dot(uv_centered, uv_centered) * vignette_intensity * 4.0;
	vignette = clamp(vignette, 0.0, 1.0);
	vignette = smoothstep(0.0, 1.0, vignette);
	vec3 vig_color = vec3(vignette_brightness);
	col = mix(vig_color, col, vignette);

	COLOR = vec4(col, 1.0);
}
"
	_material = ShaderMaterial.new()
	_material.shader = shader
	_color_rect.material = _material
	add_child(_color_rect)
	_update_shader()


## Обновляет все параметры шейдера.
func _update_shader() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("vignette_intensity", vignette_intensity)
	_material.set_shader_parameter("desaturation", desaturation)
	_material.set_shader_parameter("warm_shift", warm_shift)
	_material.set_shader_parameter("contrast_amount", contrast)
	_material.set_shader_parameter("vignette_brightness", vignette_brightness)
	_material.set_shader_parameter("blur_enabled", blur_vignette_enabled)
	_material.set_shader_parameter("blur_amount", blur_amount)
