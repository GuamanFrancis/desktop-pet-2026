class_name PetStateMachine
extends Node
## pet_state_machine.gd — Máquina de Estados Finita
## Gobierna el comportamiento autónomo de la mascota basado en sus stats.

## --- Estados ---
enum State {
	IDLE,      ## Reposo: bobbing suave, mira al cursor
	WALKING,   ## Caminando: se mueve a una posición aleatoria
	SLEEPING,  ## Durmiendo: ojos cerrados, recupera energía
	EATING,    ## Comiendo: animación de masticar
	PLAYING,   ## Jugando: rebote enérgico
	SAD        ## Triste: movimiento lento, color gris
}

## --- Señales ---
signal state_changed(old_state: State, new_state: State)
signal walk_requested(target_position: Vector2)
signal action_finished()

## --- Estado Actual ---
var current_state: State = State.IDLE
var _previous_state: State = State.IDLE

## --- Timers Internos ---
var _state_timer: float = 0.0        # Tiempo en estado actual
var _idle_walk_timer: float = 0.0     # Countdown para caminar
var _action_duration: float = 0.0     # Duración de acciones temporales
var _action_timer: float = 0.0       # Timer de acción actual

## --- Configuración ---
const SLEEP_THRESHOLD: float = 20.0       # Energía para dormirse
const WAKE_THRESHOLD: float = 60.0        # Energía para despertarse
const SAD_THRESHOLD: float = 25.0         # Felicidad para ponerse triste
const HAPPY_THRESHOLD: float = 50.0       # Felicidad para dejar de estar triste
const WALK_MIN_INTERVAL: float = 8.0      # Mínimo entre caminatas
const WALK_MAX_INTERVAL: float = 20.0     # Máximo entre caminatas
const EATING_DURATION: float = 2.5        # Duración de comer
const PLAYING_DURATION: float = 3.0       # Duración de jugar
const ENERGY_RECOVERY_RATE: float = 0.15  # Energía/seg al dormir


func _ready() -> void:
	_randomize_walk_timer()
	print("[StateMachine] ✅ Máquina de estados inicializada. Estado: IDLE")


func _process(delta: float) -> void:
	_state_timer += delta
	
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WALKING:
			_process_walking(delta)
		State.SLEEPING:
			_process_sleeping(delta)
		State.EATING:
			_process_eating(delta)
		State.PLAYING:
			_process_playing(delta)
		State.SAD:
			_process_sad(delta)


## --- Procesamiento por Estado ---

func _process_idle(delta: float) -> void:
	var stats := _get_stats()
	if not stats:
		return
	
	# Verificar transiciones automáticas por prioridad
	if stats.energy < SLEEP_THRESHOLD:
		transition_to(State.SLEEPING)
		return
	
	if stats.happiness < SAD_THRESHOLD:
		transition_to(State.SAD)
		return
	
	# Timer para caminar aleatoriamente
	_idle_walk_timer -= delta
	if _idle_walk_timer <= 0.0:
		_start_walking()


func _process_walking(_delta: float) -> void:
	# El movimiento real lo maneja PetMovement
	# Aquí solo verificamos si hay emergencias
	var stats := _get_stats()
	if stats and stats.energy < SLEEP_THRESHOLD * 0.5:
		transition_to(State.SLEEPING)


func _process_sleeping(delta: float) -> void:
	var stats := _get_stats()
	if not stats:
		return
	
	# Recuperar energía mientras duerme
	stats.rest(ENERGY_RECOVERY_RATE * delta)
	
	# Despertar cuando tiene suficiente energía
	if stats.energy >= WAKE_THRESHOLD:
		transition_to(State.IDLE)
		print("[StateMachine] 😊 ¡La mascota se despertó descansada!")


func _process_eating(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= _action_duration:
		transition_to(State.IDLE)
		action_finished.emit()


func _process_playing(delta: float) -> void:
	_action_timer += delta
	if _action_timer >= _action_duration:
		transition_to(State.IDLE)
		action_finished.emit()


func _process_sad(_delta: float) -> void:
	var stats := _get_stats()
	if not stats:
		return
	
	# Salir de tristeza si la felicidad sube
	if stats.happiness >= HAPPY_THRESHOLD:
		transition_to(State.IDLE)
		print("[StateMachine] 😊 ¡La mascota se siente mejor!")


## --- Transiciones ---

## Cambia al nuevo estado, emitiendo la señal correspondiente.
func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	
	_previous_state = current_state
	current_state = new_state
	_state_timer = 0.0
	_action_timer = 0.0
	
	# Configurar nuevo estado
	match new_state:
		State.IDLE:
			_randomize_walk_timer()
		State.EATING:
			_action_duration = EATING_DURATION
		State.PLAYING:
			_action_duration = PLAYING_DURATION
		State.SLEEPING:
			print("[StateMachine] 😴 La mascota se quedó dormida (energía baja)")
		State.SAD:
			print("[StateMachine] 😢 La mascota está triste (felicidad baja)")
	
	state_changed.emit(_previous_state, new_state)
	print("[StateMachine] %s → %s" % [State.keys()[_previous_state], State.keys()[new_state]])


## --- Acciones del Usuario ---

## Llamado cuando el usuario alimenta a la mascota.
func trigger_eating() -> void:
	if current_state == State.SLEEPING:
		return  # No interrumpir el sueño
	transition_to(State.EATING)


## Llamado cuando el usuario juega con la mascota.
func trigger_playing() -> void:
	if current_state == State.SLEEPING:
		return
	transition_to(State.PLAYING)


## Llamado cuando la mascota termina de caminar (desde PetMovement).
func on_walk_completed() -> void:
	if current_state == State.WALKING:
		transition_to(State.IDLE)


## --- Utilidades ---

func _start_walking() -> void:
	transition_to(State.WALKING)
	
	# Generar posición aleatoria en la pantalla
	var screen_size := DisplayServer.screen_get_size()
	var margin := 80
	var target := Vector2(
		randf_range(margin, screen_size.x - margin),
		randf_range(margin, screen_size.y - margin)
	)
	walk_requested.emit(target)


func _randomize_walk_timer() -> void:
	_idle_walk_timer = randf_range(WALK_MIN_INTERVAL, WALK_MAX_INTERVAL)


func _get_stats() -> PetStats:
	if SaveManager and SaveManager.pet_stats:
		return SaveManager.pet_stats
	return null


## Retorna el nombre legible del estado actual.
func get_state_name() -> String:
	return State.keys()[current_state]


## Retorna true si la mascota puede ser interrumpida por el usuario.
func can_interact() -> bool:
	return current_state != State.SLEEPING or _state_timer > 2.0
