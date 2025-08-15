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

        const required_device_extensions: []const [*c]const u8 = &.{
            "VK_KHR_swapchain",
        };

        self.required_extensions = required_device_extensions;
        
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
        log.info("surface handle = {x}", .{@intFromPtr(surface)});

        var suitablePhysicalDevice : ?PhysicalDevice = null;

        for (physicalDevices) |device| {

            const pd = make_physical_device(allocator, device, surface) catch continue;
    
            _ = is_physical_device_suitable(allocator, pd, surface, self.required_extensions) catch continue;

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
        if (suitablePhysicalDevice) |*sd| {
            
            sd.surface = surface;

        }

        const res = suitablePhysicalDevice.?;

        const device_name = @as([*:0]const u8, @ptrCast(@alignCast(res.properties.deviceName[0..])));
        log.info("Selected physical device: {s}", .{ device_name });

        var caps: c.VkSurfaceCapabilitiesKHR = undefined;
        try inst.check_vk(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(res.handle, surface, &caps));

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

    fn is_physical_device_suitable(allocator: std.mem.Allocator, device: PhysicalDevice, surface: c.VkSurfaceKHR, required_extensions: []const [*c]const u8 ) !bool {

        if (device.properties.apiVersion < device.min_api_version) {

            return false;

        }
        if (device.graphicsQueueFamily == INVALID or
            device.presentQueueFamily == INVALID or
            device.computeQueueFamily == INVALID or
            device.transferQueueFamily == INVALID) {

            return false;

        }

        var arena_state = std.heap.ArenaAllocator.init(allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator();

        const swapchain_support = try SwapchainSupportInfo.init(arena, device.handle, surface);
        defer swapchain_support.deinit(arena);
        if (swapchain_support.formats.len == 0 or swapchain_support.present_modes.len == 0) {
            return false;
        }

        if (required_extensions.len > 0) {
            var device_extension_count: u32 = undefined;
            try inst.check_vk(c.vkEnumerateDeviceExtensionProperties(device.handle, null, &device_extension_count, null));
            const device_extensions = try arena.alloc(c.VkExtensionProperties, device_extension_count);
            try inst.check_vk(c.vkEnumerateDeviceExtensionProperties(device.handle, null, &device_extension_count, device_extensions.ptr));

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

pub const Swapchain = struct {
    
    handle: c.VkSwapchainKHR = null,
    images: []c.VkImage = &.{},
    imageViews: []c.VkImageView = &.{},
    format: c.VkFormat = undefined,
    extent: c.VkExtent2D = undefined, 
    
    // Options
    physicalDevice: c.VkPhysicalDevice,
    graphicsQueueFamily: u32,
    presentQueueFamily: u32,
    device: c.VkDevice,
    surface: c.VkSurfaceKHR,
    oldSwapchain: c.VkSwapchainKHR = null,
    vsync: bool = false,
    tripleBuffer: bool = false,
    windowWidth: u32 = 0,
    windowHeight: u32 = 0,
    alloc_cb: ?*c.VkAllocationCallbacks = null,

    pub fn create(self: *Swapchain, allocator: std.mem.Allocator, window: *wind.Window) !Swapchain{

        _ = window;
        
        const supportInfo = try SwapchainSupportInfo.init(allocator, self.physicalDevice, self.surface);
        defer supportInfo.deinit(allocator);

        const format = pick_swapchain_format(supportInfo.formats);
        const presentMode = self.pick_swapchain_present_mode(supportInfo.present_modes);
        const extent = self.make_swapchain_extent(supportInfo.capabilities);

        const imageCount = blk: {
            const desiredCount = supportInfo.capabilities.minImageCount + 1;
        
            if (supportInfo.capabilities.maxImageCount > 0) {
                    break :blk @min(desiredCount, supportInfo.capabilities.maxImageCount);
                }
                break :blk desiredCount;
        };


        var swapchainInfo = std.mem.zeroInit(c.VkSwapchainCreateInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = self.surface,
            .minImageCount = imageCount,
            .imageFormat = format,
            .imageColorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .preTransform = supportInfo.capabilities.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = presentMode,
            .clipped = c.VK_TRUE,
            .oldSwapchain = self.oldSwapchain,
        });

        if (self.graphicsQueueFamily != self.presentQueueFamily) {

            const queueFamilyIndices: []const u32 = &.{
                self.graphicsQueueFamily,
                self.presentQueueFamily,
            };

            swapchainInfo.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
            swapchainInfo.queueFamilyIndexCount = 2;
            swapchainInfo.pQueueFamilyIndices = queueFamilyIndices.ptr;

        }else{

            swapchainInfo.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;

        }

        var swapchain: c.VkSwapchainKHR = undefined;
        try inst.check_vk(c.vkCreateSwapchainKHR(self.device, &swapchainInfo, self.alloc_cb, &swapchain));
        errdefer c.vkDestroySwapchainKHR(self.device, swapchain, self.alloc_cb);
        log.info("Created vulkan swapchain.", .{});

        // Try and fetch the images from the swapchain
        var swapchainImageCount: u32 = undefined;
        try inst.check_vk(c.vkGetSwapchainImagesKHR(self.device, swapchain, &swapchainImageCount, null));
        const swapchainImages = try allocator.alloc(c.VkImage, swapchainImageCount);
        errdefer allocator.free(swapchainImages);
        try inst.check_vk(c.vkGetSwapchainImagesKHR(self.device, swapchain, &swapchainImageCount, swapchainImages.ptr));

        // Create image views for the swapchain images
        const swapchainImageViews = try allocator.alloc(c.VkImageView, swapchainImageCount);
        errdefer allocator.free(swapchainImageViews);

        for (swapchainImages, swapchainImageViews) |image, *view| {   
            view.* = try create_image_view(self.device, image, format, c.VK_IMAGE_ASPECT_COLOR_BIT, self.alloc_cb);
        }

        const sc =  Swapchain{
            .handle = swapchain,
            .images = swapchainImages,
            .imageViews = swapchainImageViews,
            .format = format,
            .extent = extent,
            .physicalDevice = self.physicalDevice,
            .graphicsQueueFamily = self.graphicsQueueFamily,
            .presentQueueFamily = self.presentQueueFamily,
            .device = self.device,
            .surface = self.surface,

        };

        return sc;
        
    }

    fn pick_swapchain_format(formats: []const c.VkSurfaceFormatKHR) c.VkFormat{

        for (formats) |format| {
            if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and
                format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                return format.format;
            }
        }

        return formats[0].format;

    }

    fn pick_swapchain_present_mode(self: *Swapchain, modes: []const c.VkPresentModeKHR) c.VkPresentModeKHR {

        if (self.vsync == false) {
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
            if (mode == c.VK_PRESENT_MODE_MAILBOX_KHR and self.tripleBuffer) {
                return mode;
            }
        }

        // If nothing else is present, FIFO is guaranteed to be available by the specs.
        return c.VK_PRESENT_MODE_FIFO_KHR;

    }

    fn make_swapchain_extent(self: Swapchain ,capabilities: c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {

        if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
            return capabilities.currentExtent;
        }

        var extent = c.VkExtent2D{
            .width = self.windowWidth,
            .height = self.windowHeight,
        };

        extent.width = @max(
            capabilities.minImageExtent.width,
            @min(capabilities.maxImageExtent.width, extent.width));

        extent.height = @max(
            capabilities.minImageExtent.height,
            @min(capabilities.maxImageExtent.height, extent.height));

        return extent;    

    }


};

fn create_image_view(
    device: c.VkDevice,
    image: c.VkImage,
    format: c.VkFormat,
    aspect_flags: c.VkImageAspectFlags,
    alloc_cb: ?*c.VkAllocationCallbacks
) !c.VkImageView {

    const view_info = std.mem.zeroInit(c.VkImageViewCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .format = format,
        .components = .{
            .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = c.VK_COMPONENT_SWIZZLE_IDENTITY
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
    try inst.check_vk(c.vkCreateImageView(device, &view_info, alloc_cb, &image_view));
    return image_view;
}

const SwapchainSupportInfo = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
    formats: []c.VkSurfaceFormatKHR = &.{},
    present_modes: []c.VkPresentModeKHR = &.{},


    pub fn init(allocator: std.mem.Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !SwapchainSupportInfo{

        var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        try inst.check_vk(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &capabilities));

        var format_count: u32 = undefined;
        try inst.check_vk(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, null));
        const formats = try allocator.alloc(c.VkSurfaceFormatKHR, format_count);
        try inst.check_vk(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, formats.ptr));

        var present_mode_count: u32 = undefined;
        try inst.check_vk(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null));
        const present_modes = try allocator.alloc(c.VkPresentModeKHR, present_mode_count);
        try inst.check_vk(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, present_modes.ptr));
        
        return .{  
            .capabilities = capabilities,
            .formats = formats,
            .present_modes = present_modes,

        };
    }

    fn deinit(self: *const SwapchainSupportInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.formats);
        allocator.free(self.present_modes);
    }
    
};

