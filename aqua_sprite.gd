extends Node2D
## aqua_sprite.gd — Avatar Aqua (Live2D via GDCubism)
## Requiere el addon GDCubism instalado para renderizar el modelo Live2D.
## Si GDCubism no está instalado, muestra un placeholder azul.
## Expone la misma API pública que pet_sprite.gd para compatibilidad.

## --- Configuración ---
const MODEL_PATH: String = "res://assets/aqua/1014100.model3.json"
const OFFSET_X: float = 0.0
const TARGET_HEIGHT: float = 150.0

## Mapeo de estados del pet a motions (group "", index).
const MOTION_MAP: Dictionary = {
	"idle": [14],         # 00_Wait_01
	"walking": [8, 21],   # bound, bound_double
	"eating": [2, 24],    # 00_Happy_01, 00_Happy_02
	"sleeping": [26],     # 00_Sad_01 (calm/peaceful)
	"playing": [1, 12],   # 00_Happy_03, 00_Pride_01
	"sad": [9, 27, 6],    # 00_Cry_01, 00_Cry_02, 00_Cry_03
}

## --- Estado interno ---
var _model: Node = null  # GDCubismUserModel
var _is_live2d: bool = false
var _visual_state: String = "idle"
var _facing_right: bool = true
var _current_mood: float = 1.0
var _fallback_sprite: Sprite2D = null
var _anim_tween: Tween = null
var _base_y: float = 0.0

const FALLBACK_SIZE: float = 100.0


func _ready() -> void:
	# Live2D activado.
	_try_enable_live2d()

	# Posicionar: offset a la derecha del Dino
	var viewport_size := get_viewport_rect().size
	position = viewport_size / 2.0 + Vector2(OFFSET_X, 0)
	_base_y = position.y

	set_visual_state("idle")
	print("[AquaSprite] ✅ Avatar Aqua inicializado (Live2D: %s)" % str(_is_live2d))


func _try_enable_live2d() -> void:
	print("[AquaSprite] 🔄 Intentando cargar modelo Live2D...")
	var success := _setup_live2d()
	if success:
		# Remover fallback
		if _fallback_sprite:
			_fallback_sprite.queue_free()
			_fallback_sprite = null
		_is_live2d = true
		set_visual_state("idle")
		print("[AquaSprite] ✅ Live2D cargado correctamente.")
	else:
		_is_live2d = false
		print("[AquaSprite] ⚠️ Live2D falló. Manteniendo placeholder.")


## --- Setup Live2D (GDCubism) ---

func _setup_live2d() -> bool:
	_model = GDCubismUserModel.new()
	add_child(_model)

	# Cargar modelo (patrón del viewer: assets después de add_child)
	_model.assets = MODEL_PATH

	# Verificar si el modelo cargó correctamente
	var canvas_info: Dictionary = _model.get_canvas_info()
	if canvas_info.is_empty():
		print("[AquaSprite] ⚠️ Modelo Live2D no se pudo cargar: %s" % MODEL_PATH)
		_model.queue_free()
		_model = null
		return false

	# Configurar después de cargar (como en viewer.gd)
	_model.playback_process_mode = GDCubismUserModel.IDLE

	# Escalar al tamaño deseado
	_recalc_scale()

	# Efectos automáticos
	var breath := GDCubismEffectBreath.new()
	_model.add_child(breath)
	var eye_blink := GDCubismEffectEyeBlink.new()
	_model.add_child(eye_blink)

	# Señal de motion finalizado para loop
	_model.motion_finished.connect(_on_motion_finished)
	return true


func _recalc_scale() -> void:
	if not _model:
		return
	var canvas_info: Dictionary = _model.get_canvas_info()
	if canvas_info.is_empty():
		_model.scale = Vector2(0.075, 0.075)
		return
	var model_height: float = canvas_info.size_in_pixels.y
	if model_height > 0:
		var s: float = TARGET_HEIGHT / model_height
		_model.scale = Vector2(s, s)
	else:
		_model.scale = Vector2(0.075, 0.075)


## --- Setup Fallback (sin GDCubism) ---

func _setup_fallback() -> void:
	_fallback_sprite = Sprite2D.new()
	_fallback_sprite.name = "FallbackSprite"
	_fallback_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_fallback_sprite)
	_generate_placeholder_texture()


