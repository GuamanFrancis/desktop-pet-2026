class_name Inventory
extends Resource
## inventory.gd — Recurso Personalizado: Inventario del Jugador
## Maneja la colección de ítems, equipar/desequipar ropa, y usar consumibles.

## --- Señales ---
signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal item_equipped(item: ItemData, slot: String)
signal item_unequipped(slot: String)

## --- Propiedades ---

## Lista de todos los ítems en el inventario
@export var items: Array[ItemData] = []

## Mapa de ítems equipados: { "slot_name": ItemData }
## Ejemplo: { "head": <hat_crown>, "torso": <shirt_blue> }
@export var equipped: Dictionary = {}


## --- Gestión de Ítems ---

## Añade un ítem al inventario.
func add_item(item: ItemData) -> void:
	# Si es apilable, buscar si ya existe y aumentar cantidad
	if item.stackable:
		for existing in items:
			if existing.item_id == item.item_id:
				existing.quantity += item.quantity
				item_added.emit(item)
				print("[Inventario] 📦 +%d %s (total: %d)" % [
					item.quantity, item.display_name, existing.quantity
				])
				return
	
	items.append(item)
	item_added.emit(item)
	print("[Inventario] 📦 Añadido: %s" % item.display_name)


## Remueve un ítem del inventario. Retorna true si se removió.
func remove_item(item: ItemData) -> bool:
	var idx := items.find(item)
	if idx == -1:
		push_warning("[Inventario] Ítem no encontrado: %s" % item.display_name)
		return false
	
	# Si es apilable y tiene más de 1, solo reducir cantidad
	if item.stackable and item.quantity > 1:
		item.quantity -= 1
		item_removed.emit(item)
		print("[Inventario] 📦 -%d %s (quedan: %d)" % [1, item.display_name, item.quantity])
		return true
	
	items.remove_at(idx)
	item_removed.emit(item)
	print("[Inventario] 🗑️ Removido: %s" % item.display_name)
	return true


## --- Equipar / Desequipar ---

## Equipa un ítem en su slot correspondiente.
func equip_item(item: ItemData) -> bool:
	if not item.is_equippable():
		push_warning("[Inventario] '%s' no es equipable" % item.display_name)
		return false
	
	if item.spine_slot.is_empty():
		push_warning("[Inventario] '%s' no tiene slot de Spine definido" % item.display_name)
		return false
	
	# Desequipar lo que haya en ese slot primero
	if equipped.has(item.spine_slot):
		unequip_item(item.spine_slot)
	
	equipped[item.spine_slot] = item
	item_equipped.emit(item, item.spine_slot)
	print("[Inventario] 👕 Equipado '%s' en slot '%s'" % [item.display_name, item.spine_slot])
	return true


## Desequipa el ítem de un slot.
func unequip_item(slot: String) -> bool:
	if not equipped.has(slot):
		return false
	
	var item: ItemData = equipped[slot]
	equipped.erase(slot)
	item_unequipped.emit(slot)
	print("[Inventario] 👕 Desequipado slot '%s' (%s)" % [slot, item.display_name])
	return true


## --- Usar Consumibles ---

## Usa un ítem consumible, aplicando sus efectos a los stats.
func use_item(item: ItemData, stats: PetStats) -> bool:
	if not item.is_consumable():
		push_warning("[Inventario] '%s' no es consumible" % item.display_name)
		return false
	
	# Aplicar efectos
	item.apply_effects(stats)
	
	# Remover del inventario (o reducir cantidad)
	remove_item(item)
	return true


## --- Consultas ---

## Retorna todos los ítems de un tipo específico.
func get_items_by_type(type: ItemData.ItemType) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in items:
		if item.item_type == type:
			result.append(item)
	return result


## Retorna el ítem equipado en un slot, o null.
func get_equipped_in_slot(slot: String) -> ItemData:
	if equipped.has(slot):
		return equipped[slot]
	return null


## Retorna la cantidad total de ítems (contando stacks).
func get_total_item_count() -> int:
	var count := 0
	for item in items:
		count += item.quantity
	return count
