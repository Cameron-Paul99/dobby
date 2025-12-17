const std = @import("std");
const print = std.debug.print;
const sdl = @import("sdl.zig");
const core_mod = @import("core.zig");
const swapchain_mod = @import("swapchain_bundle.zig");
//const renderer = @import("renderer.zig");

pub fn main() !void {
    
    var window = try sdl.Window.init(800, 600);
    defer window.deinit();
    
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var core = try core_mod.Core.init(true, allocator, &window);
    defer core.deinit(allocator);

    var sc = try swapchain_mod.Swapchain.init(allocator, 
        core.device.handle, 
        core.physical_device.handle, 
        core.physical_device.surface,
        core.physical_device.graphics_queue_family,
        core.physical_device.present_queue_family,
        core.alloc_cb,
        800,
        600,
        .{.vsync = false, .triple_buffer = false},
        null);

    defer sc.deinit(allocator, core.device.handle, core.alloc_cb);

    while (!window.should_close){
        window.pollEvents();
        std.Thread.sleep(16 * std.time.ns_per_ms);
    }

}
