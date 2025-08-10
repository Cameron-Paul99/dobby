
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

           
            //pip = try pipeline.create( inst , dev, allocator),

         // _ = allocator;
        //  _ = wind;

            return Renderer {
                .instance = inst, 
                .pd = newPD ,
                .window = window,
                .dev = newDevice,

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
