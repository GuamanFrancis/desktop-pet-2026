extends Node
## ai_brain.gd — Motor de IA Local (Cerebro de la Mascota)
## Monitorea stats, genera diálogos contextuales, y prepara la interfaz
## para futura conexión con IA Cloud (Inworld/Convai §5).

## --- Señales ---
signal dialogue_requested(text: String)
signal action_requested(action: String, params: Dictionary)

## --- Configuración ---
const THINK_INTERVAL: float = 12.0       # Cada cuántos segundos "piensa"
const IDLE_CHAT_MIN: float = 30.0        # Mínimo entre charlas idle
const IDLE_CHAT_MAX: float = 90.0        # Máximo entre charlas idle
const COOLDOWN_AFTER_SPEAK: float = 8.0  # No hablar de nuevo tan rápido

## --- Estado ---
var _think_timer: Timer = null
var _idle_chat_timer: Timer = null
var _cooldown: float = 0.0
var _last_state: String = ""
var _messages_said: Dictionary = {}  # Track de mensajes para evitar repetición

## --- Referencia a stats (inyectada por main.gd) ---
var pet_stats: Resource = null
var state_machine: Node = null

## --- Tablas de Diálogo ---

## Diálogos por umbral de stats
const HUNGER_DIALOGUES := {
	90: ["¡Mi estómago ruge como un T-Rex! 🦕", "¿No hueles algo rico? Yo sí... es MI HAMBRE.", "Comidaaaa... por favooor..."],
	70: ["Empiezo a tener hambre...", "Un snack no vendría mal 🍪", "¿Ya es hora de comer?"],
	50: ["Estoy bien, pero un bocadito sería genial.", "Hmm, ¿qué habrá de comer hoy?"],
}

const HAPPINESS_DIALOGUES := {
	20: ["Me siento solo... 😢", "¿Podemos jugar un rato?", "Echo de menos la diversión..."],
	40: ["Estoy un poco aburrido.", "¡Quiero hacer algo divertido!", "¿Jugamos?"],
}

const ENERGY_DIALOGUES := {
	20: ["Zzz... necesito una siesta... 😴", "Mis ojitos se cierran solos...", "¿Puedo descansar un ratito?"],
	35: ["Estoy cansadito...", "Un descanso me vendría bien."],
}

## Diálogos de reacción a acciones
const REACTION_DIALOGUES := {
	"fed": ["¡Ñam ñam! ¡Delicioso! 🍖", "¡Gracias por la comida!", "¡Qué rico estaba eso!", "¡Mi pancita está feliz!"],
	"played": ["¡Weee! ¡Qué divertido! ⭐", "¡Otra vez, otra vez!", "¡Me encanta jugar contigo!", "¡Eso fue épico!"],
	"woke_up": ["¡Buenos días! ☀️ ¿Qué hacemos hoy?", "¡Qué buena siesta! Listo para la acción.", "*bostezo* ...¡Ya desperté!"],
	"level_up": ["¡NIVEL NUEVO! ¡Soy más fuerte! 💪", "¡¡LEVEL UP!! ¡¡Woohoo!!", "¡Evolucioné! ¿Notas algo diferente?"],
}

## Diálogos idle (aleatorios)
const IDLE_DIALOGUES := [
	"¿Sabías que los dinosaurios dominaron la Tierra por 165 millones de años? 🌍",
	"*mira a la izquierda* *mira a la derecha* ...¿qué hacía?",
	"Me pregunto cómo será el espacio exterior... 🚀",
	"¡Hoy es un gran día para ser un dinosaurio!",
	"*tararea una canción* 🎵 La la laaa~",
	"¿Tú también sientes que el tiempo vuela?",
	"Si fuera un chef, haría galletas con forma de meteorito 🍪",
	"*practicando su rugido* ...rawr! No, mucho. ...raawr? Mejor.",
	"Echo de menos el Cretácico... era más sencillo todo.",
	"¡Oye! ¡Gracias por tenerme en tu escritorio! 💚",
	"¿Qué es esa cosa... un 'mouse'? ¿Se come? 🖱️",
	"A veces sueño con volcanes... pero de chocolate 🌋",
	"*cuenta las nubes* una... dos... ¿esa es un brócoli?",
	"Mi cola es mi mejor rasgo, ¿verdad? *la mueve*",
	"¡Rawr! ...perdón, me emocioné.",
]

## Diálogos de saludo (primera interacción del día)
const GREETING_DIALOGUES := [
	"¡Hola! ¡Me alegra verte! 🎉",
	"¡Hey! ¡Bienvenido de vuelta!",
	"¡Al fin! ¡Te estaba esperando! 💚",
]


