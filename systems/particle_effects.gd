extends Node2D
## particle_effects.gd — Sistema de Partículas Procedurales
## Partículas dibujadas por código sin assets externos.
## Cada tipo de partícula (Zzz, estrellas, comida, lágrimas) usa _draw().

## --- Tipos de Efecto ---
enum EffectType {
	ZZZ,       ## Letras Z flotando (dormir)
	STARS,     ## Estrellas brillantes (jugar/level up)
	FOOD,      ## Iconos de comida cayendo (comer)
	TEARS,     ## Gotas cayendo (triste)
	SPARKLE    ## Brillos genéricos (equipar ropa)
}

## --- Estructura de una Partícula ---
class Particle:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var lifetime: float = 0.0
	var max_lifetime: float = 1.0
	var size_val: float = 8.0
	var color: Color = Color.WHITE
	var rotation_val: float = 0.0
	var rot_speed: float = 0.0
	var text: String = ""  # Para texto como "Z"

## --- Estado ---
var _particles: Array[Particle] = []
var _active_effect: EffectType = EffectType.ZZZ
var _emitting: bool = false
var _emit_timer: float = 0.0
var _emit_interval: float = 0.3
var _effect_duration: float = 0.0
var _effect_timer: float = 0.0


func _ready() -> void:
	print("[Particles] ✅ Sistema de partículas inicializado.")


func _process(delta: float) -> void:
	if not _emitting and _particles.is_empty():
		return
	
	# Emitir nuevas partículas
	if _emitting:
		_effect_timer += delta
		_emit_timer += delta
		
		if _emit_timer >= _emit_interval:
			_emit_timer = 0.0
			_spawn_particle()
		
		# ¿Terminó la duración del efecto?
		if _effect_duration > 0.0 and _effect_timer >= _effect_duration:
			_emitting = false
	
	# Actualizar partículas existentes
	var i := _particles.size() - 1
	while i >= 0:
		var p := _particles[i]
		p.lifetime += delta
		
		if p.lifetime >= p.max_lifetime:
			_particles.remove_at(i)
		else:
			# Mover
			p.pos += p.vel * delta
			p.rotation_val += p.rot_speed * delta
			
			# Fade out en el último 30%
			var life_pct := p.lifetime / p.max_lifetime
			if life_pct > 0.7:
				p.color.a = lerpf(1.0, 0.0, (life_pct - 0.7) / 0.3)
		
		i -= 1
	
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		match _active_effect:
			EffectType.ZZZ:
				_draw_zzz(p)
			EffectType.STARS:
				_draw_star(p)
			EffectType.FOOD:
				_draw_food(p)
			EffectType.TEARS:
				_draw_tear(p)
			EffectType.SPARKLE:
				_draw_sparkle(p)


## --- API Pública ---

## Inicia un efecto de partículas.
func play_effect(effect: EffectType, duration: float = 3.0) -> void:
	_active_effect = effect
	_effect_duration = duration
	_effect_timer = 0.0
	_emit_timer = 0.0
	_emitting = true
	_particles.clear()
	
	# Configurar intervalo según efecto
	match effect:
		EffectType.ZZZ:
			_emit_interval = 0.8
		EffectType.STARS:
			_emit_interval = 0.15
		EffectType.FOOD:
			_emit_interval = 0.25
		EffectType.TEARS:
			_emit_interval = 0.5
		EffectType.SPARKLE:
			_emit_interval = 0.1


## Inicia efecto continuo (sin duración fija, para estados como dormir).
func play_continuous(effect: EffectType) -> void:
	play_effect(effect, 0.0)  # 0 = infinito


## Detiene la emisión (las partículas existentes terminan su vida).
func stop_effect() -> void:
	_emitting = false


## Detiene todo inmediatamente.
func stop_all() -> void:
	_emitting = false
	_particles.clear()
	queue_redraw()


## --- Spawn de Partículas ---

