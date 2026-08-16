#version 450

layout(push_constant) uniform PushConstants {
    vec2 scale;
    vec2 translate;
} pc;

layout(location = 0) in vec2 in_pos;
layout(location = 1) in vec2 in_uv;
layout(location = 2) in vec4 in_color;
layout(location = 3) in uint in_atlas_id;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out vec2 frag_tex_coord;
layout(location = 2) flat out uint frag_atlas_id;

void main() {
    
    vec2 world = in_pos * pc.scale + pc.translate;
    gl_Position = vec4(world, 0.0, 1.0);
    frag_color = in_color;
    frag_tex_coord = in_uv;
    frag_atlas_id = in_atlas_id;
}
