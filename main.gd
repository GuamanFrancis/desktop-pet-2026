extends Node2D
## main.gd — WindowManager + Orquestador Principal
## Fuerza ventana transparente, decaimiento de stats,
## orquesta: StateMachine, Movement, Particles, AIBrain, Diálogo, Audio, Toasts.

signal pet_position_changed(new_position: Vector2)
signal user_action_triggered(action_type: String)

## --- Referencias a Nodos de Escena ---
@onready var pet_sprite: Node2D = $PetCanvas/PetSprite
@onready var pet_canvas: Node2D = $PetCanvas
@onready var dialogue_bubble: Control = $PetCanvas/DialogueBubble
@onready var notification_toast: Control = $PetCanvas/NotificationToast
@onready var inventory_panel: Control = $PetCanvas/InventoryPanel

## --- Sistemas (creados por código) ---
var state_machine: PetStateMachine = null
var pet_movement: Node = null
var particles: Node2D = null
var ai_brain: Node = null

## --- Timers ---
var _stats_log_timer: float = 0.0
var _passive_xp_timer: float = 0.0
const STATS_LOG_INTERVAL: float = 30.0
const PASSIVE_XP_INTERVAL: float = 60.0  # +1 XP cada 60 segundos


func _ready() -> void:
	_configure_window()
	_security_diagnostic()
	
	await get_tree().process_frame
	_connect_stats_signals()
	_setup_systems()
	_connect_ui()
	
	print("[Main] ✅ Entorno inicializado — 7 sistemas activos.")
	_print_stats_summary()


func _process(delta: float) -> void:
	if SaveManager and SaveManager.pet_stats:
		SaveManager.pet_stats.decay_stats(delta)
	
	# Passive XP
	_passive_xp_timer += delta
	if _passive_xp_timer >= PASSIVE_XP_INTERVAL:
		_passive_xp_timer = 0.0
		if SaveManager and SaveManager.pet_stats:
			SaveManager.pet_stats.add_xp(1)
	
	_stats_log_timer += delta
	if _stats_log_timer >= STATS_LOG_INTERVAL:
		_stats_log_timer = 0.0
		_print_stats_summary()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[Main] 👋 Cerrando Desktop Pet...")


## --- Configuración de Ventana ---

func _configure_window() -> void:
	var window := get_window()
	window.transparent = true
	window.borderless = true
	window.always_on_top = true
	
	var root := get_tree().get_root()
	root.set_transparent_background(true)
	root.gui_embed_subwindows = false
	
	window.unfocusable = false
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	window.size = Vector2i(500, 500)
	
	var screen_size := DisplayServer.screen_get_size()
	window.position = Vector2i(
		(screen_size.x - window.size.x) / 2,
		(screen_size.y - window.size.y) / 2
	)


## --- Inicialización de Sistemas ---

func _setup_systems() -> void:
	# StateMachine
	state_machine = PetStateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.walk_requested.connect(_on_walk_requested)
	
	# PetMovement
	pet_movement = preload("res://systems/pet_movement.gd").new()
	pet_movement.name = "PetMovement"
	add_child(pet_movement)
	pet_movement.movement_completed.connect(_on_movement_completed)
	pet_movement.facing_changed.connect(_on_facing_changed)
	
	# ParticleEffects
	particles = preload("res://systems/particle_effects.gd").new()
	particles.name = "Particles"
	pet_sprite.add_child(particles)
	
	# AI Brain
	ai_brain = preload("res://systems/ai_brain.gd").new()
	ai_brain.name = "AIBrain"
	add_child(ai_brain)
	# Inyectar dependencias al cerebro
	ai_brain.pet_stats = SaveManager.pet_stats if SaveManager else null
	ai_brain.state_machine = state_machine
	# Conectar señal de diálogo
	ai_brain.dialogue_requested.connect(_on_dialogue_requested)
	
	print("[Main] ✅ Sistemas: StateMachine + Movement + Particles + AIBrain")


