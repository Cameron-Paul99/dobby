const std = @import("std");
const c = @import("clibs.zig").c;
const utils = @import("utils");
const gpu_context = @import("core.zig");
const sc = @import("swapchain.zig");
const render = @import("render.zig");
const text = @import("textures.zig");
const log = std.log;
const sdl = utils.sdl;
const math = utils.math;


pub const VK_NULL_HANDLE = null;
pub const INVALID = std.math.maxInt(u32);

pub const SwapchainSupportInfo = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
    formats: []c.VkSurfaceFormatKHR = &.{},
    present_modes: []c.VkPresentModeKHR = &.{},


    pub fn init(allocator: std.mem.Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !SwapchainSupportInfo{

        var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        try check_vk(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &capabilities));

        var format_count: u32 = undefined;
        try check_vk(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, null));
        const formats = try allocator.alloc(c.VkSurfaceFormatKHR, format_count);
        errdefer allocator.free(formats);
        try check_vk(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, formats.ptr));

        var present_mode_count: u32 = undefined;
        try check_vk(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null));
        const present_modes = try allocator.alloc(c.VkPresentModeKHR, present_mode_count);
        errdefer allocator.free(present_modes);
        try check_vk(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, present_modes.ptr));
        
        return .{  
            .capabilities = capabilities,
            .formats = formats,
            .present_modes = present_modes,

        };
    }

   pub fn deinit(self: *const SwapchainSupportInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.formats);
        allocator.free(self.present_modes);
    }
    
};

pub fn loadProcAddr(
    instance: c.VkInstance,
    comptime Fn: type,
    name: [*:0]const u8,
) Fn {
    const p = c.vkGetInstanceProcAddr(instance, name);
    if (p == null) return @as(Fn, null);
    return @as(Fn, @ptrCast(p.?));
}

pub fn createDebugMessenger(renderer: *gpu_context.Core) !void {
    const create_fn = loadProcAddr(
        renderer.instance.handle,
        c.PFN_vkCreateDebugUtilsMessengerEXT,
        "vkCreateDebugUtilsMessengerEXT",
    ) orelse {
        log.err("Failed to load vkCreateDebugUtilsMessengerEXT", .{});
        return error.MissingExtension;
    };

    const create_info = std.mem.zeroInit(c.VkDebugUtilsMessengerCreateInfoEXT, .{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .pNext = null,
        .flags = 0,
        .messageSeverity =
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType =
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = @as(c.PFN_vkDebugUtilsMessengerCallbackEXT, @ptrCast(&defaultDebugCallback)),
        .pUserData = null,
    });

    var debug_messenger: c.VkDebugUtilsMessengerEXT = null;

    try check_vk(create_fn(
        renderer.instance.handle,
        &create_info,
        renderer.alloc_cb,
        &debug_messenger,
    ));

    renderer.instance.debug_messenger = debug_messenger;
    log.info("Created Vulkan debug messenger.", .{});
}


pub fn destroyDebugMessenger(renderer: *gpu_context.Core) void {
    const dm = renderer.instance.debug_messenger orelse return;

    const destroy_fn = loadProcAddr(
        renderer.instance.handle,
        c.PFN_vkDestroyDebugUtilsMessengerEXT,
        "vkDestroyDebugUtilsMessengerEXT",
    ) orelse return;

    destroy_fn(renderer.instance.handle, dm, renderer.alloc_cb);
    renderer.instance.debug_messenger = null;
}

