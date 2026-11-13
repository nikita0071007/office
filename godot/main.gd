extends Node3D

const AVATAR_PATH := "res://assets/lisa-cutout.webp"
const STATUS_PATH := "res://status.json"
const STATUS_URL := "https://raw.githubusercontent.com/nikita0071007/office/main/status.json"
const STATUS_REFRESH_SECONDS := 60.0

const CAMERA_TARGET := Vector3(0.0, 1.2, 0.0)
const DEFAULT_YAW := 0.18
const DEFAULT_PITCH := 0.14
const DEFAULT_DISTANCE := 9.4
const AGENT_ORDER := ["community", "analyst", "poster", "guard", "editor", "video", "critic", "coach", "archivist", "producer", "orders"]
const AGENT_META := {
	"community": {"name": "Лиза", "role": "Комьюнити-менеджер"},
	"analyst": {"name": "Аналитик", "role": "Аналитик"},
	"poster": {"name": "Публикатор", "role": "Публикация контента"},
	"guard": {"name": "Страж", "role": "Проверка процессов"},
	"editor": {"name": "Редактор", "role": "Редактура"},
	"video": {"name": "Видео", "role": "Видеомонтаж"},
	"critic": {"name": "Критик", "role": "Проверка качества"},
	"coach": {"name": "Коуч", "role": "Обучение"},
	"archivist": {"name": "Архивариус", "role": "Архив"},
	"producer": {"name": "Продюсер", "role": "Продюсирование"},
	"orders": {"name": "Заказы", "role": "Клиентские заказы"},
}
const STATUS_LABELS := {
	"working": "Работает",
	"waiting": "Ждёт ответа",
	"idle": "Готов",
	"error": "Нужна проверка",
}
const STATUS_COLORS := {
	"working": Color("#9bdfc6"),
	"waiting": Color("#f0d58c"),
	"idle": Color("#c0cbd0"),
	"error": Color("#ef9b95"),
}

var camera: Camera3D
var avatar: Sprite3D
var roster_panel: PanelContainer
var roster_list: VBoxContainer
var connection_label: Label
var profile_panel: PanelContainer
var agent_name_label: Label
var agent_role_label: Label
var status_label: Label
var task_label: Label
var agent_data: Dictionary = {}
var agent_buttons: Dictionary = {}
var roster_button_group: ButtonGroup
var status_request: HTTPRequest
var status_timer: Timer
var request_pending := false
var selected_agent := "community"
var dragging := false
var yaw := DEFAULT_YAW
var pitch := DEFAULT_PITCH
var distance := DEFAULT_DISTANCE


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_camera()
	_build_lisa()
	_build_hud()
	_load_agent_statuses()
	_build_status_sync()
	_update_camera()
	_layout_hud()


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#17232b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c6d5d6")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	add_child(world)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Window Light"
	sunlight.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	sunlight.light_color = Color("#fff0da")
	sunlight.light_energy = 1.2
	sunlight.shadow_enabled = true
	add_child(sunlight)

	var fill_light := OmniLight3D.new()
	fill_light.name = "Warm Room Light"
	fill_light.position = Vector3(0.0, 2.7, 0.0)
	fill_light.light_color = Color("#d3e7e1")
	fill_light.light_energy = 0.55
	fill_light.omni_range = 7.0
	add_child(fill_light)


func _build_room() -> void:
	_add_box("Floor", Vector3(10.0, 0.16, 10.0), Vector3(0.0, -0.08, 0.0), Color("#887866"))
	_add_box("Back Wall", Vector3(10.0, 3.5, 0.18), Vector3(0.0, 1.75, -4.9), Color("#d8d8d0"))
	_add_box("Left Wall", Vector3(0.18, 3.5, 10.0), Vector3(-4.9, 1.75, 0.0), Color("#b8bbb4"))
	_add_box("Right Wall", Vector3(0.18, 3.5, 10.0), Vector3(4.9, 1.75, 0.0), Color("#a1aaa8"))

	_build_window()
	_build_wall_board()
	_build_workstation(Vector3(-0.6, 0.0, -0.55), "Lisa's Desk")
	_build_workstation(Vector3(-2.3, 0.0, 1.9), "Team Desk")
	_build_plant(Vector3(-3.45, 0.0, 0.55))
	_build_plant(Vector3(3.85, 0.0, -3.7))
	_build_rug()


