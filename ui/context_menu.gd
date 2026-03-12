extends Control
## context_menu.gd — Menú Contextual (Clic Derecho) - Versión Premium
## Menú con diseño glassmorphism, animaciones fluidas y organización lógica.

## --- Señales ---
signal action_selected(action_name: String)

## --- Configuración Visual (Premium UI) ---
const MENU_WIDTH: float = 180.0
const ITEM_HEIGHT: float = 36.0
const MENU_PADDING: float = 8.0
const HEADER_HEIGHT: float = 24.0
const FONT_SIZE: int = 12
const FONT_SIZE_SMALL: int = 10
const CORNER_RADIUS: float = 12.0

## Colores Glassmorphism
const COLOR_BG_TOP: Color = Color(0.12, 0.1, 0.2, 0.94)
const COLOR_BG_BOTTOM: Color = Color(0.08, 0.07, 0.12, 0.94)
const COLOR_BORDER: Color = Color(0.4, 0.35, 0.6, 0.3)
const COLOR_ACCENT: Color = Color(0.55, 0.4, 0.95, 1.0)
const COLOR_ACCENT_GLOW: Color = Color(0.6, 0.45, 1.0, 0.3)

const COLOR_HOVER: Color = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_TEXT: Color = Color(0.88, 0.85, 0.95)
const COLOR_TEXT_DIM: Color = Color(0.5, 0.48, 0.65)
const COLOR_TEXT_HOVER: Color = Color(1.0, 1.0, 1.0)
const COLOR_DANGER: Color = Color(0.95, 0.35, 0.3)

## Tipos de Item
enum ItemType { ACTION, SEPARATOR, HEADER }

## Ítems del menú estructurados para UX profesional
var _menu_items: Array = [
	{"type": ItemType.HEADER, "text": "Mascota"},
	{"type": ItemType.ACTION, "emoji": "🍎", "label": "Alimentar", "id": "feed"},
	{"type": ItemType.ACTION, "emoji": "🎮", "label": "Jugar", "id": "play"},
	{"type": ItemType.ACTION, "emoji": "💤", "label": "Descansar", "id": "rest"},
	{"type": ItemType.SEPARATOR},
	{"type": ItemType.HEADER, "text": "Sistema"},
	{"type": ItemType.ACTION, "emoji": "📦", "label": "Inventario", "id": "inventory"},
	{"type": ItemType.ACTION, "emoji": "📊", "label": "Estadísticas", "id": "stats"},
	{"type": ItemType.SEPARATOR},
	{"type": ItemType.ACTION, "emoji": "❌", "label": "Cerrar", "id": "quit", "danger": true},
]

## Estado
var _is_showing: bool = false
var _hovered_index: int = -1
var _fade_tween: Tween = null
var _hover_anim_vals: Dictionary = {} # index -> factor (0.0 a 1.0) para suavizado
var _click_flash_idx: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	visible = false
	
	var total_h := MENU_PADDING * 2.0
	for i in range(_menu_items.size()):
		var item: Dictionary = _menu_items[i]
		match item.type:
			ItemType.ACTION: total_h += ITEM_HEIGHT
			ItemType.HEADER: total_h += HEADER_HEIGHT
			ItemType.SEPARATOR: total_h += 12.0
	
	custom_minimum_size = Vector2(MENU_WIDTH, total_h)
	size = Vector2(MENU_WIDTH, total_h)
	
	print("[ContextMenu] ✅ Menú contextual premium inicializado.")


func _process(delta: float) -> void:
	if not _is_showing:
		return

	# Interpolar animaciones de hover por cada item para máxima fluidez
	var changed := false
	for i in range(_menu_items.size()):
		var target := 1.0 if i == _hovered_index else 0.0
		var current: float = _hover_anim_vals.get(i, 0.0)
		if absf(current - target) > 0.01:
			_hover_anim_vals[i] = lerpf(current, target, delta * 12.0)
			changed = true

	if changed:
		queue_redraw()


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
				var item: Dictionary = _menu_items[_hovered_index]
				if item.type == ItemType.ACTION:
					_trigger_click_feedback(_hovered_index)
					_execute_action(item.id)
					if item.id == "quit":
						hide_menu()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			hide_menu()


func _draw() -> void:
	# 1. Fondo Glassmorphism (Gradiente Vertical)
	for row in range(int(size.y)):
		var t := float(row) / size.y
		var col := COLOR_BG_TOP.lerp(COLOR_BG_BOTTOM, t)
		draw_line(Vector2(0, row), Vector2(size.x, row), col, 1.0)
	
	# 2. Borde sutil y acento superior (Glow)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 1.0)
	draw_rect(Rect2(0, 0, size.x, 2), COLOR_ACCENT, true)
	draw_rect(Rect2(0, 2, size.x, 2), COLOR_ACCENT_GLOW, true)
	
	# 3. Dibujar Items
	var y := MENU_PADDING
	for i in range(_menu_items.size()):
		var item: Dictionary = _menu_items[i]
		
		match item.type:
			ItemType.HEADER:
				_draw_header(y, item.text)
				y += HEADER_HEIGHT

			ItemType.SEPARATOR:
				_draw_separator(y)
				y += 12.0

			ItemType.ACTION:
				_draw_action_item(i, y, item)
				y += ITEM_HEIGHT


