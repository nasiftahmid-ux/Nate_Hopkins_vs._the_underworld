extends SceneTree

const SAVE := "user://probe_save.json"


func _initialize() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("this is not json {{{")
	f = null
	var file := FileAccess.open(SAVE, FileAccess.READ)
	print("read1 = '", file.get_as_text(), "'")
	file = null

	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{}")
	f = null
	file = FileAccess.open(SAVE, FileAccess.READ)
	print("read2 = '", file.get_as_text(), "'")
	print("size2 = ", FileAccess.get_file_as_bytes(SAVE).size())
	file = null
	quit()
