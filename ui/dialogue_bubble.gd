extends Control
## dialogue_bubble.gd — Burbuja de Diálogo Premium
## Glassmorphism + efecto typewriter + cola de mensajes.
## Dibujado completamente por código.

## --- Señales ---
signal message_finished()
signal queue_empty()

## --- Configuración ---
const BUBBLE_WIDTH: float = 220.0
const BUBBLE_PADDING: float = 14.0
const BUBBLE_RADIUS: float = 12.0
const TAIL_SIZE: float = 10.0
const FONT_SIZE: int = 13
const TYPEWRITER_SPEED: float = 0.035  # Segundos por carácter
const DISPLAY_TIME: float = 4.0       # Segundos antes de auto-hide
const FADE_DURATION: float = 0.3

## Colores glassmorphism
const BG_COLOR := Color(0.08, 0.08, 0.15, 0.88)
const BORDER_COLOR := Color(0.4, 0.5, 0.9, 0.5)
const TEXT_COLOR := Color(0.92, 0.94, 0.98, 1.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.3)

## --- Estado ---
var _message_queue: Array[String] = []
var _current_message: String = ""
var _visible_chars: int = 0
var _total_chars: int = 0
var _is_typing: bool = false
var _is_showing: bool = false

## --- Timers ---
var _type_timer: Timer = null
var _display_timer: Timer = null
var _fade_tween: Tween = null

## --- Font ---
var _font: Font = null
var _line_height: float = 0.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Font del sistema
	_font = ThemeDB.fallback_font
	_line_height = _font.get_height(FONT_SIZE) + 2.0
	
	# Timer de typewriter
	_type_timer = Timer.new()
	_type_timer.wait_time = TYPEWRITER_SPEED
	_type_timer.timeout.connect(_on_type_tick)
	add_child(_type_timer)
	
	# Timer de display
	_display_timer = Timer.new()
	_display_timer.one_shot = true
	_display_timer.timeout.connect(_on_display_timeout)
	add_child(_display_timer)
	
	print("[DialogueBubble] ✅ Sistema de diálogo inicializado.")


## --- API Pública ---

## Encola un mensaje para mostrar.
func show_message(text: String) -> void:
	_message_queue.append(text)
	if not _is_showing:
		_process_next_message()


## Encola múltiples mensajes.
func show_messages(texts: Array[String]) -> void:
	for t in texts:
		_message_queue.append(t)
	if not _is_showing:
		_process_next_message()


## Cierra la burbuja inmediatamente.
func dismiss() -> void:
	_type_timer.stop()
	_display_timer.stop()
	_is_typing = false
	_is_showing = false
	_fade_out()


## Retorna true si hay burbuja visible.
func is_bubble_visible() -> bool:
	return _is_showing


## --- Procesamiento Interno ---

func _process_next_message() -> void:
	if _message_queue.is_empty():
		queue_empty.emit()
		return
	
	_current_message = _message_queue.pop_front()
	_visible_chars = 0
	_total_chars = _current_message.length()
	_is_typing = true
	_is_showing = true
	
	# Calcular tamaño de la burbuja
	_recalculate_size()
	
	# Posicionar encima de la mascota
	_reposition()
	
	# Mostrar con fade-in
	visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_BACK)
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION * 0.7)
	_fade_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), FADE_DURATION * 0.7).from(Vector2(0.8, 0.5))
	
	# Iniciar typewriter
	_type_timer.start()
	queue_redraw()


func _recalculate_size() -> void:
	# Calcular líneas del texto
	var lines := _wrap_text(_current_message, BUBBLE_WIDTH - BUBBLE_PADDING * 2)
	var text_height := lines.size() * _line_height
	var total_height := text_height + BUBBLE_PADDING * 2 + TAIL_SIZE
	var total_width := BUBBLE_WIDTH
	
	size = Vector2(total_width, total_height)
	pivot_offset = Vector2(total_width / 2.0, total_height)


func _reposition() -> void:
	# Posicionar centrado arriba de la mascota
	var viewport_size := get_viewport_rect().size
	var center_x := viewport_size.x / 2.0
	position = Vector2(
		center_x - size.x / 2.0,
		viewport_size.y / 2.0 - size.y - 60.0  # 60px arriba del centro (mascota)
	)
	# Clamping para no salir del viewport
	position.x = clampf(position.x, 4.0, viewport_size.x - size.x - 4.0)
	position.y = maxf(position.y, 4.0)


## --- Typewriter ---

