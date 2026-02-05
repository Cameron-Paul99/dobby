#version 450

layout(location = 0) in vec2 in_pos;
layout(location = 1) in vec3 in_color;
layout(location = 2) in vec2 in_tex_coord;

layout(location = 3) in vec2 sprite_pos;
layout(location = 4) in vec2 sprite_scale;
layout(location = 5) in vec2 sprite_rotation;
layout(location = 6) in vec2 uv_min;
layout(location = 7) in vec2 uv_max;
layout(location = 8) in vec4 tint;
layout(location = 9) in uint atlas_id; 

layout(location = 0) out vec3 frag_color;
layout(location = 1) out vec2 frag_tex_coord;
layout(location = 2) flat out uint frag_atlas_id;

// Matches your GPUCameraData { Mat4 view_proj; }
layout(set = 0, binding = 0) uniform CameraUBO {
    mat4 view_proj;
} camera;

void main() {

    vec2 world = in_pos * sprite_scale + sprite_pos;
    gl_Position = camera.view_proj * vec4(world, 0.0, 1.0);

    //gl_Position = vec4(in_pos, 0.0, 1.0);
    frag_color = in_color;
    frag_tex_coord = mix(uv_min, uv_max, in_tex_coord);
    frag_atlas_id = atlas_id;
}
