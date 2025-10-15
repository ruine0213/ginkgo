extends Control


@onready var menubar = $MenuBar
@onready var filemenu = $MenuBar/File

@onready var file_dialog = $FileDialog

@onready var layer_tree = $HSplitContainer/Tree

@onready var texture_rect = $HSplitContainer/TextureRect

enum FileMenuId {OPEN, EXPORT}

var current_directory
var current_image

var layer_list = []
var image_size: Vector2i



func _ready() -> void:
	filemenu.get_popup().id_pressed.connect(_on_file_selected)
	

# ORAファイルから画像を生成して表示する
func set_image() -> void:
	var ora_loader = ORALoader.new()
	ora_loader.set_root(current_directory)
	if ora_loader.is_ora(current_image):
		var stack = ora_loader.get_stack_xml(current_image)
		image_size = ora_loader.get_image_size(current_image)
		ora_loader.generate_layers(current_image, stack)
		layer_list = ora_loader.layer_list
		var image = generate_image()
		texture_rect.texture = ImageTexture.create_from_image(image)


# レイヤー情報からツリービューを作成する
func populate_layer_tree():
	layer_tree.clear()
	var root = layer_tree.create_item()
	root.set_text(0, current_image)
	
	for layer in layer_list:
		if layer.parent == null:
			add_layer_tree_item(layer, root)

func add_layer_tree_item(layer: Layer, parent_item: TreeItem):
	var item: TreeItem = layer_tree.create_item(parent_item)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_text(0, layer.name)
	item.set_checked(0, layer.visible)
	item.set_editable(0, true)
	
	item.set_metadata(0, layer)
	
	for child in layer.children:
		add_layer_tree_item(child, item)


# レイヤーごとに画像を合成する
func generate_image() -> Image:
	if layer_list.is_empty():
		return null
	var final_image := Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	final_image.fill(Color(0, 0, 0, 0))
	
	for root_layer in layer_list:
		if root_layer.parent == null:
			generate_image_recursive(final_image, root_layer, true)
	
	return final_image

func generate_image_recursive(final_image: Image, layer: Layer, parent_visible: bool):
	var this_visible = layer.visible and parent_visible

	for i in range(layer.children.size() - 1, -1, -1):
		var child = layer.children[i]
		generate_image_recursive(final_image, child, this_visible)

	if this_visible and layer.image:
		final_image.blend_rect(
			layer.image,
			Rect2(Vector2.ZERO, layer.image.get_size()),
			layer.position
		)

# レイヤーの表示状態に変更があった際に画像を更新する
func update_composited_image():
	var img = generate_image()
	if img:
		var tex = ImageTexture.create_from_image(img)
		texture_rect.texture = tex


func _on_file_selected(id: int) -> void:
	match id:
		FileMenuId.OPEN:
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray(["*.ora"])
			file_dialog.show()
		FileMenuId.EXPORT:
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters = PackedStringArray(["*.png"])
			file_dialog.current_file = ""
			file_dialog.show()


func _on_file_dialog_file_selected(path: String) -> void:
	match file_dialog.file_mode:
		FileDialog.FILE_MODE_OPEN_FILE:
			current_directory = path.get_base_dir()
			current_image = path.get_file()
			set_image()
			populate_layer_tree()
			layer_tree.show()
		FileDialog.FILE_MODE_SAVE_FILE:
			var img = texture_rect.texture.get_image()
			var err = img.save_png(path)
			if err != OK:
				push_error("ファイルが正常に保存できませんでした")


func _on_tree_item_edited() -> void:
	var edited_item = layer_tree.get_edited()
	if edited_item:
		var layer: Layer = edited_item.get_metadata(0)
		layer.visible = edited_item.is_checked(0)
		
		update_composited_image()
