const std = @import("std");
const window = @import("sdl.zig");
const c = @import("clibs.zig").c;
const target = @import("builtin").target;
const log = std.log.scoped(.instance);

pub const validation_enabled = true;

const validation_layers = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

// Max extensions SDL might ask for (overkill but safe)
const max_sdl_extensions = 16;


const is_macos = target.os.tag == .macos;

pub const Instance = struct {
   handle: c.VkInstance = undefined,
   debug_messenger: ?c.VkDebugUtilsMessengerEXT = null,
   alloc_cb: ?*c.VkAllocationCallbacks = null,

    pub fn create(alloc_cb: ?*c.VkAllocationCallbacks) !Instance {

        var sdl_extension_count: c.Uint32 = 0;

        // Call SDL_Vulkan_GetInstanceExtensions correctly
        const sdl_raw = c.SDL_Vulkan_GetInstanceExtensions(&sdl_extension_count);
        if (sdl_raw == null) {
            std.log.err("SDL_Vulkan_GetInstanceExtensions failed: {s}", .{c.SDL_GetError()});
            return error.SdlVulkanGetInstanceExtensionsFailed;
        }

        const sdl_len: usize = @intCast(sdl_extension_count);
        const sdl_many: [*]const [*c]const u8 = @ptrCast(sdl_raw);
        const sdl_extensions = sdl_many[0..sdl_len];   

        // 2. Build a combined extension name buffer on the stack
        const max_ext = 16;
        var ext_names: [max_ext][*:0]const u8 = undefined;
        var ext_count: usize = 0;

        // copy SDL extensions in
        for (sdl_extensions) |name| {
            ext_names[ext_count] = name;
            ext_count += 1;
        }

        const enable_debug = true; // or a parameter / build option
        if (enable_debug) {
            ext_names[ext_count] = "VK_EXT_debug_utils";
            ext_count += 1;
        }

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
            .pNext = null,
            .flags = if (is_macos) c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR else 0,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = @intCast(ext_count),
            .ppEnabledExtensionNames = &ext_names,
            .enabledLayerCount = @as(u32, @intCast(validation_layers.len)),
            .ppEnabledLayerNames = validation_layers.ptr,
        };

        for (sdl_extensions) |ext| {
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




};

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


