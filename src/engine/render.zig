const c = @import("clibs.zig").c;
const std = @import("std");
const helper = @import("helper.zig");
const sc = @import("swapchain.zig");
const core_mod = @import("core.zig");
const math = @import("../math.zig");
const text = @import("textures.zig");
const sdl = @import("../sdl.zig");
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
    set_frame: c.VkDescriptorSet = helper.VK_NULL_HANDLE,
    camera_ubo: helper.AllocatedBuffer = .{ .buffer = helper.VK_NULL_HANDLE, .allocation = helper.VK_NULL_HANDLE, .size = 0 },

  //  object_buffer: helper.AllocatedBuffer = .{ .buffer = helper.VK_NULL_HANDLE, .allocation = helper.VK_NULL_HANDLE, .size = 0 },
  //  object_descriptor_set: c.VkDescriptorSet = helper.VK_NULL_HANDLE,
};

const GPUCameraData = struct {
    view_proj: math.Mat4,
};

pub const UploadContext = struct {
    upload_fence: c.VkFence = helper.VK_NULL_HANDLE,
    command_pool: c.VkCommandPool = helper.VK_NULL_HANDLE,
    command_buffer: c.VkCommandBuffer = helper.VK_NULL_HANDLE,
};

pub const Renderer = struct {
    frames: [FRAME_OVERLAP]FrameData,
    render_pass: c.VkRenderPass,
    material_system: MaterialSystem,
    texture_manager: text.TextureManager,
    upload_context: UploadContext,
    vma: c.VmaAllocator,
 //   camera_pos: Vec3
    frame_number: i32 = 0,
    images_in_flight: []c.VkFence = &.{},
    vertex_buffer: helper.AllocatedBuffer = .{ .buffer = helper.VK_NULL_HANDLE, .allocation = helper.VK_NULL_HANDLE, .size = 0 },
    index_buffer: helper.AllocatedBuffer = .{ .buffer = helper.VK_NULL_HANDLE, .allocation = helper.VK_NULL_HANDLE, .size = 0 },
    dummy_ssbo: helper.AllocatedBuffer = .{ .buffer = helper.VK_NULL_HANDLE, .allocation = helper.VK_NULL_HANDLE, .size = 0 },
    descriptor_pool: c.VkDescriptorPool = helper.VK_NULL_HANDLE,
    set_layout_frame: c.VkDescriptorSetLayout = helper.VK_NULL_HANDLE,
    set_layout_material: c.VkDescriptorSetLayout = helper.VK_NULL_HANDLE,
    set_layout_compute: c.VkDescriptorSetLayout = helper.VK_NULL_HANDLE,
    sampler_linear_repeat: c.VkSampler = helper.VK_NULL_HANDLE,
    request_swapchain_recreate: bool = false,
    renderer_init: bool = false,
    index_count: u32 = 0,

    // pipelines / layouts
    // maybe upload context too

    pub fn init(allocator: std.mem.Allocator, core: *core_mod.Core, swapchain: *sc.Swapchain) !Renderer {

        // Render pass creation
        const render_pass = try sc.CreateRenderPass(swapchain, core.device.handle, core.alloc_cb);

        // Create Framebuffers
        sc.CreateFrameBuffers(core.device.handle, swapchain, render_pass, allocator, core.alloc_cb);

        // Pipeline Material Creation 
        const material_system = try MaterialSystem.init(allocator);

        // VMA allocation
        const vma = try helper.CreateVMAAllocator(core);
        
        var renderer = Renderer {
            .frames = .{ FrameData{} } ** FRAME_OVERLAP, 
            .render_pass = render_pass, 
            .material_system = material_system,
            .upload_context = .{},
            .vma = vma,
            .texture_manager =  try text.TextureManager.init(allocator),
        };

        errdefer renderer.deinit(allocator, core);

        // Create Descriptor Layouts
        try CreateDescriptorLayouts(&renderer, core);
        
        // Pipeline Creation
        try CreatePipelines(core, swapchain, &renderer, allocator);

        // Commands Creation
        try CreateCommands(&renderer, core.physical_device.graphics_queue_family, core);

        // Create Sync Structures
        try CreateSyncStructures(&renderer, core, swapchain, allocator);

        // Create Textures
        try text.CreateTextureImage("Slot", &renderer, core, allocator, helper.KtxColorSpace.srgb, "textures/Slot.ktx2");

        // Create Texture View
        try text.CreateTextureImageView(core, &renderer, "Slot");

        // Create Samplers
        try CreateSampler(&renderer , core);

        // Create Vertex Buffer
        const verts = [_]helper.Vertex{
            .{ .pos = .{ -0.5, -0.5 }, .color = .{ 1.0, 0.0, 0.0 }, .texcoord = .{0.0, 1.0 }},
            .{ .pos = .{  0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 }, .texcoord = .{1.0, 1.0}},
            .{ .pos = .{  0.5,  0.5 }, .color = .{ 0.0, 0.0, 1.0 }, .texcoord = .{1.0, 0.0 }},
            .{ .pos = .{ -0.5,  0.5 }, .color = .{ 1.0, 1.0, 0.0 }, .texcoord = .{0.0, 0.0}},
        };

        // Create Index Buffer
        const inds = [_]helper.Index_u16{ 0, 1, 2 , 2 , 3 , 0 };
        
        // Set Buffers
        renderer.vertex_buffer = try helper.CreateVertexBuffer(renderer.vma, verts[0..], &renderer.upload_context, core);
        renderer.index_buffer = try helper.CreateIndexBuffer(renderer.vma, inds[0..], &renderer.upload_context, core);
        renderer.index_count = @intCast(inds.len);
        
        // Create Descriptors
        try CreateDescriptors(&renderer, core);

        return renderer;
        
    }
    pub fn DrawFrame(
        self: *Renderer, 
        core: *core_mod.Core, 
        swapchain: *sc.Swapchain,
        win: *sdl.Window,
        allocator: std.mem.Allocator) !void {

        if (self.request_swapchain_recreate and self.renderer_init) {
          
        // Avoid zero-size swapchain
            if (win.screen_width == 0 or win.screen_height == 0) {
                return;
            }

            try self.OnSwapchainRecreated(
                    core,
                    swapchain,
                    win,
                    allocator,
                );
     
            log.info("recreated swapchain", .{});
            self.request_swapchain_recreate = false;
            return;

        }

        const timeout: u64 = 1_000_000_000;
        const frame = &self.frames[@intCast(@mod(self.frame_number, FRAME_OVERLAP))];
        if (frame.render_fence != helper.VK_NULL_HANDLE) {
            try helper.check_vk(
                c.vkWaitForFences(core.device.handle, 1, &frame.render_fence, c.VK_TRUE, timeout)
            );
        }

        try helper.check_vk(c.vkResetFences(core.device.handle, 1, &frame.render_fence));

        
        var swapchain_image_index: u32 = undefined;
        const acquire = c.vkAcquireNextImageKHR(
            core.device.handle,
            swapchain.handle,
            timeout,
            frame.present_semaphore,
            helper.VK_NULL_HANDLE,
            &swapchain_image_index,
        );

        switch (acquire) {
            c.VK_SUCCESS => {},
            c.VK_SUBOPTIMAL_KHR,
            c.VK_ERROR_OUT_OF_DATE_KHR => {
            self.request_swapchain_recreate = true;
            return;
        },
        else => return error.VulkanError,
        }

        // TODO: Revisit images in flight to remove high frame overlap. Fix by per frame render-finished semaphores
        const in_flight = self.images_in_flight[swapchain_image_index];
        if (in_flight != helper.VK_NULL_HANDLE and in_flight != frame.render_fence) {
            try helper.check_vk(c.vkWaitForFences(
                core.device.handle,
                1,
                &in_flight,
                c.VK_TRUE,
                timeout,
            ));
        }

        self.images_in_flight[swapchain_image_index] = frame.render_fence;


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

        const depth_clear = c.VkClearValue {
            .depthStencil = .{
                .depth = 1.0,
                .stencil = 0,
            },
        };
        
        const clear_values = [_]c.VkClearValue{
            color_clear,
            depth_clear,
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
        const tpl = try self.material_system.BindPipeline(cmd, "Triangle");
        
        //TODO: Bind Descriptor sets and also update shaders.
       const frame_set = frame.set_frame;

       const inst_id = self.material_system.instances_by_name.get("Triangle_Instance") orelse
            return error.MaterialInstanceNotFound;

       const mat_set = self.material_system.instances.items[@intCast(inst_id)].texture_set;

       const sets = [_]c.VkDescriptorSet {frame_set, mat_set };

       c.vkCmdBindDescriptorSets(
            cmd,
            c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            tpl.pipeline_layout,
            0,
            @as(u32, @intCast(sets.len)),
            &sets[0],
            0,
            null,
       );

        const offsets = [_]c.VkDeviceSize{0};
        c.vkCmdBindVertexBuffers(cmd, 0, 1, &self.vertex_buffer.buffer, &offsets[0]);
        c.vkCmdBindIndexBuffer(cmd, self.index_buffer.buffer, 0, c.VK_INDEX_TYPE_UINT16);
        c.vkCmdDrawIndexed(cmd, self.index_count, 1, 0, 0, 0);

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

        const pres = c.vkQueuePresentKHR(core.device.present_queue, &present_info);
        if (pres == c.VK_SUBOPTIMAL_KHR or pres == c.VK_ERROR_OUT_OF_DATE_KHR) {
            self.request_swapchain_recreate = true;
        }
        self.frame_number += 1;

    }



    pub fn OnSwapchainRecreated(
        self: *Renderer,
        core: *core_mod.Core,
        swapchain: *sc.Swapchain,
        win: *sdl.Window,
        allocator: std.mem.Allocator,
    ) !void {


        // 1. Create new swapchain FIRST
        var new_swap = try sc.Swapchain.init(
            allocator,
            core,
            win,
            .{ .vsync = false },
            swapchain.handle, // oldSwapchain
        );

        // 2. Wait until GPU is idle (temporary but safe)
        _ = c.vkDeviceWaitIdle(core.device.handle);

        // 3) Destroy OLD framebuffers (they reference old render pass)
        for (swapchain.framebuffers) |fb| {
            c.vkDestroyFramebuffer(core.device.handle, fb, core.alloc_cb);
        }
        allocator.free(swapchain.framebuffers);
        swapchain.framebuffers = &.{};

        self.material_system.deinitGpu(core.device.handle, core.alloc_cb);
        self.material_system.templates.clearRetainingCapacity();
        self.material_system.templates_by_name.clearRetainingCapacity();

        try CreatePipelines(core, &new_swap, self, allocator);

        try CreateDescriptors(self, core);

        // 3. Destroy OLD swapchain-dependent resources
        if (self.render_pass != helper.VK_NULL_HANDLE) {
            c.vkDestroyRenderPass(core.device.handle, self.render_pass, core.alloc_cb);
            self.render_pass = helper.VK_NULL_HANDLE;
        }
        // 4. Create render pass for NEW swapchain
        self.render_pass = try sc.CreateRenderPass(
            &new_swap,
            core.device.handle,
            core.alloc_cb,
        );

        // 5. Create framebuffers for NEW swapchain
        sc.CreateFrameBuffers(
            core.device.handle,
            &new_swap,
            self.render_pass,
            allocator,
            core.alloc_cb,
        );

        // 7. Destroy old swapchain
        swapchain.deinit(core, allocator ,core.alloc_cb);

        // 8. Swap new → old
        swapchain.* = new_swap;
    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator, core: *core_mod.Core) void {

        if (core.device.handle != null){
            _ = c.vkDeviceWaitIdle(core.device.handle);
        }

        if (self.descriptor_pool != null){
            c.vkDestroyDescriptorPool(core.device.handle, self.descriptor_pool, core.alloc_cb);
        }

        if (self.set_layout_frame != null) {
            c.vkDestroyDescriptorSetLayout(core.device.handle, self.set_layout_frame, core.alloc_cb);
            self.set_layout_frame = null;
        }

        if (self.set_layout_material != null) {
            c.vkDestroyDescriptorSetLayout(core.device.handle, self.set_layout_material, core.alloc_cb);
            self.set_layout_material = null;
        }

        if (self.set_layout_compute != null) {
            c.vkDestroyDescriptorSetLayout(core.device.handle, self.set_layout_compute, core.alloc_cb);
            self.set_layout_compute = null;
        }
        
        self.texture_manager.deinitGpu(core, self.vma);
        self.texture_manager.deinit(allocator);

        helper.DestroyBuffer(self.vma, &self.vertex_buffer);
        helper.DestroyBuffer(self.vma, &self.index_buffer);

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

        if (self.sampler_linear_repeat != null){
            c.vkDestroySampler(core.device.handle, self.sampler_linear_repeat, core.alloc_cb);
            self.sampler_linear_repeat = null;

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

            helper.DestroyBuffer(self.vma, &f.camera_ubo);

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

        if (self.vma != null){
            c.vmaDestroyAllocator(self.vma);
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

           const template_id = try self.AddTemplate(
                template_name, 
                pipeline, 
                pipeline_layout, 
                allocator, 
                bind_point
            );

           const instance_id = try self.AddInstance(
                instance_name, 
                texture_set,
                template_id,
                allocator
            ); 

            return instance_id;
    }

    pub fn AddInstance(
        self: *MaterialSystem, 
        instance_name: []const u8, 
        texture_set: c.VkDescriptorSet,
        template_id: MaterialTemplateId_u32,
        allocator: std.mem.Allocator)  !MaterialInstanceId_u32 {

        const instance_id: MaterialInstanceId_u32 = @intCast(self.instances.items.len);

        try self.instances.append(allocator , .{
            .template_id = template_id,
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
        ) !*MaterialTemplate {
            
        const tpl = self.GetTemplateByName(name) orelse
            @panic("Missing pipeline template");
        c.vkCmdBindPipeline(cmd, tpl.bind_point, tpl.pipeline);
        return tpl;
        
    }
    pub fn ClearRetainingCapacity(self: *MaterialSystem) void {
        self.templates.items.len = 0;
        self.templates_by_name.clearRetainingCapacity();

        // Only clear instances if you truly rebuild them
        // Otherwise leave them intact
        // self.instances.items.len = 0;
        // self.instances_by_name.clearRetainingCapacity();
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
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
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

    const set_layouts = [_]c.VkDescriptorSetLayout{
        renderer.set_layout_frame,     // set 0
        renderer.set_layout_material,  // set 1
    };

    const pipeline_layout_ci = std.mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = @as(u32, @intCast(set_layouts.len)),
        .pSetLayouts = &set_layouts[0],
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

    const binding = [_]c.VkVertexInputBindingDescription{
        .{
            .binding = 0,
            .stride = @sizeOf(helper.Vertex),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        }
    };

    const attrs = [_]c.VkVertexInputAttributeDescription{
        .{
            .location = 0,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(helper.Vertex, "pos"),
        },

        .{
            .location = 1,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(helper.Vertex, "color"),
        },
        .{
            .location = 2,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(helper.Vertex, "texcoord"),
        },
    };

    const vertex_input_state_ci = std.mem.zeroInit(c.VkPipelineVertexInputStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = @as(u32, @intCast(binding.len)),
        .pVertexBindingDescriptions = &binding[0],
        .vertexAttributeDescriptionCount = @as(u32, @intCast(attrs.len)),
        .pVertexAttributeDescriptions = &attrs[0],
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
        .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        .lineWidth = 1.0,
    });

    const multisample_state_ci = std.mem.zeroInit(c.VkPipelineMultisampleStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .minSampleShading = 1.0,
    });

    const depth_stencil_state_ci = std.mem.zeroInit(c.VkPipelineDepthStencilStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = c.VK_FALSE,
        .depthWriteEnable = c.VK_FALSE,
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

    std.debug.assert(renderer.material_system.templates_by_name.contains("Triangle"));

}

//TODO: Combined Image Sampler will be added outside Descriptors. Implement it after Sampler and Image Views.

pub fn CreateDescriptorLayouts(renderer: *Renderer, core: *core_mod.Core) !void {

    // Descriptor pool
    const pool_sizes = [_]c.VkDescriptorPoolSize{
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,         .descriptorCount = 64 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, .descriptorCount = 1024 },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,         .descriptorCount = 128  },
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,          .descriptorCount = 64 },
    };

    const pool_ci = std.mem.zeroInit(c.VkDescriptorPoolCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = 0,
        .maxSets = 1024,
        .poolSizeCount = @as(u32, @intCast(pool_sizes.len)),
        .pPoolSizes = &pool_sizes[0]
    });

    try helper.check_vk(c.vkCreateDescriptorPool(core.device.handle, &pool_ci, core.alloc_cb, &renderer.descriptor_pool));

    // -------------------------------------------------------------------------
    // 2) Set 0 (Frame/Scene) layout:
    //    binding 0: UBO (camera/time)
    //    binding 1: SSBO (big packed arena)  -- you can leave it unused for now
    // -------------------------------------------------------------------------
    const frame_buffer_binding = [_]c.VkDescriptorSetLayoutBinding{
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT | c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .pImmutableSamplers = null,
        }),
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 1,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT | c.VK_SHADER_STAGE_FRAGMENT_BIT | c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        }),
    };

    const frame_layout_ci = std.mem.zeroInit(c.VkDescriptorSetLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = @as(u32, @intCast(frame_buffer_binding.len)),
        .pBindings = &frame_buffer_binding[0],
    });

    try helper.check_vk(c.vkCreateDescriptorSetLayout(core.device.handle, &frame_layout_ci, core.alloc_cb, &renderer.set_layout_frame));

    // =========================================================================
    // 3) Set 1 (Material) layout:
    //    binding 0..N: combined image samplers (textures)
    // =========================================================================
    const MAX_TEXTURES_PER_MATERIAL: u32 = 4;


    const material_bindings = [_]c.VkDescriptorSetLayoutBinding{
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .pImmutableSamplers = null,
        }),
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 1,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .pImmutableSamplers = null,
        }),
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 2,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .pImmutableSamplers = null,
        }),
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 3,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .pImmutableSamplers = null,
        }),
    };

    comptime {
        if (material_bindings.len != MAX_TEXTURES_PER_MATERIAL)
            @compileError("material_bindings must match MAX_TEXTURES_PER_MATERIAL");
    }

    const material_layout_ci = std.mem.zeroInit(c.VkDescriptorSetLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = MAX_TEXTURES_PER_MATERIAL,
        .pBindings = &material_bindings[0],
    });

    try helper.check_vk(c.vkCreateDescriptorSetLayout(core.device.handle, &material_layout_ci, core.alloc_cb, &renderer.set_layout_material));

    // -------------------------------------------------------------------------
    // 4) Set 2 (Compute) layout:
    //    binding 0..M: storage images (RW)
    //
    // Again: fixed small count keeps it simple and memory-predictable.
    // -------------------------------------------------------------------------
    const MAX_STORAGE_IMAGES: u32 = 4;
    const compute_bindings = [_]c.VkDescriptorSetLayoutBinding{
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        }),
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 1,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        }),
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 2,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        }),
        std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
            .binding = 3,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        }),
    };

    comptime {
        if (MAX_STORAGE_IMAGES != compute_bindings.len)
            @compileError("MAX_STORAGE_IMAGES must match compute_bindings.len");
    }

    const compute_layout_ci = std.mem.zeroInit(c.VkDescriptorSetLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = MAX_STORAGE_IMAGES,
        .pBindings = &compute_bindings[0],
    });

    try helper.check_vk(c.vkCreateDescriptorSetLayout(core.device.handle, &compute_layout_ci, core.alloc_cb, &renderer.set_layout_compute));
}

