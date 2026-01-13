const std = @import("std");


// GOAL is to cook png files and then add to renderer
pub fn main() void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = allocator;

    std.log.info("asset cooker has started", .{});


    


}
