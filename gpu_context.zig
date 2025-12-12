const std = @import("std");
const c = @import("clibs.zig");
const sdl = @import("sdl.zig");
const helper = @import("helper.zig");

pub const validation_enabled = true;

pub const PhysicalDeviceSelectionCriteria = enum {
    /// Select the first device that matches the criteria.
    First,
    /// Prefer a discrete gpu.
    PreferDiscrete,
};

const Instance = struct {
    handle: c.VkInstance = undefined,
    debug_messenger: ?c.VkDebugUtilsMessengerEXT = null,
    alloc_cb: ?*c.VkAllocationCallbacks = null,
}

const Device = struct {
    handle: c.VkDevice = null,
    graphics_queue: c.VkQueue = null,
    present_queue: c.VkQueue = null,
    compute_queue: c.VkQueue = null,
    transfer_queue: c.VkQueue = null,
    sparse_binding_queue: c.VkQueue = null,
    features: c.VkPhysicalDeviceFeatures = undefined,
    pnext: ?*const anyopaque = null,
}

pub const PhysicalDevice = struct {
    handle: c.VkPhysicalDevice = null,
    properties: c.VkPhysicalDeviceProperties = undefined,
    graphics_queue_family: u32 = INVALID,
    present_queue_family: u32 = INVALID,
    compute_queue_family: u32 = INVALID,
    transfer_queue_family: u32 = INVALID,
    min_api_version: u32 = c.VK_MAKE_VERSION(1, 0, 0),
    required_extensions: []const [*c]const u8 = &.{},
    surface: c.VkSurfaceKHR = undefined,
    criteria: PhysicalDeviceSelectionCriteria = .PreferDiscrete,
}

const SwapchainEntry = struct {
    handle: c.VkSwapchainKHR,
    images: []c.VkImage,
    views: []c.VkImageView,
    extent: c.VkExtent2D,
    format: c.VkFormat,
};



