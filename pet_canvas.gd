extends Node2D
## pet_canvas.gd — PetCanvas
## Maneja el polígono dinámico de mouse passthrough, el drag-to-move,
## y la visualización del panel de stats y menú contextual.

## Estado interno de arrastre
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## Estado del hover (mouse sobre la mascota)
var _hovering: bool = false

## Estado previo del polígono de passthrough (para optimización)
var _last_passthrough_state: Dictionary = {}

## Referencias a Avatares
@onready var pet_sprite: Node2D = $PetSprite
@onready var aqua_sprite: Node2D = $AquaSprite if has_node("AquaSprite") else null

## Referencia al StatsPanel (hijo)
@onready var stats_panel: Control = $StatsPanel
## Referencia al ContextMenu (hijo)
@onready var context_menu: Control = $ContextMenu
## Referencia al DialogueBubble
@onready var dialogue_bubble: Control = $DialogueBubble
## Referencia al InventoryPanel
@onready var inventory_panel: Control = $InventoryPanel


func _ready() -> void:
	_update_passthrough_polygon()
	print("[PetCanvas] ✅ Polígono de passthrough inicializado.")


func _process(_delta: float) -> void:
	if _is_passthrough_dirty():
		_update_passthrough_polygon()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


## --- Mouse Passthrough ---

## OPTIMIZACIÓN: Solo actualizamos el polígono de passthrough cuando hay cambios reales
## en la geometría del sprite o de la UI. Esto evita llamadas costosas a DisplayServer
## y Geometry2D cada frame (60+ veces por segundo).

## Retorna true si el estado que afecta al polígono de passthrough ha cambiado.
func _is_passthrough_dirty() -> bool:
	var current_state := {
		"pet_visible": is_instance_valid(pet_sprite) and pet_sprite.visible,
		"pet_transform": Transform2D.IDENTITY,
		"pet_frame": 0,
		"aqua_visible": is_instance_valid(aqua_sprite) and aqua_sprite.visible,
		"aqua_transform": Transform2D.IDENTITY,
		"ui": []
	}

	if current_state["pet_visible"]:
		var sprite_node: Sprite2D = pet_sprite.get_sprite_node() if pet_sprite.has_method("get_sprite_node") else null
		if is_instance_valid(sprite_node):
			current_state["pet_transform"] = sprite_node.global_transform
			current_state["pet_frame"] = sprite_node.frame if sprite_node is Sprite2D else 0

	if current_state["aqua_visible"] and is_instance_valid(aqua_sprite):
		current_state["aqua_transform"] = aqua_sprite.global_transform

	for ui in [stats_panel, context_menu, dialogue_bubble, inventory_panel]:
		if is_instance_valid(ui):
			current_state["ui"].append({
				"visible": ui.visible,
				"modulate_a": ui.modulate.a,
				"global_pos": ui.global_position,
				"size": ui.size
			})
		else:
			current_state["ui"].append(null)

	if _last_passthrough_state.is_empty():
		_last_passthrough_state = current_state
		return true

	var dirty := current_state != _last_passthrough_state
	if dirty:
		_last_passthrough_state = current_state
	return dirty


func _update_passthrough_polygon() -> void:
	var combined := PackedVector2Array()

	# Dino polygon (solo si visible)
	if is_instance_valid(pet_sprite) and pet_sprite.visible:
		var polygon: PackedVector2Array = pet_sprite.call("get_silhouette_polygon")
		if polygon.size() > 0:
			var sprite_node: Node = pet_sprite.call("get_sprite_node") if pet_sprite.has_method("get_sprite_node") else null
			var target_node: Node2D = sprite_node as Node2D if sprite_node is Node2D else pet_sprite
			for point in polygon:
				combined.append(target_node.to_global(point))

	# Aqua polygon (solo si visible)
	if is_instance_valid(aqua_sprite) and aqua_sprite.visible and aqua_sprite.has_method("get_silhouette_polygon"):
		var aqua_poly: PackedVector2Array = aqua_sprite.call("get_silhouette_polygon")
		if aqua_poly.size() > 0:
			var target_node: Node2D = aqua_sprite
			if aqua_sprite.has_node("Sprite2D"):
				target_node = aqua_sprite.get_node("Sprite2D")

			var aqua_window_poly := PackedVector2Array()
			for point in aqua_poly:
				aqua_window_poly.append(target_node.to_global(point))

			if combined.size() > 0:
				var merged := Geometry2D.merge_polygons(combined, aqua_window_poly)
				if merged.size() > 0:
					combined = merged[0]
			else:
				combined = aqua_window_poly

	if combined.size() == 0:
		return

	combined = _merge_with_ui_rect(combined, stats_panel)
	combined = _merge_with_ui_rect(combined, context_menu)
	combined = _merge_with_ui_rect(combined, dialogue_bubble)
	combined = _merge_with_ui_rect(combined, inventory_panel)
	DisplayServer.window_set_mouse_passthrough(combined)


