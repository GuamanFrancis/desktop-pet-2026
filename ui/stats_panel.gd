extends Control
## stats_panel.gd — Panel Flotante de Stats (Versión Premium)
## Se muestra al pasar el mouse sobre la mascota.
## Diseño glassmorphism con gradientes, emojis, y barras animadas.

## --- Configuración Visual ---
const PANEL_WIDTH: float = 240.0
const PANEL_HEIGHT: float = 220.0
const PANEL_PADDING: float = 14.0
const BAR_HEIGHT: float = 12.0
const BAR_SPACING: float = 5.0
const BAR_RADIUS: float = 6.0
const FONT_SIZE_TITLE: int = 15
const FONT_SIZE_LABEL: int = 11
const FONT_SIZE_SMALL: int = 10

## Colores del panel (glassmorphism oscuro)
const COLOR_BG_TOP: Color = Color(0.14, 0.12, 0.22, 0.94)
const COLOR_BG_BOTTOM: Color = Color(0.08, 0.07, 0.14, 0.94)
const COLOR_ACCENT: Color = Color(0.55, 0.4, 0.95, 1.0)
const COLOR_ACCENT_GLOW: Color = Color(0.6, 0.45, 1.0, 0.3)
const COLOR_TITLE: Color = Color(0.95, 0.92, 1.0)
const COLOR_LABEL: Color = Color(0.72, 0.7, 0.82)
const COLOR_VALUE: Color = Color(0.88, 0.86, 0.95)
const COLOR_LEVEL_BG: Color = Color(0.55, 0.4, 0.95, 0.2)
const COLOR_LEVEL_TEXT: Color = Color(1.0, 0.88, 0.45)
const COLOR_SEPARATOR: Color = Color(0.35, 0.3, 0.55, 0.35)

## Colores de las barras (gradientes vibrantes)
const COLOR_HUNGER_START: Color = Color(0.15, 0.75, 0.35, 1.0)
const COLOR_HUNGER_END: Color = Color(0.3, 0.95, 0.5, 1.0)
const COLOR_HUNGER_LOW_START: Color = Color(0.85, 0.2, 0.15, 1.0)
const COLOR_HUNGER_LOW_END: Color = Color(1.0, 0.35, 0.2, 1.0)
const COLOR_HAPPINESS_START: Color = Color(0.95, 0.65, 0.1, 1.0)
const COLOR_HAPPINESS_END: Color = Color(1.0, 0.82, 0.3, 1.0)
const COLOR_ENERGY_START: Color = Color(0.2, 0.5, 0.95, 1.0)
const COLOR_ENERGY_END: Color = Color(0.35, 0.7, 1.0, 1.0)
const COLOR_XP_START: Color = Color(0.5, 0.3, 0.85, 1.0)
const COLOR_XP_END: Color = Color(0.7, 0.5, 1.0, 1.0)
const COLOR_BAR_BG: Color = Color(0.15, 0.14, 0.22, 0.85)
const COLOR_BAR_SHINE: Color = Color(1.0, 1.0, 1.0, 0.08)

## Estado
var _is_showing: bool = false
var _fade_tween: Tween = null
## Barras animadas (valores visuales que interpolan hacia los reales)
var _visual_hunger: float = 100.0
var _visual_happiness: float = 100.0
var _visual_energy: float = 100.0
var _visual_xp: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	print("[StatsPanel] ✅ Panel de stats premium inicializado.")


func _process(delta: float) -> void:
	if not _is_showing:
		return
	
	# Interpolar barras suavemente hacia los valores reales
	if SaveManager and SaveManager.pet_stats:
		var s := SaveManager.pet_stats
		_visual_hunger = lerpf(_visual_hunger, s.hunger, delta * 4.0)
		_visual_happiness = lerpf(_visual_happiness, s.happiness, delta * 4.0)
		_visual_energy = lerpf(_visual_energy, s.energy, delta * 4.0)
		var xp_pct := float(s.xp) / float(s.xp_to_next_level) * 100.0 if s.xp_to_next_level > 0 else 0.0
		_visual_xp = lerpf(_visual_xp, xp_pct, delta * 4.0)
	
	queue_redraw()