fn vkResultStr(r: c.VkResult) []const u8 {
    return switch (r) {
        c.VK_SUCCESS => "VK_SUCCESS",
        c.VK_NOT_READY => "VK_NOT_READY",
        c.VK_TIMEOUT => "VK_TIMEOUT",
        c.VK_EVENT_SET => "VK_EVENT_SET",
        c.VK_EVENT_RESET => "VK_EVENT_RESET",
        c.VK_INCOMPLETE => "VK_INCOMPLETE",
        c.VK_ERROR_OUT_OF_HOST_MEMORY => "VK_ERROR_OUT_OF_HOST_MEMORY",
        c.VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
        c.VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
        c.VK_ERROR_DEVICE_LOST => "VK_ERROR_DEVICE_LOST",
        c.VK_ERROR_MEMORY_MAP_FAILED => "VK_ERROR_MEMORY_MAP_FAILED",
        c.VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
        c.VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
        c.VK_ERROR_FEATURE_NOT_PRESENT => "VK_ERROR_FEATURE_NOT_PRESENT",
        c.VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
        c.VK_ERROR_TOO_MANY_OBJECTS => "VK_ERROR_TOO_MANY_OBJECTS",
        c.VK_ERROR_FORMAT_NOT_SUPPORTED => "VK_ERROR_FORMAT_NOT_SUPPORTED",
        c.VK_ERROR_SURFACE_LOST_KHR => "VK_ERROR_SURFACE_LOST_KHR",
        c.VK_ERROR_OUT_OF_DATE_KHR => "VK_ERROR_OUT_OF_DATE_KHR",
        c.VK_SUBOPTIMAL_KHR => "VK_SUBOPTIMAL_KHR",
        else => "VK_<unknown>",
    };
}

pub fn check_vk(result: c.VkResult) !void {
    if (result != c.VK_SUCCESS) {
        std.log.err("Vulkan call failed: {s} ({d})", .{ vkResultStr(result), result });
        return error.VulkanError;
    }
}

fn defaultDebugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    msg_type: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.c) c.VkBool32 {

    _ = user_data;

    const severity_str = switch (severity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warning",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        else => "unknown",
    };

    const type_str = switch (msg_type) {
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT => "device address",
        else => "unknown",
    };

    const message: [*c]const u8 = if (callback_data) |cb_data| cb_data.pMessage else "NO MESSAGE!";
    log.err("[{s}][{s}] Message:\n  {s}", .{ severity_str, type_str, message });

    if (severity >= c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
       // @panic("Unrecoverable Vulkan error.");
       return c.VK_FALSE;
    }

    return c.VK_FALSE;
}

extern fn vkGetInstanceProcAddr(
    instance: c.VkInstance,
    pName: [*c]const u8,
) ?*const anyopaque;


pub fn MakePhysicalDevice(allocator: std.mem.Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !gpu_context.PhysicalDevice{

    // ---- Properties
    var props: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(device, &props);

    // ---- Queue families (enumerate -> alloc -> fill)
    var qcount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &qcount, null);

    const qprops = try allocator.alloc(c.VkQueueFamilyProperties, qcount);
    defer allocator.free(qprops);

    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &qcount, qprops.ptr);

        // ---- Build result with sane defaults
    var pd = gpu_context.PhysicalDevice{
        .handle = device,
        .properties = props,
        .graphics_queue_family = INVALID,
        .present_queue_family  = INVALID,
        .compute_queue_family  = INVALID,
        .transfer_queue_family = INVALID,
    };

        // ---- Pick first matching families (early-exit when all found)
    for (qprops, 0..) |q, i| {

        const idx: u32 = @intCast(i);

        if (pd.graphics_queue_family == INVALID and q.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) 

            pd.graphics_queue_family = idx;

        if (pd.compute_queue_family == INVALID and q.queueFlags & c.VK_QUEUE_COMPUTE_BIT != 0)

            pd.compute_queue_family = idx;

        if (pd.transfer_queue_family == INVALID and q.queueFlags & c.VK_QUEUE_TRANSFER_BIT != 0)

            pd.transfer_queue_family = idx;

        if (pd.present_queue_family == INVALID) {

            var support: c.VkBool32 = 0;

            try check_vk(c.vkGetPhysicalDeviceSurfaceSupportKHR(device, idx, surface, &support));

            if (support == c.VK_TRUE)
                pd.present_queue_family = idx;
        }

        if (pd.graphics_queue_family != INVALID and
            pd.present_queue_family != INVALID and
            pd.compute_queue_family != INVALID and
            pd.transfer_queue_family != INVALID) {
            break;
        }  

    }

    return pd;

}

