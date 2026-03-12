extends Window

var _lifetime: float = 5.0
var _timer: float = 0.0
var _label: Label

func _ready() -> void:
	# Configure window
	transparent = true
	borderless = true
	always_on_top = true
	unfocusable = false
	gui_embed_subwindows = false
	size = Vector2i(100, 100)

	# Make background fully transparent
	transparent_bg = true

	# Optional: Set clear color
	# RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))

	# Position near the mouse
	var mouse_pos := DisplayServer.mouse_get_position()
	position = mouse_pos - size / 2

	# Create the visual element (a label with emoji or a color rect)
	_label = Label.new()
	_label.text = "💩" # or whatever
	_label.add_theme_font_size_override("font_size", 64)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

	print("[DroppedObject] Spawned at ", position)


func _process(delta: float) -> void:
	_timer += delta

	# Optional: fade out
	if _timer > _lifetime - 1.0:
		if _label:
			_label.modulate.a = max(0.0, _lifetime - _timer)

	if _timer >= _lifetime:
		queue_free()