func _draw() -> void:
	if not SaveManager or not SaveManager.pet_stats:
		return
	
	var stats := SaveManager.pet_stats
	var y: float = 0.0
	
	# ══════════════════════════════════════
	# FONDO CON GRADIENTE VERTICAL
	# ══════════════════════════════════════
	for row in range(int(size.y)):
		var t := float(row) / size.y
		var col := COLOR_BG_TOP.lerp(COLOR_BG_BOTTOM, t)
		draw_line(Vector2(0, row), Vector2(size.x, row), col, 1.0)
	
	# Borde exterior sutil
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.35, 0.6, 0.25), false, 1.0)
	
	# Línea de acento superior (glow)
	draw_rect(Rect2(0, 0, size.x, 2), COLOR_ACCENT, true)
	draw_rect(Rect2(0, 2, size.x, 3), COLOR_ACCENT_GLOW, true)
	
	y += PANEL_PADDING + 4.0
	
	# ══════════════════════════════════════
	# NOMBRE + BADGE DE NIVEL
	# ══════════════════════════════════════
	# Nombre
	draw_string(
		ThemeDB.fallback_font, Vector2(PANEL_PADDING, y + FONT_SIZE_TITLE),
		stats.pet_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_TITLE, COLOR_TITLE
	)
	
	# Badge de nivel (rectángulo redondeado con texto)
	var lv_text := "Lv.%d" % stats.level
	var lv_width := ThemeDB.fallback_font.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL).x
	var badge_w := lv_width + 14.0
	var badge_x := size.x - PANEL_PADDING - badge_w
	var badge_y := y - 1.0
	var badge_rect := Rect2(badge_x, badge_y, badge_w, FONT_SIZE_TITLE + 4.0)
	draw_rect(badge_rect, COLOR_LEVEL_BG, true)
	draw_rect(badge_rect, Color(0.55, 0.4, 0.95, 0.4), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(badge_x + 7.0, y + FONT_SIZE_SMALL + 1.0),
		lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_LEVEL_TEXT
	)
	
	y += FONT_SIZE_TITLE + 4.0
	
	# Estado de ánimo con emoji
	var mood := stats.get_overall_mood()
	var mood_emoji := _get_mood_emoji(mood)
	var mood_text := "%s %s" % [mood_emoji, stats.get_mood_text()]
	draw_string(
		ThemeDB.fallback_font, Vector2(PANEL_PADDING, y + FONT_SIZE_SMALL),
		mood_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL,
		_get_mood_color(mood)
	)
	
	y += FONT_SIZE_SMALL + 8.0
	
	# Separador
	draw_line(
		Vector2(PANEL_PADDING, y), Vector2(size.x - PANEL_PADDING, y),
		COLOR_SEPARATOR, 1.0
	)
	y += 8.0
	
	# ══════════════════════════════════════
	# BARRAS DE STATS
	# ══════════════════════════════════════
	
	# XP
	_draw_premium_bar(y, "✨ XP", _visual_xp / 100.0,
		COLOR_XP_START, COLOR_XP_END,
		"%d/%d" % [stats.xp, stats.xp_to_next_level])
	y += BAR_HEIGHT + FONT_SIZE_LABEL + BAR_SPACING + 4.0
	
	# Hambre
	var h_start := COLOR_HUNGER_LOW_START.lerp(COLOR_HUNGER_START, _visual_hunger / 100.0)
	var h_end := COLOR_HUNGER_LOW_END.lerp(COLOR_HUNGER_END, _visual_hunger / 100.0)
	_draw_premium_bar(y, "🍎 Hambre", _visual_hunger / 100.0,
		h_start, h_end, "%.0f%%" % stats.hunger)
	y += BAR_HEIGHT + FONT_SIZE_LABEL + BAR_SPACING + 4.0
	
	# Felicidad
	_draw_premium_bar(y, "😊 Felicidad", _visual_happiness / 100.0,
		COLOR_HAPPINESS_START, COLOR_HAPPINESS_END, "%.0f%%" % stats.happiness)
	y += BAR_HEIGHT + FONT_SIZE_LABEL + BAR_SPACING + 4.0
	
	# Energía
	_draw_premium_bar(y, "⚡ Energía", _visual_energy / 100.0,
		COLOR_ENERGY_START, COLOR_ENERGY_END, "%.0f%%" % stats.energy)


