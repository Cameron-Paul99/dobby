const c = @import("clibs.zig");
const std = @import("std");
const target = @import("builtin").target;
const inst = @import("instance.zig");
const wind = @import("../platform/x11.zig");
const log = std.log.scoped(.device);

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
    graphicsQueue: c.VkQueue = null,
    presentQueue: c.VkQueue = null,
    computeQueue: c.VkQueue = null,
    transferQueue: c.VkQueue = null,
    sparseBindingQueue: c.VkQueue = null,
    physicalDevice: PhysicalDevice,
    features: c.VkPhysicalDeviceFeatures = undefined,
    alloc_cb: ?*const c.VkAllocationCallbacks = null,
    // Optional
    pnext: ?*const anyopaque = null,

    pub fn create(self: *Device , instance: inst.Instance, allocator: std.mem.Allocator) !Device{
        
        _ = instance;

        var arenaState = std.heap.ArenaAllocator.init(allocator);
        defer arenaState.deinit();
        const arena = arenaState.allocator();

        var queueCreateInfos = std.ArrayListUnmanaged(c.VkDeviceQueueCreateInfo){};
        const queuePriorities: f32 = 1.0;

        var queueFamilySet = std.AutoArrayHashMapUnmanaged(u32, void){};

        try queueFamilySet.put(arena, self.physicalDevice.graphicsQueueFamily, {});
        try queueFamilySet.put(arena, self.physicalDevice.presentQueueFamily, {});
        try queueFamilySet.put(arena, self.physicalDevice.computeQueueFamily, {});
        try queueFamilySet.put(arena, self.physicalDevice.transferQueueFamily, {});

        var qIter = queueFamilySet.iterator();
        try queueCreateInfos.ensureTotalCapacity(arena, queueFamilySet.count());

        while (qIter.next()) |qfi| {
            
            try queueCreateInfos.append(arena, std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = qfi.key_ptr.*,
                .queueCount = 1,
                .pQueuePriorities = &queuePriorities,
            }));
        }

        const deviceExtensions: []const [*c]const u8 = &.{
            "VK_KHR_swapchain",
        };

        const deviceInfo = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = self.pnext,
            .queueCreateInfoCount = @as(u32, @intCast(queueCreateInfos.items.len)),
            .pQueueCreateInfos = queueCreateInfos.items.ptr,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @as(u32, @intCast(deviceExtensions.len)),
            .ppEnabledExtensionNames = deviceExtensions.ptr,
            .pEnabledFeatures = &self.features,
        });

        var device: c.VkDevice = undefined;
        try inst.check_vk(c.vkCreateDevice(self.physicalDevice.handle, &deviceInfo, self.alloc_cb, &device));

        var graphics_queue: c.VkQueue = undefined;
        c.vkGetDeviceQueue(device, self.physicalDevice.graphicsQueueFamily, 0, &graphics_queue);

        var present_queue: c.VkQueue = undefined;
        c.vkGetDeviceQueue(device, self.physicalDevice.presentQueueFamily, 0, &present_queue);

        var compute_queue: c.VkQueue = undefined;
        c.vkGetDeviceQueue(device, self.physicalDevice.computeQueueFamily, 0, &compute_queue);

        var transfer_queue: c.VkQueue = undefined;
        c.vkGetDeviceQueue(device, self.physicalDevice.transferQueueFamily, 0, &transfer_queue);

        var res = self.*;
    
        res.handle = device;
        res.graphicsQueue = graphics_queue;
        res.presentQueue = present_queue;
        res.computeQueue = compute_queue;
        res.transferQueue = transfer_queue;
        
        return res;

    }
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
    surface: c.VkSurfaceKHR = undefined,
    criteria: PhysicalDeviceSelectionCriteria = .PreferDiscrete,

  
    pub fn create(self: *PhysicalDevice ,instance: inst.Instance, allocator: std.mem.Allocator, window: *wind.Window ) !PhysicalDevice{
        
        var physicalDeviceCount: u32 = undefined;
        
        // Get physical device count
        try inst.check_vk(c.vkEnumeratePhysicalDevices(instance.handle, &physicalDeviceCount, null));
        
        // Allocating memory because we won't know the device count until runtime
        var arenaState = std.heap.ArenaAllocator.init(allocator);
        defer arenaState.deinit();
        const arena = arenaState.allocator();

        // Bind physical devices
        const physicalDevices = try arena.alloc(c.VkPhysicalDevice, physicalDeviceCount);
        try inst.check_vk(c.vkEnumeratePhysicalDevices(instance.handle, &physicalDeviceCount, physicalDevices.ptr));

        //Surface
        var ci = std.mem.zeroInit(c.VkXlibSurfaceCreateInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
            .dpy = window.display,
            .window = window.window,
        });

        var surface: c.VkSurfaceKHR = undefined;

        try inst.check_vk(c.vkCreateXlibSurfaceKHR(instance.handle, &ci, window.alloc_cb, &surface));
        
        var suitablePhysicalDevice : ?PhysicalDevice = null;

        for (physicalDevices) |device| {

            const pd = make_physical_device(allocator, device, surface) catch continue;
            _ = is_physical_device_suitable(pd) catch continue;

            if (self.criteria == PhysicalDeviceSelectionCriteria.First) {
                suitablePhysicalDevice = pd;
                break;
            }

            if (pd.properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
                suitablePhysicalDevice = pd;
                break;

            } else if (suitablePhysicalDevice == null) {
                suitablePhysicalDevice = pd;
            }

        }

        if (suitablePhysicalDevice == null) {
            log.err("No suitable physical device found.", .{});
            return error.vulkan_no_suitable_physical_device;
        }
        const res = suitablePhysicalDevice.?;

        const device_name = @as([*:0]const u8, @ptrCast(@alignCast(res.properties.deviceName[0..])));
        log.info("Selected physical device: {s}", .{ device_name });

        return res;

    }

    pub fn make_physical_device(allocator: std.mem.Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR,) !PhysicalDevice{

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

    fn is_physical_device_suitable(device: PhysicalDevice) !bool {

        if (device.properties.apiVersion < device.min_api_version) {

            return false;

        }
        if (device.graphicsQueueFamily == INVALID or
            device.presentQueueFamily == INVALID or
            device.computeQueueFamily == INVALID or
            device.transferQueueFamily == INVALID) {

            return false;

        }

        return true;

    }

};

