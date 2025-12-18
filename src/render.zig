const c = @import("clibs.zig").c;
const std = @import("std");
const helper = @import("helper.zig");
const log = std.log;

pub fn CreatePipelines(device: c.VkDevice, alloc_cb: ?*c.VkAllocationCallbacks) !void {
    
    // AI says this function is wrong. Keep this in mind going forward.
    const triangle_mods = try helper.MakeShaderModules(device, alloc_cb, "triangle.vert", "triangle.frag");
    defer c.vkDestroyShaderModule(device, triangle_mods.vert_mod, alloc_cb);
    defer c.vkDestroyShaderModule(device, triangle_mods.frag_mod, alloc_cb);

    const pipeline_layout_ci = std.mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    });

    var triangle_pipeline_layout: c.vk.PipelineLayout = undefined;

    try helper.check_vk(c.VkCreatePipelineLayout(device, &pipeline_layout_ci, alloc_cb, &triangle_pipeline_layout));

    const vert_stage_ci = std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = triangle_mods.vert_mod,
        .pname = "main",
    });

    const frag_stage_ci = std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = triangle_mods.frag_mod,
        .pname = "main",
    });

    const vertex_input_state_ci = std.mem.zeroInit(c.VkPipelineVertexInputStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    });

    const input_assembly_state_ci = std.mem.zeroInit(c.PipelineInputAssemblyStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VkFalse,
    });

    const rasterization_state_ci = std.mem.zeroInit(c.VkPipelineRasterizationStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygon = c.VK_POLYGON_MODE_FILL,
        .cullMode = c.VK_CULL_MODE_NONE,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .lineWidth = 1.0,
    });
    



    // temp destroy modules but we want multiple pipelines so in the future we will destroy.


}



