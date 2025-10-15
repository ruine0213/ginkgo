extends RefCounted
class_name ORALoader


var root: DirAccess

var layer_list: Array[Layer]


func _init() -> void:
	root = DirAccess.open("user://")


# ファイルの存在するディレクトリを指定する
func set_root(absolute_path: String):
	root = DirAccess.open(absolute_path)


# ORA形式であることの確認を拡張子とmimetypeで行う
func is_ora(path: String) -> bool:
	if root.file_exists(path):
		var splited_file_name = path.split(".")
		var ext = splited_file_name[splited_file_name.size() - 1]
		if ext == "ora":
			var zip = ZIPReader.new()
			var err = zip.open(root.get_current_dir().path_join(path))
			if err != OK:
				push_error("画像ファイルが開けませんでした")
				return false
			var files = zip.get_files()
			if files.find("mimetype") != -1:
				var mimetype = zip.read_file("mimetype")
				if mimetype.get_string_from_ascii() == "image/openraster":
					return true
			zip.close()
	push_error("不正なファイル形式です")
	return false


# 画像のスタック情報を取得する
func get_stack_xml(path: String):
	if is_ora(path):
		var zip = ZIPReader.new()
		var err = zip.open(root.get_current_dir().path_join(path))
		if err != OK:
			push_error("画像ファイルが開けませんでした")
			return null
		var stack_xml := zip.read_file("stack.xml")
		zip.close()
		return stack_xml
	return null


# スタック情報からレイヤーの配列を生成する
func generate_layers(path: String, stack: PackedByteArray):
	layer_list.clear()
	var zip = ZIPReader.new()
	var xml = XMLParser.new()
	var err = zip.open(root.get_current_dir().path_join(path))
	if err != OK:
		push_error("画像ファイルが開けませんでした")
		return
	err = xml.open_buffer(stack)
	if err != OK:
		push_error("スタック情報が読み込めませんでした")
		print(err)
		return
	generate_layer(zip, xml)

func generate_layer(zip: ZIPReader, xml: XMLParser, parent: Layer = null):
	while true:
		var result = xml.read()
		if result == ERR_FILE_EOF:
			break
		
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag = xml.get_node_name()
				if tag == "stack":
					var new_layer = Layer.new()
					new_layer.name = xml.get_named_attribute_value("name")
					new_layer.visible = xml.get_named_attribute_value("visibility") != "hidden"
					new_layer.position = Vector2(
						xml.get_named_attribute_value("x").to_int(),
						xml.get_named_attribute_value("y").to_int()
					)
					if parent:
						parent.children.append(new_layer)
						new_layer.parent = parent
					layer_list.append(new_layer)
					# スタックの中身を再帰的に処理
					generate_layer(zip, xml, new_layer)
				elif tag == "layer":
					var new_layer = Layer.new()
					new_layer.name = xml.get_named_attribute_value("name")
					new_layer.visible = xml.get_named_attribute_value("visibility") != "hidden"
					new_layer.position = Vector2(
						xml.get_named_attribute_value("x").to_int(),
						xml.get_named_attribute_value("y").to_int()
					)
					if parent:
						parent.children.append(new_layer)
						new_layer.parent = parent
					
					var src = xml.get_named_attribute_value("src")
					if src != "" and zip.file_exists(src):
						var image_data = zip.read_file(src)
						var img = Image.new()
						if img.load_png_from_buffer(image_data) == OK:
							new_layer.image = img
						else:
							push_warning("レイヤー画像が読み込めませんでした: %s" % src)
					layer_list.append(new_layer)
			
			XMLParser.NODE_ELEMENT_END:
				var tag = xml.get_node_name()
				if tag == "stack":
					# 現在のスタックが終わったらリターンして1つ上へ
					return
	

# 画像の全体サイズを取得する
func get_image_size(path: String):
	var stack = get_stack_xml(path)
	var xml := XMLParser.new()
	var err = xml.open_buffer(stack)
	if err != OK:
		push_error("スタック情報が読み込めませんでした")
		return null
	var result = xml.read()
	if result == ERR_FILE_EOF:
		push_error("スタック情報が空です")
		return null
	if xml.get_node_type() == XMLParser.NODE_ELEMENT:
		var tag = xml.get_node_name()
		if tag == "image":
			var w = xml.get_named_attribute_value("w").to_int()
			var h = xml.get_named_attribute_value("h").to_int()
			var size = Vector2(w, h)
			return size
	push_error("画像サイズ情報が読み込めませんでした")
	return null


#----Pending----

func get_thumbnail(path: String) -> Image:
	if is_ora(path):
		var zip = ZIPReader.new()
		var err = zip.open(root.get_current_dir().path_join(path))
		if err != OK:
			print(err)
			return null
		var thumb_file = zip.read_file("Thumbnails/thumbnail.png")
		var thumb = Image.new()
		err = thumb.load_png_from_buffer(thumb_file)
		if err != OK:
			print(err)
			return null
		return thumb
	return null

func get_merged_image(path: String) -> Image:
	if is_ora(path):
		var zip = ZIPReader.new()
		var err = zip.open(root.get_current_dir().path_join(path))
		if err != OK:
			print(err)
			return null
		var image_file = zip.read_file("mergedimage.png")
		var image = Image.new()
		err = image.load_png_from_buffer(image_file)
		if err != OK:
			print(err)
			return null
		return image
	return null