## Dibuja una barra premium con gradiente horizontal + brillo superior.
func _draw_premium_bar(y: float, label: String, percentage: float,
		color_start: Color, color_end: Color, value_text: String) -> void:
	var bar_x := PANEL_PADDING
	var bar_width := size.x - PANEL_PADDING * 2.0
	
	# Label
	draw_string(
		ThemeDB.fallback_font, Vector2(bar_x, y + FONT_SIZE_LABEL),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_LABEL, COLOR_LABEL
	)
	
	# Valor (derecha)
	var val_w := ThemeDB.fallback_font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL).x
	draw_string(
		ThemeDB.fallback_font, Vector2(size.x - PANEL_PADDING - val_w, y + FONT_SIZE_LABEL),
		value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, COLOR_VALUE
	)
	
	var bar_y := y + FONT_SIZE_LABEL + 3.0
	var pct := clampf(percentage, 0.0, 1.0)
	
	# Fondo de la barra
	draw_rect(Rect2(bar_x, bar_y, bar_width, BAR_HEIGHT), COLOR_BAR_BG, true)
	
	# Barra de progreso con gradiente horizontal
	if pct > 0.0:
		var fill_w := bar_width * pct
		for col in range(int(fill_w)):
			var t := float(col) / bar_width
			var c := color_start.lerp(color_end, t)
			draw_line(
				Vector2(bar_x + col, bar_y),
				Vector2(bar_x + col, bar_y + BAR_HEIGHT),
				c, 1.0
			)
		
		# Brillo superior (efecto glass)
		var shine_rect := Rect2(bar_x, bar_y, fill_w, BAR_HEIGHT / 2.0)
		draw_rect(shine_rect, COLOR_BAR_SHINE, true)
		
		# Glow al final de la barra
		if fill_w > 2.0:
			var glow_color := color_end
			glow_color.a = 0.3
			draw_rect(Rect2(bar_x + fill_w - 2.0, bar_y, 4.0, BAR_HEIGHT), glow_color, true)
	
	# Borde de la barra
	draw_rect(Rect2(bar_x, bar_y, bar_width, BAR_HEIGHT), Color(0.3, 0.28, 0.45, 0.4), false, 1.0)


func _get_mood_color(mood: float) -> Color:
	if mood > 0.7:
		return Color(0.4, 0.92, 0.55)
	elif mood > 0.4:
		return Color(1.0, 0.85, 0.35)
	else:
		return Color(0.95, 0.35, 0.3)


func _get_mood_emoji(mood: float) -> String:
	if mood > 0.8:
		return "😄"
	elif mood > 0.5:
		return "🙂"
	elif mood > 0.3:
		return "😟"
	else:
		return "😢"


## --- Mostrar / Ocultar ---

func show_panel(target_pos: Vector2) -> void:
	if _is_showing:
		return
	_is_showing = true
	visible = true
	
	# Sincronizar barras visuales al abrir
	if SaveManager and SaveManager.pet_stats:
		var s := SaveManager.pet_stats
		_visual_hunger = s.hunger
		_visual_happiness = s.happiness
		_visual_energy = s.energy
		_visual_xp = float(s.xp) / float(s.xp_to_next_level) * 100.0 if s.xp_to_next_level > 0 else 0.0
	
	# Posicionar encima de la mascota
	position = Vector2(
		target_pos.x - size.x / 2.0,
		target_pos.y - size.y - 25.0
	)
	position.x = clampf(position.x, 5.0, get_viewport_rect().size.x - size.x - 5.0)
	position.y = maxf(position.y, 5.0)
	
	# Fade in con slide up
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	var target_y := position.y
	position.y += 8.0
	
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_fade_tween.tween_property(self, "position:y", target_y, 0.3)


func hide_panel() -> void:
	if not _is_showing:
		return
	_is_showing = false
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_fade_tween.tween_property(self, "position:y", position.y + 5.0, 0.2)
	_fade_tween.chain().tween_callback(func(): visible = false)
