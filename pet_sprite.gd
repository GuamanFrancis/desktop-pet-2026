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
const SPRITE_SCALE: float = 0.7
const CROSSFADE_DURATION: float = 0.35    # Duración del crossfade entre estados
const IDLE_BOB_AMPLITUDE: float = 4.0
const IDLE_BREATHE_SCALE: float = 0.02    # Variación de escala al respirar
const ANTICIPATION_DURATION: float = 0.15 # Preparación antes de acción
const SQUASH_AMOUNT: float = 0.12         # Intensidad del squash & stretch

## --- Nodos internos ---
var _sprite_front: Sprite2D = null  # Sprite visible actual
var _sprite_back: Sprite2D = null   # Sprite que sale (para crossfade)

## --- Estado ---
var _base_y: float = 0.0
var _anim_tween: Tween = null
var _crossfade_tween: Tween = null
var _visual_state: String = "idle"
var _facing_right: bool = true
var _current_mood: float = 1.0

## --- Sprite Paths ---
const SPRITE_PATHS: Dictionary = {
	"idle": "res://assets/sprites/dino_idle.png",
	"sleeping": "res://assets/sprites/dino_sleeping.png",
	"eating": "res://assets/sprites/dino_eating.png",
	"playing": "res://assets/sprites/dino_playing.png",
	"sad": "res://assets/sprites/dino_sad.png",
	"walking": "res://assets/sprites/dino_walking.png",
}


func _ready() -> void:
	# Crear los dos Sprite2D para crossfade
	_sprite_back = Sprite2D.new()
	_sprite_back.name = "SpriteBack"
	add_child(_sprite_back)
	
	_sprite_front = Sprite2D.new()
	_sprite_front.name = "SpriteFront"
	add_child(_sprite_front)
	
	# Cargar sprites
	_load_sprites()
	
	# Configurar escala y posición
	_sprite_front.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite_back.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite_back.modulate.a = 0.0
	
	# Aplicar sprite idle
	if _sprites.has("idle"):
		_sprite_front.texture = _sprites["idle"] as Texture2D
	
	# Centrar en viewport
	var viewport_size := get_viewport_rect().size
	position = viewport_size / 2.0
	_base_y = position.y
	
	# Iniciar idle
	_start_idle_animation()
	print("[PetSprite] ✅ Sistema de animación profesional inicializado (%d sprites)." % _sprites.size())


## --- Carga de Sprites ---

func _load_sprites() -> void:
	for state_name: String in SPRITE_PATHS:
		var path: String = SPRITE_PATHS[state_name]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_sprites[state_name] = tex
		else:
			print("[PetSprite] ⚠️ Sprite no encontrado: %s" % path)
	
	if _sprites.is_empty():
		_generate_fallback_texture()


## --- Cambio de Estado con Crossfade ---

func set_visual_state(new_state: String) -> void:
	if new_state == _visual_state:
		return
	
	var old_state := _visual_state
	_visual_state = new_state
	
	# Detener animaciones previas
	_kill_tweens()
	
	# --- CROSSFADE: sprite actual → back, nuevo → front ---
	if _sprites.has(new_state):
		# Copiar el sprite actual al back
		_sprite_back.texture = _sprite_front.texture
		_sprite_back.scale = _sprite_front.scale
		_sprite_back.modulate = _sprite_front.modulate
		_sprite_back.modulate.a = 1.0
		_sprite_back.position = _sprite_front.position
		
		# Poner el nuevo sprite en front (invisible al inicio)
		_sprite_front.texture = _sprites[new_state] as Texture2D
		_sprite_front.modulate.a = 0.0
		
		# Animar crossfade
		_crossfade_tween = create_tween().set_parallel(true)
		_crossfade_tween.set_trans(Tween.TRANS_SINE)
		_crossfade_tween.set_ease(Tween.EASE_IN_OUT)
		_crossfade_tween.tween_property(_sprite_front, "modulate:a", 1.0, CROSSFADE_DURATION)
		_crossfade_tween.tween_property(_sprite_back, "modulate:a", 0.0, CROSSFADE_DURATION)
	
	# Reset transformaciones del front
	_sprite_front.position = Vector2.ZERO
	_sprite_front.rotation = 0.0
	_sprite_front.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	if not _facing_right:
		_sprite_front.scale.x = -SPRITE_SCALE
	
	# --- ANTICIPATION antes de la acción ---
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
			_start_idle_animation()


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


## --- LOOPS DE ANIMACIÓN ---

func _start_idle_animation() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.set_ease(Tween.EASE_IN_OUT)
	# Bobbing suave + respiración (scale Y oscila)
	_anim_tween.tween_property(_sprite_front, "position:y",
		-IDLE_BOB_AMPLITUDE, IDLE_BOB_AMPLITUDE * 0.35)
	_anim_tween.parallel().tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * (1.0 + IDLE_BREATHE_SCALE), IDLE_BOB_AMPLITUDE * 0.35)
	_anim_tween.tween_property(_sprite_front, "position:y",
		IDLE_BOB_AMPLITUDE, IDLE_BOB_AMPLITUDE * 0.35)
	_anim_tween.parallel().tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * (1.0 - IDLE_BREATHE_SCALE * 0.5), IDLE_BOB_AMPLITUDE * 0.35)


