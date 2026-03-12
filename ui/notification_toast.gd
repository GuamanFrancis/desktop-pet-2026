extends Control
## notification_toast.gd — Sistema de Notificaciones (Toasts)
## Banners animados para eventos importantes (level up, logros).
## Slide-in + permanencia + slide-out. Cola de hasta 3 visibles.

## --- Configuración ---
const TOAST_WIDTH: float = 200.0
const TOAST_HEIGHT: float = 36.0
const TOAST_PADDING: float = 10.0
const TOAST_RADIUS: float = 8.0
const TOAST_SPACING: float = 6.0
const DISPLAY_TIME: float = 3.5
const SLIDE_DURATION: float = 0.35
const FONT_SIZE: int = 12
const MAX_VISIBLE: int = 3

## Colores
const BG_COLOR := Color(0.1, 0.08, 0.18, 0.92)
const BORDER_COLOR := Color(0.55, 0.4, 0.95, 0.6)
const TEXT_COLOR := Color(0.95, 0.93, 1.0)
const GLOW_COLOR := Color(0.6, 0.45, 1.0, 0.15)

## --- Estado ---
var _active_toasts: Array[Dictionary] = []
var _queue: Array[Dictionary] = []
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	print("[Toast] ✅ Sistema de notificaciones inicializado.")


## --- API Pública ---

## Muestra un toast con icono y texto.
func show_toast(icon: String, text: String, color: Color = BORDER_COLOR) -> void:
	var toast_data := {
		"icon": icon,
		"text": text,
		"color": color,
		"alpha": 0.0,
		"offset_y": -TOAST_HEIGHT,  # Empieza arriba (fuera de vista)
		"target_y": 0.0,
		"timer": DISPLAY_TIME,
		"state": "entering",  # entering, visible, exiting
	}
	
	if _active_toasts.size() >= MAX_VISIBLE:
		_queue.append(toast_data)
	else:
		_add_toast(toast_data)


func _add_toast(data: Dictionary) -> void:
	# Calcular posición Y (debajo de los toasts existentes)
	var slot_y := 8.0
	for existing in _active_toasts:
		slot_y += TOAST_HEIGHT + TOAST_SPACING
	data["target_y"] = slot_y
	data["offset_y"] = slot_y - TOAST_HEIGHT
	_active_toasts.append(data)


func _process(delta: float) -> void:
	if _active_toasts.is_empty():
		return
	
	var to_remove: Array[int] = []
	
	for i in range(_active_toasts.size()):
		var toast: Dictionary = _active_toasts[i]
		
		match toast["state"]:
			"entering":
				toast["alpha"] = minf(toast["alpha"] as float + delta / SLIDE_DURATION, 1.0)
				toast["offset_y"] = lerpf(toast["offset_y"] as float, toast["target_y"] as float, delta * 8.0)
				if toast["alpha"] as float >= 1.0:
					toast["state"] = "visible"
			"visible":
				toast["timer"] = (toast["timer"] as float) - delta
				if toast["timer"] as float <= 0.0:
					toast["state"] = "exiting"
			"exiting":
				toast["alpha"] = maxf(toast["alpha"] as float - delta / SLIDE_DURATION, 0.0)
				toast["offset_y"] = (toast["offset_y"] as float) - delta * 60.0
				if toast["alpha"] as float <= 0.0:
					to_remove.append(i)
	
	# Remover toasts terminados (de atrás para adelante)
	to_remove.reverse()
	for idx in to_remove:
		_active_toasts.remove_at(idx)
		# Procesar cola
		if not _queue.is_empty():
			_add_toast(_queue.pop_front())
		# Recalcular posiciones
		_recalculate_positions()
	
	queue_redraw()


func _recalculate_positions() -> void:
	var slot_y := 8.0
	for toast in _active_toasts:
		toast["target_y"] = slot_y
		slot_y += TOAST_HEIGHT + TOAST_SPACING


func _draw() -> void:
	if _active_toasts.is_empty():
		return
	
	var viewport_w := get_viewport_rect().size.x
	
	for toast in _active_toasts:
		var alpha: float = toast["alpha"] as float
		var y_pos: float = toast["offset_y"] as float
		var icon: String = toast["icon"] as String
		var text: String = toast["text"] as String
		var accent: Color = toast["color"] as Color
		
		var x_pos := (viewport_w - TOAST_WIDTH) / 2.0
		
		# Sombra
		var shadow_rect := Rect2(x_pos + 2, y_pos + 2, TOAST_WIDTH, TOAST_HEIGHT)
		var shadow_col := Color(0, 0, 0, 0.25 * alpha)
		draw_rect(shadow_rect, shadow_col, true)
		
		# Fondo
		var bg := BG_COLOR
		bg.a *= alpha
		var rect := Rect2(x_pos, y_pos, TOAST_WIDTH, TOAST_HEIGHT)
		draw_rect(rect, bg, true)
		
		# Glow superior
		var glow := GLOW_COLOR
		glow.a *= alpha
		draw_rect(Rect2(x_pos, y_pos, TOAST_WIDTH, TOAST_HEIGHT * 0.4), glow, true)
		
		# Acento izquierdo (línea de color)
		var acc := accent
		acc.a *= alpha
		draw_rect(Rect2(x_pos, y_pos, 3, TOAST_HEIGHT), acc, true)
		
		# Borde
		var border := BORDER_COLOR
		border.a *= alpha * 0.5
		draw_rect(rect, border, false, 1.0)
		
		# Texto
		var txt_col := TEXT_COLOR
		txt_col.a *= alpha
		var full_text := "%s %s" % [icon, text]
		draw_string(_font, Vector2(x_pos + TOAST_PADDING, y_pos + TOAST_HEIGHT / 2.0 + FONT_SIZE / 2.0 - 1),
			full_text, HORIZONTAL_ALIGNMENT_LEFT, TOAST_WIDTH - TOAST_PADDING * 2, FONT_SIZE, txt_col)
