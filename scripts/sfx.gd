class_name Sfx
extends RefCounted
## Plays sound effects by name. Sounds live in scenes/game_sounds.tscn (and
## scenes/build_sounds.tscn for build mode): open the scene, select a node (e.g. "Pay") and
## drag a .wav / .ogg file onto its "Stream" slot. Nodes with no stream are silent.

static var _roots: Array[Node] = []
static var _cache: Dictionary = {}


static func setup(sounds_root: Node) -> void:
	_roots = [sounds_root]
	_cache.clear()


## Registers another scene that holds sound nodes.
static func add_root(sounds_root: Node) -> void:
	_roots.append(sounds_root)
	_cache.clear()


static func _find(sound_name: StringName) -> AudioStreamPlayer:
	if _cache.has(sound_name) and is_instance_valid(_cache[sound_name]):
		return _cache[sound_name] as AudioStreamPlayer
	for root in _roots:
		if is_instance_valid(root):
			var found := root.get_node_or_null(NodePath(String(sound_name))) as AudioStreamPlayer
			if found != null:
				_cache[sound_name] = found
				return found
	return null


static func play(sound_name: StringName) -> void:
	var p := _find(sound_name)
	if p != null and p.stream != null:
		p.play()


static func stop(sound_name: StringName) -> void:
	var p := _find(sound_name)
	if p != null and p.playing:
		p.stop()


static func is_playing(sound_name: StringName) -> bool:
	var p := _find(sound_name)
	return p != null and p.playing
