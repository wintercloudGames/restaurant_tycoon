class_name BuildUi
extends CanvasLayer
## On-screen help and item list for build mode (see build_ui.tscn).

@onready var status_label: Label = %StatusLabel
@onready var item_list: VBoxContainer = %ItemList
@onready var appeal_label: Label = %AppealLabel
@onready var scroll: ScrollContainer = %Scroll

var _labels: Array[Label] = []
var _locked: Array[bool] = []
var _selected: int = -1


func set_items(entries: Array[String]) -> void:
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	_labels.clear()
	for e in entries:
		var label := Label.new()
		label.text = e
		item_list.add_child(label)
		_labels.append(label)


## Items that need a higher rank than you have are shown dimmed.
func set_locked(flags: Array[bool]) -> void:
	_locked = flags
	set_selected(_selected)


func set_selected(index: int) -> void:
	_selected = index
	for i in _labels.size():
		var is_locked: bool = i < _locked.size() and _locked[i]
		if i == index:
			_labels[i].modulate = Color(1.0, 0.5, 0.4) if is_locked else Color(1.0, 0.85, 0.3)
		else:
			_labels[i].modulate = Color(0.55, 0.55, 0.6, 0.6) if is_locked else Color(1, 1, 1, 0.8)
	if index >= 0 and index < _labels.size():
		_scroll_to.call_deferred(index)


func _scroll_to(index: int) -> void:
	if index < _labels.size() and is_instance_valid(_labels[index]):
		scroll.ensure_control_visible(_labels[index])


func set_status(text: String, ok: bool = true) -> void:
	status_label.text = text
	status_label.modulate = Color.WHITE if ok else Color(1.0, 0.5, 0.5)


func set_appeal(appeal: int, tip_mult: float) -> void:
	appeal_label.text = "Decor appeal: %d  (+%d%% tips)" % [appeal, int(round((tip_mult - 1.0) * 100.0))]
