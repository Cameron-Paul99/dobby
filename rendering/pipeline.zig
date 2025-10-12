const c = @import("clibs.zig").c;
const std = @import("std");

const PipelineBuilder = struct {

    shader_stages: []c.vk.PipelineShaderStageCreateInfo,
    vertex_input_state: c.vk.PipelineVertexInputStateCreateInfo,
    input_assembly_state: c.vk.PipelineInputAssemblyStateCreateInfo,
    viewport: c.vk.Viewport,
    scissor: c.vk.Rect2D,
    rasterization_state: c.vk.PipelineRasterizationStateCreateInfo,
    color_blend_attachment_state: c.vk.PipelineColorBlendAttachmentState,
    multisample_state: c.vk.PipelineMultisampleStateCreateInfo,
    pipeline_layout: c.vk.PipelineLayout,
    depth_stencil_state: c.vk.PipelineDepthStencilStateCreateInfo,

    pub fn create(self: PipelineBuilder, device: c.vk.Device, render_pass: c.vk.RenderPass) c.vk.Pipeline{
        const viewportState = std.mem.zeroInit(c.vk.PipelineViewportStateCreateInfo, .{
            .


    }
};
