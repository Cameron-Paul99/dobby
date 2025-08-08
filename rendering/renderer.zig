
const c = @import("clibs.zig");
const vulkanInstance = @import("instance.zig");
const std = @import("std");
const wind = @import("../platform/x11.zig");

pub const Renderer = struct {
    
    instance: vulkanInstance.Instance,
    device: device.Device,
    window: *wind.Window,
    //pipeline: pipeline.Pipeline,

    pub fn init(allocator: *const std.mem.Allocator, window: *wind.Window) !Renderer{
       
       // _ = allocator;

           const inst = try vulkanInstance.Instance.create( null, window);
           const dev = try device.create(inst, allocator);
            //pip = try pipeline.create( inst , dev, allocator),

         // _ = allocator;
        //  _ = wind;

            return Renderer {.instance = inst, .window = window}; //.device = dev, .pipeline = pip};

    }

    pub fn draw(self: *Renderer, window: *wind.Window) void {

        _ = self;
        _ = window;

    }


    pub fn deinit(self: *Renderer) void{
            _ = self;
    }

};
