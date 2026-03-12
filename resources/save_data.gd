class_name SaveData
extends Resource
## save_data.gd — Recurso contenedor para serializar todo el estado del juego.
## Usado internamente por SaveManager para guardar/cargar en un solo archivo.

## Stats de la mascota
@export var pet_stats: PetStats = null
## Inventario del jugador
@export var inventory: Inventory = null
