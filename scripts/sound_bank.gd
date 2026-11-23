class_name SoundBank
extends RefCounted
## Fills the sound nodes (scenes/game_sounds.tscn, rank_sounds.tscn, build_sounds.tscn) with the
## game's default sounds. A node that already has a Stream set in the editor keeps it, so you
## can still drag your own .wav / .ogg onto any node to replace a default.
##
## The custom sounds in assets/sounds/ (music, customer voices, cooking, the restaurant murmur...)
## are made by tools/make_sounds.py; the clicks and blips come from Kenney's interface pack
## in assets/Audio/. Each entry: node name -> [files, volume dB, random pitch, loop]. Several
## files = one is picked at random each time (and the pitch varies a little).

const S := "res://assets/sounds/"
const K := "res://assets/Audio/"

const BANK := {
	# Music and atmosphere
	"Music": [[S + "music_cafe.ogg"], -12.0, 1.0, true],
	"Ambience": [[S + "ambience_restaurant.ogg"], -60.0, 1.0, true], # main.gd raises it with the crowd
	# Customers
	"CustomerArrive": [[S + "door_chime.ogg"], -14.0, 1.0, false],
	"CustomerTalk": [[S + "voice_ask_0.ogg", S + "voice_ask_1.ogg", S + "voice_ask_2.ogg", S + "voice_ask_3.ogg"], -9.0, 1.1, false],
	"OrderTaken": [[S + "voice_ok_0.ogg", S + "voice_ok_1.ogg", S + "voice_ok_2.ogg", S + "voice_ok_3.ogg"], -9.0, 1.1, false],
	"Serve": [[S + "plate_clink.ogg"], -10.0, 1.05, false],
	"Eat": [[S + "munch.ogg"], -6.0, 1.1, false],
	"Yum": [[S + "voice_yum_0.ogg", S + "voice_yum_1.ogg", S + "voice_yum_2.ogg"], -10.0, 1.08, false],
	"Pay": [[S + "cash_register.ogg"], -12.0, 1.0, false],
	"CustomerHappy": [[S + "voice_happy_0.ogg", S + "voice_happy_1.ogg", S + "voice_happy_2.ogg", S + "voice_happy_3.ogg"], -10.0, 1.08, false],
	"Angry": [[S + "voice_angry_0.ogg", S + "voice_angry_1.ogg", S + "voice_angry_2.ogg", S + "voice_angry_3.ogg"], -6.0, 1.08, false],
	# Kitchen
	"NewTicket": [[S + "paper.ogg"], -10.0, 1.1, false],
	"PutOnStove": [[S + "pan_clank.ogg"], -12.0, 1.08, false],
	"Sizzle": [[S + "sizzle_loop.ogg"], -14.0, 1.0, true],
	"OrderUpBell": [[S + "order_up_bell.ogg"], -10.0, 1.0, false],
	"Chop": [[S + "chop_0.ogg", S + "chop_1.ogg", S + "chop_2.ogg"], -6.0, 1.1, false],
	"Stir": [[S + "stir_0.ogg", S + "stir_1.ogg", S + "stir_2.ogg"], -8.0, 1.1, false],
	# Player
	"PickUp": [[S + "pickup.ogg"], -10.0, 1.05, false],
	"Footstep": [[S + "step_0.ogg", S + "step_1.ogg", S + "step_2.ogg", S + "step_3.ogg"], -18.0, 1.1, false],
	"Interact": [[K + "tick_002.ogg"], -20.0, 1.0, false],
	# Shop and menus
	"Buy": [[S + "ui_buy.ogg"], -8.0, 1.0, false],
	"ShopOpen": [[S + "ui_open.ogg"], -10.0, 1.0, false], # also the pause menu opening
	"ShopClose": [[S + "ui_close.ogg"], -10.0, 1.0, false], # also resuming from the pause menu
	"GameStart": [[S + "ui_start.ogg"], -8.0, 1.0, false], # pressing PLAY on the start screen
	"UIClick": [[S + "ui_click.ogg"], -12.0, 1.0, false], # menu buttons and shop tabs
	# Minigames
	"MinigamePress": [[K + "click_002.ogg"], -12.0, 1.05, false],
	"MinigamePerfect": [[K + "confirmation_002.ogg"], -6.0, 1.0, false],
	"MinigameGood": [[K + "select_002.ogg"], -6.0, 1.0, false],
	"MinigameMiss": [[K + "error_006.ogg"], -10.0, 1.0, false],
	"MinigameDone": [[K + "maximize_006.ogg"], -6.0, 1.0, false],
	"MinigameCancel": [[K + "back_002.ogg"], -8.0, 1.0, false],
	# Rank and expansions
	"RankUp": [[S + "rank_up.ogg"], -4.0, 1.0, false],
	"Expand": [[S + "expand.ogg"], -4.0, 1.0, false],
	# Build mode
	"BuildToggle": [[K + "switch_002.ogg"], -8.0, 1.0, false],
	"BuildSelect": [[K + "select_003.ogg"], -10.0, 1.0, false],
	"BuildRotate": [[K + "tick_004.ogg"], -10.0, 1.0, false],
	"BuildPlace": [[K + "drop_002.ogg"], -6.0, 1.05, false],
	"BuildSell": [[K + "confirmation_004.ogg"], -8.0, 1.0, false],
	"BuildError": [[K + "error_002.ogg"], -10.0, 1.0, false],
}


## Gives every node in BANK under any of `roots` its default sound (making the node if a scene
## doesn't have it), unless the node already has a stream.
static func fill(roots: Array[Node]) -> void:
	if roots.is_empty():
		return
	for sound_name in BANK:
		var player: AudioStreamPlayer = null
		for root in roots:
			player = root.get_node_or_null(NodePath(sound_name)) as AudioStreamPlayer
			if player != null:
				break
		if player == null:
			player = AudioStreamPlayer.new()
			player.name = sound_name
			roots[0].add_child(player)
		if player.stream != null:
			continue # set by hand in the editor: keep it
		var spec: Array = BANK[sound_name]
		var stream := _make_stream(spec[0], float(spec[2]), bool(spec[3]))
		if stream == null:
			continue
		player.stream = stream
		player.volume_db = float(spec[1])
		# Short sounds can overlap (two customers talking at once, fast chopping).
		if not bool(spec[3]):
			player.max_polyphony = 4


static func _make_stream(files: Array, random_pitch: float, loop: bool) -> AudioStream:
	var streams: Array[AudioStream] = []
	for f in files:
		if ResourceLoader.exists(f):
			var s := load(f) as AudioStream
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = loop
			if s != null:
				streams.append(s)
	if streams.is_empty():
		return null
	if streams.size() == 1 and random_pitch <= 1.0:
		return streams[0]
	var r := AudioStreamRandomizer.new()
	for s in streams:
		r.add_stream(-1, s)
	r.random_pitch = random_pitch
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if streams.size() > 1 else AudioStreamRandomizer.PLAYBACK_RANDOM
	return r
