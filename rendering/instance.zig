const std = @import("std");
const window = @import("../platform/x11.zig");
const c = @import("clibs.zig");
const target = @import("builtin").target;
const log = std.log.scoped(.instance);

const validation_enabled = true;

const validation_layers = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const is_macos = target.os.tag == .macos;

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
   handle: c.VkInstance = undefined,
   debug_messenger: ?c.VkDebugUtilsMessengerEXT = null,
   alloc_cb: ?*c.VkAllocationCallbacks = null,

    pub fn create(alloc_cb: ?*c.VkAllocationCallbacks, wind: *window.Window) !Instance {
        const extensions = try getRequiredExtensions(wind);

        const app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Dobby",
            .applicationVersion = c.VK_MAKE_VERSION(0, 1, 0),
            .pEngineName = "Dobby",
            .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
            .apiVersion = c.VK_API_VERSION_1_1,
        };

        const instance_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .flags = if (is_macos) c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR else 0,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = @as(u32, @intCast(extensions.len)),
            .ppEnabledExtensionNames = extensions.ptr,
            .enabledLayerCount = @as(u32, @intCast(validation_layers.len)),
            .ppEnabledLayerNames = validation_layers.ptr,
        };

        for (extensions) |ext| {
            std.debug.print("Enabling extension: {s}\n", .{ext});
        }

        var vk_instance: c.VkInstance = undefined;
        try check_vk(c.vkCreateInstance(&instance_info, alloc_cb, &vk_instance));

        var inst = Instance{
            .handle = vk_instance,
            .alloc_cb = alloc_cb,
            .debug_messenger = null,
        };

        if (validation_enabled) {
            try inst.createDebugMessenger();
        }

        return inst;
    }


    pub fn loadProcAddr(self: *Instance, comptime Fn: type, name: [*c]const u8) Fn {
         const func = vkGetInstanceProcAddr(self.handle, name);
         if (func) |f| return @ptrCast(f);
         @panic("vkGetInstanceProcAddr returned null");
    }

    pub fn createDebugMessenger(self: *Instance) !void {
        const create_fn_opt = self.loadProcAddr(
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
        try check_vk(create_fn(self.handle, &create_info, self.alloc_cb, &debug_messenger));

        self.debug_messenger = debug_messenger;
        log.info("Created Vulkan debug messenger.", .{});
    }

    pub fn destroyDebugMessenger(self: *Instance) void {
        if (self.debug_messenger) |dm| {
            const destroy_fn = self.loadProcAddr(
                c.PFN_vkDestroyDebugUtilsMessengerEXT,
                "vkDestroyDebugUtilsMessengerEXT");

            destroy_fn(self.handle, dm, self.alloc_cb);
        }
    }

    fn getRequiredExtensions(wind: *window.Window) ![]const [*:0]const u8 {
        return switch (wind.backend) {
            .x11 => &[_][*:0]const u8{
                "VK_KHR_surface",
                "VK_KHR_xlib_surface",
                "VK_EXT_debug_utils",
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


fn defaultDebugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    msg_type: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.C) c.VkBool32 {

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
        @panic("Unrecoverable Vulkan error.");
    }

    return c.VK_FALSE;
}

extern fn vkGetInstanceProcAddr(
    instance: c.VkInstance,
    pName: [*c]const u8,
) ?*const anyopaque;


