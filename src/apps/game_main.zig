const std = @import("std");
const engine = @import("engine");

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game_window = try engine.sdl.Window.init(800, 600);
    defer game_window.deinit();

    var core = try engine.core.Core.init(true, allocator, &game_window);
    defer core.deinit(allocator);

    var swapchain = try engine.swapchain.Swapchain.init(allocator, &core, &game_window, .{.vsync = false}, null);
    defer swapchain.deinit(&core, allocator, core.alloc_cb);

    var renderer = try engine.renderer.Renderer.init(allocator, &core, &swapchain, &game_window);
    defer renderer.deinit(allocator, &core);

    while (!game_window.should_close){
        
        game_window.pollEvents(&renderer);

    }


}
