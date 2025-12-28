const c = @import("clibs.zig").c;
const std = @import("std");
const helper = @import("helper.zig");
const sc = @import("swapchain.zig");
const core_mod = @import("core.zig");
//const math3d = @import("math.zig");
const log = std.log;

pub const MaterialTemplateId_u32 = u32;
pub const MaterialInstanceId_u32 = u32;

//const Vec2 = math.Vec2;
//const Vec3 = math.Vec3;
//const Vec4 = math.Vec4;
//const Mat4 = math.Mat4;



const MaterialTemplate = struct {
    pipeline: c.VkPipeline,
    pipeline_layout: c.VkPipelineLayout,
    bind_point: c.VkPipelineBindPoint, 
};

const MaterialInstance = struct {
    template_id: u32,
    texture_set: c.VkDescriptorSet,
};

const FRAME_OVERLAP = 4;

const FrameData = struct {
    present_semaphore: c.VkSemaphore = helper.VK_NULL_HANDLE,
    render_semaphore: c.VkSemaphore = helper.VK_NULL_HANDLE,
    render_fence: c.VkFence = helper.VK_NULL_HANDLE,
    command_pool: c.VkCommandPool = helper.VK_NULL_HANDLE,
    main_command_buffer: c.VkCommandBuffer = helper.VK_NULL_HANDLE,

    object_buffer: helper.AllocatedBuffer = .{ .buffer = helper.VK_NULL_HANDLE, .allocation = helper.VK_NULL_HANDLE, .size = 0 },
    object_descriptor_set: c.VkDescriptorSet = helper.VK_NULL_HANDLE,
};

const UploadContext = struct {
    upload_fence: c.VkFence = helper.VK_NULL_HANDLE,
    command_pool: c.VkCommandPool = helper.VK_NULL_HANDLE,
    command_buffer: c.VkCommandBuffer = helper.VK_NULL_HANDLE,
};

