class_name ItemData
extends Resource
## item_data.gd — Recurso Personalizado: Definición de un Ítem
## Cada ítem (ropa, comida, accesorio) es una instancia de este recurso.

## --- Tipos de Ítem ---
enum ItemType {
	CLOTHING,    ## Ropa (camiseta, pantalón, etc.)
	ACCESSORY,   ## Accesorio (sombrero, collar, gafas)
	FOOD,        ## Comida (restaura hambre)
	SPECIAL      ## Especial (ítems de evento, Twitch, etc.)
}

## --- Propiedades Exportadas ---

## Identificador único del ítem (ej. "hat_crown", "food_apple")
@export var item_id: String = ""
## Nombre visible para el jugador
@export var display_name: String = ""
## Descripción del ítem
@export_multiline var description: String = ""
## Tipo de ítem
@export var item_type: ItemType = ItemType.FOOD
## Slot de Spine donde se aplica la ropa/accesorio (para futuro §4)
## Ejemplo: "head", "torso", "left_hand"
@export var spine_slot: String = ""
## Efectos al usar el ítem sobre los stats de la mascota
## Ejemplo: {"hunger": 25.0, "happiness": 10.0}
@export var stat_effects: Dictionary = {}
## Ruta del ícono (para futuro UI de inventario)
@export var icon_path: String = ""
## Si el ítem se puede apilar (comida sí, ropa no)
@export var stackable: bool = false
## Cantidad actual (solo si stackable)
@export var quantity: int = 1
## Precio en moneda del juego (para Kushki §6)
@export var price: int = 0


## --- Métodos ---

## Aplica los efectos del ítem a los stats de la mascota.
## Retorna true si se aplicó correctamente.
func apply_effects(stats: PetStats) -> bool:
	if stat_effects.is_empty():
		return false
	
	for stat_name in stat_effects:
		var value: float = stat_effects[stat_name]
		match stat_name:
			"hunger":
				# Aplicar directamente, NO llamar feed() que ya añade XP
				stats.hunger = clampf(stats.hunger + value, 0.0, 100.0)
				stats.stat_changed.emit("hunger", stats.hunger)
			"happiness":
				stats.happiness = clampf(stats.happiness + value, 0.0, 100.0)
				stats.stat_changed.emit("happiness", stats.happiness)
			"energy":
				stats.rest(value)
			"xp":
				stats.add_xp(int(value))
			_:
				push_warning("[ItemData] Efecto desconocido: %s" % stat_name)
	
	print("[ItemData] ✅ Aplicados efectos de '%s'" % display_name)
	return true


## Retorna true si el ítem es equipable (ropa o accesorio).
func is_equippable() -> bool:
	return item_type == ItemType.CLOTHING or item_type == ItemType.ACCESSORY


## Retorna true si el ítem es consumible (comida).
func is_consumable() -> bool:
	return item_type == ItemType.FOOD
