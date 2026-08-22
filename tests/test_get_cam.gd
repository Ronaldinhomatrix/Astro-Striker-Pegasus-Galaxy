extends Node

func test_get_editor_camera() -> void:
	var editor_plugin = EditorScript.new()
	var viewport = EditorInterface.get_editor_viewport_3d(0)
	if viewport:
		var cam = viewport.get_camera_3d()
		if cam:
			print("EDITOR_CAM_GLOBAL_POS=", cam.global_position)
			print("EDITOR_CAM_GLOBAL_ROT=", cam.global_rotation)
