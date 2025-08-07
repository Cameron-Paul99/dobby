
const c = @import("clibs.zig");
const vulkanInstance = @import("instance.zig");
const std = @import("std");
const window = @import("../platform/x11.zig");

pub const Renderer = struct {
    
    instance: vulkanInstance.Instance,
    //device: device.Device,
    //pipeline: pipeline.Pipeline,

    pub fn init(allocator: *const std.mem.Allocator, wind: *window.Window) !Renderer{
       
        _ = allocator;

           const inst = try vulkanInstance.Instance.create( null, wind);
          //  dev = try device.create(inst, allocator),
            //pip = try pipeline.create( inst , dev, allocator),

         // _ = allocator;
        //  _ = wind;

            return Renderer {.instance = inst}; //.device = dev, .pipeline = pip};

    }

    pub fn draw(self: *Renderer, wind: *window.Window) void {

        _ = self;
        _ = wind;

    }


    pub fn deinit(self: *Renderer) void{
            _ = self;
    }

};
