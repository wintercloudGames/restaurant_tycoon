class_name CharAnim
extends RefCounted
## Finds the AnimationPlayer inside a character model and plays animations by loose name.

var player: AnimationPlayer
var current: String = ""


func _init(model: Node) -> void:
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		player = found[0] as AnimationPlayer


## Plays the first animation whose name matches one of `candidates`
## (case-insensitive; exact match first, then "contains"). Returns true if one was found.
func play(candidates: Array[String]) -> bool:
	if player == null:
		return false
	var names := player.get_animation_list()
	for want in candidates:
		for n in names:
			if String(n).to_lower() == want:
				_start(String(n))
				return true
	for want in candidates:
		for n in names:
			if String(n).to_lower().contains(want):
				_start(String(n))
				return true
	return false


func _start(anim_name: String) -> void:
	if anim_name == current:
		return
	current = anim_name
	var animation := player.get_animation(anim_name)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	player.play(anim_name, 0.2)