// TODO: Add SSBO
pub fn CreateDescriptors(renderer: *Renderer, core: *core_mod.Core) !void{


    // -------------------------------------------------------------------------
    // 5) Allocate only what you need now:
    //    Allocate Set 0 per-frame descriptor sets. Material/Compute sets can be allocated later.
    // -------------------------------------------------------------------------

    const frame_count: u32 = @as(u32, @intCast(renderer.frames.len));

    var frame_layouts: [FRAME_OVERLAP]c.VkDescriptorSetLayout = undefined;
    var tmp_sets:    [FRAME_OVERLAP]c.VkDescriptorSet = undefined;

    for (&frame_layouts) |*l| {
        l.* = renderer.set_layout_frame;
    }

    const alloc_info = std.mem.zeroInit(c.VkDescriptorSetAllocateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = renderer.descriptor_pool,
        .descriptorSetCount = frame_count,
        .pSetLayouts = &frame_layouts[0],
    });
    
    try helper.check_vk(c.vkAllocateDescriptorSets(core.device.handle, &alloc_info, &tmp_sets[0]));

    for (tmp_sets, 0..) |set, i|{
        renderer.frames[i].set_frame = set;

    }

    // -------------------------------------------------------------------------
    // 6) Create per-frame camera UBO + (optional) one dummy SSBO for binding 1
    // -------------------------------------------------------------------------

    const CAMERA_UBO_SIZE: c.VkDeviceSize = @intCast(@sizeOf(GPUCameraData));

    for (0..frame_count) |i| {
        if (renderer.frames[i].camera_ubo.buffer == helper.VK_NULL_HANDLE) {
            renderer.frames[i].camera_ubo = try helper.CreateBuffer(
                renderer.vma,
                CAMERA_UBO_SIZE,
                c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                c.VMA_MEMORY_USAGE_CPU_TO_GPU,
                0,
            );
        }

        const camera_info = std.mem.zeroInit(c.VkDescriptorBufferInfo, .{
            .buffer = renderer.frames[i].camera_ubo.buffer,
            .offset = 0,
            .range = CAMERA_UBO_SIZE,
        });

        const writes = [_]c.VkWriteDescriptorSet{
            std.mem.zeroInit(c.VkWriteDescriptorSet, .{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = renderer.frames[i].set_frame,
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .pBufferInfo = &camera_info,
                .pImageInfo = null,
                .pTexelBufferView = null,
            }),
        };

        c.vkUpdateDescriptorSets(core.device.handle, @as(u32, @intCast(writes.len)), &writes[0], 0, null);
    }

    var material_set: c.VkDescriptorSet = null;

    const material_alloc = std.mem.zeroInit(c.VkDescriptorSetAllocateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = renderer.descriptor_pool,
        .descriptorSetCount = 1,
        .pSetLayouts = &renderer.set_layout_material,
    });

    try helper.check_vk(c.vkAllocateDescriptorSets(core.device.handle, &material_alloc, &material_set));

    const slot_id = renderer.texture_manager.textures_by_name.get("Slot") orelse
        return error.TextureNotFound;
    const slot_tex = &renderer.texture_manager.textures.items[@intCast(slot_id)];

    const image_info = std.mem.zeroInit(c.VkDescriptorImageInfo, .{
        .sampler = renderer.sampler_linear_repeat,
        .imageView = slot_tex.view,
        .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    });

    const img_write = std.mem.zeroInit(c.VkWriteDescriptorSet, .{
        .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = material_set,
        .dstBinding = 0, // binding 0 in set 1
        .dstArrayElement = 0,
        .descriptorCount = 1,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .pImageInfo = &image_info,
        .pBufferInfo = null,
        .pTexelBufferView = null,
    });

    c.vkUpdateDescriptorSets(core.device.handle, 1, &img_write, 0, null);

    const inst_id = renderer.material_system.instances_by_name.get("Triangle_Instance") orelse
        return error.MaterialInstanceNotFound;
    renderer.material_system.instances.items[@intCast(inst_id)].texture_set = material_set;

    // DUMMY SSBO buffer

    // if (renderer.dummy_ssbo.buffer == helper.VK_NULL_HANDLE) {
    //     renderer.dummy_ssbo = try helper.CreateBuffer(
    //         renderer.vma,
    //         16,
    //         c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
    //         c.VMA_MEMORY_USAGE_CPU_TO_GPU,
    //         0,
    //     );
    // }


}

pub fn CreateSampler(renderer: *Renderer , core: *core_mod.Core) !void{

    const sampler_ci = c.VkSamplerCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .magFilter = c.VK_FILTER_LINEAR,
        .minFilter = c.VK_FILTER_LINEAR,
        .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
        .minLod = 0.0,
        .maxLod = c.VK_LOD_CLAMP_NONE,
        .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .anisotropyEnable = c.VK_TRUE,
        .maxAnisotropy = 16.0,
        .compareEnable = c.VK_FALSE,
        .compareOp = c.VK_COMPARE_OP_ALWAYS,
        .borderColor = c.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = c.VK_FALSE,
    };

    try helper.check_vk(c.vkCreateSampler(core.device.handle, &sampler_ci, core.alloc_cb, &renderer.sampler_linear_repeat));
}




