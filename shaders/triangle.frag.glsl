#version 450

layout(set = 1, binding = 0) uniform sampler2D texSampler;

layout(location = 0) out vec4 outColor;
layout(location = 0) in vec3 frag_color;
layout(location = 1) in vec2 frag_tex_coord;

void main(){
	outColor = vec4(frag_color * texture(texSampler, frag_tex_coord).rgb, 1.0);

}
