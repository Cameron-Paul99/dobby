const std = @import("std");
const window = @import("../platform/x11.zig");
const c = @import("clibs.zig");
const target = @import("builtin").target;
const log = std.log.scoped(.instance);

const validation_enabled = true;

const validation_layers = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

var debug_info = c.VkDebugUtilsMessengerCreateInfoEXT{
    .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
    .pNext = null,
    .flags = 0,
    .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                       c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                       c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
    .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                   c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                   c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
    //.pfnUserCallback = debugCallback,
    .pUserData = null,
};

pub const Instance = struct {
    handle: c.VkInstance,
    debug_messenger: ?c.VkDebugUtilsMessengerEXT = null,

    pub fn create(wind: *window.Window) !Instance {
        const is_macos = target.os.tag == .macos;

        const extensions = try getRequiredExtensions(wind);

        const app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Dobby",
            .applicationVersion = c.VK_MAKE_VERSION(0, 1, 0),
            .pEngineName = "Dobby",
            .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
            .apiVersion = c.VK_MAKE_VERSION(1, 1, 0),
        };

        const instance_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = if (validation_enabled) &debug_info else null,
            .flags = if (is_macos) c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR else 0,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount =  @intCast(extensions.len),
            .ppEnabledExtensionNames = extensions.ptr,
            .enabledLayerCount = if (validation_enabled) @intCast(validation_layers.len) else 0,
            .ppEnabledLayerNames = if (validation_enabled) validation_layers.ptr else null,
        };

        var instance: c.VkInstance = undefined;
        try check_vk(c.vkCreateInstance(&instance_info, null, &instance));
        log.info("Created Vulkan instance.", .{});

        var debug_messenger: ?c.VkDebugUtilsMessengerEXT = null;

    if (validation_enabled) {
        const create_fn = get_instance_proc(
            *const fn (
                c.VkInstance,
                *const c.VkDebugUtilsMessengerCreateInfoEXT,
                ?*const c.VkAllocationCallbacks,
                *c.VkDebugUtilsMessengerEXT
            ) callconv(.C) c.VkResult,
            instance,
            "vkCreateDebugUtilsMessengerEXT",
        ) orelse return error.MissingExtension;

        var messenger: c.VkDebugUtilsMessengerEXT = undefined;
        try check_vk(create_fn(instance, &debug_info, null, &messenger));
        debug_messenger = messenger;
    }

        return Instance{
            .handle = instance,
            .debug_messenger = debug_messenger,
        };
    }

    fn get_instance_proc(comptime T: type, instance: c.VkInstance, name: [*:0]const u8) ?T {
        return @ptrCast(c.vkGetInstanceProcAddr(instance, name));
    }

    fn getRequiredExtensions(wind: *window.Window) ![]const [*:0]const u8 {
        return switch (wind.backend) {
            .x11 => &[_][*:0]const u8{
                "VK_KHR_surface",
                "VK_KHR_xlib_surface",
            },
            .wayland => &[_][*:0]const u8{
                "VK_KHR_surface",
                "VK_KHR_wayland_surface",
            },
            .win32 => &[_][*:0]const u8{
                "VK_KHR_surface",
                "VK_KHR_win32_surface",
            },
            .win64 => &[_][*:0]const u8{
                "VK_KHR_surface",
                "VK_KHR_win64_surface",
            },
            .macos => &[_][*:0]const u8{
                "VK_KHR_surface",
                "VK_EXT_metal_surface",
                "VK_KHR_get_physical_device_properties2",
                "VK_KHR_portability_enumeration",
            },
        };
    }

    fn check_vk(result: c.VkResult) !void {
        if (result != c.VK_SUCCESS) return error.VulkanError;
    }
};

export fn debugCallback(
    //message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    //message_type: c.VkDebugUtilsMessageTypeFlagsEXT,
    //callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    //user_data: ?*anyopaque,
) callconv(.C) c.VkBool32 {

   // std.log.warn("Validation: {?s}", .{callback_data.?.pMessage});
    return c.VK_FALSE;
}