pub const Renderer = struct {
    frames: [FRAME_OVERLAP]FrameData,
    render_pass: c.VkRenderPass,
    material_system: MaterialSystem,
    upload_context: UploadContext,
 //   camera_pos: Vec3
    frame_number: i32 = 0,
    images_in_flight: []c.VkFence = &.{},

    // pipelines / layouts
    // maybe upload context too

    pub fn init(allocator: std.mem.Allocator, core: *core_mod.Core, swapchain: *sc.Swapchain) !Renderer {

        // Render pass creation
        const render_pass = try sc.CreateRenderPass(swapchain, core.device.handle, core.alloc_cb);

        // Create Framebuffers
        sc.CreateFrameBuffers(core.device.handle, swapchain, render_pass, allocator, core.alloc_cb);

        // Pipeline Material Creation 
        const material_system = try MaterialSystem.init(allocator);

        var renderer = Renderer {
            .frames = .{ FrameData{} } ** FRAME_OVERLAP, 
            .render_pass = render_pass, 
            .material_system = material_system,
            .upload_context = .{},
        };
        
        // Pipeline Creation
        try CreatePipelines(core, swapchain, &renderer, allocator);
        
        // Commands Creation
        try CreateCommands(&renderer, core.physical_device.graphics_queue_family, core);

        // Create Sync Structures
        try CreateSyncStructures(&renderer, core, swapchain, allocator); 


        return renderer;
        
    }
    pub fn DrawFrame(self: *Renderer, core: *core_mod.Core, swapchain: *sc.Swapchain) !void {

        const timeout: u64 = 1_000_000_000;
        const frame = &self.frames[@intCast(@mod(self.frame_number, FRAME_OVERLAP))];

        try helper.check_vk(c.vkWaitForFences(core.device.handle, 1 ,&frame.render_fence, c.VK_TRUE, timeout));
        try helper.check_vk(c.vkResetFences(core.device.handle, 1, &frame.render_fence));
        
        var swapchain_image_index: u32 = undefined;
        try helper.check_vk(c.vkAcquireNextImageKHR(
                core.device.handle, 
                swapchain.handle, 
                timeout, 
                frame.present_semaphore, 
                helper.VK_NULL_HANDLE, 
                &swapchain_image_index
        ));

        // TODO: Revisit images in flight to remove high frame overlap. Fix by per frame render-finished semaphores

        //if (self.images_in_flight[swapchain_image_index]  != null) {
           // try helper.check_vk(c.vkWaitForFences(
          //          core.device.handle, 
         //           1, 
         //           &self.images_in_flight[swapchain_image_index], 
         //           c.VK_TRUE, 
        //            timeout
         //   ));
        //}

       // self.images_in_flight[swapchain_image_index] = frame.render_fence;

        const cmd = frame.main_command_buffer;

        try helper.check_vk(c.vkResetCommandBuffer(cmd, 0));

        const cmd_begin_info = std.mem.zeroInit(c.VkCommandBufferBeginInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        });
        
        try helper.check_vk(c.vkBeginCommandBuffer(cmd, &cmd_begin_info));
        
        const color_clear: c.VkClearValue = .{
            .color = .{ .float32 = [_]f32{0.0, 0.0, 0.0, 1.0} },
        };

        // TODO: Depth addition

        //const depth_clear = c.VkClearValue {
         //   .depthStencil = .{
         //       .depth = 1.0,
         //       .stencil = 0,
         //   },
        //};
        //
        const clear_values = [_]c.VkClearValue{
            color_clear,  
        };

        const render_pass_begin_info = std.mem.zeroInit(c.VkRenderPassBeginInfo , .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.render_pass,
            .framebuffer = swapchain.framebuffers[swapchain_image_index],
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = swapchain.extent,
            },
            .clearValueCount = @as(u32, @intCast(clear_values.len)),
            .pClearValues = &clear_values[0],
        });

        c.vkCmdBeginRenderPass(cmd, &render_pass_begin_info, c.VK_SUBPASS_CONTENTS_INLINE);

        // Bind pipeline and draw
        try self.material_system.BindPipeline(cmd, "Triangle");
        
       // const verts = [_]helper.Vertex{
       //     .{ .pos = .{ 0.0, -0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
      //      .{ .pos = .{ 0.5,  0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
     //       .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
     //   };
        
     //   const offsets = [_]c.VkDeviceSize{0};
     //   c.vkCmdBindVertexBuffers(cmd, 0, 1, &vertex_buffer, &offsets[0]);

        c.vkCmdDraw(cmd, 3, 1, 0, 0);

        c.vkCmdEndRenderPass(cmd);
        try helper.check_vk(c.vkEndCommandBuffer(cmd));

        // Submit

        const wait_stages = [_]c.VkPipelineStageFlags { c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT };

        const submit_info: c.VkSubmitInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &frame.present_semaphore,
            .pWaitDstStageMask = &wait_stages,
            .commandBufferCount = 1,
            .pCommandBuffers = &cmd,
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &frame.render_semaphore,
        };

        try helper.check_vk(c.vkQueueSubmit(core.device.graphics_queue, 1, &submit_info, frame.render_fence));

        // Present

        const present_info: c.VkPresentInfoKHR = .{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &frame.render_semaphore,
            .swapchainCount = 1,
            .pSwapchains = &swapchain.handle,
            .pImageIndices = &swapchain_image_index,
            .pResults = null,
        };

        _ = c.vkQueuePresentKHR(core.device.present_queue, &present_info);

        self.frame_number += 1;

    }
    pub fn OnSwapchainRecreated(self: *Renderer, core: *core_mod.Core, swapchain: *sc.Swapchain) !void { 
        _ = core;
        _ = swapchain;
        _ = self;

    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator, core: *core_mod.Core) void {

        if (core.device.handle != null){
            _ = c.vkDeviceWaitIdle(core.device.handle);
        }

        if (self.images_in_flight.len != 0) {
            allocator.free(self.images_in_flight);
            self.images_in_flight = &.{};
        }
        
        self.material_system.deinitGpu(core.device.handle, core.alloc_cb);
        self.material_system.deinit(allocator);

        // 2) render pass
        if (self.render_pass != null) {
            c.vkDestroyRenderPass(core.device.handle, self.render_pass, core.alloc_cb);
            self.render_pass = null;
        }

        for (&self.frames) |*f| {
            // Destroy sync first (they’re separate objects)
            if (f.present_semaphore != helper.VK_NULL_HANDLE) {
                c.vkDestroySemaphore(core.device.handle, f.present_semaphore, core.alloc_cb);
                f.present_semaphore = helper.VK_NULL_HANDLE;
            }
            if (f.render_semaphore != helper.VK_NULL_HANDLE) {
                c.vkDestroySemaphore(core.device.handle, f.render_semaphore, core.alloc_cb);
                f.render_semaphore = helper.VK_NULL_HANDLE;
            }
            if (f.render_fence != helper.VK_NULL_HANDLE) {
                c.vkDestroyFence(core.device.handle, f.render_fence, core.alloc_cb);
                f.render_fence = helper.VK_NULL_HANDLE;
            }

        // Destroying the pool implicitly releases its command buffers
            if (f.command_pool != helper.VK_NULL_HANDLE) {
                c.vkDestroyCommandPool(core.device.handle, f.command_pool, core.alloc_cb);
                f.command_pool = helper.VK_NULL_HANDLE;
                f.main_command_buffer = helper.VK_NULL_HANDLE;
            }
        }

        if (self.upload_context.command_pool != helper.VK_NULL_HANDLE) {
            c.vkDestroyCommandPool(core.device.handle, self.upload_context.command_pool, core.alloc_cb);
            self.upload_context.command_pool = helper.VK_NULL_HANDLE;
            self.upload_context.command_buffer = helper.VK_NULL_HANDLE;
        }

        if (self.upload_context.upload_fence != helper.VK_NULL_HANDLE){
            c.vkDestroyFence(core.device.handle, self.upload_context.upload_fence, core.alloc_cb);
            self.upload_context.upload_fence = helper.VK_NULL_HANDLE; 

        }
    }
};


