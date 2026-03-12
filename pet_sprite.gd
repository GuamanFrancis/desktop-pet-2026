extends Node2D
## pet_sprite.gd — PetSprite (Sistema de Animación Profesional)
## Implementa:
##   - Crossfade suave entre sprites al cambiar estado
##   - Squash & stretch (principios de animación Disney)
##   - Anticipation y follow-through
##   - Breathing animation (idle)
## Usa dos Sprite2D superpuestos para transiciones.

## --- Sprites por Estado ---
var _sprites: Dictionary = {}

## --- Configuración ---
const SPRITE_SCALE: float = 6.0           # Escala aumentada para pixel art (24x24 -> 144x144)
const CROSSFADE_DURATION: float = 0.2     # Crossfade más rápido para pixel art
const IDLE_BOB_AMPLITUDE: float = 3.0
const IDLE_BREATHE_SCALE: float = 0.015
const ANTICIPATION_DURATION: float = 0.12
const SQUASH_AMOUNT: float = 0.08

## --- Configuración de Animación (Frames de 24x24) ---
const HFRAMES: int = 24
const FRAME_DURATION: float = 0.12

const ANIM_DATA: Dictionary = {
	"idle": {"frames": [0, 1, 2, 3], "loop": true},
	"walking": {"frames": [4, 5, 6, 7, 8, 9], "loop": true},
	"eating": {"frames": [10, 11, 12, 11], "loop": true},
	"sad": {"frames": [13, 14, 15], "loop": true},
	"sleeping": {"frames": [17, 18, 19, 20], "loop": true},
	"playing": {"frames": [4, 5, 10, 11, 4, 5], "loop": true},
}

## --- Nodos internos ---
var _sprite_front: Sprite2D = null
var _sprite_back: Sprite2D = null

## --- Estado ---
var _base_y: float = 0.0
var _anim_tween: Tween = null
var _crossfade_tween: Tween = null
var _frame_tween: Tween = null
var _visual_state: String = "idle"
var _facing_right: bool = true
var _current_mood: float = 1.0

## --- Sprite Sheet Path ---
const MAIN_SHEET_PATH: String = "res://dinoCharactersVersion1.1/sheets/DinoSprites - doux.png"


func _ready() -> void:
	# Crear los dos Sprite2D para crossfade
	_sprite_back = Sprite2D.new()
	_sprite_back.name = "SpriteBack"
	_sprite_back.hframes = HFRAMES
	_sprite_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite_back)
	
	_sprite_front = Sprite2D.new()
	_sprite_front.name = "SpriteFront"
	_sprite_front.hframes = HFRAMES
	_sprite_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite_front)
	
	# Cargar sprite sheet
	_load_sheet()
	
	# Configurar escala y posición
	_sprite_front.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite_back.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite_back.modulate.a = 0.0
	
	# Centrar en viewport
	var viewport_size := get_viewport_rect().size
	position = viewport_size / 2.0
	_base_y = position.y
	
	# Iniciar con idle
	set_visual_state("idle")
	print("[PetSprite] ✅ Sistema de animación pixel-art inicializado.")


## --- Carga de Assets ---

func _load_sheet() -> void:
	if ResourceLoader.exists(MAIN_SHEET_PATH):
		var tex := load(MAIN_SHEET_PATH) as Texture2D
		_sprite_front.texture = tex
		_sprite_back.texture = tex
	else:
		print("[PetSprite] ⚠️ Sprite sheet no encontrado: %s" % MAIN_SHEET_PATH)
		_generate_fallback_texture()


## --- Cambio de Estado con Crossfade ---

func set_visual_state(new_state: String) -> void:
	if new_state == _visual_state and _frame_tween:
		return
	
	var old_state := _visual_state
	_visual_state = new_state
	
	# Detener animaciones previas
	_kill_tweens()
	
	# Preparar crossfade
	_sprite_back.frame = _sprite_front.frame
	_sprite_back.scale = _sprite_front.scale
	_sprite_back.modulate = _sprite_front.modulate
	_sprite_back.modulate.a = 1.0
	_sprite_back.position = _sprite_front.position

	_sprite_front.modulate.a = 0.0
	
	# Animar crossfade
	_crossfade_tween = create_tween().set_parallel(true)
	_crossfade_tween.set_trans(Tween.TRANS_SINE)
	_crossfade_tween.set_ease(Tween.EASE_IN_OUT)
	_crossfade_tween.tween_property(_sprite_front, "modulate:a", 1.0, CROSSFADE_DURATION)
	_crossfade_tween.tween_property(_sprite_back, "modulate:a", 0.0, CROSSFADE_DURATION)

	# Reset transformaciones
	_sprite_front.position = Vector2.ZERO
	_sprite_front.rotation = 0.0
	_sprite_front.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	if not _facing_right:
		_sprite_front.scale.x = -SPRITE_SCALE
	
	# Iniciar loop de frames para el nuevo estado
	_start_frame_animation(new_state)

	# --- ANTICIPATION / Juiciness ---
	match new_state:
		"eating", "playing":
			_play_anticipation(new_state)
		"walking":
			_play_anticipation_walk()
		"sleeping":
			_play_settle_down()
		"sad":
			_play_droop()
		"idle":
			_start_idle_bobbing()


