const pipeline = @import("pipeline.zig");
const device = @import("device.zig");
const instance = @import("instance.zig");
const std = @import("std");
const window = @import("../platform/x11.zig");

pub const Renderer = struct {
    
    //instance: instance.Instance,
    //device: device.Device,
    //pipeline: pipeline.Pipeline,

    pub fn init(allocator: *const std.mem.Allocator, wind: *window.Window) !Renderer{
        
           //const inst = try instance.create(allocator, wind);
          //  dev = try device.create(inst, allocator),
            //pip = try pipeline.create( inst , dev, allocator),

          _ = allocator;
          _ = wind;

            return Renderer {}; //.device = dev, .pipeline = pip};

    }

    pub fn draw(self: *Renderer, wind: *window.Window) void {

        _ = self;
        _ = wind;

    }


    pub fn deinit(self: *Renderer) void{
            _ = self;
    }



};
