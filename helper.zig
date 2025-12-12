const std = @import("std");
const c = @import("clibs.zig");
const sdl = @import("sdl.zig");
const gpu_context = @import("gpu_context.zig"); 

pub fn loadProcAddr(inst: *Instance, comptime Fn: type, name: [*c]const u8) Fn {

    const func = vkGetInstanceProcAddr(inst.handle, name);
    if (func) |f| return @ptrCast(f);
    @panic("vkGetInstanceProcAddr returned null");

}

pub fn createDebugMessenger(inst: *Instance) !void {

    const create_fn_opt = inst.loadProcAddr(
        c.PFN_vkCreateDebugUtilsMessengerEXT,
        "vkCreateDebugUtilsMessengerEXT",
    );

    const create_fn = create_fn_opt orelse {
        log.err("Failed to load vkCreateDebugUtilsMessengerEXT", .{});
        return error.MissingExtension;
    };

    const create_info = std.mem.zeroInit(c.VkDebugUtilsMessengerCreateInfoEXT, .{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = defaultDebugCallback,
        .pUserData = null,
    });

    var debug_messenger: c.VkDebugUtilsMessengerEXT = undefined;
    try check_vk(create_fn(inst.handle, &create_info, inst.alloc_cb, &debug_messenger));

    inst.debug_messenger = debug_messenger;
    log.info("Created Vulkan debug messenger.", .{});

}

pub fn destroyDebugMessenger(inst: *Instance) void {

    if (inst.debug_messenger) |dm| {
        const destroy_fn = inst.loadProcAddr(
            c.PFN_vkDestroyDebugUtilsMessengerEXT,
            "vkDestroyDebugUtilsMessengerEXT");
        destroy_fn(inst.handle, dm, inst.alloc_cb);
    }

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


pub fn MakePhysicalDevice(allocator: std.mem.Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR,) !PhysicalDevice{

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
    var pd = PhysicalDevice{
        .handle = device,
        .properties = props,
        .graphicsQueueFamily = INVALID,
        .presentQueueFamily  = INVALID,
        .computeQueueFamily  = INVALID,
        .transferQueueFamily = INVALID,
    };

        // ---- Pick first matching families (early-exit when all found)
    for (qprops, 0..) |q, i| {

        const idx: u32 = @intCast(i);

        if (pd.graphicsQueueFamily == INVALID and q.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) 

            pd.graphicsQueueFamily = idx;

        if (pd.computeQueueFamily == INVALID and q.queueFlags & c.VK_QUEUE_COMPUTE_BIT != 0)

            pd.computeQueueFamily = idx;

        if (pd.transferQueueFamily == INVALID and q.queueFlags & c.VK_QUEUE_TRANSFER_BIT != 0)

            pd.transferQueueFamily = idx;

        if (pd.presentQueueFamily == INVALID) {

            var support: c.VkBool32 = 0;

            try inst.check_vk(c.vkGetPhysicalDeviceSurfaceSupportKHR(device, idx, surface, &support));

            if (support == c.VK_TRUE)
                pd.presentQueueFamily = idx;
        }

        if (pd.graphicsQueueFamily != INVALID and
            pd.presentQueueFamily != INVALID and
            pd.computeQueueFamily != INVALID and
            pd.transferQueueFamily != INVALID) {
            break;
        }  

    }

    return pd;

}

pub fn IsPhysicalDeviceSuitable(allocator: std.mem.Allocator, device: gpu_context.PhysicalDevice, surface: c.VkSurfaceKHR, required_extensions: []const [*c]const u8 ) !bool {

        if (device.properties.apiVersion < device.min_api_version) {

            return false;

        }
        if (device.graphicsQueueFamily == INVALID or
            device.presentQueueFamily == INVALID or
            device.computeQueueFamily == INVALID or
            device.transferQueueFamily == INVALID) {

            return false;

        }


        const swapchain_support = try SwapchainSupportInfo.init(arena, device.handle, surface);
        defer swapchain_support.deinit(arena);
        if (swapchain_support.formats.len == 0 or swapchain_support.present_modes.len == 0) {
            return false;
        }

        if (required_extensions.len > 0) {
            var device_extension_count: u32 = undefined;
            try check_vk(c.vkEnumerateDeviceExtensionProperties(device.handle, null, &device_extension_count, null));
            const device_extensions = try arena.alloc(c.VkExtensionProperties, device_extension_count);
            try check_vk(c.vkEnumerateDeviceExtensionProperties(device.handle, null, &device_extension_count, device_extensions.ptr));

            _ = blk: for (required_extensions) |req_ext| {
                for (device_extensions) |device_ext| {
                    const device_ext_name: [*c]const u8 = @ptrCast(device_ext.extensionName[0..]);
                    if (std.mem.eql(u8, std.mem.span(req_ext), std.mem.span(device_ext_name))) {
                        break :blk true;
                    }
                }
            } else return false;
        }

        return true;

    }

};