## --- ANTICIPATION (preparación antes de acción) ---

## Squash rápido antes de comer/jugar
func _play_anticipation(then_state: String) -> void:
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_BACK)
	_anim_tween.set_ease(Tween.EASE_OUT)
	
	# Squash: comprimir verticalmente, expandir horizontalmente
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * (1.0 + SQUASH_AMOUNT), SPRITE_SCALE * (1.0 - SQUASH_AMOUNT)),
		ANTICIPATION_DURATION)
	# Stretch: expandir verticalmente
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * (1.0 - SQUASH_AMOUNT * 0.5), SPRITE_SCALE * (1.0 + SQUASH_AMOUNT * 0.5)),
		ANTICIPATION_DURATION)
	# Return + iniciar animación del estado
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE),
		0.1)
	
	match then_state:
		"eating":
			_anim_tween.tween_callback(_start_eat_loop)
		"playing":
			_anim_tween.tween_callback(_start_play_loop)


## Anticipation de caminar: inclinarse ligeramente hacia la dirección
func _play_anticipation_walk() -> void:
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	# Agacharse levemente (preparación)
	_anim_tween.tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * 0.92, ANTICIPATION_DURATION)
	# Estirar hacia arriba (impulso)
	_anim_tween.tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * 1.05, ANTICIPATION_DURATION * 0.7)
	# Normalizar + iniciar loop
	_anim_tween.tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE, 0.1)
	_anim_tween.tween_callback(_start_walk_loop)


## Transición a dormir: settle down suave
func _play_settle_down() -> void:
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.set_ease(Tween.EASE_IN_OUT)
	# Bajar ligeramente + squash (sentarse)
	_anim_tween.tween_property(_sprite_front, "position:y",
		6.0, 0.5)
	_anim_tween.parallel().tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * 0.95, 0.5)
	_anim_tween.tween_callback(_start_sleep_loop)


## Transición a triste: droop (caer)
func _play_droop() -> void:
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	# Inclinarse hacia adelante
	_anim_tween.tween_property(_sprite_front, "rotation",
		deg_to_rad(-3.0), 0.4)
	_anim_tween.parallel().tween_property(_sprite_front, "position:y",
		4.0, 0.4)
	_anim_tween.tween_callback(_start_sad_loop)


## --- ANIMACIÓN POR FRAMES ---

func _start_frame_animation(anim_name: String) -> void:
	if not ANIM_DATA.has(anim_name):
		return

	var frames: Array = ANIM_DATA[anim_name]["frames"]
	_frame_tween = create_tween().set_loops()

	for frame_idx in frames:
		_frame_tween.tween_callback(func(): _sprite_front.frame = frame_idx)
		_frame_tween.tween_interval(FRAME_DURATION)


func _start_idle_bobbing() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.set_ease(Tween.EASE_IN_OUT)
	_anim_tween.tween_property(_sprite_front, "position:y", -IDLE_BOB_AMPLITUDE, 0.8)
	_anim_tween.parallel().tween_property(_sprite_front, "scale:y", SPRITE_SCALE * (1.0 + IDLE_BREATHE_SCALE), 0.8)
	_anim_tween.tween_property(_sprite_front, "position:y", IDLE_BOB_AMPLITUDE, 0.8)
	_anim_tween.parallel().tween_property(_sprite_front, "scale:y", SPRITE_SCALE, 0.8)


func _start_walk_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_sprite_front, "position:y", -2.0, 0.15)
	_anim_tween.tween_property(_sprite_front, "position:y", 0.0, 0.15)


func _start_eat_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.tween_property(_sprite_front, "scale", Vector2(SPRITE_SCALE * 1.05, SPRITE_SCALE * 0.95), 0.1)
	_anim_tween.tween_property(_sprite_front, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.1)


