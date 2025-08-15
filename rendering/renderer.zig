
const c = @import("clibs.zig");
const vulkanInstance = @import("instance.zig");
const std = @import("std");
const wind = @import("../platform/x11.zig");
const device = @import("device.zig");

const vk_alloc_cbs: ?*c.VkAllocationCallbacks = null;

pub const Renderer = struct {
    
    instance: vulkanInstance.Instance,
    pd: device.PhysicalDevice,
    dev: device.Device,
    window: *wind.Window,
    swapchain: device.Swapchain,
    //pipeline: pipeline.Pipeline,

    pub fn init(allocator:std.mem.Allocator, window: *wind.Window) !Renderer{
       
          //_ = allocator;

           const inst = try vulkanInstance.Instance.create( null, window);
           var pd: device.PhysicalDevice = device.PhysicalDevice{};
           const newPD = try pd.create(inst, std.heap.page_allocator, window);

           var dev: device.Device = device.Device{
               .physicalDevice = newPD, 
               .features = std.mem.zeroInit(c.VkPhysicalDeviceFeatures, .{}),
               .alloc_cb = vk_alloc_cbs,
            };

           const newDevice = try dev.create(inst, allocator);

           var sc: device.Swapchain = device.Swapchain{
               .physicalDevice = newPD.handle,
               .graphicsQueueFamily = newPD.graphicsQueueFamily,
               .presentQueueFamily = newPD.presentQueueFamily,
               .device = newDevice.handle,
               .surface = newPD.surface,
               .oldSwapchain = null,
               .vsync = true,
               .windowWidth = @intCast(window.screen_width),
               .windowHeight = @intCast(window.screen_height),
               .alloc_cb = vk_alloc_cbs,
                
           };

           const swapchain = try sc.create(allocator, window);

           
            //pip = try pipeline.create( inst , dev, allocator),

         // _ = allocator;
        //  _ = wind;

            return Renderer {
                .instance = inst, 
                .pd = newPD ,
                .window = window,
                .dev = newDevice,
                .swapchain = swapchain,

            }; //.device = dev, .pipeline = pip};

    }

    pub fn draw(self: *Renderer, window: *wind.Window) void {

        _ = self;
        _ = window;

    }


    pub fn deinit(self: *Renderer) void{
            _ = self;
    }

};