func _on_type_tick() -> void:
	if not _is_typing:
		return
	
	_visible_chars += 1
	queue_redraw()
	
	if _visible_chars >= _total_chars:
		_type_timer.stop()
		_is_typing = false
		message_finished.emit()
		# Iniciar countdown para auto-hide
		_display_timer.wait_time = DISPLAY_TIME
		_display_timer.start()


func _on_display_timeout() -> void:
	_fade_out()


func _fade_out() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	visible = false
	_is_showing = false
	# ¿Hay más mensajes en cola?
	if not _message_queue.is_empty():
		# Breve pausa antes del siguiente
		await get_tree().create_timer(0.3).timeout
		_process_next_message()
	else:
		queue_empty.emit()


## --- Dibujo ---

func _draw() -> void:
	if not _is_showing:
		return
	
	var w := size.x
	var h := size.y - TAIL_SIZE
	var r := BUBBLE_RADIUS
	
	# Sombra
	var shadow_rect := Rect2(3, 3, w, h)
	_draw_rounded_rect(shadow_rect, r, SHADOW_COLOR)
	
	# Fondo principal
	var bg_rect := Rect2(0, 0, w, h)
	_draw_rounded_rect(bg_rect, r, BG_COLOR)
	
	# Borde brillante
	_draw_rounded_border(bg_rect, r, BORDER_COLOR, 1.5)
	
	# Brillo superior (glassmorphism)
	var gloss_color := Color(1, 1, 1, 0.06)
	var gloss_rect := Rect2(2, 2, w - 4, h * 0.35)
	_draw_rounded_rect(gloss_rect, r - 1, gloss_color)
	
	# Cola (tail) — triángulo apuntando abajo hacia la mascota
	var tail_center := w / 2.0
	var tail_points := PackedVector2Array([
		Vector2(tail_center - TAIL_SIZE * 0.7, h),
		Vector2(tail_center, h + TAIL_SIZE),
		Vector2(tail_center + TAIL_SIZE * 0.7, h),
	])
	draw_colored_polygon(tail_points, BG_COLOR)
	# Borde del tail
	draw_line(tail_points[0], tail_points[1], BORDER_COLOR, 1.5)
	draw_line(tail_points[1], tail_points[2], BORDER_COLOR, 1.5)
	
	# Texto con typewriter
	var lines := _wrap_text(_current_message, w - BUBBLE_PADDING * 2)
	var chars_drawn := 0
	for i in range(lines.size()):
		var line_text: String = lines[i]
		var visible_in_line := clampi(_visible_chars - chars_drawn, 0, line_text.length())
		var display_text := line_text.substr(0, visible_in_line)
		
		var y_pos := BUBBLE_PADDING + (i + 1) * _line_height - 2.0
		draw_string(_font, Vector2(BUBBLE_PADDING, y_pos), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
		
		chars_drawn += line_text.length()


## --- Helpers de Dibujo ---

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var points := _get_rounded_rect_points(rect, radius)
	draw_colored_polygon(points, color)


func _draw_rounded_border(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var points := _get_rounded_rect_points(rect, radius)
	points.append(points[0])  # Cerrar el polígono
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, true)


func _get_rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 6
	# Top-left
	for i in range(segments + 1):
		var angle := PI + (PI / 2.0) * (float(i) / segments)
		points.append(Vector2(rect.position.x + radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius))
	# Top-right
	for i in range(segments + 1):
		var angle := PI * 1.5 + (PI / 2.0) * (float(i) / segments)
		points.append(Vector2(rect.end.x - radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius))
	# Bottom-right
	for i in range(segments + 1):
		var angle := 0.0 + (PI / 2.0) * (float(i) / segments)
		points.append(Vector2(rect.end.x - radius + cos(angle) * radius,
			rect.end.y - radius + sin(angle) * radius))
	# Bottom-left
	for i in range(segments + 1):
		var angle := PI / 2.0 + (PI / 2.0) * (float(i) / segments)
		points.append(Vector2(rect.position.x + radius + cos(angle) * radius,
			rect.end.y - radius + sin(angle) * radius))
	return points


## --- Word Wrapping ---

func _wrap_text(text: String, max_width: float) -> Array[String]:
	var lines: Array[String] = []
	var words := text.split(" ")
	var current_line := ""
	
	for word in words:
		var test_line := current_line + (" " if current_line.length() > 0 else "") + word
		var test_width := _font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		if test_width > max_width and current_line.length() > 0:
			lines.append(current_line)
			current_line = word
		else:
			current_line = test_line
	
	if current_line.length() > 0:
		lines.append(current_line)
	
	if lines.is_empty():
		lines.append("")
	
	return lines
