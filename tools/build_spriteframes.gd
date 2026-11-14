extends SceneTree
## Gera os SpriteFrames dos personagens top-down a partir dos PNGs em assets/characters/*/topdown/.
## Uso: godot --headless --path . -s res://tools/build_spriteframes.gd
## Saídas: res://resources/pablita_topdown_frames.tres e res://resources/pipop_topdown_frames.tres
## Animações base: idle_<dir> (quadro neutro) e walk_<dir> (4 quadros), dir = south|north|east|west.
## Extras de Pipop (Bíblia 3.2): sonic_roar, defense, hurt, hold_box, read_box/read_book, sleep.

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

	if who == "pipop":
		var base_dir: String = "res://assets/characters/pipop/topdown"
		_add_extra_anim(frames, "sonic_roar", [
			"%s/pip_sonic_0.png" % base_dir,
			"%s/pip_sonic_1.png" % base_dir,
			"%s/pip_sonic_2.png" % base_dir,
		], 10.0, true)
		_add_extra_anim(frames, "defense", ["%s/pip_defense.png" % base_dir], 4.0, false)
		_add_extra_anim(frames, "hurt", ["%s/pip_hurt.png" % base_dir], 6.0, false)
		_add_extra_anim(frames, "hold_box", ["%s/pip_box.png" % base_dir], 4.0, true)
		_add_extra_anim(frames, "read_book", ["%s/pip_book.png" % base_dir], 4.0, true)
		_add_extra_anim(frames, "sleep", ["%s/pip_sleep.png" % base_dir], 2.0, true)

	var err: int = ResourceSaver.save(frames, out_path)
	print("%s -> %s (erro=%d)" % [who, out_path, err])

func _add_extra_anim(frames: SpriteFrames, anim_name: String, paths: Array[String], fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loop)
	frames.set_animation_speed(anim_name, fps)
	for path: String in paths:
		if ResourceLoader.exists(path):
			frames.add_frame(anim_name, load(path))
		else:
			push_warning("Sprite ausente para animacao %s: %s" % [anim_name, path])