func _build_window() -> void:
	_add_box("Window Glass", Vector3(3.15, 1.72, 0.035), Vector3(-2.2, 2.12, -4.77), Color("#9ebbc7"), 0.25)
	_add_box("Window Left Frame", Vector3(0.075, 1.9, 0.09), Vector3(-3.82, 2.12, -4.73), Color("#f0eee7"))
	_add_box("Window Right Frame", Vector3(0.075, 1.9, 0.09), Vector3(-0.58, 2.12, -4.73), Color("#f0eee7"))
	_add_box("Window Top Frame", Vector3(3.28, 0.075, 0.09), Vector3(-2.2, 3.03, -4.73), Color("#f0eee7"))
	_add_box("Window Bottom Frame", Vector3(3.28, 0.075, 0.09), Vector3(-2.2, 1.2, -4.73), Color("#f0eee7"))
	_add_box("Window Mullion", Vector3(0.055, 1.74, 0.09), Vector3(-2.2, 2.12, -4.72), Color("#ede9df"))
	_add_box("Window Sill", Vector3(3.48, 0.13, 0.34), Vector3(-2.2, 1.06, -4.62), Color("#aa8868"))


func _build_wall_board() -> void:
	_add_box("Planning Board", Vector3(2.0, 1.45, 0.09), Vector3(2.6, 2.0, -4.72), Color("#e8e4da"))
	_add_box("Board Header", Vector3(1.58, 0.13, 0.025), Vector3(2.58, 2.5, -4.655), Color("#628e86"))
	_add_box("Note 1", Vector3(0.36, 0.3, 0.03), Vector3(2.05, 2.08, -4.65), Color("#e4cb88"))
	_add_box("Note 2", Vector3(0.36, 0.3, 0.03), Vector3(2.62, 2.08, -4.65), Color("#d6b4b8"))
	_add_box("Note 3", Vector3(0.36, 0.3, 0.03), Vector3(3.18, 2.08, -4.65), Color("#b7c9b0"))
	_add_box("Board Shelf", Vector3(1.1, 0.07, 0.18), Vector3(2.6, 1.12, -4.62), Color("#947250"))


func _build_workstation(center: Vector3, workstation_name: String) -> void:
	var x := center.x
	var z := center.z
	_add_box(workstation_name + " Top", Vector3(2.3, 0.12, 1.25), Vector3(x, 0.76, z), Color("#b78961"))
	_add_box(workstation_name + " Leg A", Vector3(0.11, 0.72, 0.11), Vector3(x - 1.0, 0.35, z - 0.47), Color("#4c4d49"))
	_add_box(workstation_name + " Leg B", Vector3(0.11, 0.72, 0.11), Vector3(x + 1.0, 0.35, z - 0.47), Color("#4c4d49"))
	_add_box(workstation_name + " Leg C", Vector3(0.11, 0.72, 0.11), Vector3(x - 1.0, 0.35, z + 0.47), Color("#4c4d49"))
	_add_box(workstation_name + " Leg D", Vector3(0.11, 0.72, 0.11), Vector3(x + 1.0, 0.35, z + 0.47), Color("#4c4d49"))

	_add_box(workstation_name + " Monitor", Vector3(0.95, 0.62, 0.1), Vector3(x, 1.18, z - 0.34), Color("#303b42"), 0.35)
	_add_box(workstation_name + " Screen", Vector3(0.82, 0.49, 0.015), Vector3(x, 1.18, z - 0.282), Color("#3e6967"), 0.3)
	_add_box(workstation_name + " Monitor Stand", Vector3(0.13, 0.18, 0.11), Vector3(x, 0.88, z - 0.3), Color("#5b6463"))
	_add_box(workstation_name + " Keyboard", Vector3(0.68, 0.035, 0.24), Vector3(x, 0.855, z + 0.12), Color("#394247"), 0.45)

	_add_box(workstation_name + " Chair Seat", Vector3(0.72, 0.12, 0.72), Vector3(x, 0.52, z + 1.1), Color("#46555d"))
	_add_box(workstation_name + " Chair Back", Vector3(0.72, 0.72, 0.12), Vector3(x, 0.93, z + 1.4), Color("#394a53"))
	_add_box(workstation_name + " Chair Stem", Vector3(0.09, 0.44, 0.09), Vector3(x, 0.28, z + 1.1), Color("#475150"))
	_add_box(workstation_name + " Chair Base", Vector3(0.72, 0.08, 0.72), Vector3(x, 0.07, z + 1.1), Color("#414a4d"))

	_add_cylinder(workstation_name + " Mug", 0.1, 0.12, 0.16, Vector3(x + 0.76, 0.9, z + 0.17), Color("#e3e0d7"))


