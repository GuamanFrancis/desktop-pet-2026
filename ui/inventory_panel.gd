extends Control
## inventory_panel.gd — Panel Visual de Inventario
## Grid de slots con glassmorphism. Muestra items, permite usar con click.

## --- Señales ---
signal item_used(item: Resource)

## --- Configuración ---
const PANEL_WIDTH: float = 260.0
const PANEL_HEIGHT: float = 280.0
const PADDING: float = 14.0
const GRID_COLS: int = 4
const GRID_ROWS: int = 3
const SLOT_SIZE: float = 48.0
const SLOT_GAP: float = 8.0
const FONT_SIZE_TITLE: int = 14
const FONT_SIZE_ITEM: int = 10
const FONT_SIZE_QTY: int = 9

## Colores
const BG_TOP := Color(0.12, 0.1, 0.2, 0.94)
const BG_BOTTOM := Color(0.07, 0.06, 0.12, 0.94)
const ACCENT := Color(0.55, 0.4, 0.95, 1.0)
const SLOT_BG := Color(0.15, 0.13, 0.25, 0.8)
const SLOT_HOVER := Color(0.25, 0.2, 0.4, 0.9)
const SLOT_BORDER := Color(0.35, 0.3, 0.55, 0.4)
const TEXT_COLOR := Color(0.92, 0.9, 0.98)
const QTY_COLOR := Color(1.0, 0.88, 0.4)
const EMPTY_COLOR := Color(0.4, 0.38, 0.55, 0.3)

## Items type emojis
const ITEM_EMOJIS := {
	0: "🍎",  # FOOD
	1: "👕",  # CLOTHING
	2: "🎁",  # GIFT
	3: "📦",  # OTHER
}

## --- Estado ---
var _is_showing: bool = false
var _fade_tween: Tween = null
var _hovered_slot: int = -1
var _tooltip_text: String = ""
var _font: Font = null


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_font = ThemeDB.fallback_font
	print("[Inventario] ✅ Panel de inventario inicializado.")


func _gui_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	
	if event is InputEventMouseMotion:
		var mouse: InputEventMouseMotion = event as InputEventMouseMotion
		var new_slot := _get_slot_at(mouse.position)
		if new_slot != _hovered_slot:
			_hovered_slot = new_slot
			_update_tooltip()
			queue_redraw()
	
	elif event is InputEventMouseButton:
		var btn: InputEventMouseButton = event as InputEventMouseButton
		if btn.pressed and btn.button_index == MOUSE_BUTTON_LEFT:
			var slot := _get_slot_at(btn.position)
			if slot >= 0:
				_use_item_at(slot)


