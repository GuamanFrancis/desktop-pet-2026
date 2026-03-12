extends Control
## context_menu.gd — Menú Contextual (Clic Derecho)
## Menú radial/lista para interactuar con la mascota:
## alimentar, jugar, descansar, ver inventario, salir.

## --- Señales ---
signal action_selected(action_name: String)

## --- Configuración Visual ---
const MENU_WIDTH: float = 160.0
const ITEM_HEIGHT: float = 32.0
const MENU_PADDING: float = 6.0
const FONT_SIZE: int = 12
const CORNER_RADIUS: float = 8.0

## Colores
const COLOR_BG: Color = Color(0.12, 0.11, 0.18, 0.95)
const COLOR_HOVER: Color = Color(0.5, 0.38, 0.85, 0.3)
const COLOR_TEXT: Color = Color(0.88, 0.85, 0.95)
const COLOR_TEXT_HOVER: Color = Color(1.0, 0.95, 1.0)
const COLOR_ACCENT: Color = Color(0.55, 0.4, 0.95, 1.0)
const COLOR_SEPARATOR: Color = Color(0.3, 0.28, 0.42, 0.4)
const COLOR_DANGER: Color = Color(0.9, 0.3, 0.25)

## Ítems del menú: [emoji, texto, action_name, es_peligroso]
var _menu_items: Array = [
	["🍎", "Alimentar", "feed", false],
	["🎮", "Jugar", "play", false],
	["💤", "Descansar", "rest", false],
	["", "", "separator", false],
	["📦", "Inventario", "inventory", false],
	["📊", "Stats", "stats", false],
	["", "", "separator", false],
	["❌", "Cerrar App", "quit", true],
]

## Estado
var _is_showing: bool = false
var _hovered_index: int = -1
var _fade_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	visible = false
	
	var total_h := MENU_PADDING * 2.0
	for item_idx in range(_menu_items.size()):
		var item: Array = _menu_items[item_idx]
		if item[2] == "separator":
			total_h += 8.0
		else:
			total_h += ITEM_HEIGHT
	
	custom_minimum_size = Vector2(MENU_WIDTH, total_h)
	size = Vector2(MENU_WIDTH, total_h)
	
	print("[ContextMenu] ✅ Menú contextual inicializado.")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hover := _get_item_at_position(event.position)
		if new_hover != _hovered_index:
			_hovered_index = new_hover
			queue_redraw()
	
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _hovered_index >= 0:
				var item: Array = _menu_items[_hovered_index]
				var action_name: String = str(item[2])
				if action_name != "separator":
					_execute_action(action_name)
					# Solo cerrar el menú si es "quit"; las demás acciones se mantienen
					if action_name == "quit":
						hide_menu()
					else:
						# Flash visual: redibuja para dar feedback
						queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			hide_menu()


func _draw() -> void:
	# Fondo
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.35, 0.6, 0.2), false, 1.0)
	
	# Línea de acento superior
	draw_rect(Rect2(0, 0, size.x, 2), COLOR_ACCENT, true)
	
	var y := MENU_PADDING
	
	for i in range(_menu_items.size()):
		var item: Array = _menu_items[i]
		var action: String = str(item[2])
		
		if action == "separator":
			# Línea separadora
			y += 2.0
			draw_line(
				Vector2(MENU_PADDING + 8.0, y + 2.0),
				Vector2(size.x - MENU_PADDING - 8.0, y + 2.0),
				COLOR_SEPARATOR, 1.0
			)
			y += 8.0
			continue
		
		var item_rect := Rect2(MENU_PADDING, y, size.x - MENU_PADDING * 2.0, ITEM_HEIGHT)
		
		# Highlight de hover
		if i == _hovered_index:
			draw_rect(item_rect, COLOR_HOVER, true)
		
		# Emoji
		var emoji: String = str(item[0])
		var text: String = str(item[1])
		var is_danger: bool = bool(item[3])
		
		var text_color := COLOR_DANGER if is_danger else (COLOR_TEXT_HOVER if i == _hovered_index else COLOR_TEXT)
		
		# Emoji + texto
		var full_text := "%s  %s" % [emoji, text]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(MENU_PADDING + 10.0, y + ITEM_HEIGHT / 2.0 + FONT_SIZE / 2.0 - 1.0),
			full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_color
		)
		
		y += ITEM_HEIGHT


