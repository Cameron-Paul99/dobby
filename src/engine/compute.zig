const c = @import("clibs.zig").c;
const std = @import("std");

pub const ComputePipeline = struct {
    pipeline: c.VkPipeline,
    layout: c.VkPipelineLayout,

    pub fn deinit(self: ComputePipeline, device: c.VkDevice, alloc_cb: ?*c.VkAllocationCallbacks) void {
        c.vkDestroyPipeline(device, self.pipeline, alloc_cb);
        c.vkDestroyPipelineLayout(device, self.layout, alloc_cb);
    }
};



pub fn CreateComputePipelines(
    device: c.VkDevice,
    shader_path: []const u8,
    set_layouts: []const c.VkDescriptorSetLayout,
    push_constant_size: u32,
    alloc_cb: ?*c.VkAllocationCallbacks,
) !ComputePipeline {
    
    // 1. Load shader
    const shader_mod = try helper.MakeComputeShaderModule(device, alloc_cb, shader_path);
    defer c.vkDestroyShaderModule(device, shader_mod, alloc_cb);

    // 2. Push constants
    const push_range = c.VkPushConstantRange{
        .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0,
        .size = push_constant_size,
    };

    // 3. Pipeline layout
    var layout: c.VkPipelineLayout = undefined;
    const layout_ci = std.mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = @as(u32, @intCast(set_layouts.len)),
        .pSetLayouts = set_layouts.ptr,
        .pushConstantRangeCount = if (push_constant_size > 0) 1 else 0,
        .pPushConstantRanges = if (push_constant_size > 0) &push_range else null,
    });
    try helper.check_vk(c.vkCreatePipelineLayout(device, &layout_ci, alloc_cb, &layout));
    errdefer c.vkDestroyPipelineLayout(device, layout, alloc_cb);

    // 4. Pipeline
    var pipeline: c.VkPipeline = undefined;
    const pipeline_ci = std.mem.zeroInit(c.VkComputePipelineCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage = std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .module = shader_mod,
            .pName = "main",
        }),
        .layout = layout,
    });
    try helper.check_vk(c.vkCreateComputePipelines(
        device, 
        null, // pipeline cache — can add later
        1, 
        &pipeline_ci, 
        alloc_cb, 
        &pipeline
    ));

    return .{
        .pipeline = pipeline,
        .layout = layout,
    };
}





