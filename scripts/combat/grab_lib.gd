## Séquences de prises synchronisées. Le défenseur est positionné par rapport
## à l'attaquant à chaque frame (décalage local, Z+ = devant l'attaquant) et
## joue l'animation miroir : les deux modèles restent parfaitement calés.
class_name GrabLib
extends RefCounted

const SEQS := {
	&"slam": {
		"name": "Body Slam de Kin", "length": 72, "hit_frame": 53, "damage": 16.0,
		"atk_anim": &"slam_atk", "def_anim": &"slam_def", "tech_window": 12,
		"path": [[0, 0.62], [10, 0.55], [26, 0.25], [44, 0.25], [53, 1.15], [72, 1.15]],
	},
	&"throw": {
		"name": "Projection du Fleuve", "length": 58, "hit_frame": 44, "damage": 13.0,
		"atk_anim": &"throw_atk", "def_anim": &"throw_def", "tech_window": 12,
		"path": [[0, 0.62], [10, 0.55], [22, 0.75], [33, 1.7], [44, 2.6], [58, 2.6]],
	},
	&"ultimate": {
		"name": "Ultime", "length": 150, "hit_frame": 95, "damage": 0.0,
		"atk_anim": &"ult_atk", "def_anim": &"ult_def", "tech_window": 0,
		"hits": [[8, 0.08], [14, 0.08], [22, 0.08], [30, 0.08], [40, 0.16], [95, 0.52]],
		"path": [[0, 0.85], [30, 0.95], [40, 1.0], [60, 1.25], [95, 1.35], [150, 1.35]],
	},
}

static func offset_at(seq: Dictionary, f: float) -> float:
	var path: Array = seq.path
	if f <= path[0][0]:
		return path[0][1]
	for i in path.size() - 1:
		var a: Array = path[i]
		var b: Array = path[i + 1]
		if f <= b[0]:
			var t: float = (f - a[0]) / maxf(1.0, b[0] - a[0])
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(a[1], b[1], t)
	return path[path.size() - 1][1]