pub const Renderer = struct {

    instance: Instance,
    device: Device,
    physical_device: PhysicalDevice,
    swapchain: []SwapchainEntry,
    capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
    formats: []c.VkSurfaceFormatKHR = &.{},
    present_modes: []c.VkPresentModeKHR = &.{},
    alloc_cb: ?*c.VkAllocationCallbacks = null,

    pub fn create(self: *Renderer, enable_debug: bool, allocator: std.mem.Allocator) !Renderer {

        
        // Allocation of Arena State
        var arenaState = std.heap.ArenaAllocator.init(allocator);
        defer arenaState.deinit();
        const arena = arenaState.allocator();

         
        // SDL Init
        var sdl_extension_count: c.UInt32 = 0;

        const sdl_raw = c.SDL_Vulkan_GetInstanceExtensions(&sdl_extension_count);
        if (sdl_raw == null){
            std.log.err("SDL_Vulkan_GetInstanceExtensions failed: {s}", .{c.SDL_GetError()});
            return error.SdlVulkanGetInstanceExtensionsFailed;
        }

        const sdl_len: usize = @intCast(sdl_extension_count);
        const sdl_many: [*]const [*c]const u8 = @ptrCast(sdl_raw);
        const sdl_extensions = sdl_many[0..sdl_len];

        const max_ext = 16;
        var ext_names: [max_ext][*:0]const u8 = undefined;
        var ext_count: usize = 0;

        for (sdl_extensions) |name| {
            ext_names[ext_count] = name;
            ext_count += 1;
        }

        for (sdl_extensions) |ext| {
            std.debug.print("Enabling extension: {s}\n", .{ext});
        }


        // Enable debugging
        if (enable_debug){
            ext_names[ext_count] =  "VK_EXT_debug_utils";
            ext_count += count;
        }


        // Create App info and Instance info
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


        // Creating Instance
        var vk_instance: c.VkInstance = undefined;
        try helper.check_vk(c.vkCreateInstance(&instance_info, alloc_cb, &vk_instance));
        
        self.instance = Instance{
            .handle = vk_instance,
            .alloc_cb = alloc_cb,
            .debug_messenger = null,
        }

        if (validation_enabled){
            try helper.createDebugMessenger(&self.instance);
        }


        // Creating Physical Device
        var physical_device_count: u32 = undefined;

        const required_device_extensions: []const [*c]const u8 = &.{
            "VK_KHR_swapchain",
        };

        self.required_extensions = required_device_extensions;

        try helper.check_vk(c.vkEnumeratePhysicalDevices(self.instance.handle, &physical_device_count, null));

        const physical_devices = try arena.alloc(c.VkPhysicalDevice, physical_device_count);
        try helper.check_vk(c.vkEnumeratePhysicalDevices(self.instance.handle, &physical_device_count, physical_devices.ptr));


        // Creating Surface
        var surface: c.VkSurface = undefined;

        if ( !c.SDL_Vulkan_CreateSurface(sdl.window, self.instance.handle, self.alloc_cb, &surface)){
            std.log.err("SDL_Vulkan_CreateSurface failed: {s}", .{c.SDL_GetError()});
            return error.FailedToCreateSurface;
        }

        log.info("surface handle = {x}", .{@intFromPtr(surface)});


        // Suitable Device
        var suitable_physical_device : ?PhysicalDevice = null;

        for (physical_devices) |device| {

            const pd = helper.MakePhysicalDevice(allocator, device, surface) catch continue;

            _ = helper.IsPhysicalDeviceSuitable(allocator, pd, surface, self.required_extensions) catch continue; 

            if (self.physical_device.criteria ==  PhysicalDeviceSelectionCriteria.First){
                
                suitable_physical_device = pd;
                break;

            }

            if (pd.properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU){
                
                suitable_physical_device = pd;

            }else if (suitable_physical_device == null){

                suitable_physical_device = pd;

            }


        }

        if (suitable_physical_device == null){

            log.err("No suitable physical device found.", .{});
            return error.vulkan_no_suitable_physical_device;    

        }

        if (suitable_physical_device) |*sd| {

            sd.surface = surface;

        }
    
        self.physical_device.* = suitable_physical_device.?; 

        const device_name = @as([*:0]const u8, @ptrCast(@alignCast(self.physical_device.properties.deviceName[0..])));

        log.info("Selected physical device: {s}", .{ device_name });


        
        // Logical Device
        var queue_create_infos = std.ArrayListUnmanaged(c.VkDeviceQueueCreateInfo){};
        const queue_priorities: f32 = 1.0;

        var queue_family_set = std.AutoArrayHashMapUnmanaged(u32, void){};

        try queue_family_set.put(arena, self.physical_device.graphics_queue_family, {});
        try queue_family_set.put(arena, self.physical_device.present_queue_family, {});
        try queue_family_set.put(arena, self.physical_device.compute_queue_family, {});
        try queue_family_set.put(arena, self.physical_device.transfer_queue_family, {});

        var qIter = queue_family_set.iterator();
        try queue_create_infos.ensureTotalCapacity(arena, queue_family_Set.count());
        
        while (qIter.next()) |qfi| {
            
            try queue_create_infos.append(arena, std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = qfi.key_ptr.*,
                .queueCount = 1,
                .pQueuePriorities = &queue_priorities,
            }));
        }

        const device_info = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = self.device.pnext,
            .queueCreateInfoCount = @as(u32, @intCast(queue_create_infos.items.len)),
            .pQueueCreateInfos = queue_create_infos.items.ptr,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @as(u32, @intCast(required_device_extensions.len)),
            .ppEnabledExtensionNames = required_device_extensions.ptr,
            .pEnabledFeatures = &self.device.features,
        });

        try helper.check_vk(c.vkCreateDevice(self.physical_device.handle, &device_info, self.alloc_cb, &self.device.handle));

        c.vkGetDeviceQueue(self.device.handle, self.physical_device.graphics_queue_family, 0, &self.device.graphics_queue);
        c.vkGetDeviceQueue(self.device.handle, self.physical_device.present_queue_family, 0, &self.device.present_queue);
        c.vkGetDeviceQueue(self.device.handle, self.physical_device.compute_queue_family, 0, &self.device.compute_queue);
        c.vkGetDeviceQueue(self.device.handle, self.physical_device.transfer_queue_family, 0, &self.device.transfer_queue); 


    }


};
