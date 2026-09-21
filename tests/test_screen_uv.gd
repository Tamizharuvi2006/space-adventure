extends SceneTree

func _init() -> void:
	var s = Shader.new()
	s.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = SCREEN_UV;
	COLOR = vec4(uv.x, uv.y, 0.0, 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = s
	var cr = ColorRect.new()
	cr.material = mat
	print("Shader compiled successfully with SCREEN_UV!")
	quit()