// Add 2 more helper functions for instance and template
pub const MaterialSystem = struct {

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
        texture_set: c.VkDescriptorSet,
        bind_point: c.VkPipelineBindPoint,
        allocator: std.mem.Allocator
        ) !MaterialInstanceId_u32 {

            _ = try self.AddTemplate(
                template_name, 
                pipeline, 
                pipeline_layout, 
                allocator, 
                bind_point
            );

            const instance_id = try self.AddInstance(
                instance_name, 
                texture_set, 
                allocator
            ); 

            return instance_id;
    }

    pub fn AddInstance(
        self: *MaterialSystem, 
        instance_name: []const u8, 
        texture_set: c.VkDescriptorSet, allocator: std.mem.Allocator)  !MaterialInstanceId_u32 {

        const instance_id: MaterialInstanceId_u32 = @intCast(self.instances.items.len);

        try self.instances.append(allocator , .{
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
        pipeline_layout: c.VkPipelineLayout,
        allocator: std.mem.Allocator,
        bind_point: c.VkPipelineBindPoint, 
        ) !MaterialTemplateId_u32 {

        const template_id: MaterialTemplateId_u32 = @intCast(self.templates.items.len);

        try self.templates.append(allocator , .{
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .bind_point = bind_point  
        });

        try self.templates_by_name.put(template_name, template_id);

        return template_id;

    }

    pub fn GetTemplateByName(
        self: *MaterialSystem,
        name: []const u8,
    ) ?*MaterialTemplate {
        const id = self.templates_by_name.get(name) orelse return null;
        return &self.templates.items[@intCast(id)];
    }

    pub fn BindPipeline(
        self: *MaterialSystem,
        cmd: c.VkCommandBuffer,
        name: []const u8,
        ) !void {
            
        const tpl = self.GetTemplateByName(name) orelse
            @panic("Missing pipeline template");
        c.vkCmdBindPipeline(cmd, tpl.bind_point, tpl.pipeline);
        
    }


    pub fn init(allocator: std.mem.Allocator) !MaterialSystem {
        return .{

            .templates = try std.ArrayList(MaterialTemplate).initCapacity(allocator, 0),
            .templates_by_name = std.StringHashMap(MaterialTemplateId_u32).init(allocator),

            .instances = try std.ArrayList(MaterialInstance).initCapacity(allocator, 0),
            .instances_by_name = std.StringHashMap(MaterialInstanceId_u32).init(allocator),

        };
    }

    pub fn deinit(self: *MaterialSystem, allocator: std.mem.Allocator) void {
        self.templates.deinit(allocator);
        self.templates_by_name.deinit();
        self.instances.deinit(allocator);
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


// TODO: make a transfer queue, rather than submitting to the graphics queue
pub fn CreateCommands(renderer: *Renderer ,graphics_qfi: u32, core: *core_mod.Core) !void {
    
    const command_pool_ci = std.mem.zeroInit(c.VkCommandPoolCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = graphics_qfi,
    });

    for (&renderer.frames) |*frame| {

       try helper.check_vk(c.vkCreateCommandPool( core.device.handle, &command_pool_ci, core.alloc_cb, &frame.command_pool));

       const command_buffer_ci = std.mem.zeroInit(c.VkCommandBufferAllocateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = frame.command_pool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
       });

       try helper.check_vk(c.vkAllocateCommandBuffers(core.device.handle, &command_buffer_ci, &frame.main_command_buffer));
       log.info("Created command pool and command buffer", .{});

    }
    
    const upload_command_pool_ci = std.mem.zeroInit(c.VkCommandPoolCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = 0,
        .queueFamilyIndex = graphics_qfi,
    });

    try helper.check_vk(c.vkCreateCommandPool(core.device.handle, &upload_command_pool_ci, core.alloc_cb, &renderer.upload_context.command_pool));
    
    const upload_command_buffer_ci = std.mem.zeroInit(c.VkCommandBufferAllocateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = renderer.upload_context.command_pool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    });

    try helper.check_vk(c.vkAllocateCommandBuffers(core.device.handle, &upload_command_buffer_ci, &renderer.upload_context.command_buffer));

}