func _start_play_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.tween_property(_sprite_front, "position:y", -15.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_sprite_front, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.tween_interval(0.2)


func _start_sleep_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.tween_property(_sprite_front, "scale:y", SPRITE_SCALE * 0.96, 1.5)
	_anim_tween.tween_property(_sprite_front, "scale:y", SPRITE_SCALE, 1.5)


func _start_sad_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.tween_property(_sprite_front, "rotation", deg_to_rad(-3.0), 1.0)
	_anim_tween.tween_property(_sprite_front, "rotation", deg_to_rad(3.0), 1.0)


## --- Utilidades ---

func _kill_tweens() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
	if _frame_tween and _frame_tween.is_valid():
		_frame_tween.kill()
		_frame_tween = null
	# Matar crossfade sólo si ya terminó (alpha ~1.0 o ~0.0)
	if _crossfade_tween and _crossfade_tween.is_valid():
		if _sprite_front and _sprite_front.modulate.a > 0.95:
			_crossfade_tween.kill()
			_crossfade_tween = null
			_sprite_front.modulate.a = 1.0
			_sprite_back.modulate.a = 0.0


func set_facing_direction(right: bool) -> void:
	_facing_right = right
	if _sprite_front:
		var current_scale_x := absf(_sprite_front.scale.x)
		_sprite_front.scale.x = current_scale_x if right else -current_scale_x


func update_mood_color(mood: float) -> void:
	_current_mood = clampf(mood, 0.0, 1.0)
	var brightness := lerpf(0.65, 1.0, _current_mood)
	if _sprite_front:
		var current_alpha := _sprite_front.modulate.a
		_sprite_front.modulate = Color(brightness, brightness, brightness, current_alpha)


## --- Polígono de Silueta ---
var _cached_polygons: Dictionary = {}

func get_silhouette_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	
	if _sprite_front and _sprite_front.texture:
		var tex := _sprite_front.texture
		var frame := _sprite_front.frame

		if _cached_polygons.has(frame):
			var base_poly: PackedVector2Array = _cached_polygons[frame]
			var scale_x := absf(_sprite_front.scale.x)
			var scale_y := absf(_sprite_front.scale.y)
			var half_width := (tex.get_width() / _sprite_front.hframes) / 2.0
			var half_height := (tex.get_height() / _sprite_front.vframes) / 2.0

			for pt in base_poly:
				# Centrar el punto (BitMap coordinates to centered coordinates)
				var centered_pt := Vector2(pt.x - half_width, pt.y - half_height)
				var final_pt := Vector2(centered_pt.x * scale_x, centered_pt.y * scale_y)
				# Aplicar la escala de la mascota (si el sprite está invertido horizontalmente)
				if not _facing_right:
					final_pt.x = -final_pt.x
				polygon.append(final_pt)
			return polygon

		var hframes := _sprite_front.hframes
		var vframes := _sprite_front.vframes

		# Calcular el tamaño y la posición del frame en la textura
		var frame_width := tex.get_width() / hframes
		var frame_height := tex.get_height() / vframes
		var frame_x := (frame % hframes) * frame_width
		var frame_y := (frame / hframes) * frame_height
		var frame_rect := Rect2i(frame_x, frame_y, frame_width, frame_height)

		# Obtener la imagen de la textura
		var img := tex.get_image()
		if not img:
			return _get_fallback_polygon()

		# Extraer el sub-rectángulo del frame actual
		var frame_img := img.get_region(frame_rect)

		# Crear un BitMap a partir de la imagen
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(frame_img)

		# Generar los polígonos desde el BitMap
		var polygons := bitmap.opaque_to_polygons(Rect2(0, 0, frame_width, frame_height), 1.0)

		if polygons.size() > 0:
			# Escalar y centrar el primer polígono (asumimos que es el contorno principal)
			var base_poly: PackedVector2Array = polygons[0]
			_cached_polygons[frame] = base_poly

			var scale_x := absf(_sprite_front.scale.x)
			var scale_y := absf(_sprite_front.scale.y)
			var half_width := frame_width / 2.0
			var half_height := frame_height / 2.0

			for pt in base_poly:
				# Centrar el punto (BitMap coordinates to centered coordinates)
				var centered_pt := Vector2(pt.x - half_width, pt.y - half_height)
				var final_pt := Vector2(centered_pt.x * scale_x, centered_pt.y * scale_y)
				# Aplicar la escala de la mascota (si el sprite está invertido horizontalmente)
				if not _facing_right:
					final_pt.x = -final_pt.x
				polygon.append(final_pt)
			return polygon

	return _get_fallback_polygon()


func _get_fallback_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in range(16):
		var angle := (float(i) / 16.0) * TAU
		polygon.append(Vector2(cos(angle) * 60, sin(angle) * 60))
	return polygon


## --- Fallback ---

func _generate_fallback_texture() -> void:
	var diameter := 120
	var radius := diameter / 2
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)
	for x in range(diameter):
		for y in range(diameter):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
				var t := dist / float(radius)
				img.set_pixel(x, y, Color(lerpf(0.3, 0.15, t), lerpf(0.8, 0.5, t), lerpf(0.5, 0.3, t), 1.0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_sprites["idle"] = ImageTexture.create_from_image(img)
