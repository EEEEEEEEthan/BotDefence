@tool
extends Texture2D
class_name EditableTexture

@export var _hex_data: String:
	set (value):
		_hex_data = value
		emit_changed()
		notify_property_list_changed()

var _bytes: PackedByteArray:
	get:
		if not _bytes:
			if _hex_data:
				_bytes = _hex_data.hex_decode()
		return _bytes
	set(value):
		_bytes = value
		_hex_data = _bytes.hex_encode()

var _texture: ImageTexture:
	get:
		if not _texture:
			if _hex_data:
				var image = Image.new()
				var error = image.load_png_from_buffer(_bytes)
				if error == OK:
					_texture = ImageTexture.new()
					_texture.set_image(image)
		if not _texture:
			var image := Image.create(16, 16, false, Image.FORMAT_RGBA8);
			image.fill(Color.WHITE)
			_texture = ImageTexture.create_from_image(image);
		return _texture
	set(value):
		_texture = value
		if value:
			var image = value.get_image()
			if image:
				_bytes = image.save_png_to_buffer()
		else:
			_bytes = PackedByteArray()

func _get_width() -> int:
	return _texture.get_width()

func _get_height() -> int:
	return _texture.get_height()

func _get_rid() -> RID:
	return _texture.get_rid()

func _has_alpha() -> bool:
	return _texture.has_alpha()

func _draw(rid: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_texture.draw(rid, pos, modulate, transpose)

func _draw_rect(rid: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	_texture.draw_rect(rid, rect, tile, modulate, transpose)

func _draw_rect_region(rid: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	_texture.draw_rect_region(rid, rect, src_rect, modulate, transpose, clip_uv)