func _spawn_particle() -> void:
	var p := Particle.new()
	
	match _active_effect:
		EffectType.ZZZ:
			p.pos = Vector2(randf_range(-15, 15), randf_range(-30, -10))
			p.vel = Vector2(randf_range(8, 20), randf_range(-25, -15))
			p.max_lifetime = randf_range(1.5, 2.5)
			p.size_val = randf_range(10, 16)
			p.color = Color(0.6, 0.7, 1.0, 0.9)
			p.text = "Z"
		
		EffectType.STARS:
			var angle := randf() * TAU
			var speed := randf_range(30, 80)
			p.pos = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			p.vel = Vector2(cos(angle), sin(angle)) * speed
			p.max_lifetime = randf_range(0.5, 1.2)
			p.size_val = randf_range(4, 10)
			p.color = Color(1.0, 0.9, 0.3, 1.0)
			p.rot_speed = randf_range(-3.0, 3.0)
		
		EffectType.FOOD:
			p.pos = Vector2(randf_range(-20, 20), -20)
			p.vel = Vector2(randf_range(-10, 10), randf_range(20, 40))
			p.max_lifetime = randf_range(1.0, 1.8)
			p.size_val = randf_range(6, 12)
			p.color = Color(0.9, 0.3, 0.2, 1.0)
			p.rot_speed = randf_range(-2.0, 2.0)
		
		EffectType.TEARS:
			p.pos = Vector2(randf_range(-15, 15), randf_range(-5, 5))
			p.vel = Vector2(randf_range(-5, 5), randf_range(30, 50))
			p.max_lifetime = randf_range(0.8, 1.5)
			p.size_val = randf_range(3, 6)
			p.color = Color(0.4, 0.6, 1.0, 0.8)
		
		EffectType.SPARKLE:
			var angle := randf() * TAU
			var speed := randf_range(15, 50)
			p.pos = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			p.vel = Vector2(cos(angle), sin(angle)) * speed
			p.max_lifetime = randf_range(0.3, 0.8)
			p.size_val = randf_range(2, 6)
			p.color = Color(0.8, 0.7, 1.0, 1.0)
	
	_particles.append(p)


## --- Dibujo de Partículas ---

func _draw_zzz(p: Particle) -> void:
	var scale_factor := 1.0 + p.lifetime * 0.3  # Crece al subir
	draw_string(
		ThemeDB.fallback_font, p.pos,
		p.text, HORIZONTAL_ALIGNMENT_CENTER, -1,
		int(p.size_val * scale_factor), p.color
	)


func _draw_star(p: Particle) -> void:
	# Estrella de 4 puntas
	var s := p.size_val
	var points := PackedVector2Array()
	for i in range(8):
		var angle := p.rotation_val + float(i) / 8.0 * TAU
		var r := s if i % 2 == 0 else s * 0.4
		points.append(p.pos + Vector2(cos(angle), sin(angle)) * r)
	
	if points.size() >= 3:
		draw_colored_polygon(points, p.color)


func _draw_food(p: Particle) -> void:
	# Círculo rojo (manzana simplificada)
	var s := p.size_val
	draw_circle(p.pos, s, p.color)
	# Tallo verde
	var stem_color := Color(0.3, 0.7, 0.2, p.color.a)
	draw_line(p.pos + Vector2(0, -s), p.pos + Vector2(2, -s - 4), stem_color, 2.0)


func _draw_tear(p: Particle) -> void:
	# Gota de agua (círculo + triángulo)
	var s := p.size_val
	draw_circle(p.pos + Vector2(0, s * 0.3), s, p.color)
	var tri := PackedVector2Array([
		p.pos + Vector2(0, -s),
		p.pos + Vector2(-s, s * 0.3),
		p.pos + Vector2(s, s * 0.3)
	])
	draw_colored_polygon(tri, p.color)


func _draw_sparkle(p: Particle) -> void:
	# Cruz brillante
	var s := p.size_val
	draw_line(p.pos + Vector2(-s, 0), p.pos + Vector2(s, 0), p.color, 1.5)
	draw_line(p.pos + Vector2(0, -s), p.pos + Vector2(0, s), p.color, 1.5)
	# Diagonal más tenue
	var faint := p.color
	faint.a *= 0.5
	draw_line(p.pos + Vector2(-s*0.6, -s*0.6), p.pos + Vector2(s*0.6, s*0.6), faint, 1.0)
	draw_line(p.pos + Vector2(s*0.6, -s*0.6), p.pos + Vector2(-s*0.6, s*0.6), faint, 1.0)
