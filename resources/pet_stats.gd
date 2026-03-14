class_name PetStats
extends Resource
## pet_stats.gd — Recurso Personalizado: Atributos de la Mascota
## Contiene nivel, XP, hambre, felicidad, energía.
## Se serializa automáticamente con ResourceSaver.

## --- Señales ---
signal level_up(new_level: int)
signal stat_changed(stat_name: String, new_value: float)
@warning_ignore("unused_signal")
signal pet_died()

## --- Propiedades Exportadas (visibles en el Inspector de Godot) ---

@export var pet_name: String = "Mascota"
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next_level: int = 100

@export_range(0.0, 100.0) var hunger: float = 100.0
@export_range(0.0, 100.0) var happiness: float = 100.0
@export_range(0.0, 100.0) var energy: float = 100.0

## --- Constantes de Decaimiento ---

## Puntos que pierde cada stat por segundo (valores bajos = decaimiento lento)
const HUNGER_DECAY_RATE: float = 0.05      # ~5 puntos por cada 100 segundos
const HAPPINESS_DECAY_RATE: float = 0.03    # ~3 puntos por cada 100 segundos
const ENERGY_DECAY_RATE: float = 0.02       # ~2 puntos por cada 100 segundos

## Multiplicador de XP para cada nivel
const XP_GROWTH_FACTOR: float = 1.5


## --- Métodos de XP y Nivel ---

## Añade experiencia y sube de nivel si corresponde.
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * XP_GROWTH_FACTOR)
		level_up.emit(level)
		print("[PetStats] 🎉 ¡Subió al nivel %d! Siguiente nivel: %d XP" % [level, xp_to_next_level])
	stat_changed.emit("xp", float(xp))


## --- Métodos de Stats ---

## Alimenta a la mascota (sube hambre, un poco de felicidad).
func feed(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, 100.0)
	happiness = clampf(happiness + amount * 0.2, 0.0, 100.0)
	add_xp(10)
	stat_changed.emit("hunger", hunger)
	stat_changed.emit("happiness", happiness)
	print("[PetStats] 🍎 Alimentada: hambre=%.1f, felicidad=%.1f (+10 XP)" % [hunger, happiness])


## Juega con la mascota (sube felicidad, baja energía).
func play(amount: float) -> void:
	happiness = clampf(happiness + amount, 0.0, 100.0)
	energy = clampf(energy - amount * 0.5, 0.0, 100.0)
	add_xp(15)
	stat_changed.emit("happiness", happiness)
	stat_changed.emit("energy", energy)
	print("[PetStats] 🎮 Jugó: felicidad=%.1f, energía=%.1f (+15 XP)" % [happiness, energy])


## Descansa a la mascota (sube energía).
func rest(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, 100.0)
	stat_changed.emit("energy", energy)
	print("[PetStats] 💤 Descansó: energía=%.1f" % energy)


## Aplica el decaimiento natural de stats con el paso del tiempo.
## Llamado desde main.gd cada frame con delta.
func decay_stats(delta: float) -> void:
	var old_hunger := hunger
	var old_happiness := happiness
	var old_energy := energy
	
	hunger = clampf(hunger - HUNGER_DECAY_RATE * delta, 0.0, 100.0)
	happiness = clampf(happiness - HAPPINESS_DECAY_RATE * delta, 0.0, 100.0)
	energy = clampf(energy - ENERGY_DECAY_RATE * delta, 0.0, 100.0)
	
	# Penalización: si tiene mucha hambre, la felicidad baja más rápido
	if hunger < 20.0:
		happiness = clampf(happiness - HAPPINESS_DECAY_RATE * delta * 2.0, 0.0, 100.0)
	
	# Emitir señales solo si cambiaron significativamente (evitar spam)
	if absf(old_hunger - hunger) > 0.1:
		stat_changed.emit("hunger", hunger)
	if absf(old_happiness - happiness) > 0.1:
		stat_changed.emit("happiness", happiness)
	if absf(old_energy - energy) > 0.1:
		stat_changed.emit("energy", energy)


## --- Utilidades ---

## Retorna el estado general de la mascota (0.0 = terrible, 1.0 = perfecto).
func get_overall_mood() -> float:
	return (hunger + happiness + energy) / 300.0


## Retorna un texto descriptivo del estado de ánimo.
func get_mood_text() -> String:
	var mood := get_overall_mood()
	if mood > 0.8:
		return "Feliz"
	elif mood > 0.5:
		return "Normal"
	elif mood > 0.3:
		return "Triste"
	else:
		return "Crítico"
