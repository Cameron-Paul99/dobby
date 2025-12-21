const c = @import("clibs.zig").c;
const std = @import("std");
const helper = @import("helper.zig");
const sc = @import("swapchain.zig");
const core_mod = @import("core.zig");
const log = std.log;

pub const MaterialTemplateId_u32 = u32;
pub const MaterialInstanceId_u32 = u32;

pub const AllocatedBuffer = struct {
    buffer: c.VkBuffer,
    allocation: c.VmaAllocation,
};

const MaterialTemplate = struct {
    pipeline: c.VkPipeline,
    pipeline_layout: c.VkPipelineLayout,
};

const MaterialInstance = struct {
    template_id: u32,
    texture_set: c.VkDescriptorSet,
};

const FRAME_OVERLAP = 2;

const FrameData = struct {
    present_semaphore: c.VkSemaphore = helper.VK_NULL_HANDLE,
    render_semaphore: c.VkSemaphore = helper.VK_NULL_HANDLE,
    render_fence: c.VkFence = helper.VK_NULL_HANDLE,
    command_pool: c.VkCommandPool = helper.VK_NULL_HANDLE,
    main_command_buffer: c.VkCommandBuffer = helper.VK_NULL_HANDLE,

    object_buffer: AllocatedBuffer = .{ .buffer = helper.VK_NULL_HANDLE, .allocation = helper.VK_NULL_HANDLE },
    object_descriptor_set: c.VkDescriptorSet = helper.VK_NULL_HANDLE,
};


pub const Renderer = struct {
    frames: [FRAME_OVERLAP]FrameData,
    render_pass: c.VkRenderPass,
    material_system: MaterialSystem,
    // pipelines / layouts
    // maybe upload context too

    pub fn init(allocator: std.mem.Allocator, core: *core_mod.Core, swapchain: *sc.Swapchain) !Renderer {

        // Render pass creation
        const render_pass = try sc.CreateRenderPass(&swapchain, core.device.handle, core.alloc_cb);

        // Create Framebuffers
        sc.CreateFrameBuffers(core.device.handle, &swapchain, render_pass, allocator, core.alloc_cb);

        // Pipeline Material Creation 
        const material_system = try MaterialSystem.init(allocator);

        CreateCommands(core.physical_device.graphics_queue_family);

    
        return .{
            .frames = .{ FrameData{} } ** FRAME_OVERLAP, 
            .render_pass = render_pass, 
            .material_system = material_system
        }; 
        
    }
    pub fn drawFrame(self: *Renderer, core: *core_mod.Core, swapchain: *sc.Swapchain) !void {
        _ = core;
        _ = swapchain;
        _ = self;
    }
    pub fn onSwapchainRecreated(self: *Renderer, core: *core_mod.Core, swapchain: *sc.Swapchain) !void { 
        _ = core;
        _ = swapchain;
        _ = self;

    }
    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator, core: *core_mod.Core, alloc_cb: ?*c.VkAllocationCallbacks) void { 
        
        self.material_system.deinit(allocator);
        self.material_system.deinitGpu(core.device.handle, core.alloc_cb);

        // 2) render pass
        if (self.render_pass.* != null) {
            c.vkDestroyRenderPass(core.device.handle, self.render_pass.*, alloc_cb);
            self.render_pass.* = null;
        }

    }
};


// Add 2 more helper functions for instance and template
pub const MaterialSystem = struct {

    allocator: std.mem.Allocator,
    templates: std.ArrayList(MaterialTemplate),
    templates_by_name: std.StringHashMap(MaterialTemplateId_u32),

    instances: std.ArrayList(MaterialInstance),
    instances_by_name: std.StringHashMap(MaterialInstanceId_u32),

    pub fn AddTemplateAndInstance(
        self: *MaterialSystem, 
        template_name: []const u8, 
        instance_name: []const u8, 
        pipeline: c.VkPipeline, 
        pipeline_layout: c.VkPipelineLayout, 
        texture_set: c.VkDescriptorSet ) !MaterialInstanceId_u32 {

            _ = try self.AddTemplate(template_name, pipeline, pipeline_layout);

            const instance_id = try self.AddInstance(instance_name, texture_set); 

            return instance_id;
    }

    pub fn AddInstance(
        self: *MaterialSystem, 
        instance_name: []const u8, 
        texture_set: c.VkDescriptorSet)  !MaterialInstanceId_u32 {

        const instance_id: MaterialInstanceId_u32 = @intCast(self.instances.items.len);

        try self.instances.append(self.allocator , .{
            .template_id = instance_id,
            .texture_set = texture_set,
        });

        try self.instances_by_name.put(instance_name, instance_id);
            
        return instance_id;
    }

    pub fn AddTemplate(
        self: *MaterialSystem, 
        template_name: []const u8,
        pipeline: c.VkPipeline, 
        pipeline_layout: c.VkPipelineLayout 
        ) !MaterialTemplateId_u32 {

        const template_id: MaterialTemplateId_u32 = @intCast(self.templates.items.len);

        try self.templates.append(self.allocator , .{
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
        });

        try self.templates_by_name.put(template_name, template_id);

        return template_id;

    }

    pub fn init(allocator: std.mem.Allocator) !MaterialSystem {
        return .{

            .allocator = allocator,

            .templates = try std.ArrayList(MaterialTemplate).initCapacity(allocator, 0),
            .templates_by_name = std.StringHashMap(MaterialTemplateId_u32).init(allocator),

            .instances = try std.ArrayList(MaterialInstance).initCapacity(allocator, 0),
            .instances_by_name = std.StringHashMap(MaterialInstanceId_u32).init(allocator),
        };
    }

    pub fn deinit(self: *MaterialSystem) void {
        self.templates.deinit(self.allocator);
        self.templates_by_name.deinit();
        self.instances.deinit(self.allocator);
        self.instances_by_name.deinit();
    }

    pub fn deinitGpu(
        self: *MaterialSystem,
        device: c.VkDevice,
        alloc_cb: ?*const c.VkAllocationCallbacks,
    ) void {
        // Destroy pipelines first (they reference layouts internally)
        for (self.templates.items) |t| {
            if (t.pipeline != null) { // if your VK_NULL_HANDLE is null
                c.vkDestroyPipeline(device, t.pipeline, alloc_cb);
            }
        }

        // Destroy pipeline layouts
        for (self.templates.items) |t| {
            if (t.pipeline_layout != null) {
                c.vkDestroyPipelineLayout(device, t.pipeline_layout, alloc_cb);
            }
        }
    }

};