func _merge_with_ui_rect(base_polygon: PackedVector2Array, ui_control: Control) -> PackedVector2Array:
	if not is_instance_valid(ui_control) or not ui_control.visible or ui_control.modulate.a < 0.1:
		return base_polygon
	var pos := ui_control.global_position
	var sz := ui_control.size
	var rect_poly := PackedVector2Array([
		pos,
		Vector2(pos.x + sz.x, pos.y),
		Vector2(pos.x + sz.x, pos.y + sz.y),
		Vector2(pos.x, pos.y + sz.y)
	])
	var merged := Geometry2D.merge_polygons(base_polygon, rect_poly)
	if merged.size() > 0:
		return merged[0]
	return base_polygon


## --- Drag-to-Move ---

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Cerrar menú contextual si clic fuera
			if _is_context_menu_open() and not _is_point_on_context_menu(event.position):
				context_menu.hide_menu()
				get_viewport().set_input_as_handled()
				return
			
			# Cerrar inventario si clic fuera
			if _is_inventory_open() and not _is_point_on_inventory(event.position):
				inventory_panel.hide_panel()
				get_viewport().set_input_as_handled()
				return
			
			if _is_point_on_sprite(event.position):
				_dragging = true
				_drag_offset = event.position
				if _is_context_menu_open():
					context_menu.hide_menu()
				if _is_inventory_open():
					inventory_panel.hide_panel()
				get_viewport().set_input_as_handled()
		else:
			_dragging = false
	
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _is_point_on_sprite(event.position):
			_on_right_click(event.position)
			get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Si el menú contextual está abierto, NO mostrar el panel de stats
	if _is_context_menu_open():
		# Solo manejar drag si es necesario
		if _dragging:
			_do_drag(event)
		return
	
	# Detectar hover sobre la mascota para mostrar/ocultar stats
	var on_sprite := _is_point_on_sprite(event.position)
	
	if on_sprite and not _hovering and not _dragging:
		_hovering = true
		_show_stats()
	elif not on_sprite and _hovering and not _dragging:
		# Solo ocultar si el cursor NO está sobre el panel de stats
		# Esto evita el parpadeo cuando el cursor pasa del sprite al panel
		if not _is_point_on_stats_panel(event.position):
			_hovering = false
			_hide_stats()
	
	# Drag-to-move
	if _dragging:
		_do_drag(event)


## Ejecuta el movimiento de arrastre de la ventana.
func _do_drag(event: InputEventMouseMotion) -> void:
	var window := get_window()
	window.position += Vector2i(event.relative)
	
	var main_node := get_parent()
	if main_node.has_method("notify_position_changed"):
		main_node.notify_position_changed(Vector2(window.position))
	
	get_viewport().set_input_as_handled()


## --- Detección de Punto ---

func _is_point_on_sprite(point: Vector2) -> bool:
	# Check Dino (solo si visible)
	if is_instance_valid(pet_sprite) and pet_sprite.visible:
		var local_point := pet_sprite.to_local(point)
		var polygon: PackedVector2Array = pet_sprite.call("get_silhouette_polygon")
		if Geometry2D.is_point_in_polygon(local_point, polygon):
			return true
	# Check Aqua (solo si visible)
	if is_instance_valid(aqua_sprite) and aqua_sprite.visible and aqua_sprite.has_method("get_silhouette_polygon"):
		var local_point := aqua_sprite.to_local(point)
		var polygon: PackedVector2Array = aqua_sprite.call("get_silhouette_polygon")
		if Geometry2D.is_point_in_polygon(local_point, polygon):
			return true
	return false


func _is_point_on_stats_panel(point: Vector2) -> bool:
	if not is_instance_valid(stats_panel) or not stats_panel.visible or stats_panel.modulate.a < 0.1:
		return false
	var panel_rect := Rect2(stats_panel.global_position, stats_panel.size)
	return panel_rect.has_point(point)


func _is_point_on_context_menu(point: Vector2) -> bool:
	if not is_instance_valid(context_menu) or not context_menu.visible or context_menu.modulate.a < 0.1:
		return false
	var menu_rect := Rect2(context_menu.global_position, context_menu.size)
	return menu_rect.has_point(point)


func _is_context_menu_open() -> bool:
	return is_instance_valid(context_menu) and context_menu.is_menu_visible()


func _is_inventory_open() -> bool:
	return is_instance_valid(inventory_panel) and inventory_panel.visible and inventory_panel.modulate.a > 0.1


func _is_point_on_inventory(point: Vector2) -> bool:
	if not _is_inventory_open():
		return false
	var inv_rect := Rect2(inventory_panel.global_position, inventory_panel.size)
	return inv_rect.has_point(point)


## --- Stats Panel ---

func _show_stats() -> void:
	if not is_instance_valid(stats_panel) or not is_instance_valid(pet_sprite):
		return
	# NO mostrar stats si el menú contextual está abierto
	if _is_context_menu_open():
		return
	stats_panel.show_panel(pet_sprite.global_position)


func _hide_stats() -> void:
	if not is_instance_valid(stats_panel):
		return
	stats_panel.hide_panel()


## --- Menú Contextual ---

func _on_right_click(click_pos: Vector2) -> void:
	if not is_instance_valid(context_menu):
		return
	
	# 1. Ocultar panels
	_hovering = false
	_hide_stats()
	if _is_inventory_open():
		inventory_panel.hide_panel()
	
	# 2. Mostrar menú contextual
	context_menu.show_menu(click_pos)
