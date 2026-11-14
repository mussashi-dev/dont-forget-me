extends SceneTree
## Gera os SpriteFrames dos personagens top-down a partir dos PNGs em assets/characters/*/topdown/.
## Uso: godot --headless --path . -s res://tools/build_spriteframes.gd
## Saídas: res://resources/pablita_topdown_frames.tres e res://resources/pipop_topdown_frames.tres
## Animações: idle_<dir> (quadro neutro) e walk_<dir> (4 quadros), dir = south|north|east|west.

const DIRS: Array[String] = ["south", "north", "east", "west"]

func _init() -> void:
	_build("pablita", "res://resources/pablita_topdown_frames.tres", 9.0)
	_build("pipop", "res://resources/pipop_topdown_frames.tres", 8.0)
	quit(0)

func _build(who: String, out_path: String, walk_fps: float) -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for d: String in DIRS:
		var idle_name: String = "idle_%s" % d
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 1.0)
		frames.add_frame(idle_name, load("res://assets/characters/%s/topdown/walk_%s_1.png" % [who, d]))
		var walk_name: String = "walk_%s" % d
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, walk_fps)
		for i: int in 4:
			frames.add_frame(walk_name, load("res://assets/characters/%s/topdown/walk_%s_%d.png" % [who, d, i]))
	var err: int = ResourceSaver.save(frames, out_path)
	print("%s -> %s (erro=%d)" % [who, out_path, err])