func _draw_header(y: float, text: String) -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(MENU_PADDING + 8.0, y + HEADER_HEIGHT - 6.0),
		text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_TEXT_DIM
	)


func _draw_separator(y: float) -> void:
	var margin := 12.0
	draw_line(
		Vector2(margin, y + 6.0),
		Vector2(size.x - margin, y + 6.0),
		COLOR_BORDER, 1.0
	)


func _draw_action_item(idx: int, y: float, item: Dictionary) -> void:
	var h_factor: float = _hover_anim_vals.get(idx, 0.0)
	var rect := Rect2(MENU_PADDING, y, size.x - MENU_PADDING * 2.0, ITEM_HEIGHT)

	# Hover Background (con fade)
	if h_factor > 0.01:
		var hover_col := COLOR_HOVER
		hover_col.a *= h_factor
		draw_rect(rect, hover_col, true)
		# Borde de hover sutil
		var border_col := COLOR_ACCENT
		border_col.a = 0.2 * h_factor
		draw_rect(rect, border_col, false, 1.0)

	# Click Feedback Flash
	if idx == _click_flash_idx:
		draw_rect(rect, Color(1, 1, 1, 0.2), true)

	# Contenido: Emoji + Texto
	var text_col := COLOR_DANGER if item.get("danger", false) else COLOR_TEXT
	if h_factor > 0.5:
		text_col = text_col.lerp(COLOR_TEXT_HOVER, (h_factor - 0.5) * 2.0)

	var offset_x := 10.0 + (2.0 * h_factor) # Sutil movimiento a la derecha en hover

	# Emoji
	draw_string(
		ThemeDB.fallback_font,
		Vector2(MENU_PADDING + offset_x, y + ITEM_HEIGHT / 2.0 + 5.0),
		item.emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE + 2
	)

	# Label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(MENU_PADDING + offset_x + 22.0, y + ITEM_HEIGHT / 2.0 + 5.0),
		item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_col
	)


## Determina qué ítem está bajo la posición del mouse.
func _get_item_at_position(pos: Vector2) -> int:
	var y := MENU_PADDING
	for i in range(_menu_items.size()):
		var item: Dictionary = _menu_items[i]
		var h := 0.0
		match item.type:
			ItemType.ACTION: h = ITEM_HEIGHT
			ItemType.HEADER: h = HEADER_HEIGHT
			ItemType.SEPARATOR: h = 12.0
		
		var item_rect := Rect2(0, y, size.x, h)
		if item_rect.has_point(pos):
			return i if item.type == ItemType.ACTION else -1
		
		y += h
	return -1


func _trigger_click_feedback(idx: int) -> void:
	_click_flash_idx = idx
	await get_tree().create_timer(0.1).timeout
	_click_flash_idx = -1
	queue_redraw()


## Ejecuta la acción seleccionada.
func _execute_action(action_name: String) -> void:
	if not SaveManager or not SaveManager.pet_stats:
		return
	
	if AudioManager:
		AudioManager.play_click()
	
	var stats := SaveManager.pet_stats
	var inv := SaveManager.inventory
	
	match action_name:
		"feed":
			var foods := inv.get_items_by_type(ItemData.ItemType.FOOD)
			if foods.size() > 0:
				inv.use_item(foods[0], stats)
			else:
				stats.feed(5.0)
		"play":
			stats.play(15.0)
			stats.add_xp(10)
		"rest":
			stats.rest(20.0)
		"inventory":
			_print_inventory()
		"stats":
			_print_detailed_stats()
		"quit":
			SaveManager.save_game()
			get_tree().quit()
	
	action_selected.emit(action_name)


func _print_inventory() -> void:
	var inv := SaveManager.inventory
	print("═══════════════════════════════")
	print("[Inventario] 📦 Total: %d ítems" % inv.get_total_item_count())
	for item in inv.items:
		var qty := " x%d" % item.quantity if item.stackable else ""
		print("  • %s%s (%s)" % [item.display_name, qty, ItemData.ItemType.keys()[item.item_type]])
	print("═══════════════════════════════")


func _print_detailed_stats() -> void:
	var s := SaveManager.pet_stats
	print("═══════════════════════════════")
	print("[Stats] 📊 %s — Nivel %d" % [s.pet_name, s.level])
	print("  XP: %d / %d | H: %.0f | F: %.0f | E: %.0f" % [s.xp, s.xp_to_next_level, s.hunger, s.happiness, s.energy])
	print("═══════════════════════════════")


## --- Mostrar / Ocultar ---

func show_menu(at_position: Vector2) -> void:
	if _is_showing:
		hide_menu()
		return
	
	_is_showing = true
	visible = true
	_hovered_index = -1
	_hover_anim_vals.clear()
	
	# Posicionamiento con márgenes
	position = at_position
	var vp_size := get_viewport_rect().size
	position.x = clampf(position.x, 5.0, vp_size.x - size.x - 5.0)
	position.y = clampf(position.y, 5.0, vp_size.y - size.y - 5.0)
	
	# Animación Pop Premium (Scale + Alpha)
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	pivot_offset = size / 2.0 # Escalar desde el centro
	scale = Vector2(0.7, 0.7)
	modulate.a = 0.0

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_BACK)
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	_fade_tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	
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
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_fade_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.15)
	_fade_tween.chain().tween_callback(func(): visible = false)


func is_menu_visible() -> bool:
	return _is_showing