pub fn IsPhysicalDeviceSuitable(allocator: std.mem.Allocator, device: gpu_context.PhysicalDevice, surface: c.VkSurfaceKHR, required_extensions: []const [*c]const u8 ) !bool {

        var arena_state = std.heap.ArenaAllocator.init(allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator(); 

        if (device.properties.apiVersion < device.min_api_version) {

            return false;

        }
        if (device.graphics_queue_family == INVALID or
            device.present_queue_family == INVALID or
            device.compute_queue_family == INVALID or
            device.transfer_queue_family == INVALID) {

            return false;

        }


        const swapchain_support = try SwapchainSupportInfo.init(arena, device.handle, surface);

           if (swapchain_support.formats.len == 0 or swapchain_support.present_modes.len == 0) {
            return false;
        }

        if (required_extensions.len > 0) {
            var device_extension_count: u32 = 0;
            try check_vk(c.vkEnumerateDeviceExtensionProperties(device.handle, null, &device_extension_count, null));
            const device_extensions = try allocator.alloc(c.VkExtensionProperties, device_extension_count);
            defer allocator.free(device_extensions);
            try check_vk(c.vkEnumerateDeviceExtensionProperties(device.handle, null, &device_extension_count, device_extensions.ptr));

            for (required_extensions) |req_ext| {
                var found = false;
                for (device_extensions) |device_ext| {
                    const device_ext_name: [*c]const u8 = @ptrCast(device_ext.extensionName[0..]);
                    if (std.mem.eql(u8, std.mem.span(req_ext), std.mem.span(device_ext_name))) {
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            }
        }

        return true;
}

pub fn PickSwapchainFormat(formats: []const c.VkSurfaceFormatKHR) c.VkFormat{

    for (formats) |format| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and
            format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return format.format;
        }
    }

    return formats[0].format;

}

pub fn PickSwapchainPresentMode(swapchain: sc.SwapchainConfig, modes: []const c.VkPresentModeKHR) c.VkPresentModeKHR {

    if (swapchain.vsync == false) {
            // Prefer immediate mode if present.
        for (modes) |mode| {
            if (mode == c.VK_PRESENT_MODE_IMMEDIATE_KHR) {
                return mode;
            }
        }
        log.info("Immediate present mode is not possible. Falling back to vsync", .{});
    }

        // Prefer triple buffering if possible.
    for (modes) |mode| {
        if (mode == c.VK_PRESENT_MODE_MAILBOX_KHR and swapchain.triple_buffer) {
            return mode;
        }
    }

    // If nothing else is present, FIFO is guaranteed to be available by the specs.
    return c.VK_PRESENT_MODE_FIFO_KHR;

}


pub fn MakeSwapchainExtent(capabilities: c.VkSurfaceCapabilitiesKHR, window_width: u32, window_height: u32) c.VkExtent2D {

    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    }

    var extent = c.VkExtent2D{
        .width = window_width,
        .height = window_height,
    };

    extent.width = @max(
        capabilities.minImageExtent.width,
        @min(capabilities.maxImageExtent.width, extent.width));

    extent.height = @max(
        capabilities.minImageExtent.height,
        @min(capabilities.maxImageExtent.height, extent.height));

    return extent;    

}

pub fn CreateImageView(
    device: c.VkDevice, 
    image: c.VkImage, 
    format: c.VkFormat, 
    aspect_flags: c.VkImageAspectFlags, 
    alloc_cb: ?*c.VkAllocationCallbacks) !c.VkImageView{

    const view_info = std.mem.zeroInit(c.VkImageViewCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .format = format,
        .components = .{
            .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = .{
            .aspectMask = aspect_flags,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },

    });

    var image_view: c.VkImageView = undefined;
    try check_vk(c.vkCreateImageView(device, &view_info, alloc_cb, &image_view));

    return image_view;
    
}

