const std = @import("std");
const window = @import("../platform/x11.zig");

pub const Instance = struct {
    
    pub fn create(allocator: *const std.mem.Allocator, wind: *window.Window) !Instance{
       _ = allocator;
       _ = wind;

       return Instance{};

    }

    


};
