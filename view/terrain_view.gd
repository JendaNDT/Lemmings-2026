class_name TerrainView
extends Sprite2D
## Kreslí terén: logickou mapu pošle na grafickou kartu jako texturu
## a shader (terrain.gdshader) z ní udělá hezký terén.

var _mask: TerrainMask
var _image: Image
var _texture: ImageTexture
var _version := -1


func setup(mask: TerrainMask) -> void:
	_mask = mask
	_image = Image.create_from_data(
		mask.width, mask.height, false, Image.FORMAT_RGBA8, mask.data
	)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture
	_version = mask.version


func _process(_delta: float) -> void:
	if _mask == null or _mask.version == _version:
		return
	_version = _mask.version
	_image.set_data(_mask.width, _mask.height, false, Image.FORMAT_RGBA8, _mask.data)
	_texture.update(_image)
