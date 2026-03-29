const std = @import("std");
const c = @import("clibs.zig").c;
const helper = @import("helper.zig");
const target = @import("builtin").target;
const swapchain = @import("swapchain.zig");
const engine = @import("engine.zig");
const sdl = engine.sdl;

pub const validation_enabled = true;
const is_macos = target.os.tag == .macos;
const log = std.log.scoped(.renderer);
const validation_layers = &[_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

pub const PhysicalDeviceSelectionCriteria = enum {
    /// Select the first device that matches the criteria.
    First,
    /// Prefer a discrete gpu.
    PreferDiscrete,
};

pub const Instance = struct {
    handle: c.VkInstance = null,
    debug_messenger: ?c.VkDebugUtilsMessengerEXT = null,
    alloc_cb: ?*c.VkAllocationCallbacks = null,
};

const Device = struct {
    handle: c.VkDevice = null,
    graphics_queue: c.VkQueue = null,
    present_queue: c.VkQueue = null,
    compute_queue: c.VkQueue = null,
    transfer_queue: c.VkQueue = null,
    sparse_binding_queue: c.VkQueue = null,
    features: c.VkPhysicalDeviceFeatures = undefined,
    pnext: ?*const anyopaque = null,
};

pub const PhysicalDevice = struct {
    handle: c.VkPhysicalDevice = null,
    properties: c.VkPhysicalDeviceProperties = undefined,
    graphics_queue_family: u32 = helper.INVALID,
    present_queue_family: u32 = helper.INVALID,
    compute_queue_family: u32 = helper.INVALID,
    transfer_queue_family: u32 = helper.INVALID,
    min_api_version: u32 = c.VK_MAKE_VERSION(1, 0, 0),
    required_extensions: []const [*c]const u8 = &.{},
    surface: c.VkSurfaceKHR = undefined,
    criteria: PhysicalDeviceSelectionCriteria = .PreferDiscrete,
};

pub const Core = struct {

    instance: Instance,
    device: Device,
    physical_device: PhysicalDevice,
    game_swapchain: swapchain.Swapchain,
    editor_swapchain: swapchain.Swapchain,
    capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
    formats: []c.VkSurfaceFormatKHR = &.{},
    present_modes: []c.VkPresentModeKHR = &.{},
    alloc_cb: ?*c.VkAllocationCallbacks = null,

    pub fn init(enable_debug: bool, allocator: std.mem.Allocator, win: *sdl.Window) !Core {

        // First INIT
        var self = Core{
            .instance = .{}, 
            .device = .{}, 
            .physical_device = .{}, 
            .game_swapchain = .{}, 
            .editor_swapchain = .{},
            .capabilities = undefined,
            .formats = &.{},
            .present_modes = &.{},
            .alloc_cb = null,
        };

        // Allocation of Arena State
        var arenaState = std.heap.ArenaAllocator.init(allocator);
        defer arenaState.deinit();
        const arena = arenaState.allocator();
         
        // SDL Init
        var sdl_extension_count: c_uint = 0;

        const sdl_raw = c.SDL_Vulkan_GetInstanceExtensions(&sdl_extension_count);
        if (sdl_raw == null){
            std.log.err("SDL_Vulkan_GetInstanceExtensions failed: {s}", .{c.SDL_GetError()});
            return error.SdlVulkanGetInstanceExtensionsFailed;
        }

        const sdl_len: usize = @intCast(sdl_extension_count);
        const sdl_many: [*]const [*c]const u8 = @ptrCast(sdl_raw);
        const sdl_extensions = sdl_many[0..sdl_len];

        const max_ext = 16;
        if (sdl_len > max_ext) return error.TooManyExtensions;
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
            ext_count += 1;
        }

        // Create App info and Instance info
        const app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Dobby",
            .applicationVersion = c.VK_MAKE_VERSION(0, 0, 9),
            .pEngineName = "Dobby",
            .engineVersion = c.VK_MAKE_VERSION(0, 0, 9),
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
        try helper.check_vk(c.vkCreateInstance(&instance_info, self.alloc_cb, &vk_instance));
        
        self.instance = Instance{
            .handle = vk_instance,
            .alloc_cb = self.alloc_cb,
            .debug_messenger = null,
        };

        if (validation_enabled){
            try helper.createDebugMessenger(&self);
        }


        // Creating Physical Device
        var physical_device_count: u32 = undefined;

        const required_device_extensions: []const [*c]const u8 = &.{
            "VK_KHR_swapchain",
        };

        self.physical_device.required_extensions = required_device_extensions;

        try helper.check_vk(c.vkEnumeratePhysicalDevices(self.instance.handle, &physical_device_count, null));

        const physical_devices = try arena.alloc(c.VkPhysicalDevice, physical_device_count);
        try helper.check_vk(c.vkEnumeratePhysicalDevices(self.instance.handle, &physical_device_count, physical_devices.ptr));


        // Creating Surface
        var surface: c.VkSurfaceKHR = undefined;

        if ( !c.SDL_Vulkan_CreateSurface(win.window, self.instance.handle, self.alloc_cb, &surface)){
            std.log.err("SDL_Vulkan_CreateSurface failed: {s}", .{c.SDL_GetError()});
            return error.FailedToCreateSurface;
        }

        log.info("surface handle = {x}", .{@intFromPtr(surface)});


        // Suitable Device
        var suitable_physical_device : ?PhysicalDevice = null;

        for (physical_devices) |device| {

            const pd = helper.MakePhysicalDevice(allocator, device, surface) catch continue;

            _ = helper.IsPhysicalDeviceSuitable(allocator, pd, surface, required_device_extensions) catch continue; 

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
    
        self.physical_device = suitable_physical_device.?; 

        const device_name = @as([*:0]const u8, @ptrCast(@alignCast(self.physical_device.properties.deviceName[0..])));

        log.info("Selected physical device: {s}", .{ device_name });
        
        // Supported physical device features
        // TODO: Add more supported features if needed
        var supported_feats: c.VkPhysicalDeviceFeatures = undefined;
        c.vkGetPhysicalDeviceFeatures(self.physical_device.handle, &supported_feats);

        var enabled_feats = std.mem.zeroInit(c.VkPhysicalDeviceFeatures, .{});
        if (supported_feats.samplerAnisotropy == c.VK_TRUE) {
            enabled_feats.samplerAnisotropy = c.VK_TRUE;
        }

        // Wireframe rendering / line widths
        if (supported_feats.fillModeNonSolid == c.VK_TRUE)
            enabled_feats.fillModeNonSolid = c.VK_TRUE;

        // Depth clamp (shadow maps, no near-plane clipping artifacts)
        if (supported_feats.depthClamp == c.VK_TRUE)
            enabled_feats.depthClamp = c.VK_TRUE;

        // Indexed drawing with non-uniform indices (nearly universal)
        if (supported_feats.multiDrawIndirect == c.VK_TRUE)
            enabled_feats.multiDrawIndirect = c.VK_TRUE;

        // Float64 in shaders (useful for precision-sensitive work)
        if (supported_feats.shaderFloat64 == c.VK_TRUE)
            enabled_feats.shaderFloat64 = c.VK_TRUE;

        // Clipping against multiple viewports (VR, shadow cascades)
        if (supported_feats.multiViewport == c.VK_TRUE)
            enabled_feats.multiViewport = c.VK_TRUE;
        
        // Large descriptor arrays (bindless textures)
        if (supported_feats.shaderSampledImageArrayDynamicIndexing == c.VK_TRUE)
            enabled_feats.shaderSampledImageArrayDynamicIndexing = c.VK_TRUE;

        if (supported_feats.shaderStorageBufferArrayDynamicIndexing == c.VK_TRUE)
            enabled_feats.shaderStorageBufferArrayDynamicIndexing = c.VK_TRUE;

        // Compute shaders need this for writing to storage images (light culling pass)
        if (supported_feats.shaderStorageImageExtendedFormats == c.VK_TRUE)
            enabled_feats.shaderStorageImageExtendedFormats = c.VK_TRUE;

        // Useful for shadow map sampling
        if (supported_feats.shaderClipDistance == c.VK_TRUE)
            enabled_feats.shaderClipDistance = c.VK_TRUE;
        
        // TODO: Add to Pipeline state
        // Alpha-to-coverage for foliage/vegetation (trees, grass)
       // if (supported_feats.alphaToCoverageEnable == c.VK_TRUE)  // actually a pipeline state, not a feature
        //    {} // handled at pipeline creation time

        // Wide lines for debug drawing
        if (supported_feats.wideLines == c.VK_TRUE)
            enabled_feats.wideLines = c.VK_TRUE;

        // Logical Device
        const queue_priorities: f32 = 1.0;
        const family_indices = [_]u32{
            self.physical_device.graphics_queue_family,
            self.physical_device.present_queue_family,
            self.physical_device.compute_queue_family,
            self.physical_device.transfer_queue_family,
        };

        // Deduplicate into a fixed stack buffer — max 4 unique families
        var unique_families: [4]u32 = undefined;
        var unique_count: usize = 0;
        outer: for (family_indices) |fi| {

            for (unique_families[0..unique_count]) |uf| {
                if (uf == fi) continue :outer;
            }
            unique_families[unique_count] = fi;
            unique_count += 1;
        }

        var queue_create_infos: [4]c.VkDeviceQueueCreateInfo = undefined;
        for (unique_families[0..unique_count], 0..) |fi, i| {
            queue_create_infos[i] = std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = fi,
                .queueCount = 1,
                .pQueuePriorities = &queue_priorities,
            });
        }


        // Query Vulkan 1.2 feature support
        var supported_12_feats = std.mem.zeroInit(c.VkPhysicalDeviceVulkan12Features, .{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        });

        var feat_query = std.mem.zeroInit(c.VkPhysicalDeviceFeatures2, .{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
            .pNext = &supported_12_feats,
        });

        c.vkGetPhysicalDeviceFeatures2(self.physical_device.handle, &feat_query);

        // Enable only what's supported
        var enabled_12_feats = std.mem.zeroInit(c.VkPhysicalDeviceVulkan12Features, .{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
            .pNext = null,
        });

        if (supported_12_feats.bufferDeviceAddress == c.VK_TRUE)
            enabled_12_feats.bufferDeviceAddress = c.VK_TRUE;

        if (supported_12_feats.shaderSampledImageArrayNonUniformIndexing == c.VK_TRUE)
            enabled_12_feats.shaderSampledImageArrayNonUniformIndexing = c.VK_TRUE;

        if (supported_12_feats.descriptorBindingPartiallyBound == c.VK_TRUE)
            enabled_12_feats.descriptorBindingPartiallyBound = c.VK_TRUE;

        if (supported_12_feats.runtimeDescriptorArray == c.VK_TRUE)
            enabled_12_feats.runtimeDescriptorArray = c.VK_TRUE;

        const device_info = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = &enabled_12_feats,
            .queueCreateInfoCount = @as(u32, @intCast(unique_count)),
            .pQueueCreateInfos = &queue_create_infos,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @as(u32, @intCast(required_device_extensions.len)),
            .ppEnabledExtensionNames = required_device_extensions.ptr,
            .pEnabledFeatures = &enabled_feats,
        });

        // Create Device and Queues

        try helper.check_vk(c.vkCreateDevice(self.physical_device.handle, &device_info, self.alloc_cb, &self.device.handle));

        c.vkGetDeviceQueue(self.device.handle, self.physical_device.graphics_queue_family, 0, &self.device.graphics_queue);
        c.vkGetDeviceQueue(self.device.handle, self.physical_device.present_queue_family, 0, &self.device.present_queue);
        c.vkGetDeviceQueue(self.device.handle, self.physical_device.compute_queue_family, 0, &self.device.compute_queue);
        c.vkGetDeviceQueue(self.device.handle, self.physical_device.transfer_queue_family, 0, &self.device.transfer_queue);

        return self;
    }
    
    pub fn deinit(self: *Core, allocator: std.mem.Allocator) void {
       
        _ = allocator;
        // If GPU exists then wait till finished before deleteing resources
        if (self.device.handle != null){
            
            _ = c.vkDeviceWaitIdle(self.device.handle);

        }

        // Destroying Device
        if (self.device.handle != null){
            c.vkDestroyDevice(self.device.handle, self.alloc_cb);
            self.device.handle = null;
        }

        // Destroy Surface (s)
        if (self.instance.handle != null and self.physical_device.surface != null){
            c.vkDestroySurfaceKHR(self.instance.handle, self.physical_device.surface, self.alloc_cb);
            self.physical_device.surface = null;
        }
    }


};
