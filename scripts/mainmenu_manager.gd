extends Node

const GAME_SCENE := "res://scenes/game.tscn"
const GALLERY_SCENE := "res://scenes/gallery.tscn"
const CREDITS_SCENE := "res://scenes/credits.tscn"

@onready var spells_grid: GridContainer = $VBoxContainer/GridContainer
@onready var title_sprite: AnimatedSprite2D = $VBoxContainer/Container/AnimatedSprite2D
@onready var play_buttons_container: VBoxContainer = $VBoxContainer/HBoxContainer/VBoxContainer
@onready var fade_color_rect: ColorRect = $ColorRect2
@onready var gallery_button: Button = $VBoxContainer/HBoxContainer/gallerybutton

func _ready() -> void:
	get_tree().paused = false
	
	if title_sprite:
		title_sprite.play()

	if Gamemanager.coming_back_from_game:
		Gamemanager.coming_back_from_game = false
		Gamemanager.unlock_item(12)

		fade_color_rect.show()
		fade_color_rect.color = Color.BLACK

		create_tween().tween_property(
			fade_color_rect,
			"color",
			Color(0, 0, 0, 0),
			2.0
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	
	if Gamemanager.pending_unlocks.size() > 0:
		$VBoxContainer/HBoxContainer/gallerybutton/NEW.show()

func start_play_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"scale",
		Vector2(2, 2),
		5.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	fade_color_rect.show()

	tween.tween_property(
		fade_color_rect,
		"color",
		Color.BLACK,
		5.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if gallery_button.material:
		tween.tween_method(
			func(value: float):
				gallery_button.material.set_shader_parameter("dissolve_value", value),
			1.0,
			0.0,
			2.0
		)

	await tween.finished
	Gamemanager.change_scene(GAME_SCENE)

func _on_gallerybutton_pressed() -> void:
	Gamemanager.change_scene(GALLERY_SCENE)

func _on_backbutton_pressed() -> void:
	Gamemanager.return_scene()

func _on_creditsbutton_pressed() -> void:
	Gamemanager.change_scene(CREDITS_SCENE)

func _on_playbutton_pressed() -> void:
	start_play_animation()

func _on_newbutton_pressed() -> void:
	Gamemanager.clear_game_state()
	start_play_animation()
