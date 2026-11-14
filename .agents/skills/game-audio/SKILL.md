---
name: game-audio
description: Game audio systems for Godot 4.x — sound effects, music, audio buses, adaptive audio, and spatial sound.
---

# Game Audio Skill for Godot 4.x

Complete guide for designing, managing, and optimizing game audio in Godot 4.x.

## Audio Bus Layout

Configure buses in Godot's bottom **Audio** tab or via code:
```text
Master (Default)
├── Music      (Volume slider, EQ / Limiter)
├── SFX        (Sound effects, Reverb / Delay sends)
│   └── Footsteps
├── UI         (Menu sounds, never affected by game pausing)
└── Ambience   (Background environmental loops)
```

### Bus Volume & Settings
Human hearing is logarithmic. Always convert linear slider values (0.0 to 1.0) to decibels:
```gdscript
func set_bus_volume_linear(bus_name: String, linear_volume: float) -> void:
    var bus_idx := AudioServer.get_bus_index(bus_name)
    if bus_idx != -1:
        var db := linear_to_db(clampf(linear_volume, 0.0001, 1.0))
        AudioServer.set_bus_volume_db(bus_idx, db)
        AudioServer.set_bus_mute(bus_idx, linear_volume <= 0.0001)

func get_bus_volume_linear(bus_name: String) -> float:
    var bus_idx := AudioServer.get_bus_index(bus_name)
    if bus_idx != -1:
        if AudioServer.is_bus_mute(bus_idx):
            return 0.0
        return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
    return 1.0
```

## AudioManager Autoload Singleton

Register as `AudioManager` in Project Settings -> Autoload:

```gdscript
# res://autoload/audio_manager.gd
extends Node

@export var sfx_pool_size: int = 16

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _current_music_player: AudioStreamPlayer

func _ready() -> void:
    # Ensure audio plays during pause if needed
    process_mode = Node.PROCESS_MODE_ALWAYS

    # SFX Pool
    for i in sfx_pool_size:
        var player := AudioStreamPlayer.new()
        player.bus = "SFX"
        add_child(player)
        _sfx_pool.append(player)

    # Music Players for crossfading
    _music_player_a = AudioStreamPlayer.new()
    _music_player_a.bus = "Music"
    add_child(_music_player_a)

    _music_player_b = AudioStreamPlayer.new()
    _music_player_b.bus = "Music"
    add_child(_music_player_b)

    _current_music_player = _music_player_a

## Play SFX with pitch variation to avoid repetitive sounds
func play_sfx(stream: AudioStream, pitch_variance: float = 0.1, volume_db: float = 0.0) -> void:
    if not stream:
        return
    for player in _sfx_pool:
        if not player.playing:
            player.stream = stream
            player.volume_db = volume_db
            player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
            player.play()
            return
    # If all busy, steal the oldest
    var fallback: AudioStreamPlayer = _sfx_pool[0]
    fallback.stream = stream
    fallback.volume_db = volume_db
    fallback.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
    fallback.play()

## Play UI sounds on the UI bus
func play_ui(stream: AudioStream) -> void:
    if not stream:
        return
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.bus = "UI"
    add_child(player)
    player.play()
    player.finished.connect(player.queue_free)

## Crossfade music tracks
func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
    if not stream:
        return
    var next_player := _music_player_b if _current_music_player == _music_player_a else _music_player_a
    next_player.stream = stream
    next_player.volume_db = -80.0
    next_player.play()

    var tween := create_tween().set_parallel(true)
    tween.tween_property(_current_music_player, "volume_db", -80.0, fade_time)
    tween.tween_property(next_player, "volume_db", 0.0, fade_time)

    await tween.finished
    _current_music_player.stop()
    _current_music_player = next_player
```

## Spatial 2D Audio (Positional SFX)

Use `AudioStreamPlayer2D` for in-world sounds (explosions, machine hum, footsteps):
- **max_distance:** Maximum distance where sound is audible (e.g., 500 pixels).
- **attenuation:** Falloff curve (1.0 = linear, >1.0 = fast dropoff).
- **area_mask:** Interaction with AudioListener2D.

```gdscript
func spawn_explosion_sound(global_pos: Vector2, sound: AudioStream) -> void:
    var player := AudioStreamPlayer2D.new()
    player.stream = sound
    player.bus = "SFX"
    player.max_distance = 600.0
    player.global_position = global_pos
    get_tree().current_scene.add_child(player)
    player.play()
    player.finished.connect(player.queue_free)
```

## File Formats & Asset Best Practices
- **Music & Ambient Loops:** `.ogg` (Vorbis). Always enable `Loop` in the Import dock for music files.
- **Short Sound Effects (SFX):** `.wav` (PCM 16-bit, 44.1kHz). Low latency, instant playback without decompression overhead.
- **Micro-variations:** For recurring actions (footsteps, gunshots, jumping), use 3 to 5 audio variants and randomize selection:
```gdscript
@export var step_sounds: Array[AudioStream] = []

func play_footstep() -> void:
    if step_sounds.size() > 0:
        AudioManager.play_sfx(step_sounds.pick_random(), 0.08)
```