pub const PipelineBuilder = struct {

    shader_stages: []c.VkPipelineShaderStageCreateInfo,
    vertex_input_state: c.VkPipelineVertexInputStateCreateInfo,
    input_assembly_state: c.VkPipelineInputAssemblyStateCreateInfo,
    viewport: c.VkViewport,
    scissor: c.VkRect2D,
    rasterization_state: c.VkPipelineRasterizationStateCreateInfo,
    color_blend_attachment_state: c.VkPipelineColorBlendAttachmentState,
    multisample_state: c.VkPipelineMultisampleStateCreateInfo,
    pipeline_layout: c.VkPipelineLayout,
    depth_stencil_state: c.VkPipelineDepthStencilStateCreateInfo,

    pub fn create(self: PipelineBuilder, device: c.VkDevice, render_pass: c.VkRenderPass, alloc_cb: ?*c.VkAllocationCallbacks) !c.VkPipeline{

        const viewport_state = std.mem.zeroInit(c.VkPipelineViewportStateCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = &self.viewport,
            .scissorCount = 1,
            .pScissors = &self.scissor,
        });

        const color_blend_state = std.mem.zeroInit(c.VkPipelineColorBlendStateCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = c.VK_FALSE,
            .logicOp = c.VK_LOGIC_OP_COPY,
            .attachmentCount = 1,
            .pAttachments = &self.color_blend_attachment_state,
        });
        
        const pipeline_ci = std.mem.zeroInit(c.VkGraphicsPipelineCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
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
        
        var pipeline: c.VkPipeline = undefined;
        
        try check_vk(c.vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipeline_ci, alloc_cb, &pipeline));

        return pipeline;

    }
    
};

pub fn CreateShaderModule(device: c.VkDevice, code: []const u8, alloc_cb: ?*c.VkAllocationCallbacks) ?c.VkShaderModule {
    // NOTE: This being a better language than C/C++, means we don´t need to load
    // the SPIR-V code from a file, we can just embed it as an array of bytes.
    // To reflect the different behaviour from the original code, we also changed
    // the function name.
    std.debug.assert(code.len % 4 == 0);

    const data: *const u32 = @alignCast(@ptrCast(code.ptr));

    const shader_module_ci = std.mem.zeroInit(c.VkShaderModuleCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = data,
    });

    var shader_module: c.VkShaderModule = undefined;
    check_vk(c.vkCreateShaderModule(device, &shader_module_ci, alloc_cb, &shader_module)) catch |err| {
        log.err("Failed to create shader module with error: {s}", .{ @errorName(err) });
        return null;
    };

    return shader_module;
}


pub const ShaderModules = struct {
    
    vert_mod: c.VkShaderModule,
    frag_mod: c.VkShaderModule,

};

pub fn MakeShaderModules(device: c.VkDevice, alloc_cb: ?*c.VkAllocationCallbacks ,comptime vert_name: []const u8, comptime frag_name: []const u8) !ShaderModules{
        
        const vert_code align(4) = @embedFile(vert_name).*;
        const frag_code align(4) = @embedFile(frag_name).*;

        const vert_mod = CreateShaderModule(device, &vert_code, alloc_cb) orelse VK_NULL_HANDLE;
        const frag_mod = CreateShaderModule(device, &frag_code, alloc_cb) orelse VK_NULL_HANDLE;
        
        if (vert_mod != VK_NULL_HANDLE) log.info("Vert module loaded successfully", .{});
        if (frag_mod != VK_NULL_HANDLE) log.info("Frag module loaded successfully", .{});

        return .{.vert_mod = vert_mod , .frag_mod = frag_mod};

}