func _build_plant(position: Vector3) -> void:
	_add_cylinder("Plant Pot", 0.25, 0.34, 0.48, position + Vector3(0.0, 0.24, 0.0), Color("#a96f56"))
	_add_sphere("Plant Leaf A", position + Vector3(-0.2, 0.82, 0.0), Vector3(0.16, 0.46, 0.14), Color("#557d67"))
	_add_sphere("Plant Leaf B", position + Vector3(0.18, 0.88, 0.04), Vector3(0.16, 0.5, 0.14), Color("#668b6d"))
	_add_sphere("Plant Leaf C", position + Vector3(0.0, 0.95, -0.18), Vector3(0.14, 0.43, 0.13), Color("#78966f"))
	_add_sphere("Plant Leaf D", position + Vector3(0.0, 0.96, 0.2), Vector3(0.14, 0.42, 0.12), Color("#4d765f"))


func _build_rug() -> void:
	_add_box("Office Rug", Vector3(3.8, 0.025, 2.6), Vector3(0.55, 0.015, 1.55), Color("#a69783"))
	_add_box("Rug Border", Vector3(3.48, 0.028, 2.28), Vector3(0.55, 0.033, 1.55), Color("#897967"))
	_add_box("Rug Center", Vector3(3.22, 0.03, 2.02), Vector3(0.55, 0.05, 1.55), Color("#a89a86"))


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Office Camera"
	camera.current = true
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)


