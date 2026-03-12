extends Node
## save_manager.gd — Autoload: Persistencia Encriptada (§3 Anti-Cheat)
## Guarda datos con FileAccess.open_encrypted_with_pass() para prevenir
## edición manual del archivo de guardado.
## Migración automática desde formato .tres antiguo.

## --- Constantes ---
const SAVE_PATH_ENCRYPTED: String = "user://save_data.sav"
const SAVE_PATH_LEGACY: String = "user://save_data.tres"
const AUTO_SAVE_INTERVAL: float = 60.0

## --- Configuración ---
var _encryption_key: String = ""
var _legacy_encryption_key: String = ""

## --- Datos del Juego (accesibles globalmente via SaveManager) ---
var pet_stats: PetStats = null
var inventory: Inventory = null

## --- Nodos Internos ---
var _auto_save_timer: Timer = null


func _ready() -> void:
	_load_encryption_key()
	load_game()
	_setup_auto_save()
	print("[SaveManager] ✅ Sistema de persistencia encriptada inicializado.")
	print("[SaveManager] 📂 Ruta: %s" % ProjectSettings.globalize_path(SAVE_PATH_ENCRYPTED))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[SaveManager] 💾 Guardando antes de cerrar...")
		save_game()
		get_tree().quit()


## --- Guardado Encriptado ---

func save_game() -> void:
	if not pet_stats:
		push_warning("[SaveManager] ⚠️ No hay datos para guardar.")
		return
	
	var data := _serialize_to_dict()
	var json_string := JSON.stringify(data, "\t")
	
	# Crear backup antes de sobreescribir
	if FileAccess.file_exists(SAVE_PATH_ENCRYPTED):
		var backup_path := SAVE_PATH_ENCRYPTED + ".bak"
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(SAVE_PATH_ENCRYPTED),
			ProjectSettings.globalize_path(backup_path)
		)
	
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH_ENCRYPTED, FileAccess.WRITE, _encryption_key)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[SaveManager] ❌ Error al guardar: %s" % error_string(FileAccess.get_open_error()))


## --- Carga ---

func load_game() -> void:
	# 1. Intentar cargar archivo encriptado con clave actual
	if FileAccess.file_exists(SAVE_PATH_ENCRYPTED):
		if _load_encrypted(_encryption_key):
			return

		# 1b. Intentar con clave legacy si existe
		if not _legacy_encryption_key.is_empty():
			if _load_encrypted(_legacy_encryption_key):
				print("[SaveManager] 🔄 Migrando datos a nueva clave de encriptación...")
				save_game() # Re-encriptar con la clave nueva
				return
	
	# 2. Intentar recuperar desde backup
	var backup_path := SAVE_PATH_ENCRYPTED + ".bak"
	if FileAccess.file_exists(backup_path):
		print("[SaveManager] 🔄 Intentando recuperar desde backup...")
		# Copiar backup sobre el archivo principal
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(backup_path),
			ProjectSettings.globalize_path(SAVE_PATH_ENCRYPTED)
		)
		if _load_encrypted(_encryption_key):
			print("[SaveManager] ✅ Recuperado exitosamente desde backup.")
			return

		if not _legacy_encryption_key.is_empty():
			if _load_encrypted(_legacy_encryption_key):
				print("[SaveManager] ✅ Recuperado desde backup usando clave legacy. Migrando...")
				save_game()
				return
	
	# 3. Intentar migrar archivo .tres antiguo
	if ResourceLoader.exists(SAVE_PATH_LEGACY):
		if _migrate_legacy():
			return
	
	# 4. Crear partida nueva
	_create_new_game()


func _load_encrypted(key: String) -> bool:
	if key.is_empty():
		return false

	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH_ENCRYPTED, FileAccess.READ, key)
	if not file:
		push_warning("[SaveManager] ⚠️ No se pudo abrir archivo encriptado.")
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_warning("[SaveManager] ⚠️ JSON corrupto en save file.")
		return false
	
	var data: Dictionary = json.data as Dictionary
	if not data or not _deserialize_from_dict(data):
		push_warning("[SaveManager] ⚠️ Datos inválidos en save file.")
		return false
	
	print("[SaveManager] 📂 Datos cargados (encriptado): %s Lv.%d" % [pet_stats.pet_name, pet_stats.level])
	return true


func _migrate_legacy() -> bool:
	var loaded = ResourceLoader.load(SAVE_PATH_LEGACY)
	if loaded is SaveData:
		pet_stats = loaded.pet_stats
		inventory = loaded.inventory
		# Guardar en formato nuevo
		save_game()
		print("[SaveManager] 🔄 Migración exitosa: .tres → .sav encriptado")
		return true
	return false


## --- Serialización Manual ---