func _draw() -> void:
	if not _is_showing:
		return
	
	# Fondo gradiente
	for row in range(int(size.y)):
		var t := float(row) / size.y
		draw_line(Vector2(0, row), Vector2(size.x, row), BG_TOP.lerp(BG_BOTTOM, t), 1.0)
	
	# Borde
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.35, 0.6, 0.3), false, 1.0)
	# Acento superior
	draw_rect(Rect2(0, 0, size.x, 2), ACCENT, true)
	
	# Título
	var y := PADDING + FONT_SIZE_TITLE
	draw_string(_font, Vector2(PADDING, y), "🎒 Inventario", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_TITLE, TEXT_COLOR)
	y += 8.0
	
	# Separador
	draw_line(Vector2(PADDING, y), Vector2(size.x - PADDING, y), Color(0.35, 0.3, 0.55, 0.35), 1.0)
	y += 10.0
	
	# Grid de slots
	var items: Array = _get_items()
	var grid_start_x := (size.x - (GRID_COLS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP)) / 2.0
	
	for row_idx in range(GRID_ROWS):
		for col_idx in range(GRID_COLS):
			var slot_idx := row_idx * GRID_COLS + col_idx
			var sx := grid_start_x + col_idx * (SLOT_SIZE + SLOT_GAP)
			var sy := y + row_idx * (SLOT_SIZE + SLOT_GAP)
			var rect := Rect2(sx, sy, SLOT_SIZE, SLOT_SIZE)
			
			# Fondo del slot
			var bg := SLOT_HOVER if slot_idx == _hovered_slot else SLOT_BG
			draw_rect(rect, bg, true)
			draw_rect(rect, SLOT_BORDER, false, 1.0)
			
			if slot_idx < items.size():
				var item: ItemData = items[slot_idx] as ItemData
				# Emoji del tipo
				var emoji: String = ITEM_EMOJIS.get(item.item_type, "📦") as String
				draw_string(_font, Vector2(sx + SLOT_SIZE / 2.0 - 8, sy + SLOT_SIZE / 2.0 + 4),
					emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR)
				# Cantidad
				if item.quantity > 1:
					var qty_text := "x%d" % item.quantity
					var qty_w := _font.get_string_size(qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_QTY).x
					draw_string(_font, Vector2(sx + SLOT_SIZE - qty_w - 3, sy + SLOT_SIZE - 3),
						qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_QTY, QTY_COLOR)
			else:
				# Slot vacío
				draw_string(_font, Vector2(sx + SLOT_SIZE / 2.0 - 4, sy + SLOT_SIZE / 2.0 + 4),
					"·", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, EMPTY_COLOR)
	
	# Tooltip
	if _hovered_slot >= 0 and _tooltip_text.length() > 0:
		var tip_y := y + GRID_ROWS * (SLOT_SIZE + SLOT_GAP) + 8.0
		draw_rect(Rect2(PADDING, tip_y - 2, size.x - PADDING * 2, FONT_SIZE_ITEM + 10), Color(0.1, 0.08, 0.18, 0.85), true)
		draw_string(_font, Vector2(PADDING + 6, tip_y + FONT_SIZE_ITEM),
			_tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - PADDING * 3), FONT_SIZE_ITEM, TEXT_COLOR)


## --- API Pública ---

func show_panel(target_pos: Vector2) -> void:
	if _is_showing:
		return
	_is_showing = true
	visible = true
	_hovered_slot = -1
	
	position = Vector2(
		target_pos.x - size.x / 2.0,
		target_pos.y - size.y - 25.0
	)
	position.x = clampf(position.x, 5.0, get_viewport_rect().size.x - size.x - 5.0)
	position.y = maxf(position.y, 5.0)
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	var target_y := position.y
	position.y += 10.0
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	_fade_tween.tween_property(self, "position:y", target_y, 0.25)


func hide_panel() -> void:
	if not _is_showing:
		return
	_is_showing = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_fade_tween.tween_property(self, "position:y", position.y + 5.0, 0.15)
	_fade_tween.chain().tween_callback(func(): visible = false)


func is_panel_visible() -> bool:
	return _is_showing


## --- Helpers ---

func _get_items() -> Array:
	if SaveManager and SaveManager.inventory:
		return SaveManager.inventory.items
	return []


func _get_slot_at(pos: Vector2) -> int:
	var y_start := PADDING + FONT_SIZE_TITLE + 18.0
	var grid_start_x := (size.x - (GRID_COLS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP)) / 2.0
	
	for row_idx in range(GRID_ROWS):
		for col_idx in range(GRID_COLS):
			var sx := grid_start_x + col_idx * (SLOT_SIZE + SLOT_GAP)
			var sy := y_start + row_idx * (SLOT_SIZE + SLOT_GAP)
			if Rect2(sx, sy, SLOT_SIZE, SLOT_SIZE).has_point(pos):
				var idx := row_idx * GRID_COLS + col_idx
				if idx < _get_items().size():
					return idx
				return -1
	return -1


func _update_tooltip() -> void:
	if _hovered_slot >= 0:
		var items := _get_items()
		if _hovered_slot < items.size():
			var item: ItemData = items[_hovered_slot] as ItemData
			_tooltip_text = "%s — %s" % [item.display_name, item.description]
			return
	_tooltip_text = ""


func _use_item_at(slot: int) -> void:
	var items := _get_items()
	if slot >= 0 and slot < items.size():
		var item: ItemData = items[slot] as ItemData
		if AudioManager:
			AudioManager.play_click()
		item_used.emit(item)
		queue_redraw()  # Refresh grid after use
		print("[Inventario] ✅ Usando: %s" % item.display_name)
