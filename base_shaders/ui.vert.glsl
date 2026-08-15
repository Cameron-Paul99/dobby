#version 450


layout(push_constant) uniform PushConstants {
    vec2 scale;
    vec2 translate;
} pc;

layout(location = 0) in vec2 in_pos;
layout(location = 1) in vec2 in_uv_max;
layout(location = 2) in vec2 in_uv_min;
layout(location = 3) in vec4 in_color;
layout(location = 4) in uint in_atlas_id;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out vec2 frag_tex_coord;
layout(location = 2) flat out uint frag_atlas_id;

void main() {

    gl_Position = vec4(in_pos * pc.scale + pc.translate, 0.0, 1.0);

    frag_color = in_color;
    frag_tex_coord = in_uv;
    frag_atlas_id = in_atlas_id;
    
}