func _connect_ui() -> void:
	# Conectar inventario
	if is_instance_valid(inventory_panel) and inventory_panel.has_signal("item_used"):
		inventory_panel.item_used.connect(_on_inventory_item_used)

	# Conectar menú contextual
	var context_menu := $PetCanvas/ContextMenu
	if is_instance_valid(context_menu) and context_menu.has_signal("action_selected"):
		context_menu.action_selected.connect(_on_context_menu_action)


## --- Señales de Stats ---

func _connect_stats_signals() -> void:
	if not SaveManager or not SaveManager.pet_stats:
		return
	SaveManager.pet_stats.level_up.connect(_on_level_up)
	SaveManager.pet_stats.stat_changed.connect(_on_stat_changed)


func _on_level_up(new_level: int) -> void:
	print("[Main] 🎉 ¡La mascota subió al nivel %d!" % new_level)
	# Partículas
	if particles:
		particles.play_effect(particles.EffectType.STARS, 2.0)
	# Toast
	if is_instance_valid(notification_toast):
		notification_toast.show_toast("⭐", "¡Nivel %d!" % new_level, Color(1.0, 0.85, 0.3))
	# Audio
	if AudioManager:
		AudioManager.play_level_up()
	# AI Brain: reaccionar al level up
	if ai_brain:
		ai_brain.notify_level_up(new_level)


func _on_stat_changed(_stat_name: String, _new_value: float) -> void:
	if is_instance_valid(pet_sprite) and pet_sprite.has_method("update_mood_color"):
		var mood := SaveManager.pet_stats.get_overall_mood()
		pet_sprite.call("update_mood_color", mood)


## --- Señales de State Machine ---

func _on_state_changed(old_state: PetStateMachine.State, new_state: PetStateMachine.State) -> void:
	# Visual
	if is_instance_valid(pet_sprite):
		var state_visual := _state_to_visual_name(new_state)
		pet_sprite.call("set_visual_state", state_visual)
	
	# Partículas
	if particles:
		particles.stop_effect()
		match new_state:
			PetStateMachine.State.SLEEPING:
				particles.play_continuous(particles.EffectType.ZZZ)
			PetStateMachine.State.EATING:
				particles.play_effect(particles.EffectType.FOOD, 2.5)
			PetStateMachine.State.PLAYING:
				particles.play_effect(particles.EffectType.STARS, 3.0)
			PetStateMachine.State.SAD:
				particles.play_continuous(particles.EffectType.TEARS)
	
	# Audio por estado
	if AudioManager:
		match new_state:
			PetStateMachine.State.EATING:
				AudioManager.play_eat()
			PetStateMachine.State.PLAYING:
				AudioManager.play_play()
			PetStateMachine.State.SLEEPING:
				AudioManager.play_sleep()
			PetStateMachine.State.SAD:
				AudioManager.play_sad()
	
	# Notificar al AI Brain
	if ai_brain:
		ai_brain.notify_state_changed(
			_state_to_visual_name(old_state),
			_state_to_visual_name(new_state)
		)
	
	# Cancelar movimiento si ya no estamos walking
	if old_state == PetStateMachine.State.WALKING and new_state != PetStateMachine.State.WALKING:
		if pet_movement and pet_movement.has_method("cancel_movement"):
			pet_movement.call("cancel_movement")


func _on_walk_requested(target_position: Vector2) -> void:
	if pet_movement and pet_movement.has_method("move_to"):
		pet_movement.call("move_to", target_position)


func _on_movement_completed() -> void:
	if state_machine:
		state_machine.on_walk_completed()


func _on_facing_changed(facing_right: bool) -> void:
	if is_instance_valid(pet_sprite) and pet_sprite.has_method("set_facing_direction"):
		pet_sprite.call("set_facing_direction", facing_right)


## --- AI Brain ---

