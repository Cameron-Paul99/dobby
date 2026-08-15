#version 450

layout(set = 1, binding = 0) uniform sampler atlasSampler;
layout(set = 1, binding = 1) uniform texture2D atlases[64];

layout(location = 0) in vec4 frag_color;
layout(location = 1) in vec2 frag_tex_coord;
layout(location = 2) flat in uint frag_atlas_id;

layout(location = 0) out vec4 outColor;


void main(){

    vec4 tex = texture(
        sampler2D(atlases[frag_atlas_id], atlasSampler),
        frag_tex_coord
    );


    outColor = frag_color * tex;
}