func _generate_placeholder_texture() -> void:
	var size_i := int(FALLBACK_SIZE)
	var img := Image.create(size_i, size_i * 2, false, Image.FORMAT_RGBA8)
	var center := Vector2(size_i / 2.0, size_i)

	for x in range(size_i):
		for y in range(size_i * 2):
			var dist := Vector2(x, y).distance_to(center)
			var radius := size_i * 0.45
			if dist <= radius:
				var t := dist / radius
				var r := lerpf(0.4, 0.2, t)
				var g := lerpf(0.6, 0.3, t)
				var b := lerpf(1.0, 0.6, t)
				img.set_pixel(x, y, Color(r, g, b, 1.0 - t * 0.3))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	var tex := ImageTexture.create_from_image(img)
	_fallback_sprite.texture = tex


## --- API Pública (compatible con pet_sprite.gd) ---

func set_visual_state(new_state: String) -> void:
	if new_state == _visual_state:
		return
	_visual_state = new_state

	if _is_live2d and _model:
		_play_motion_for_state(new_state)
	else:
		_play_fallback_animation(new_state)


func set_facing_direction(right: bool) -> void:
	_facing_right = right
	if _is_live2d and _model:
		_model.scale.x = absf(_model.scale.x) if right else -absf(_model.scale.x)
	elif _fallback_sprite:
		_fallback_sprite.scale.x = absf(_fallback_sprite.scale.x) if right else -absf(_fallback_sprite.scale.x)


func get_sprite_node() -> Node2D:
	if _is_live2d and _model:
		return _model
	return _fallback_sprite


func update_mood_color(mood: float) -> void:
	_current_mood = clampf(mood, 0.0, 1.0)
	var brightness := lerpf(0.65, 1.0, _current_mood)
	var target: Node2D = _model if (_is_live2d and _model) else _fallback_sprite
	if target:
		target.modulate = Color(brightness, brightness, brightness, target.modulate.a)


func get_silhouette_polygon() -> PackedVector2Array:
	var half_w := 60.0
	var half_h := 120.0
	if _is_live2d and _model:
		half_w = 75.0
		half_h = 150.0
	return PackedVector2Array([
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
		Vector2(half_w, half_h), Vector2(-half_w, half_h)
	])


## --- Live2D Motions ---

func _play_motion_for_state(state_name: String) -> void:
	if not _model or not _is_live2d:
		return
	var key := state_name if MOTION_MAP.has(state_name) else "idle"
	var indices: Array = MOTION_MAP[key]
	var idx: int = indices[randi() % indices.size()]
	_model.start_motion("", idx, GDCubismUserModel.PRIORITY_FORCE)


func _on_motion_finished() -> void:
	_play_motion_for_state(_visual_state)


## --- Fallback Animations ---

func _play_fallback_animation(state_name: String) -> void:
	_kill_tween()
	if not _fallback_sprite:
		return

	_fallback_sprite.position = Vector2.ZERO
	_fallback_sprite.rotation = 0.0

	match state_name:
		"idle":
			_start_idle_bob()
		"walking":
			_start_walk_bob()
		"eating":
			_start_eat_pulse()
		"sleeping":
			_start_sleep_breathe()
		"playing":
			_start_play_bounce()
		"sad":
			_start_sad_sway()


func _start_idle_bob() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.tween_property(_fallback_sprite, "position:y", -3.0, 0.8)
	_anim_tween.tween_property(_fallback_sprite, "position:y", 3.0, 0.8)


func _start_walk_bob() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_fallback_sprite, "position:y", -5.0, 0.15)
	_anim_tween.tween_property(_fallback_sprite, "position:y", 0.0, 0.15)


func _start_eat_pulse() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.tween_property(_fallback_sprite, "scale", Vector2(1.05, 0.95), 0.15)
	_anim_tween.tween_property(_fallback_sprite, "scale", Vector2(1.0, 1.0), 0.15)


func _start_sleep_breathe() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.tween_property(_fallback_sprite, "scale:y", 0.97, 1.5)
	_anim_tween.tween_property(_fallback_sprite, "scale:y", 1.0, 1.5)


func _start_play_bounce() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.tween_property(_fallback_sprite, "position:y", -12.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_fallback_sprite, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.tween_interval(0.2)


func _start_sad_sway() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_fallback_sprite, "rotation", deg_to_rad(-3.0), 1.0)
	_anim_tween.tween_property(_fallback_sprite, "rotation", deg_to_rad(3.0), 1.0)


func _kill_tween() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