func _start_walk_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.set_ease(Tween.EASE_IN_OUT)
	# Paso 1: pie izquierdo → inclinación + squash al pisar
	_anim_tween.tween_property(_sprite_front, "position:y",
		-6.0, 0.18)
	_anim_tween.parallel().tween_property(_sprite_front, "rotation",
		deg_to_rad(2.5), 0.18)
	# Aterrizar: squash
	_anim_tween.tween_property(_sprite_front, "position:y",
		2.0, 0.12)
	_anim_tween.parallel().tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * 0.94, 0.12)
	# Recuperar
	_anim_tween.tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE, 0.06)
	# Paso 2: pie derecho → inclinación opuesta + squash
	_anim_tween.tween_property(_sprite_front, "position:y",
		-6.0, 0.18)
	_anim_tween.parallel().tween_property(_sprite_front, "rotation",
		deg_to_rad(-2.5), 0.18)
	_anim_tween.tween_property(_sprite_front, "position:y",
		2.0, 0.12)
	_anim_tween.parallel().tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * 0.94, 0.12)
	_anim_tween.tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE, 0.06)
	_anim_tween.tween_property(_sprite_front, "rotation",
		0.0, 0.06)


func _start_eat_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_BOUNCE)
	_anim_tween.set_ease(Tween.EASE_OUT)
	# Masticar: squash rápido + slight rotation
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * 1.06, SPRITE_SCALE * 0.94), 0.1)
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * 0.97, SPRITE_SCALE * 1.03), 0.1)
	_anim_tween.tween_property(_sprite_front, "rotation",
		deg_to_rad(1.5), 0.05)
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.08)
	_anim_tween.tween_property(_sprite_front, "rotation",
		deg_to_rad(-1.0), 0.05)
	_anim_tween.tween_property(_sprite_front, "rotation",
		0.0, 0.1)


func _start_play_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_BACK)
	_anim_tween.set_ease(Tween.EASE_OUT)
	# Saltar: stretch vertical → arriba → squash al aterrizar
	# Preparar (squash)
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * 1.1, SPRITE_SCALE * 0.88), 0.1)
	# Saltar (stretch)
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * 0.9, SPRITE_SCALE * 1.12), 0.08)
	_anim_tween.parallel().tween_property(_sprite_front, "position:y",
		-20.0, 0.2)
	# Rotar en el aire
	_anim_tween.tween_property(_sprite_front, "rotation",
		deg_to_rad(10.0), 0.1)
	# Caer
	_anim_tween.tween_property(_sprite_front, "position:y",
		0.0, 0.15)
	_anim_tween.parallel().tween_property(_sprite_front, "rotation",
		0.0, 0.15)
	# Aterrizar (squash fuerte = impacto)
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * 1.15, SPRITE_SCALE * 0.85), 0.06)
	# Rebote (follow-through)
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE * 0.97, SPRITE_SCALE * 1.04), 0.1)
	# Normalizar
	_anim_tween.tween_property(_sprite_front, "scale",
		Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.15)
	# Pausa breve antes de repetir
	_anim_tween.tween_interval(0.3)


func _start_sleep_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.set_ease(Tween.EASE_IN_OUT)
	# Respiración profunda de dormir (solo scale Y, muy lento)
	_anim_tween.tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * 0.94, 1.8)
	_anim_tween.tween_property(_sprite_front, "scale:y",
		SPRITE_SCALE * 0.98, 1.8)


func _start_sad_loop() -> void:
	_anim_tween = create_tween().set_loops()
	_anim_tween.set_trans(Tween.TRANS_SINE)
	_anim_tween.set_ease(Tween.EASE_IN_OUT)
	# Mecerse ligeramente de lado a lado (self-comforting)
	_anim_tween.tween_property(_sprite_front, "rotation",
		deg_to_rad(-4.0), 2.0)
	_anim_tween.tween_property(_sprite_front, "rotation",
		deg_to_rad(-1.0), 2.0)


## --- Utilidades ---

func _kill_tweens() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null
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

func get_silhouette_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	
	if _sprite_front and _sprite_front.texture:
		var tex_size := _sprite_front.texture.get_size() * absf(_sprite_front.scale.x)
		var half := tex_size / 2.0
		var inset := half.x * 0.12
		polygon.append(Vector2(-half.x + inset, -half.y))
		polygon.append(Vector2(half.x - inset, -half.y))
		polygon.append(Vector2(half.x, -half.y + inset))
		polygon.append(Vector2(half.x, half.y - inset))
		polygon.append(Vector2(half.x - inset, half.y))
		polygon.append(Vector2(-half.x + inset, half.y))
		polygon.append(Vector2(-half.x, half.y - inset))
		polygon.append(Vector2(-half.x, -half.y + inset))
	else:
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
