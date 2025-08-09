
const c = @import("clibs.zig");
const vulkanInstance = @import("instance.zig");
const std = @import("std");
const wind = @import("../platform/x11.zig");
const device = @import("device.zig");

pub const Renderer = struct {
    
    instance: vulkanInstance.Instance,
    dev: device.PhysicalDevice,
    window: *wind.Window,
    //pipeline: pipeline.Pipeline,

    pub fn init(allocator: *const std.mem.Allocator, window: *wind.Window) !Renderer{
       
          _ = allocator;

           const inst = try vulkanInstance.Instance.create( null, window);
           var dev : device.PhysicalDevice = device.PhysicalDevice{};
           const newDevice = try dev.create(inst, std.heap.page_allocator, window);
            //pip = try pipeline.create( inst , dev, allocator),

         // _ = allocator;
        //  _ = wind;

            return Renderer {.instance = inst, .dev = newDevice ,.window = window}; //.device = dev, .pipeline = pip};

    }

    pub fn draw(self: *Renderer, window: *wind.Window) void {

        _ = self;
        _ = window;

    }


    pub fn deinit(self: *Renderer) void{
            _ = self;
    }

};