pub const Vertex = extern struct {
    pos: [2]f32,
    color: [3]f32,
    texcoord: [2]f32,
};

pub const Index_u16 = u16;

pub const AllocatedBuffer = struct {
    buffer: c.VkBuffer,
    allocation: c.VmaAllocation,
    size: c.VkDeviceSize = 0,
};

pub fn CreateVertexBuffer(
    vma: c.VmaAllocator,
    vertices: []const Vertex,
    upload_ctx: *render.UploadContext,
    core: *gpu_context.Core) !AllocatedBuffer {
    
    const size: c.VkDeviceSize = @intCast(vertices.len * @sizeOf(Vertex));

    var staging = try CreateBuffer(
        vma, 
        size, 
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, 
        c.VMA_MEMORY_USAGE_CPU_ONLY, 
        0,
    );

    defer DestroyBuffer(vma, &staging);

    var mapped: ?*anyopaque = null;
    try check_vk(c.vmaMapMemory(vma, staging.allocation, &mapped));
    defer c.vmaUnmapMemory(vma, staging.allocation);

    const dst: [*]u8 = @ptrCast(mapped.?);
    const src: []const u8 = std.mem.sliceAsBytes(vertices);

    @memcpy(dst[0..src.len], src);

    const vb = try CreateBuffer(
        vma,
        size,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        c.VMA_MEMORY_USAGE_GPU_ONLY,
        0,
    );

    //TODO: add an immediate submit. Though it is optional
    //
    try CopyBuffer(core, upload_ctx, staging.buffer, vb.buffer, size);

    return vb;
    

}

pub fn CreateIndexBuffer(
    vma: c.VmaAllocator, 
    indices: []const Index_u16,
    upload_ctx: *render.UploadContext,
    core: *gpu_context.Core) !AllocatedBuffer{

    const size: c.VkDeviceSize = @intCast(indices.len * @sizeOf(Index_u16));

    var staging = try CreateBuffer(
        vma,
        size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VMA_MEMORY_USAGE_CPU_ONLY,
        0,
    );

    defer DestroyBuffer(vma, &staging);

    var mapped: ?*anyopaque = null;
    try check_vk(c.vmaMapMemory(vma, staging.allocation, &mapped));
    defer c.vmaUnmapMemory(vma, staging.allocation);

    const dst: [*]u8 = @ptrCast(mapped.?);
    const src: []const u8 = std.mem.sliceAsBytes(indices);

    @memcpy(dst[0..src.len], src);

    const ib = try CreateBuffer(
        vma,
        size,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        c.VMA_MEMORY_USAGE_GPU_ONLY,
        0,
    );

    try CopyBuffer( core, upload_ctx, staging.buffer, ib.buffer, size);

    return ib;

}

pub fn CreateBuffer(
    vma: c.VmaAllocator, 
    size: c.VkDeviceSize,
    usage: c.VkBufferUsageFlags,
    mem_usage: c.VmaMemoryUsage,
    alloc_flags: c.VmaAllocationCreateFlags) !AllocatedBuffer {

    var out: AllocatedBuffer = .{ 
        .buffer = VK_NULL_HANDLE, 
        .allocation = VK_NULL_HANDLE,
        .size = size
    };

    const buffer_ci = std.mem.zeroInit(c.VkBufferCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    });

    const ainfo = std.mem.zeroInit(c.VmaAllocationCreateInfo, .{
        .usage = mem_usage,
        .flags = alloc_flags,
    });

    try check_vk(c.vmaCreateBuffer(vma, &buffer_ci, &ainfo, &out.buffer, &out.allocation, null));

    return out;

}