func _build_lisa() -> void:
	var texture := load(AVATAR_PATH) as Texture2D
	if texture == null:
		push_warning("Lisa portrait was not found at %s" % AVATAR_PATH)
		return

	var shadow := _add_cylinder("Lisa Floor Shadow", 0.68, 0.72, 0.025, Vector3(2.55, 0.025, 0.55), Color(0.06, 0.07, 0.07, 0.24))
	shadow.scale = Vector3(1.0, 1.0, 0.45)
	var shadow_material := shadow.material_override as StandardMaterial3D
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	avatar = Sprite3D.new()
	avatar.name = "Lisa Photo Billboard"
	avatar.texture = texture
	avatar.pixel_size = 0.0022
	avatar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	avatar.position = Vector3(2.55, 1.27, 0.55)
	avatar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(avatar)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var title := Label.new()
	title.text = "ОФИС АГЕНТОВ  ·  GODOT"
	title.position = Vector2(24.0, 20.0)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#f1f4f3"))
	root.add_child(title)

	roster_panel = PanelContainer.new()
	roster_panel.name = "Agent Roster"
	roster_panel.position = Vector2(24.0, 56.0)
	roster_panel.custom_minimum_size = Vector2(254.0, 0.0)
	roster_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(roster_panel)

	var roster_content := VBoxContainer.new()
	roster_content.add_theme_constant_override("separation", 8)
	roster_panel.add_child(roster_content)

	var roster_header := HBoxContainer.new()
	roster_content.add_child(roster_header)

	var roster_title := Label.new()
	roster_title.text = "КОМАНДА"
	roster_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_title.add_theme_font_size_override("font_size", 11)
	roster_title.add_theme_color_override("font_color", Color("#8ecbc1"))
	roster_header.add_child(roster_title)

	var roster_count := Label.new()
	roster_count.text = "%d агентов" % AGENT_ORDER.size()
	roster_count.add_theme_font_size_override("font_size", 10)
	roster_count.add_theme_color_override("font_color", Color("#aab8bd"))
	roster_header.add_child(roster_count)

	connection_label = Label.new()
	connection_label.text = "● локальная копия"
	connection_label.add_theme_font_size_override("font_size", 10)
	connection_label.add_theme_color_override("font_color", Color("#aab8bd"))
	roster_content.add_child(connection_label)

	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size = Vector2(222.0, 350.0)
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_content.add_child(roster_scroll)

	roster_list = VBoxContainer.new()
	roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_list.add_theme_constant_override("separation", 4)
	roster_scroll.add_child(roster_list)

	var hint := Label.new()
	hint.text = "Перетаскивайте мышью, чтобы осмотреть комнату · Колесо — масштаб"
	hint.position = Vector2(24.0, -42.0)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#d3dcdf"))
	root.add_child(hint)

	profile_panel = PanelContainer.new()
	profile_panel.name = "Lisa Profile"
	profile_panel.anchor_left = 1.0
	profile_panel.anchor_right = 1.0
	profile_panel.anchor_top = 0.5
	profile_panel.anchor_bottom = 0.5
	profile_panel.offset_left = -342.0
	profile_panel.offset_right = -24.0
	profile_panel.offset_top = -135.0
	profile_panel.offset_bottom = 135.0
	profile_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(profile_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	profile_panel.add_child(content)

	var kicker := Label.new()
	kicker.text = "АГЕНТ"
	kicker.add_theme_font_size_override("font_size", 10)
	kicker.add_theme_color_override("font_color", Color("#8ecbc1"))
	content.add_child(kicker)

	agent_name_label = Label.new()
	agent_name_label.text = "Лиза"
	agent_name_label.add_theme_font_size_override("font_size", 30)
	agent_name_label.add_theme_color_override("font_color", Color("#f2f4f3"))
	content.add_child(agent_name_label)

	agent_role_label = Label.new()
	agent_role_label.text = "Комьюнити-менеджер"
	agent_role_label.add_theme_font_size_override("font_size", 14)
	agent_role_label.add_theme_color_override("font_color", Color("#d5dfe1"))
	content.add_child(agent_role_label)

	status_label = Label.new()
	status_label.text = "● В офисе"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#a9d7ca"))
	content.add_child(status_label)

	task_label = Label.new()
	task_label.text = "Следит за комментариями и готовит ответы для команды."
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.add_theme_font_size_override("font_size", 13)
	task_label.add_theme_color_override("font_color", Color("#b9c5ca"))
	content.add_child(task_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)

	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(42.0, 38.0)
	zoom_out.pressed.connect(_zoom_out)
	buttons.add_child(zoom_out)

	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(42.0, 38.0)
	zoom_in.pressed.connect(_zoom_in)
	buttons.add_child(zoom_in)

	var reset := Button.new()
	reset.text = "Сбросить вид"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.custom_minimum_size = Vector2(0.0, 38.0)
	reset.pressed.connect(_reset_camera)
	buttons.add_child(reset)

	get_viewport().size_changed.connect(_layout_hud)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.15, 0.92)
	style.border_color = Color(0.72, 0.82, 0.83, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16.0
	style.content_margin_top = 16.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 16.0
	return style


func _layout_hud() -> void:
	if profile_panel == null or roster_panel == null:
		return

	var width := get_viewport().get_visible_rect().size.x
	roster_panel.visible = width >= 980.0
	roster_panel.anchor_left = 0.0
	roster_panel.anchor_right = 0.0
	roster_panel.anchor_top = 0.0
	roster_panel.anchor_bottom = 0.0
	roster_panel.offset_left = 24.0
	roster_panel.offset_right = 278.0
	roster_panel.offset_top = 56.0
	roster_panel.offset_bottom = 455.0
	if width < 720.0:
		profile_panel.anchor_left = 0.0
		profile_panel.anchor_right = 1.0
		profile_panel.anchor_top = 1.0
		profile_panel.anchor_bottom = 1.0
		profile_panel.offset_left = 12.0
		profile_panel.offset_right = -12.0
		profile_panel.offset_top = -240.0
		profile_panel.offset_bottom = -58.0
	else:
		profile_panel.anchor_left = 1.0
		profile_panel.anchor_right = 1.0
		profile_panel.anchor_top = 0.5
		profile_panel.anchor_bottom = 0.5
		profile_panel.offset_left = -342.0
		profile_panel.offset_right = -24.0
		profile_panel.offset_top = -135.0
		profile_panel.offset_bottom = 135.0


func _load_agent_statuses() -> void:
	if FileAccess.file_exists(STATUS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATUS_PATH))
		if parsed is Dictionary:
			var agents: Variant = parsed.get("agents", {})
			if agents is Dictionary:
				agent_data = agents

	_populate_agent_roster()
	_select_agent(selected_agent)