## Determina qué ítem está bajo la posición del mouse.
func _get_item_at_position(pos: Vector2) -> int:
	var y := MENU_PADDING
	
	for i in range(_menu_items.size()):
		var item: Array = _menu_items[i]
		
		if str(item[2]) == "separator":
			y += 8.0
			continue
		
		var item_rect := Rect2(0, y, size.x, ITEM_HEIGHT)
		if item_rect.has_point(pos):
			return i
		
		y += ITEM_HEIGHT
	
	return -1


## Ejecuta la acción seleccionada.
func _execute_action(action_name: String) -> void:
	if not SaveManager or not SaveManager.pet_stats:
		return
	
	# Audio feedback
	if AudioManager:
		AudioManager.play_click()
	
	var stats := SaveManager.pet_stats
	var inv := SaveManager.inventory
	
	match action_name:
		"feed":
			var foods := inv.get_items_by_type(ItemData.ItemType.FOOD)
			if foods.size() > 0:
				inv.use_item(foods[0], stats)
				print("[Menú] 🍎 Alimentada con '%s' del inventario" % foods[0].display_name)
			else:
				stats.feed(5.0)
				print("[Menú] 🍎 Alimentada (sin ítems, ración básica)")
			# Trigger estado de comer en la máquina de estados
			_notify_main("on_user_feed")
		"play":
			stats.play(15.0)
			stats.add_xp(10)
			print("[Menú] 🎮 ¡Jugó con la mascota! +10 XP")
			_notify_main("on_user_play")
		"rest":
			stats.rest(20.0)
			print("[Menú] 💤 La mascota descansó.")
		"inventory":
			_print_inventory()
			# Abrir panel visual de inventario
			var inv_panel := get_parent().get_node_or_null("InventoryPanel")
			if inv_panel and inv_panel.has_method("show_panel"):
				var viewport_center := get_viewport_rect().size / 2.0
				inv_panel.call("show_panel", viewport_center)
		"stats":
			_print_detailed_stats()
		"quit":
			print("[Menú] ❌ Cerrando aplicación...")
			SaveManager.save_game()
			get_tree().quit()
	
	action_selected.emit(action_name)


## Notifica al nodo Main para que active la transición de estado correspondiente.
func _notify_main(method_name: String) -> void:
	# Subir por el árbol: ContextMenu → PetCanvas → Main
	var main_node := get_parent()
	if main_node:
		main_node = main_node.get_parent()
	if main_node and main_node.has_method(method_name):
		main_node.call(method_name)


func _print_inventory() -> void:
	var inv := SaveManager.inventory
	print("═══════════════════════════════")
	print("[Inventario] 📦 Total: %d ítems" % inv.get_total_item_count())
	for item in inv.items:
		var qty := " x%d" % item.quantity if item.stackable else ""
		print("  • %s%s (%s)" % [item.display_name, qty, ItemData.ItemType.keys()[item.item_type]])
	if inv.items.size() == 0:
		print("  (vacío)")
	print("═══════════════════════════════")


func _print_detailed_stats() -> void:
	var s := SaveManager.pet_stats
	print("═══════════════════════════════")
	print("[Stats] 📊 %s — Nivel %d" % [s.pet_name, s.level])
	print("  XP: %d / %d" % [s.xp, s.xp_to_next_level])
	print("  Hambre:    %.1f / 100" % s.hunger)
	print("  Felicidad: %.1f / 100" % s.happiness)
	print("  Energía:   %.1f / 100" % s.energy)
	print("  Ánimo:     %s (%.0f%%)" % [s.get_mood_text(), s.get_overall_mood() * 100])
	print("═══════════════════════════════")


## --- Mostrar / Ocultar ---

func show_menu(at_position: Vector2) -> void:
	if _is_showing:
		hide_menu()
		return
	
	_is_showing = true
	visible = true
	_hovered_index = -1
	
	# Posicionar cerca del clic
	position = at_position
	
	# Asegurar que no se salga de la ventana
	var vp_size := get_viewport_rect().size
	if position.x + size.x > vp_size.x:
		position.x = vp_size.x - size.x - 5.0
	if position.y + size.y > vp_size.y:
		position.y = vp_size.y - size.y - 5.0
	position.x = maxf(position.x, 5.0)
	position.y = maxf(position.y, 5.0)
	
	# Fade in + scale
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	scale = Vector2(0.9, 0.9)
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_fade_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	
	queue_redraw()


func hide_menu() -> void:
	if not _is_showing:
		return
	_is_showing = false
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.1)
	_fade_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	_fade_tween.chain().tween_callback(func(): visible = false)


func is_menu_visible() -> bool:
	return _is_showing
