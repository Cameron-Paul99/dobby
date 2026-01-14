const std = @import("std");


// GOAL is to cook png files and then add to renderer
pub fn main() void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = allocator;

    std.log.info("asset cooker has started", .{});

   // while(true) {
      //  try cookShaders();
      //  try cookTextures();

    //    std.time.sleep(300 * std.time.ns_per_ms);
    //}

}

fn cookShaders() void {

}

fn cookTextures() void {



}
