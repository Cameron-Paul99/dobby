#version 450

layout(location = 0) in vec2 in_pos;
layout(location = 1) in vec3 in_color;
layout(location = 2) in vec2 in_tex_coord;

layout(location = 1) out vec2 frag_tex_coord;
layout(location = 0) out vec3 frag_color;

// Matches your GPUCameraData { Mat4 view_proj; }
layout(set = 0, binding = 0) uniform CameraUBO {
    mat4 view_proj;
} camera;

void main() {

    gl_Position = vec4(in_pos, 0.0, 1.0);
    frag_color = in_color;
    frag_tex_coord = in_tex_coord;
}
