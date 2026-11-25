## Petites textures générées au démarrage (aucun fichier externe).
class_name FxTextures
extends RefCounted

static var _dot: ImageTexture
static var _spark: ImageTexture

static func soft_dot() -> ImageTexture:
	if _dot == null:
		var s := 32
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		for y in s:
			for x in s:
				var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_dot = ImageTexture.create_from_image(img)
	return _dot

static func spark() -> ImageTexture:
	if _spark == null:
		var s := 32
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		for y in s:
			for x in s:
				var p := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5) / (s / 2.0)
				var a := clampf(1.0 - absf(p.x) * 4.0, 0.0, 1.0) * clampf(1.0 - absf(p.y), 0.0, 1.0)
				a = maxf(a, clampf(1.0 - absf(p.y) * 4.0, 0.0, 1.0) * clampf(1.0 - absf(p.x), 0.0, 1.0))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_spark = ImageTexture.create_from_image(img)
	return _spark
