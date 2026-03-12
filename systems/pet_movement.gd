extends Node
## pet_movement.gd — Sistema de Movimiento Suave
## Mueve la ventana por la pantalla usando curvas de Bézier con easing natural.
## Cumple con §3 del doc de arquitectura: movimiento biomecánico, no lineal.

## --- Señales ---
signal movement_completed()
signal facing_changed(facing_right: bool)

## --- Estado ---
var _is_moving: bool = false
var _move_progress: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
var _move_duration: float = 0.0

## Puntos de la curva de Bézier cúbica
var _p0: Vector2 = Vector2.ZERO  # Inicio
var _p1: Vector2 = Vector2.ZERO  # Control 1
var _p2: Vector2 = Vector2.ZERO  # Control 2
var _p3: Vector2 = Vector2.ZERO  # Destino

## Referencia a la ventana
var _window: Window = null

## --- Configuración ---
## Ley de Fitts: T = a + b * log2(D/W + 1)
const FITTS_A: float = 0.4     # Constante base (tiempo mínimo)
const FITTS_B: float = 0.25    # Factor de escala
const MIN_DURATION: float = 1.5
const MAX_DURATION: float = 4.0
## Micro-ajustes estocásticos para biomecánica
const NOISE_AMPLITUDE: float = 3.0  # Píxeles de desviación aleatoria
const NOISE_FREQUENCY: float = 4.0  # Oscilaciones por trayecto


func _ready() -> void:
	_window = get_window()
	print("[PetMovement] ✅ Sistema de movimiento inicializado.")


func _process(delta: float) -> void:
	if not _is_moving:
		return
	
	# Avanzar progreso
	_move_progress += delta / _move_duration
	_move_progress = clampf(_move_progress, 0.0, 1.0)
	
	# Easing: ease-in-out cúbico para arranque y frenado natural
	var t := _ease_in_out_cubic(_move_progress)
	
	# Posición sobre la curva de Bézier
	var bezier_pos := _cubic_bezier(t, _p0, _p1, _p2, _p3)
	
	# Micro-ajustes estocásticos (jitter biomecánico)
	# Solo en la parte central del movimiento, no al inicio/final
	var jitter_factor := sin(t * PI)  # 0 en extremos, 1 en el medio
	var noise_x := sin(t * NOISE_FREQUENCY * TAU) * NOISE_AMPLITUDE * jitter_factor
	var noise_y := cos(t * NOISE_FREQUENCY * TAU * 0.7) * NOISE_AMPLITUDE * 0.5 * jitter_factor
	
	bezier_pos += Vector2(noise_x, noise_y)
	
	# Aplicar posición a la ventana
	if _window:
		_window.position = Vector2i(bezier_pos)
		# Update facing direction based on movement
		_update_facing(bezier_pos)
	
	# ¿Terminó?
	if _move_progress >= 1.0:
		_is_moving = false
		movement_completed.emit()
		print("[PetMovement] ✅ Llegó al destino.")


## --- API Pública ---

## Inicia un movimiento suave hacia la posición destino.
func move_to(target: Vector2) -> void:
	if not _window:
		_window = get_window()
	
	_p0 = Vector2(_window.position)
	_p3 = target
	
	# Generar puntos de control de Bézier (curva natural, no recta)
	var distance := _p0.distance_to(_p3)
	var direction := (_p3 - _p0).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	
	# Control points: desviación lateral aleatoria para curva orgánica
	var lateral_offset := randf_range(-distance * 0.3, distance * 0.3)
	_p1 = _p0 + direction * distance * 0.3 + perpendicular * lateral_offset
	_p2 = _p0 + direction * distance * 0.7 + perpendicular * lateral_offset * -0.5
	
	# Duración basada en Ley de Fitts
	_move_duration = _calculate_fitts_duration(distance)
	_move_progress = 0.0
	_is_moving = true
	
	print("[PetMovement] 🚶 Moviendo: %.0f px en %.1f seg" % [distance, _move_duration])


## Cancela el movimiento actual.
func cancel_movement() -> void:
	_is_moving = false
	_move_progress = 0.0


## Retorna true si está en movimiento.
func is_moving() -> bool:
	return _is_moving


## --- Matemáticas ---

## Curva de Bézier cúbica: B(t) = (1-t)³P0 + 3(1-t)²tP1 + 3(1-t)t²P2 + t³P3
func _cubic_bezier(t: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> Vector2:
	var u := 1.0 - t
	var tt := t * t
	var uu := u * u
	var uuu := uu * u
	var ttt := tt * t
	
	return uuu * p0 + 3.0 * uu * t * p1 + 3.0 * u * tt * p2 + ttt * p3


## Easing cúbico in-out: arranque suave → velocidad → frenado suave
func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	else:
		var f := (2.0 * t - 2.0)
		return 0.5 * f * f * f + 1.0


## Ley de Fitts: T = a + b * log2(D/W + 1)
## D = distancia, W = tamaño del objetivo (ancho de la mascota)
func _calculate_fitts_duration(distance: float) -> float:
	var w := 100.0
	var duration := FITTS_A + FITTS_B * log(distance / w + 1.0) / log(2.0)
	return clampf(duration, MIN_DURATION, MAX_DURATION)


func _update_facing(current_pos: Vector2) -> void:
	if _prev_pos != Vector2.ZERO:
		var dx := current_pos.x - _prev_pos.x
		if absf(dx) > 0.5:  # Threshold to avoid jitter
			facing_changed.emit(dx > 0)
	_prev_pos = current_pos
