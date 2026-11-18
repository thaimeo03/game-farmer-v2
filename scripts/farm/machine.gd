class_name Machine
extends InteractZone
## Processing machine (oven, juicer, stove, loom). Pick a recipe from Database.recipes_for(
## machine_id), its inputs are taken from the bag, and after `duration` the output is ready
## to collect. One job at a time. Saved under "machine_<id>".

@export var machine_id: StringName
@export var title := "Máy chế biến"

var job: RecipeData
var started_at := 0.0

var _status: Label3D


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] %s" % title
	super()
	_status = Label3D.new()
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.position.y = 2.2
	_status.font_size = 44
	_status.outline_size = 12
	add_child(_status)
	var saved = SaveManager.register(StringName("machine_%s" % machine_id), self)
	if saved:
		job = Database.recipes.get(StringName(saved.get("recipe", "")))
		started_at = float(saved.get("started_at", 0.0))


func is_done() -> bool:
	return job != null and GameState.clock - started_at >= job.duration


func _process(_delta: float) -> void:
	if job == null:
		_status.text = title
	elif is_done():
		_status.text = "Xong! %s" % job.output.display_name
	else:
		_status.text = "%s %ds" % [job.output.display_name, ceili(job.duration - (GameState.clock - started_at))]


func interact(_player: Player) -> void:
	if is_done():
		GameState.inventory.add(job.output, job.output_count)
		Progression.reward(&"craft")
		GameState.toast("+%d %s" % [job.output_count, job.output.display_name])
		job = null
		return
	if job:
		GameState.toast("Đang làm %s, chờ thêm chút" % job.output.display_name)
		return
	var rows := []
	for r in Database.recipes_for(machine_id):
		var locked := Progression.level < r.unlock_level
		rows.append({
			"text": "%s  ←  %s  (%ds)%s" % [r.output.display_name, r.inputs_text(), int(r.duration),
				"   [cần cấp %d]" % r.unlock_level if locked else ""],
			"buttons": [["Làm", start.bind(r), r.can_make()]],
		})
	hud().open_menu(title, rows)


func start(recipe: RecipeData) -> bool:
	if job or not recipe.consume_inputs():
		return false
	job = recipe
	started_at = GameState.clock
	GameState.toast("Bắt đầu làm %s" % recipe.output.display_name)
	return true


func to_save() -> Dictionary:
	return {"recipe": String(job.id) if job else "", "started_at": started_at}