func _serialize_to_dict() -> Dictionary:
	var data := {}
	
	# PetStats
	data["pet"] = {
		"name": pet_stats.pet_name,
		"level": pet_stats.level,
		"xp": pet_stats.xp,
		"xp_next": pet_stats.xp_to_next_level,
		"hunger": pet_stats.hunger,
		"happiness": pet_stats.happiness,
		"energy": pet_stats.energy,
	}
	
	# Inventory
	var items: Array[Dictionary] = []
	if inventory:
		for item: ItemData in inventory.items:
			items.append({
				"id": item.item_id,
				"name": item.display_name,
				"desc": item.description,
				"type": item.item_type,
				"stackable": item.stackable,
				"quantity": item.quantity,
				"effects": item.stat_effects,
			})
	data["inventory"] = items
	
	# Integridad
	var hash_input := JSON.stringify(data["pet"])
	data["checksum"] = hash_input.sha256_text()
	
	return data


func _deserialize_from_dict(data: Dictionary) -> bool:
	if not data.has("pet"):
		return false
	
	# Verificar integridad
	if data.has("checksum"):
		var expected := JSON.stringify(data["pet"]).sha256_text()
		if expected != data["checksum"] as String:
			push_warning("[SaveManager] ⚠️ ¡Checksum inválido! Posible manipulación.")
			# Aún así cargamos, pero advertimos
	
	# PetStats
	pet_stats = PetStats.new()
	var pet_data: Dictionary = data["pet"] as Dictionary
	pet_stats.pet_name = pet_data.get("name", "Mascota") as String
	pet_stats.level = int(pet_data.get("level", 1))
	pet_stats.xp = int(pet_data.get("xp", 0))
	pet_stats.xp_to_next_level = int(pet_data.get("xp_next", 100))
	pet_stats.hunger = float(pet_data.get("hunger", 100.0))
	pet_stats.happiness = float(pet_data.get("happiness", 100.0))
	pet_stats.energy = float(pet_data.get("energy", 100.0))
	
	# Inventory
	inventory = Inventory.new()
	if data.has("inventory"):
		for item_dict: Dictionary in data["inventory"]:
			var item := ItemData.new()
			item.item_id = item_dict.get("id", "") as String
			item.display_name = item_dict.get("name", "") as String
			item.description = item_dict.get("desc", "") as String
			item.item_type = int(item_dict.get("type", 0))
			item.stackable = bool(item_dict.get("stackable", false))
			item.quantity = int(item_dict.get("quantity", 1))
			item.stat_effects = item_dict.get("effects", {}) as Dictionary
			inventory.add_item(item)
	
	return true


## --- Nuevo Juego ---

func _create_new_game() -> void:
	pet_stats = PetStats.new()
	inventory = Inventory.new()
	
	# Ítems iniciales
	var apple := ItemData.new()
	apple.item_id = "food_apple"
	apple.display_name = "Manzana"
	apple.description = "Una manzana fresca. Restaura hambre."
	apple.item_type = ItemData.ItemType.FOOD
	apple.stackable = true
	apple.quantity = 3
	apple.stat_effects = { "hunger": 15.0, "happiness": 5.0 }
	inventory.add_item(apple)
	
	var cookie := ItemData.new()
	cookie.item_id = "food_cookie"
	cookie.display_name = "Galleta"
	cookie.description = "Galleta de chocolate. +felicidad."
	cookie.item_type = ItemData.ItemType.FOOD
	cookie.stackable = true
	cookie.quantity = 2
	cookie.stat_effects = { "hunger": 8.0, "happiness": 15.0 }
	inventory.add_item(cookie)
	
	print("[SaveManager] 🆕 Nueva partida creada: %s" % pet_stats.pet_name)
	save_game()


## --- Auto-guardado ---

func _setup_auto_save() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)


func _on_auto_save() -> void:
	save_game()


func _load_encryption_key() -> void:
	# 1. Intentar desde variables de entorno (Recomendado para producción)
	_encryption_key = OS.get_environment("SAVE_ENCRYPTION_KEY")
	_legacy_encryption_key = OS.get_environment("LEGACY_SAVE_ENCRYPTION_KEY")

	# 2. Intentar desde ProjectSettings (como fallback)
	if _encryption_key.is_empty():
		if ProjectSettings.has_setting("application/config/save_key"):
			_encryption_key = ProjectSettings.get_setting("application/config/save_key")

	if _legacy_encryption_key.is_empty():
		if ProjectSettings.has_setting("application/config/legacy_save_key"):
			_legacy_encryption_key = ProjectSettings.get_setting("application/config/legacy_save_key")

	# 3. Fallback dinámico si no hay ninguna clave
	if _encryption_key.is_empty():
		# Generamos una clave basada en el ID único del dispositivo como último recurso
		_encryption_key = OS.get_unique_id()
		push_warning("[SaveManager] ⚠️ Usando clave generada dinámicamente. Configure SAVE_ENCRYPTION_KEY para mayor seguridad.")