func _build_status_sync() -> void:
	status_request = HTTPRequest.new()
	status_request.timeout = 8.0
	status_request.request_completed.connect(_on_status_request_completed)
	add_child(status_request)

	status_timer = Timer.new()
	status_timer.wait_time = STATUS_REFRESH_SECONDS
	status_timer.timeout.connect(_request_status_update)
	add_child(status_timer)
	status_timer.start()
	_request_status_update()


func _request_status_update() -> void:
	if request_pending or status_request == null:
		return

	request_pending = true
	var url := STATUS_URL + "?t=" + str(Time.get_ticks_msec())
	var error := status_request.request(url)
	if error != OK:
		request_pending = false
		_set_connection_online(false)


func _on_status_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_pending = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_connection_online(false)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_set_connection_online(false)
		return

	var agents: Variant = parsed.get("agents", {})
	if not agents is Dictionary:
		_set_connection_online(false)
		return

	agent_data = agents
	_populate_agent_roster()
	_select_agent(selected_agent)
	_set_connection_online(true)


func _set_connection_online(online: bool) -> void:
	if connection_label == null:
		return
	if online:
		connection_label.text = "● онлайн · обновлено"
		connection_label.add_theme_color_override("font_color", Color("#9bdfc6"))
	else:
		connection_label.text = "● офлайн · локальная копия"
		connection_label.add_theme_color_override("font_color", Color("#aab8bd"))