func _ready() -> void:
	# Timer de pensamiento
	_think_timer = Timer.new()
	_think_timer.wait_time = THINK_INTERVAL
	_think_timer.timeout.connect(_on_think)
	_think_timer.autostart = true
	add_child(_think_timer)
	
	# Timer de idle chat
	_idle_chat_timer = Timer.new()
	_idle_chat_timer.one_shot = true
	_idle_chat_timer.timeout.connect(_on_idle_chat)
	add_child(_idle_chat_timer)
	_schedule_next_idle_chat()
	
	# Saludo inicial (con delay)
	await get_tree().create_timer(3.0).timeout
	_say(GREETING_DIALOGUES.pick_random())
	
	print("[AIBrain] ✅ Cerebro de IA inicializado.")


## --- API Pública ---

## Notifica una acción del usuario/sistema para generar reacción.
func notify_action(action_name: String) -> void:
	if REACTION_DIALOGUES.has(action_name):
		var pool: Array = REACTION_DIALOGUES[action_name]
		_say(_pick_unique(pool, action_name))


## Notifica cambio de estado de la máquina de estados.
func notify_state_changed(old_state: String, new_state: String) -> void:
	if old_state == "sleeping" and new_state != "sleeping":
		notify_action("woke_up")
	_last_state = new_state


## Notifica level up.
func notify_level_up(new_level: int) -> void:
	var pool: Array = REACTION_DIALOGUES["level_up"]
	var msg: String = _pick_unique(pool, "level_up")
	msg = msg.replace("[X]", str(new_level))
	_say(msg)


## Interfaz para IA Cloud futura (§5) --
## Cuando se conecte Inworld/Convai, este método recibirá la respuesta.
func process_cloud_response(response: Dictionary) -> void:
	if response.has("text"):
		_say(str(response["text"]))
	if response.has("action"):
		var params = response.get("params", {})
		if typeof(params) != TYPE_DICTIONARY:
			params = {}
		action_requested.emit(str(response["action"]), params)


## --- Lógica de Pensamiento ---

func _on_think() -> void:
	if _cooldown > 0:
		_cooldown -= THINK_INTERVAL
		return
	
	if not pet_stats:
		return
	
	# Evaluar stats y decir algo si algo está mal
	var hunger: float = pet_stats.hunger
	var happiness: float = pet_stats.happiness
	var energy: float = pet_stats.energy
	
	# Prioridad: hambre > energía > felicidad
	if _check_stat_dialogue(hunger, HUNGER_DIALOGUES, "hunger"):
		return
	if _check_stat_dialogue(100.0 - energy, ENERGY_DIALOGUES, "energy"):
		# Energy dialogues trigger when energy is LOW, so we invert
		return
	if _check_stat_dialogue(100.0 - happiness, HAPPINESS_DIALOGUES, "happiness"):
		return


func _check_stat_dialogue(value: float, table: Dictionary, category: String) -> bool:
	# Buscar el umbral más alto que se supere
	var thresholds: Array = table.keys()
	thresholds.sort()
	thresholds.reverse()  # Mayor primero
	
	for threshold: int in thresholds:
		if value >= threshold:
			var pool: Array = table[threshold]
			_say(_pick_unique(pool, category + str(threshold)))
			return true
	
	return false


## --- Idle Chat ---

func _on_idle_chat() -> void:
	if _cooldown > 0:
		_schedule_next_idle_chat()
		return
	
	_say(IDLE_DIALOGUES.pick_random())
	_schedule_next_idle_chat()


func _schedule_next_idle_chat() -> void:
	_idle_chat_timer.wait_time = randf_range(IDLE_CHAT_MIN, IDLE_CHAT_MAX)
	_idle_chat_timer.start()


## --- Utilidades ---

func _say(text: String) -> void:
	dialogue_requested.emit(text)
	_cooldown = COOLDOWN_AFTER_SPEAK


## Evita repetir el mismo mensaje dos veces seguidas en una categoría.
func _pick_unique(pool: Array, category: String) -> String:
	if pool.size() <= 1:
		return pool[0] if pool.size() > 0 else ""
	
	var last_said: String = str(_messages_said.get(category, ""))
	var filtered: Array = pool.filter(func(m: String) -> bool: return m != last_said)
	var chosen: String = filtered.pick_random() if filtered.size() > 0 else pool.pick_random()
	_messages_said[category] = chosen
	return chosen
