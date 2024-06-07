class_name FileUtilities
extends Object

static func load_image_texture(path: String) -> ImageTexture:
	var loaded_image: Image = Image.new()
	if loaded_image.load(path) != OK:
		push_warning("Failed to load image texture at: ", path)
		return null
	else:
		var image_texture: ImageTexture = ImageTexture.new()
		image_texture.set_image(loaded_image)
		return image_texture
