const std = @import("std");
const c = @import("clibs.zig").c;
const render = @import("render.zig");
const core_mod = @import("core.zig");
const sc = @import("swapchain.zig");

pub const Window = struct {

    window: ?*c.SDL_Window,
    screen_width: c_int,
    screen_height: c_int,
    alloc_cb: ?*c.VkAllocationCallbacks = null,
    should_close: bool,

    pub fn init(width: c_int, height: c_int) !Window {

        if (!c.SDL_Init(c.SDL_INIT_VIDEO)){

            std.log.err("SDL_Init failed: {s}", .{c.SDL_GetError()});
            return error.FailedToInitSDL;

        }

        const flags = c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE;

        const window = c.SDL_CreateWindow(
            "Dobby",
             width,
             height,
             flags,
        ) orelse {
            std.log.err("SDL_CreateWindow failed: {s}", .{c.SDL_GetError()});
            return error.FailedToCreateWindow;

        };

        return Window {
            .window = window,
            .screen_width = width,
            .screen_height = height,
            .alloc_cb = null,
            .should_close = false
        };

    }

    pub fn pollEvents(
        self: *Window,
        renderer: *render.Renderer, 
    ) void {

        var evt: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&evt)) {

            switch (evt.type) {
                c.SDL_EVENT_QUIT => self.should_close = true,
                c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => self.should_close = true,
                c.SDL_EVENT_KEY_DOWN => std.debug.print("Key pressed event\n", .{}),
                c.SDL_EVENT_KEY_UP => std.debug.print("Key released event\n", .{}),
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => std.debug.print("Mouse button pressed\n", .{}),
                c.SDL_EVENT_MOUSE_BUTTON_UP => std.debug.print("Mouse button released\n", .{}),
                c.SDL_EVENT_MOUSE_MOTION => std.debug.print("Mouse moved\n", .{}),
                c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {

                    if (renderer.renderer_init){
                        renderer.request_swapchain_recreate = true;
                    }else{
                        renderer.renderer_init = true;
                    }
                },
                else => std.debug.print("Other SDL event: {}\n", .{evt.type}),
            } 
        
        }

    }

    pub fn deinit(self: *Window) void {
        if (self.window) |w| {
            c.SDL_DestroyWindow(w);
            self.window = null;
        }
    }

};
