const std = @import("std");
const print = std.debug.print;
const sdl = @import("sdl.zig");
const renderer = @import("renderer.zig");

pub fn main() !void {
    
    var window = try sdl.Window.init(800, 600);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var vulkanRenderer = try renderer.Renderer.init(allocator, &window);
    defer vulkanRenderer.deinit();

    while (!window.should_close){
        window.pollEvents();
        std.Thread.sleep(16 * std.time.ns_per_ms);
    }

    window.deinit();

}
