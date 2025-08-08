const c = @import("clibs.zig");
const std = @import("std");
const target = @import("builtin").target;
const inst = @import("instance.zig");


const INVALID = std.math.maxInt(u32);

/// Selection criteria for a physical device.
///
pub const PhysicalDeviceSelectionCriteria = enum {
    /// Select the first device that matches the criteria.
    First,
    /// Prefer a discrete gpu.
    PreferDiscrete,
};


pub const Device = struct {
    
    handle: c.VkDevice = null,
    graphicsQueueFamily: c.VkQueue = null,
    presentQueueFamily: c.VkQueue = null,
    computeQueueFamily: c.VkQueue = null,
    transferQueueFamily: c.VkQueue = null,
    sparseBindingQueueFamily: c.VkQueue = null,

};


pub const PhysicalDevice = struct {
    
    handle: c.VkPhysicalDevice = null,
    properties: c.VkPhysicalDeviceProperties = undefined,
    graphicsQueueFamily: u32 = INVALID,
    presentQueueFamily: u32 = INVALID,
    computeQueueFamily: u32 = INVALID,
    transferQueueFamily: u32 = INVALID,
    min_api_version: u32 = c.VK_MAKE_VERSION(1, 0, 0),
    required_extensions: []const [*c]const u8 = &.{},
    surface: c.VkSurfaceKHR,
    criteria: PhysicalDeviceSelectionCriteria = .PreferDiscrete,

  
    pub fn create(instance: inst.Instance, allocator: std.mem.Allocator) !PhysicalDevice{
        
        var physicalDeviceCount: u32 = undefined;
        
        // Get physical device count
        try check_vk(c.vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, null));
        
        // Allocating memory because we won't know the device count until runtime
        var arenaState = std.heap.ArenaAllocator.init(allocator);
        defer arenaState.deinit();
        const arena = arenaState.allocator();

        // Bind physical devices
        const physicalDevices = try arena.alloc(c.VkPhysicalDevice, physicalDeviceCount);
        try check_vk(c.vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, physicalDevices.ptr));
        
        var suitablePhysicalDevice = ?PhysicalDevice = null;

        for (physicalDevices) |device| {

        }

    }

    pub fn make_physical_devices( , allocator: std.mem.Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR,) !PhysicalDevice{

        // ---- Properties
        var props: c.VkPhysicalDeviceProperties = undefined;
        c.vkGetPhysicalDeviceProperties(device, &props);

        // ---- Queue families (enumerate -> alloc -> fill)
        var qcount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &qcount, null);

        const qprops = try alloc.alloc(c.VkQueueFamilyProperties, qcount);
        defer alloc.free(qprops);

        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &qcount, qprops.ptr);

        // ---- Build result with sane defaults
        var pd = PhysicalDevice{
            .handle = device,
            .properties = props,
            .graphics_queue_family = INVALID,
            .present_queue_family  = INVALID,
            .compute_queue_family  = INVALID,
            .transfer_queue_family = INVALID,
        };

        inline fn has(flags: c.VkQueueFlags, bit: c.VkQueueFlagBits) bool {
            return (flags & bit) != 0;
        }

        inline fn unset(x: u32) bool {
            return x == INVALID;
        }

        inline fn done(g: u32, p: u32, c_: u32, t: u32) bool {
            return g != INVALID and p != INVALID and c_ != INVALID and t != INVALID;
        }

        // ---- Pick first matching families (early-exit when all found)
        for (qprops, 0..) |q, i| {
            const idx: u32 = @intCast(i);

            if (unset(pd.graphicsQueueFamily) and has(q.queueFlags, c.VK_QUEUE_GRAPHICS_BIT))

                pd.graphicsQueueFamily = idx;

            if (unset(pd.computeQueueFamily) and has(q.queueFlags, c.VK_QUEUE_COMPUTE_BIT))

                pd.computeQueueFamily = idx;

            if (unset(pd.transferQueueFamily) and has(q.queueFlags, c.VK_QUEUE_TRANSFER_BIT))

                pd.transferQueueFamily = idx;

            if (unset(pd.presentQueueFamily)) {

                var support: c.VkBool32 = 0;

                try check_vk(c.vkGetPhysicalDeviceSurfaceSupportKHR(device, idx, surface, &support));

                if (support == c.VK_TRUE)
                    pd.presentQueueFamily = idx;
            }

            if (done(pd.graphicsQueueFamily, pd.presentQueueFamily, pd.computeQueueFamily, pd.transferQueueFamily))
                break;
        }

        return pd;

    }

};