func _populate_agent_roster() -> void:
	if roster_list == null:
		return

	for child in roster_list.get_children():
		child.queue_free()
	agent_buttons.clear()
	roster_button_group = ButtonGroup.new()

	for agent_key in AGENT_ORDER:
		var key := str(agent_key)
		var meta: Dictionary = AGENT_META.get(key, {"name": key.capitalize(), "role": "AI-агент"})
		var raw_data: Variant = agent_data.get(key, {})
		var data: Dictionary = raw_data if raw_data is Dictionary else {}
		var state := str(data.get("status", "idle"))
		var status_text := str(STATUS_LABELS.get(state, "В офисе"))
		var agent_button := Button.new()
		agent_button.text = "●  %s   ·   %s" % [str(meta.get("name", agent_key)), status_text]
		agent_button.toggle_mode = true
		agent_button.button_group = roster_button_group
		agent_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		agent_button.custom_minimum_size = Vector2(0.0, 31.0)
		agent_button.add_theme_font_size_override("font_size", 11)
		agent_button.add_theme_color_override("font_color", Color(STATUS_COLORS.get(state, Color("#c0cbd0"))))
		agent_button.add_theme_stylebox_override("normal", _roster_button_style(Color(0.0, 0.0, 0.0, 0.0)))
		agent_button.add_theme_stylebox_override("hover", _roster_button_style(Color(0.35, 0.55, 0.58, 0.22)))
		agent_button.add_theme_stylebox_override("pressed", _roster_button_style(Color(0.35, 0.55, 0.58, 0.34)))
		agent_button.pressed.connect(_select_agent.bind(key))
		roster_list.add_child(agent_button)
		agent_buttons[key] = agent_button


func _roster_button_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(6)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	return style


func _select_agent(agent_key: String) -> void:
	selected_agent = agent_key
	var meta: Dictionary = AGENT_META.get(agent_key, {"name": agent_key.capitalize(), "role": "AI-агент"})
	var raw_data: Variant = agent_data.get(agent_key, {})
	var data: Dictionary = raw_data if raw_data is Dictionary else {}
	var state := str(data.get("status", "idle"))
	agent_name_label.text = str(meta.get("name", agent_key))
	agent_role_label.text = str(meta.get("role", "AI-агент"))
	status_label.text = "● " + str(STATUS_LABELS.get(state, "В офисе"))
	status_label.add_theme_color_override("font_color", Color(STATUS_COLORS.get(state, Color("#c0cbd0"))))
	var task := str(data.get("task", "Сейчас нет активной задачи."))
	task_label.text = task if not task.is_empty() else "Сейчас нет активной задачи."

	for key in agent_buttons:
		var button: Button = agent_buttons[key]
		button.set_pressed_no_signal(key == selected_agent)


func _add_box(box_name: String, size: Vector3, position: Vector3, color: Color, roughness := 0.86) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = _material(color, roughness)
	add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(cylinder_name: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = cylinder_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = _material(color)
	add_child(mesh_instance)
	return mesh_instance


func _add_sphere(sphere_name: String, position: Vector3, scale: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = sphere_name
	var mesh := SphereMesh.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.scale = scale
	mesh_instance.material_override = _material(color)
	add_child(mesh_instance)
	return mesh_instance


func _material(color: Color, roughness := 0.86) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _update_camera() -> void:
	if camera == null:
		return

	var horizontal := distance * cos(pitch)
	var direction := Vector3(sin(yaw) * horizontal, distance * sin(pitch), cos(yaw) * horizontal)
	camera.position = CAMERA_TARGET + direction
	camera.look_at(CAMERA_TARGET, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = maxf(6.0, distance - 0.55)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(13.0, distance + 0.55)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw = clampf(yaw - event.relative.x * 0.005, -0.85, 0.85)
		pitch = clampf(pitch + event.relative.y * 0.004, -0.02, 0.42)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			yaw = clampf(yaw - 0.08, -0.85, 0.85)
		elif event.keycode == KEY_RIGHT:
			yaw = clampf(yaw + 0.08, -0.85, 0.85)
		elif event.keycode == KEY_UP:
			pitch = clampf(pitch + 0.06, -0.02, 0.42)
		elif event.keycode == KEY_DOWN:
			pitch = clampf(pitch - 0.06, -0.02, 0.42)
		else:
			return
		_update_camera()


func _zoom_in() -> void:
	distance = maxf(6.0, distance - 0.65)
	_update_camera()


func _zoom_out() -> void:
	distance = minf(13.0, distance + 0.65)
	_update_camera()


func _reset_camera() -> void:
	yaw = DEFAULT_YAW
	pitch = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE
	_update_camera()