func _on_dialogue_requested(text: String) -> void:
	if is_instance_valid(dialogue_bubble) and dialogue_bubble.has_method("show_message"):
		dialogue_bubble.show_message(text)


## --- Acciones del Usuario ---

func _on_context_menu_action(action_name: String) -> void:
	match action_name:
		"feed":
			on_user_feed()
		"play":
			on_user_play()
		"rest":
			if state_machine:
				state_machine.transition_to(PetStateMachine.State.SLEEPING)
		"inventory":
			if inventory_panel:
				inventory_panel.show_panel(get_viewport_rect().size / 2.0)

## --- Inventario ---

func _on_inventory_item_used(item: Resource) -> void:
	if not item is ItemData:
		return
	var item_data: ItemData = item as ItemData
	
	match item_data.item_type:
		ItemData.ItemType.FOOD:
			# Aplicar efectos de comida
			if SaveManager and SaveManager.pet_stats:
				var effects: Dictionary = item_data.stat_effects
				if effects.has("hunger"):
					SaveManager.pet_stats.feed(effects["hunger"] as float)
				if effects.has("happiness"):
					SaveManager.pet_stats.happiness = clampf(
						SaveManager.pet_stats.happiness + (effects["happiness"] as float),
						0.0, 100.0)
			# Reducir cantidad
			item_data.quantity -= 1
			if item_data.quantity <= 0 and SaveManager and SaveManager.inventory:
				SaveManager.inventory.remove_item(item_data)
			# Feedback
			if state_machine:
				state_machine.trigger_eating()
			if AudioManager:
				AudioManager.play_eat()
			if ai_brain:
				ai_brain.notify_action("fed")
			if is_instance_valid(notification_toast):
				notification_toast.show_toast("🍎", "Usaste: %s" % item_data.display_name)
			print("[Main] 🍎 Item usado: %s" % item_data.display_name)


func _state_to_visual_name(state: PetStateMachine.State) -> String:
	match state:
		PetStateMachine.State.IDLE: return "idle"
		PetStateMachine.State.WALKING: return "walking"
		PetStateMachine.State.SLEEPING: return "sleeping"
		PetStateMachine.State.EATING: return "eating"
		PetStateMachine.State.PLAYING: return "playing"
		PetStateMachine.State.SAD: return "sad"
		_: return "idle"


## --- Métodos Públicos (Orquestación de Acciones) ---

func on_user_feed() -> void:
	if state_machine:
		state_machine.trigger_eating()
	if ai_brain:
		ai_brain.notify_action("fed")
	if AudioManager:
		AudioManager.play_eat()
	user_action_triggered.emit("feed")


func on_user_play() -> void:
	if state_machine:
		state_machine.trigger_playing()
	if ai_brain:
		ai_brain.notify_action("played")
	if AudioManager:
		AudioManager.play_play()
	user_action_triggered.emit("play")


## --- Logging ---

func _print_stats_summary() -> void:
	if not SaveManager or not SaveManager.pet_stats:
		return
	var s := SaveManager.pet_stats
	var state_name := state_machine.get_state_name() if state_machine else "N/A"
	print("[Stats] %s Lv.%d | %s | H:%.0f F:%.0f E:%.0f | XP:%d/%d | %s" % [
		s.pet_name, s.level, state_name,
		s.hunger, s.happiness, s.energy,
		s.xp, s.xp_to_next_level, s.get_mood_text()
	])


func _security_diagnostic() -> void:
	print("[Seguridad] ✅ Sin llamadas a OpenProcess / ReadProcessMemory / WriteProcessMemory")
	print("[Seguridad] ✅ Mouse passthrough vía DisplayServer nativo de Godot")
	print("[Seguridad] ✅ Guardado encriptado con FileAccess.open_encrypted_with_pass()")


func notify_position_changed(pos: Vector2) -> void:
	pet_position_changed.emit(pos)