pub fn CopyBuffer(
    core: *gpu_context.Core,
    upload_ctx: *render.UploadContext, 
    src: c.VkBuffer,
    dst: c.VkBuffer,
    size: c.VkDeviceSize) !void {

    try check_vk(c.vkResetFences(core.device.handle, 1, &upload_ctx.upload_fence));
    try check_vk(c.vkResetCommandBuffer(upload_ctx.command_buffer, 0));

    const region = c.VkBufferCopy {
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };

    const begin = std.mem.zeroInit(c.VkCommandBufferBeginInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    });

    try check_vk(c.vkBeginCommandBuffer(upload_ctx.command_buffer, &begin));

    c.vkCmdCopyBuffer(upload_ctx.command_buffer, src, dst, 1, &region);

    try check_vk(c.vkEndCommandBuffer(upload_ctx.command_buffer));

    const submit = std.mem.zeroInit(c.VkSubmitInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &upload_ctx.command_buffer,
    });

    try check_vk(c.vkQueueSubmit(core.device.graphics_queue, 1, &submit, upload_ctx.upload_fence));
    _ = c.vkWaitForFences(core.device.handle, 1, &upload_ctx.upload_fence, c.VK_TRUE, std.math.maxInt(u64));

}

pub fn DestroyImage(core: *gpu_context.Core, vma: c.VmaAllocator, img: *AllocatedImage) void {
    if (img.view != null) {
        c.vkDestroyImageView(core.device.handle, img.view, core.alloc_cb);
        img.view = null;
    }
    if (img.image != null) {
        c.vmaDestroyImage(vma, img.image, img.allocation);
        img.* = .{ .image = null, .allocation = null, .view = null, .width = 0, .height = 0, .format = c.VK_FORMAT_UNDEFINED };
    }
}

pub fn DestroyBuffer(vma: c.VmaAllocator, b: *AllocatedBuffer) void{

    if (b.buffer != null){
        
        c.vmaDestroyBuffer(vma, b.buffer, b.allocation);
        b.* = .{
            .buffer = null,
            .allocation = null,
            .size = 0,
        };

    }

}

pub const AllocatedImage = struct {
    image: c.VkImage = VK_NULL_HANDLE,
    allocation: c.VmaAllocation = null,
    view: c.VkImageView = VK_NULL_HANDLE, // usually store this too
    sampler: c.VkSampler = VK_NULL_HANDLE,
    width: u32 = 0,
    height: u32 = 0,
    format: c.VkFormat = c.VK_FORMAT_UNDEFINED,
};

pub const ImageMemoryClass = enum {
    gpu_only,        // textures, render targets
    cpu_upload,      // rare: linear images
};

pub fn CreateImage(
    vma: c.VmaAllocator,
    extent: c.VkExtent3D,
    format: c.VkFormat,
    tiling: c.VkImageTiling,
    usage: c.VkImageUsageFlags,
    mem_class: ImageMemoryClass,
) !AllocatedImage {

    const image_ci = std.mem.zeroInit(c.VkImageCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .imageType = c.VK_IMAGE_TYPE_2D,
        .format = format,
        .extent = extent,
        .mipLevels = 1,
        .arrayLayers = 1,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .tiling = tiling,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
    });

    var alloc_ci = std.mem.zeroInit(c.VmaAllocationCreateInfo, .{
        .usage = c.VMA_MEMORY_USAGE_AUTO,
        .flags = 0,
        .requiredFlags = 0,
        .preferredFlags = 0,
        .memoryTypeBits = 0,
        .pool = null,
        .pUserData = null,
        .priority = 0,
    });

    switch (mem_class) {
        .gpu_only => {
            alloc_ci.usage = c.VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE;
            alloc_ci.flags |= c.VMA_ALLOCATION_CREATE_WITHIN_BUDGET_BIT;
        },
        .cpu_upload => {
            alloc_ci.usage = c.VMA_MEMORY_USAGE_AUTO;
            alloc_ci.flags |=
                c.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT |
                c.VMA_ALLOCATION_CREATE_MAPPED_BIT;
        },
    }

    var image: c.VkImage = VK_NULL_HANDLE;
    var allocation: c.VmaAllocation = null;

    try check_vk(c.vmaCreateImage(
        vma,
        &image_ci,
        &alloc_ci,
        &image,
        &allocation,
        null, // or &alloc_info if you want VmaAllocationInfo back
    ));

    return .{
        .image = image,
        .allocation = allocation,
        .width = extent.width,
        .height = extent.height,
        .format = format,
    };

}