pub fn CreateCommands(graphics_qfi: u32,  ) void {
    
    const command_pool_ci = std.mem.zeroInit(c.VkCommandPoolCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = graphics_qfi,
    });

    // Add Frames here
    //
    //

    _ = command_pool_ci;




}







pub fn CreatePipelines(device: c.VkDevice, swapchain: *sc.Swapchain, material_system: *helper.MaterialSystem , render_pass: c.VkRenderPass, alloc_cb: ?*c.VkAllocationCallbacks) !void {
    
    // AI says this function is wrong. Keep this in mind going forward.
    const triangle_mods = try helper.MakeShaderModules(device, alloc_cb, "triangle.vert", "triangle.frag");
    defer c.vkDestroyShaderModule(device, triangle_mods.vert_mod, alloc_cb);
    defer c.vkDestroyShaderModule(device, triangle_mods.frag_mod, alloc_cb);

    const pipeline_layout_ci = std.mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    });


    // Pipeline Layout creation
    var triangle_pipeline_layout: c.VkPipelineLayout = undefined;
    try helper.check_vk(c.vkCreatePipelineLayout(device, &pipeline_layout_ci, alloc_cb, &triangle_pipeline_layout));
    

    // Stage Creation of pipeline
    const vert_stage_ci = std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = triangle_mods.vert_mod,
        .pName = "main",
    });

    const frag_stage_ci = std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = triangle_mods.frag_mod,
        .pName = "main",
    });

    const vertex_input_state_ci = std.mem.zeroInit(c.VkPipelineVertexInputStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    });

    const input_assembly_state_ci = std.mem.zeroInit(c.VkPipelineInputAssemblyStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    });

    const rasterization_state_ci = std.mem.zeroInit(c.VkPipelineRasterizationStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .cullMode = c.VK_CULL_MODE_NONE,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .lineWidth = 1.0,
    });

    const multisample_state_ci = std.mem.zeroInit(c.VkPipelineMultisampleStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .minSampleShading = 1.0,
    });

    const depth_stencil_state_ci = std.mem.zeroInit(c.VkPipelineDepthStencilStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = c.VK_TRUE,
        .depthWriteEnable = c.VK_TRUE,
        .depthCompareOp = c.VK_COMPARE_OP_LESS_OR_EQUAL,
        .depthBoundsTestEnable = c.VK_FALSE,
        .stencilTestEnable = c.VK_FALSE,
        .minDepthBounds = 0.0,
        .maxDepthBounds = 1.0,
    });

    const color_blend_attachment_state = std.mem.zeroInit(c.VkPipelineColorBlendAttachmentState, .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
    });

    var shader_stages = [_]c.VkPipelineShaderStageCreateInfo{
        vert_stage_ci,
        frag_stage_ci,
    };

    // Pipeline building
    var pipeline_builder = helper.PipelineBuilder {
        .shader_stages = shader_stages[0..],
        .vertex_input_state = vertex_input_state_ci,
        .input_assembly_state = input_assembly_state_ci,
        .viewport = .{
            .x = 0.0,
            .y = 0.0,
            .width = @as(f32, @floatFromInt(swapchain.extent.width)),
            .height = @as(f32, @floatFromInt(swapchain.extent.height)),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        },
        .scissor = .{
            .offset = .{.x = 0, .y = 0},
            .extent = swapchain.extent,
        },
        .rasterization_state = rasterization_state_ci,
        .color_blend_attachment_state = color_blend_attachment_state,
        .multisample_state = multisample_state_ci,
        .pipeline_layout = triangle_pipeline_layout,
        .depth_stencil_state = depth_stencil_state_ci,

    };

    const triangle_pipeline = try pipeline_builder.create(device, render_pass, alloc_cb);

    _ = try material_system.AddTemplateAndInstance(
         "Triangle", 
         "Triangle_Instance", 
         triangle_pipeline, 
         triangle_pipeline_layout, 
         helper.VK_NULL_HANDLE
         );

}



