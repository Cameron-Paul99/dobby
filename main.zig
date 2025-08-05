const std = @import("std");
const print = std.debug.print;
const x11 = @import("platform/x11.zig");
const renderer = @import("rendering/renderer.zig");

pub fn main() !void {
    
    var window = try x11.Window.init(800, 600);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var vulkanRenderer = try renderer.Renderer.init(&allocator, &window);
    defer vulkanRenderer.deinit();

    while (true){
        window.pollEvents();
        std.time.sleep(16 * std.time.ns_per_ms);
    }

    window.deinit();

}