pub const KtxColorSpace = enum { srgb, linear };

pub fn ChooseTranscodeFormat(cs: KtxColorSpace) struct {
    ktx_fmt: c.ktx_transcode_fmt_e,
    vk_fmt: c.VkFormat,
} {
    return switch (cs) {
        .srgb => .{ .ktx_fmt = c.KTX_TTF_BC7_RGBA, .vk_fmt = c.VK_FORMAT_BC7_SRGB_BLOCK },
        .linear => .{ .ktx_fmt = c.KTX_TTF_BC7_RGBA, .vk_fmt = c.VK_FORMAT_BC7_UNORM_BLOCK },
    };
}

pub fn TransitionImageLayout(
    renderer: *render.Renderer,
    core: *gpu_context.Core,
    allocated_image: *AllocatedImage,
    old_layout: c.VkImageLayout,
    new_layout: c.VkImageLayout,) !void{

    var src_access: c.VkAccessFlags = 0;
    var dst_access: c.VkAccessFlags = 0;
    var src_stage: c.VkPipelineStageFlags = 0;
    var dst_stage: c.VkPipelineStageFlags = 0;

    if (old_layout == c.VK_IMAGE_LAYOUT_UNDEFINED and new_layout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
    {
        dst_access = c.VK_ACCESS_TRANSFER_WRITE_BIT;
        src_stage = c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        dst_stage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;

    }else if (old_layout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and new_layout == c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL){

        src_access = c.VK_ACCESS_TRANSFER_WRITE_BIT;
        dst_access = c.VK_ACCESS_SHADER_READ_BIT;
        src_stage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
        dst_stage = c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;

    }else {
        
        return error.UnsupportedImageLayoutTransition;
        
    }

    const cmd = try BeginSingleTimeCommands(renderer, core);
    defer EndSingleTimeCommands(core, renderer, cmd) catch |err| {
        @panic(@errorName(err));
    }; 

    const subresource = c.VkImageSubresourceRange{
        .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
        .baseMipLevel = 0,
        .levelCount = 1,
        .baseArrayLayer = 0,
        .layerCount = 1,
    };

    const barrier = c.VkImageMemoryBarrier{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .pNext = null,
        .srcAccessMask = src_access,
        .dstAccessMask = dst_access,
        .oldLayout = old_layout,
        .newLayout = new_layout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = allocated_image.image,
        .subresourceRange = subresource, 
    };

    c.vkCmdPipelineBarrier(
        cmd,
        src_stage,
        dst_stage,
        0, // VkDependencyFlags
        0, null, // memory barriers
        0, null, // buffer memory barriers
        1, &barrier, // image memory barriers
    ); 

}

pub fn CopyBufferToImage(
    core: *gpu_context.Core, 
    renderer: *render.Renderer, 
    allocated_image: *AllocatedImage,
    allocated_buffer: *AllocatedBuffer) !void{

    const cmd = try BeginSingleTimeCommands(renderer , core);
    defer EndSingleTimeCommands(core, renderer, cmd) catch |err| {
        @panic(@errorName(err));
    }; 

    const subresource = c.VkImageSubresourceLayers{
        .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
        .mipLevel = 0,
        .baseArrayLayer = 0,
        .layerCount = 1,
    };

    const region = c.VkBufferImageCopy{
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,
        .imageSubresource = subresource,
        .imageOffset = .{.x = 0, .y = 0, .z = 0},
        .imageExtent = .{ .width = allocated_image.width, .height = allocated_image.height, .depth = 1 }
    };

    c.vkCmdCopyBufferToImage(
        cmd,
        allocated_buffer.buffer,
        allocated_image.image,
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1,
        &region,
    );

}

pub fn BeginSingleTimeCommands(
    renderer: *render.Renderer, 
    core: *gpu_context.Core) !c.VkCommandBuffer{

    const info = std.mem.zeroInit(c.VkCommandBufferAllocateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = renderer.upload_context.command_pool,
        .commandBufferCount = 1,
    });

    var cmd: c.VkCommandBuffer = undefined;

    try check_vk(c.vkAllocateCommandBuffers(core.device.handle, &info, &cmd));

      var begin_info = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
    };

     try check_vk(c.vkBeginCommandBuffer(cmd, &begin_info));

     return cmd;

}

