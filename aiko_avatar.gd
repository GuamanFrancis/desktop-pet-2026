extends Node2D
## aiko_avatar.gd — Controlador de Avatar para Aiko (Secuencia PNG)
## Este script reemplaza el comportamiento base del dinosaurio.
## Escucha la máquina de estados y reproduce animaciones usando AnimationPlayer.
## Permite cambiar texturas a voluntad (ej. de ropa/uniformes) si las configuras en las pistas.

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

## --- Controladores Visuales ---
var _current_state: String = "idle"
var _facing_right: bool = true

## --- Caché de Polígonos de Click-Through ---
# Se utiliza para guardar el polígono generado para evitar recalcular
# BitMaps pesados (ej. imágenes grandes de anime HD) en cada frame.
var _cached_polygons: Dictionary = {}


func _ready() -> void:
	print("[AikoAvatar] 🌸 Inicializando Avatar Secundario: Aiko")
	set_visual_state("idle")


## --- Conexión con PetStateMachine ---
## Se asume que Main o la StateMachine llaman a esta función
## enviando el estado actual (e.g. "idle", "walking", "mischief_steal")
func set_visual_state(new_state: String) -> void:
	if new_state == _current_state:
		return
	_current_state = new_state

	# Mapeo de estados de StateMachine a nombres de animación en el AnimationPlayer
	# Si la animación existe en el AnimationPlayer, la reproduce.
	# Si no, intenta un fallback o usa la animación default.
	match new_state:
		"idle", "walking", "sleeping", "eating", "playing", "sad":
			if anim_player.has_animation(new_state):
				anim_player.play(new_state)
			else:
				anim_player.play("idle")

		# --- Travesuras (Mischief) ---
		"mischief_steal":
			if anim_player.has_animation("steal"):
				anim_player.play("steal")
			elif anim_player.has_animation("walking"):
				anim_player.play("walking") # Fallback si no hay anim de robo
			else:
				anim_player.play("idle")
		"mischief_scare":
			if anim_player.has_animation("scare"):
				anim_player.play("scare")
			else:
				_play_shake_fallback()
		"mischief_block":
			if anim_player.has_animation("sit"):
				anim_player.play("sit")
			else:
				anim_player.play("idle")
		"mischief_drop":
			if anim_player.has_animation("throw"):
				anim_player.play("throw")
			else:
				_play_bounce_fallback()
		"mischief_tremor":
			if anim_player.has_animation("tremor"):
				anim_player.play("tremor")
			else:
				anim_player.play("sad")

		_:
			anim_player.play("idle")


## --- Fallbacks de Animación procedimental ---
## (Si falta algún Sprite específico para las travesuras, la animamos por código)

func _play_shake_fallback() -> void:
	anim_player.play("idle") # Reproducir idle pero temblando por código
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.1)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.2)


func _play_bounce_fallback() -> void:
	anim_player.play("idle")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", -30.0, 0.2)
	tween.tween_property(sprite, "position:y", 0.0, 0.2)


## --- Dirección y Color ---

func set_facing_direction(right: bool) -> void:
	_facing_right = right
	# Si Aiko está dibujada mirando a la izquierda por defecto,
	# debes invertir este cálculo (ej. scale.x = -abs(scale.x) if right else abs(scale.x))
	if sprite:
		var current_scale_x := absf(sprite.scale.x)
		sprite.scale.x = current_scale_x if right else -current_scale_x


func update_mood_color(mood: float) -> void:
	var brightness := lerpf(0.65, 1.0, clampf(mood, 0.0, 1.0))
	if sprite:
		sprite.modulate = Color(brightness, brightness, brightness, sprite.modulate.a)


## --- Polígono de Silueta (Hitbox Transparente Dinámica) ---
## Crucial para que el usuario pueda hacer clic A TRAVÉS de Aiko en el escritorio.

func get_silhouette_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()

	if sprite and sprite.texture:
		var tex := sprite.texture

		# Clave para caché: usamos el nombre o path de la textura + el frame actual
		# Si Aiko no es un SpriteSheet (hframes=1) sino secuencias de PNGs que cambian en AnimationPlayer,
		# la textura misma es la que cambia.
		var cache_key := str(tex.resource_path) + "_" + str(sprite.frame)

		if _cached_polygons.has(cache_key):
			var base_poly: PackedVector2Array = _cached_polygons[cache_key]
			var scale_x := absf(sprite.scale.x)
			var scale_y := absf(sprite.scale.y)

			var half_width := (tex.get_width() / sprite.hframes) / 2.0
			var half_height := (tex.get_height() / sprite.vframes) / 2.0

			for pt in base_poly:
				# Centrar el punto y escalarlo
				var centered_pt := Vector2(pt.x - half_width, pt.y - half_height)
				var final_pt := Vector2(centered_pt.x * scale_x, centered_pt.y * scale_y)
				if not _facing_right:
					final_pt.x = -final_pt.x
				polygon.append(final_pt)
			return polygon

		# Si no está en caché, generar el BitMap y extraer el polígono
		var hframes := sprite.hframes
		var vframes := sprite.vframes

		var frame := sprite.frame
		var frame_width := tex.get_width() / hframes
		var frame_height := tex.get_height() / vframes
		var frame_x := (frame % hframes) * frame_width
		var frame_y := (frame / hframes) * frame_height
		var frame_rect := Rect2i(frame_x, frame_y, frame_width, frame_height)

		var img := tex.get_image()
		if not img:
			return _get_fallback_polygon()

		var frame_img := img.get_region(frame_rect)

		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(frame_img)

		# Tolerancia de alfa (1.0 = completamente opaco).
		# Si las imágenes de Aiko tienen bordes suaves o semitransparentes, puedes bajar a 0.5.
		var polygons := bitmap.opaque_to_polygons(Rect2(0, 0, frame_width, frame_height), 0.5)

		if polygons.size() > 0:
			var base_poly: PackedVector2Array = polygons[0]
			_cached_polygons[cache_key] = base_poly # Guardar en caché

			var scale_x := absf(sprite.scale.x)
			var scale_y := absf(sprite.scale.y)
			var half_width := frame_width / 2.0
			var half_height := frame_height / 2.0

			for pt in base_poly:
				var centered_pt := Vector2(pt.x - half_width, pt.y - half_height)
				var final_pt := Vector2(centered_pt.x * scale_x, centered_pt.y * scale_y)
				if not _facing_right:
					final_pt.x = -final_pt.x
				polygon.append(final_pt)
			return polygon

	return _get_fallback_polygon()


func _get_fallback_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	# Círculo de fallback grande si algo sale mal
	for i in range(16):
		var angle := (float(i) / 16.0) * TAU
		polygon.append(Vector2(cos(angle) * 80, sin(angle) * 150)) # Aiko es más alta que el Dino, el fallback es un óvalo
	return polygon
