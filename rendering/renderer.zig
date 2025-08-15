
const c = @import("clibs.zig");
const vulkanInstance = @import("instance.zig");
const std = @import("std");
const wind = @import("../platform/x11.zig");
const dev = @import("device.zig");

const vk_alloc_cbs: ?*c.VkAllocationCallbacks = null;

pub const Renderer = struct {
    
    instance: vulkanInstance.Instance,
    pd: dev.PhysicalDevice,
    device: dev.Device,
    window: *wind.Window,
    swapchain: dev.Swapchain,
    //pipeline: pipeline.Pipeline,

    pub fn init(allocator:std.mem.Allocator, window: *wind.Window) !Renderer{
       
          //_ = allocator;

           const inst = try vulkanInstance.Instance.create( null, window);

           var pd: dev.PhysicalDevice = dev.PhysicalDevice{};
           try pd.init(inst, std.heap.page_allocator, window);
            
           // Device creation
           const device = blk: {
                var temp = dev.Device{
                    .physicalDevice = pd, 
                    .features = std.mem.zeroInit(c.VkPhysicalDeviceFeatures, .{}),
                    .alloc_cb = vk_alloc_cbs,
                };
                try temp.init(inst, allocator);
                break :blk temp;
           };

            
           const swapchain = blk:{
               var temp = dev.Swapchain{
                    .physicalDevice = pd.handle,
                    .graphicsQueueFamily = pd.graphicsQueueFamily,
                    .presentQueueFamily = pd.presentQueueFamily,
                    .device = device.handle,
                    .surface = pd.surface,
                    .oldSwapchain = null,
                    .vsync = true,
                    .windowWidth = @intCast(window.screen_width),
                    .windowHeight = @intCast(window.screen_height),
                    .alloc_cb = vk_alloc_cbs,
                };
               try temp.init(allocator,window);
               break :blk temp;
           };

           
            //pip = try pipeline.create( inst , dev, allocator),

            return Renderer {
                .instance = inst, 
                .pd = pd ,
                .window = window,
                .device = device,
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
