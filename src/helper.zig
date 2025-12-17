const std = @import("std");
const c = @import("clibs.zig").c;
const sdl = @import("sdl.zig");
const gpu_context = @import("vulkan.zig");
const log = std.log;

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
        try check_vk(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, formats.ptr));

        var present_mode_count: u32 = undefined;
        try check_vk(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null));
        const present_modes = try allocator.alloc(c.VkPresentModeKHR, present_mode_count);
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

pub fn createDebugMessenger(renderer: *gpu_context.Renderer) !void {
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


pub fn destroyDebugMessenger(renderer: *gpu_context.Renderer) void {
    const dm = renderer.instance.debug_messenger orelse return;

    const destroy_fn = loadProcAddr(
        renderer.instance.handle,
        c.PFN_vkDestroyDebugUtilsMessengerEXT,
        "vkDestroyDebugUtilsMessengerEXT",
    ) orelse return;

    destroy_fn(renderer.instance.handle, dm, renderer.alloc_cb);
    renderer.instance.debug_messenger = null;
}

pub fn check_vk(result: c.VkResult) !void {
    if (result != c.VK_SUCCESS) return error.VulkanError;
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

        if (device.properties.apiVersion < device.min_api_version) {

            return false;

        }
        if (device.graphics_queue_family == INVALID or
            device.present_queue_family == INVALID or
            device.compute_queue_family == INVALID or
            device.transfer_queue_family == INVALID) {

            return false;

        }


        const swapchain_support = try SwapchainSupportInfo.init(allocator, device.handle, surface);
        defer swapchain_support.deinit(allocator);
        if (swapchain_support.formats.len == 0 or swapchain_support.present_modes.len == 0) {
            return false;
        }

        if (required_extensions.len > 0) {
            var device_extension_count: u32 = undefined;
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

pub fn PickSwapchainPresentMode(swapchain: gpu_context.SwapchainConfig, modes: []const c.VkPresentModeKHR) c.VkPresentModeKHR {

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


pub fn MakeSwapchainExtent(swapchain: gpu_context.Swapchain ,capabilities: c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {

    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    }

    var extent = c.VkExtent2D{
        .width = swapchain.window_width,
        .height = swapchain.window_height,
    };

    extent.width = @max(
        capabilities.minImageExtent.width,
        @min(capabilities.maxImageExtent.width, extent.width));

    extent.height = @max(
        capabilities.minImageExtent.height,
        @min(capabilities.maxImageExtent.height, extent.height));

    return extent;    

}

pub fn CreateImageView(device: c.VkDevice, image: c.VkImage, format: c.VkFormat, aspect_flags: c.VkImageAspectFlags, alloc_cb: ?*c.VkAllocationCallbacks) !c.VkImageView{

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
