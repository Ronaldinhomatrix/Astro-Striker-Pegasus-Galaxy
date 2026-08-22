@tool
extends EditorPlugin

## Atalho: Ctrl+Shift+1
## Move a nave (nó "Player" da cena editada) para a POSIÇÃO EXATA DA CÂMERA do editor 3D,
## para que você possa vê-la "por dentro". Útil para conferir a escala do cenário a cada ajuste.

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 and event.ctrl_pressed and event.shift_pressed:
			_move_ship_to_cursor()
			get_viewport().set_input_as_handled()


func _move_ship_to_cursor() -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		print("ShipToCursor: nenhuma cena editada.")
		return

	var vp := EditorInterface.get_editor_viewport_3d()
	if vp == null:
		print("ShipToCursor: viewport 3D indisponível.")
		return

	var cam := vp.get_camera_3d()
	if cam == null:
		print("ShipToCursor: câmera 3D indisponível.")
		return

	# Posição exata da câmera do editor (onde o usuário está olhando por dentro)
	var cursor_pos := cam.global_position

	var ship := _find_ship(scene)
	if ship == null:
		print("ShipToCursor: nó 'Player' não encontrado na cena.")
		return

	# A nave é filha de um PathFollow3D que desliza sobre uma curva (Path3D).
	# Mover só o nó "Player" não persiste: o PathFollow3D o recoloca na curva.
	# A forma que funciona é mover a curva inteira (o Path3D "FlightPath") por um delta,
	# o que leva a nave junto e é salvo corretamente na cena.
	var delta := cursor_pos - ship.global_position
	var path := _find_path(ship)
	if path == null:
		print("ShipToCursor: Path3D ancestral não encontrado; movendo só a nave.")
		ship.global_position = cursor_pos
		return
	path.global_position += delta
	print("ShipToCursor: nave movida para ", cursor_pos)


func _find_ship(root: Node) -> Node3D:
	var player := root.find_child("Player", true, false)
	if player is Node3D:
		return player
	return null


func _find_path(ship: Node) -> Node3D:
	# Sobe a árvore até achar um Path3D (o pai da curva de vôo)
	var current := ship.get_parent()
	while current != null:
		if current is Path3D:
			return current
		current = current.get_parent()
	return null
