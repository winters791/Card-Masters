extends GutTest
## Phase 0 smoke tests: the project boots and the folder layout is in place.


func test_main_scene_is_configured() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(main_scene, "res://ui/main.tscn")


func test_main_scene_instantiates() -> void:
	var packed: PackedScene = load("res://ui/main.tscn")
	assert_not_null(packed, "main scene should load")
	var main: Node = packed.instantiate()
	assert_not_null(main, "main scene should instantiate")
	add_child_autofree(main)


func test_folder_layout_exists() -> void:
	for dir_path: String in ["res://core", "res://cards", "res://ai", "res://ui", "res://tests"]:
		assert_true(DirAccess.dir_exists_absolute(dir_path), "%s should exist" % dir_path)