pub fn EndSingleTimeCommands(
    core: *gpu_context.Core, 
    renderer: *render.Renderer, 
    cmd: c.VkCommandBuffer) !void{

    try check_vk(c.vkEndCommandBuffer(cmd));

    const submit_info = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .commandBufferCount = 1,
        .pCommandBuffers = &cmd,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,
    };

    try check_vk(c.vkResetFences(core.device.handle, 1, &renderer.upload_context.upload_fence));
    try check_vk(c.vkQueueSubmit(core.device.graphics_queue, 1, &submit_info, renderer.upload_context.upload_fence));
    try check_vk(c.vkQueueWaitIdle(core.device.graphics_queue));

    c.vkFreeCommandBuffers(core.device.handle, renderer.upload_context.command_pool, 1, &cmd);

}

    
pub fn CreateVMAAllocator(core: *gpu_context.Core) !c.VmaAllocator {

    var vma_ci = std.mem.zeroInit(c.VmaAllocatorCreateInfo, .{
        .physicalDevice = core.physical_device.handle,
        .device = core.device.handle,
        .instance = core.instance.handle,
    }); 

    var allocator: c.VmaAllocator = undefined;
    try check_vk(c.vmaCreateAllocator(&vma_ci, &allocator));

    return allocator;


}

pub const SpriteDraw = extern struct {
    entity: u32,
    sprite_pos: [2]f32,
    sprite_scale: [2]f32,
    sprite_rotation: [2]f32,
    uv_min: [2]f32,
    uv_max: [2]f32,
    tint: [4]f32,
    atlas_id: u32,
};

pub fn UploadInstanceData(
    vma: c.VmaAllocator,
    upload_ctx: *render.UploadContext,
    core: *gpu_context.Core,
    dst: *AllocatedBuffer,
    instances: []const SpriteDraw,
) !void {
    const size = render.MAX_SPRITES * @sizeOf(SpriteDraw);

    var staging = try CreateBuffer(
        vma,
        size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VMA_MEMORY_USAGE_CPU_ONLY,
        0,
    );
    defer DestroyBuffer(vma, &staging);

    var mapped: ?*anyopaque = null;
    try check_vk(c.vmaMapMemory(vma, staging.allocation, &mapped));
    defer c.vmaUnmapMemory(vma, staging.allocation);

    const dst_bytes: [*]u8 = @ptrCast(mapped.?);
    const src_bytes = std.mem.sliceAsBytes(instances);
    @memcpy(dst_bytes[0..src_bytes.len], src_bytes);

    try CopyBuffer(core, upload_ctx, staging.buffer, dst.buffer, size);
}

pub fn UploadToBuffer(
    vma: c.VmaAllocator,
    buffer: AllocatedBuffer,
    data: anytype,
) !void {
    var mapped: ?*anyopaque = null;

    try check_vk(c.vmaMapMemory(vma, buffer.allocation, &mapped));
    defer c.vmaUnmapMemory(vma, buffer.allocation);

    const src = std.mem.asBytes(&data);
    const dst = @as([*]u8, @ptrCast(mapped.?));

    @memcpy(dst[0..src.len], src);
}

