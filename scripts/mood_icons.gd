class_name MoodIcons
extends RefCounted
## Little pictures for customers' speech bubbles, all drawn in code (no image files): the mood
## faces, the bubble itself, its tail and the "take my order" badge.

## Every mood a customer can be in, from calm to furious (plus the happy face while eating).
const MOODS: Array[String] = ["happy", "neutral", "worried", "angry", "yum"]
const FACE_SIZE := 64
const BUBBLE_W := 256
const BUBBLE_H := 176

static var _cache: Dictionary = {}


## The bubble's tint for a mood.
static func mood_color(mood: String) -> Color:
	match mood:
		"happy":
			return Color(0.78, 1.0, 0.8)
		"neutral":
			return Color(1.0, 0.97, 0.72)
		"worried":
			return Color(1.0, 0.8, 0.5)
		"angry":
			return Color(1.0, 0.5, 0.45)
		"yum":
			return Color(0.72, 0.95, 1.0)
	return Color.WHITE


## Patience bar color: green when full, yellow in the middle, red when nearly out.
static func bar_color(patience: float) -> Color:
	if patience > 0.5:
		return Color(1.0, 0.85, 0.2).lerp(Color(0.35, 0.9, 0.45), (patience - 0.5) * 2.0)
	return Color(0.95, 0.25, 0.2).lerp(Color(1.0, 0.85, 0.2), patience * 2.0)


static func face(mood: String) -> ImageTexture:
	return _cached("face_" + mood, func() -> ImageTexture: return _make_face(mood))


static func bubble() -> ImageTexture:
	return _cached("bubble", _make_bubble)


static func tail() -> ImageTexture:
	return _cached("tail", _make_tail)


static func badge() -> ImageTexture:
	return _cached("badge", _make_badge)


static func white() -> ImageTexture:
	return _cached("white", func() -> ImageTexture:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		return ImageTexture.create_from_image(img))


static func _cached(key: String, make: Callable) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


# ---- Faces ---------------------------------------------------------------

## Distance from point (px, py) to the line segment a-b.
static func _seg_dist(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var abx := bx - ax
	var aby := by - ay
	var t := clampf(((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby), 0.0, 1.0)
	return Vector2(px - (ax + abx * t), py - (ay + aby * t)).length()


## Colour of a face feature at (u, v) (both -0.5 .. 0.5, y down), or transparent for plain skin.
static func _feature(mood: String, u: float, v: float) -> Color:
	var ink := Color(0.25, 0.14, 0.1)
	var none := Color(0, 0, 0, 0)
	# eyes
	if mood == "yum":
		for ex in [-0.15, 0.15]:
			if absf(u - ex) < 0.07 and absf(v - (-0.03 - 0.05 * (1.0 - pow((u - ex) / 0.07, 2.0)))) < 0.022:
				return ink # happy closed eyes
	else:
		for ex in [-0.15, 0.15]:
			if Vector2(u - ex, v + 0.08).length() < 0.055:
				return ink
	# eyebrows when angry
	if mood == "angry":
		if _seg_dist(u, v, -0.28, -0.22, -0.07, -0.13) < 0.03 or _seg_dist(u, v, 0.07, -0.13, 0.28, -0.22) < 0.03:
			return ink
	# mouth
	match mood:
		"happy":
			if absf(u) <= 0.22 and absf(v - (0.12 + 0.08 * (1.0 - pow(u / 0.22, 2.0)))) < 0.028:
				return ink
		"neutral":
			if absf(u) <= 0.16 and absf(v - 0.17) < 0.026:
				return ink
		"worried":
			if absf(u) <= 0.2 and absf(v - (0.24 - 0.07 * (1.0 - pow(u / 0.2, 2.0)))) < 0.028:
				return ink
			if Vector2((u - 0.31) / 0.05, (v + 0.2) / 0.08).length() < 1.0:
				return Color(0.45, 0.75, 1.0) # a sweat drop
		"angry":
			if absf(u) <= 0.2 and absf(v - (0.25 - 0.06 * (1.0 - pow(u / 0.2, 2.0)))) < 0.03:
				return ink
		"yum":
			if v >= 0.1 and Vector2(u / 0.17, (v - 0.1) / 0.14).length() < 1.0:
				return Color(0.55, 0.12, 0.12) # open, happy mouth
			if absf(u) <= 0.19 and absf(v - 0.1) < 0.02:
				return ink
	return none


static func _make_face(mood: String) -> ImageTexture:
	var img := Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color(1.0, 0.85, 0.25)
	if mood == "worried":
		skin = Color(1.0, 0.72, 0.3)
	elif mood == "angry":
		skin = Color(1.0, 0.4, 0.32)
	var ink := Color(0.25, 0.14, 0.1)
	for y in FACE_SIZE:
		for x in FACE_SIZE:
			var u := (float(x) + 0.5) / FACE_SIZE - 0.5
			var v := (float(y) + 0.5) / FACE_SIZE - 0.5
			var r := sqrt(u * u + v * v)
			if r > 0.48:
				continue
			var c := ink if r > 0.43 else skin
			if r <= 0.43:
				var f := _feature(mood, u, v)
				if f.a > 0.0:
					c = f
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# ---- Bubble shapes ---------------------------------------------------------

static func _make_bubble() -> ImageTexture:
	var img := Image.create(BUBBLE_W, BUBBLE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half := Vector2(BUBBLE_W, BUBBLE_H) / 2.0
	var radius := 30.0
	var border := 7.0
	for y in BUBBLE_H:
		for x in BUBBLE_W:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - half
			var q := p.abs() - (half - Vector2(radius, radius))
			var dist := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			if dist <= 0.0:
				img.set_pixel(x, y, Color(0.18, 0.16, 0.2) if dist > -border else Color.WHITE)
	return ImageTexture.create_from_image(img)


## The little point under the bubble.
static func _make_tail() -> ImageTexture:
	var w := 56
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var fy := (float(y) + 0.5) / h
			var u := absf((float(x) + 0.5) / w - 0.5)
			var edge := 0.5 * (1.0 - fy)
			if u <= edge:
				var on_border := u > edge - 0.11 * (1.0 - fy * 0.3) or fy > 0.9
				img.set_pixel(x, y, Color(0.18, 0.16, 0.2) if (on_border and fy > 0.12) else Color.WHITE)
	return ImageTexture.create_from_image(img)


## An orange "!" badge: shown while a customer is waiting for someone to take their order.
static func _make_badge() -> ImageTexture:
	var img := Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in FACE_SIZE:
		for x in FACE_SIZE:
			var u := (float(x) + 0.5) / FACE_SIZE - 0.5
			var v := (float(y) + 0.5) / FACE_SIZE - 0.5
			var r := sqrt(u * u + v * v)
			if r > 0.48:
				continue
			var c := Color(0.25, 0.12, 0.05) if r > 0.42 else Color(1.0, 0.6, 0.1)
			if r <= 0.42:
				if absf(u) < 0.065 and v > -0.3 and v < 0.07:
					c = Color.WHITE
				elif Vector2(u, v - 0.2).length() < 0.075:
					c = Color.WHITE
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
