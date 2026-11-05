extends RefCounted

## The ten SpeedChat colors from OptionsPage.speedChatStyles.
## Each row is arrow rgb, rollover rgb, then the speech-bubble frame rgb.

const NAMES: PackedStringArray = [
	"Purple", "Blue", "Cyan", "Teal", "Green", "Yellow", "Orange", "Red", "Pink", "Brown",
]
const _RAW: Array = [
	[200, 60, 229, 200, 135, 255, 220, 195, 229],
	[0, 0, 255, 140, 150, 235, 201, 215, 255],
	[90, 175, 225, 120, 215, 255, 208, 230, 250],
	[130, 235, 235, 120, 225, 225, 234, 255, 255],
	[0, 200, 70, 0, 200, 80, 204, 255, 204],
	[235, 230, 0, 255, 250, 100, 255, 250, 204],
	[255, 153, 0, 229, 147, 0, 255, 234, 204],
	[255, 0, 50, 229, 0, 50, 255, 204, 204],
	[255, 153, 193, 240, 157, 192, 255, 215, 238],
	[170, 120, 20, 165, 120, 50, 210, 200, 180],
]


static func count() -> int:
	return NAMES.size()


static func clamp_index(index: int) -> int:
	return clampi(index, 0, count() - 1)


static func style_name(index: int) -> String:
	return NAMES[clamp_index(index)]


static func frame(index: int) -> Color:
	return _swatch(index, 6, 0.98)


static func arrow(index: int) -> Color:
	return _swatch(index, 0, 1.0)


static func rollover(index: int) -> Color:
	return _swatch(index, 3, 0.95)


static func emote(index: int) -> Color:
	var hot := rollover(index)
	var hsv := _hsv(hot)
	var tint := _rgb(hsv.x, 1.0, 0.8 * hsv.z)
	tint.a = 1.0
	return tint


static func _swatch(index: int, at: int, alpha: float) -> Color:
	var raw: Array = _RAW[clamp_index(index)]
	return Color(float(raw[at]) / 255.0, float(raw[at + 1]) / 255.0, float(raw[at + 2]) / 255.0, alpha)


static func _hsv(color: Color) -> Vector3:
	var hi := maxf(color.r, maxf(color.g, color.b))
	var lo := minf(color.r, minf(color.g, color.b))
	var delta := hi - lo
	var hue := 0.0
	var sat := 0.0
	if delta != 0.0 and hi != 0.0:
		sat = delta / hi
		if color.r == hi:
			hue = (color.g - color.b) / delta
		elif color.g == hi:
			hue = 2.0 + (color.b - color.r) / delta
		else:
			hue = 4.0 + (color.r - color.g) / delta
		hue *= 60.0
		if hue < 0.0:
			hue += 360.0
	return Vector3(hue, sat, hi)


static func _rgb(hue: float, sat: float, value: float) -> Color:
	if sat == 0.0:
		return Color(value, value, value)
	var turned := fmod(hue, 360.0)
	if turned < 0.0:
		turned += 360.0
	turned /= 60.0
	var sector := int(floor(turned))
	var span := turned - float(sector)
	var p := value * (1.0 - sat)
	var q := value * (1.0 - sat * span)
	var t := value * (1.0 - sat * (1.0 - span))
	match sector:
		0:
			return Color(value, t, p)
		1:
			return Color(q, value, p)
		2:
			return Color(p, value, t)
		3:
			return Color(p, q, value)
		4:
			return Color(t, p, value)
		_:
			return Color(value, p, q)
