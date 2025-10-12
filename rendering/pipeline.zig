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
    alloc_cb: ?*c.VkAllocationCallbacks = null,

    pub fn create(self: PipelineBuilder, device: c.vk.Device, render_pass: c.vk.RenderPass) c.vk.Pipeline{

        const viewportState = std.mem.zeroInit(c.vk.PipelineViewportStateCreateInfo, .{
            .sType = c.vk.STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = &self.viewport,
            .scissorCount = 1,
            .pScissor = &self.scissor,
        });

        const color_blend_state = std.mem.zeroInit(c.vk.PipelineColorBlendStateCreateInfo, .{
            .sType = c.vk.STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = c.vk.FALSE,
            .logicOp = c.vk.LOGIC_OP_COPY,
            .attachmentCount = 1,
            .pAttachments = &self.color_blend_attachment_state,
        });
        
        const pipeline_ci = std.mem.zeroinit(c.vk.GraphicsPipelineCreateInfo, .{

            .sType = c.vk.STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = @as(u32, @intCast(self.shader_stages.len)),
            .pStages = self.shader_stages.ptr,
            .pVertexInputState = &self.vertex_input_state,
            .pInputAssemblyState = &self.input_assembly_state,
            .pViewportState = &viewport_state,
            .pRasterizationState = &self.rasterization_state,
            .pMultisampleState = &self.multisample_state,
            .pColorBlendState = &color_blend_state,
            .pDepthStencilState = &self.depth_stencil_state,
            .layout = self.pipeline_layout,
            .renderPass = render_pass,
            .subpass = 0,
            .basePipelineHandle = VK_NULL_HANDLE,
        });
        
        var pipeline: c.vk.Pipeline = undefined;
        
        check_vk(c.vk.CreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipeline_ci, self.alloc_cbs, &pipeline)) catch {
            log.err("Failed to create graphics pipeline", .{});
            return VK_NULL_HANDLE;
        };

        return pipeline;

    }

    pub fn InitPipelines(self: *Self) void{
        



    }
};