pub fn CreateSyncStructures(
    renderer: *Renderer, 
    core: *core_mod.Core, 
    swapchain: *sc.Swapchain, 
    allocator: std.mem.Allocator) !void{

    const semaphore_ci = std.mem.zeroInit(c.VkSemaphoreCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    });

    const fence_ci = std.mem.zeroInit(c.VkFenceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    });

    for (&renderer.frames) |*frame| {
        try helper.check_vk(c.vkCreateSemaphore(core.device.handle, &semaphore_ci, core.alloc_cb, &frame.present_semaphore));
        try helper.check_vk(c.vkCreateSemaphore(core.device.handle, &semaphore_ci, core.alloc_cb, &frame.render_semaphore));
        try helper.check_vk(c.vkCreateFence(core.device.handle, &fence_ci, core.alloc_cb, &frame.render_fence));
    }

    const upload_fence_ci = std.mem.zeroInit(c.VkFenceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    });

    renderer.images_in_flight = try allocator.alloc(c.VkFence, swapchain.framebuffers.len);
    @memset(renderer.images_in_flight, null);
    std.debug.assert(swapchain.framebuffers.len == swapchain.images.len);

    try helper.check_vk(c.vkCreateFence(
            core.device.handle, 
            &upload_fence_ci, 
            core.alloc_cb, 
            &renderer.upload_context.upload_fence
    ));

    log.info("Created sync structures", .{});
}


pub fn CreatePipelines(
    core: *core_mod.Core,
    swapchain: *sc.Swapchain, 
    renderer: *Renderer ,
    allocator: std.mem.Allocator
    ) !void {
    
    // AI says this function is wrong. Keep this in mind going forward.
    const triangle_mods = try helper.MakeShaderModules(core.device.handle, core.alloc_cb, "triangle.vert", "triangle.frag");
    defer c.vkDestroyShaderModule(core.device.handle, triangle_mods.vert_mod, core.alloc_cb);
    defer c.vkDestroyShaderModule(core.device.handle, triangle_mods.frag_mod, core.alloc_cb);

    const pipeline_layout_ci = std.mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    });


    // Pipeline Layout creation
    var triangle_pipeline_layout: c.VkPipelineLayout = undefined;
    try helper.check_vk(c.vkCreatePipelineLayout(core.device.handle, &pipeline_layout_ci, core.alloc_cb, &triangle_pipeline_layout));
    

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

    const triangle_pipeline = try pipeline_builder.create(core.device.handle, renderer.render_pass, core.alloc_cb);

    _ = try renderer.material_system.AddTemplateAndInstance(
         "Triangle", 
         "Triangle_Instance", 
         triangle_pipeline, 
         triangle_pipeline_layout, 
         helper.VK_NULL_HANDLE,
         c.VK_PIPELINE_BIND_POINT_GRAPHICS,
         allocator,
    );

}



