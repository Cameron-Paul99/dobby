const std = @import("std");
const c = @import("clibs.zig").c;
const render = @import("render.zig");
const core_mod = @import("core.zig");
const sc = @import("swapchain.zig");
const input = @import("controls.zig");
const math = @import("utils").math;

pub const Window = struct {

    window: ?*c.SDL_Window,
    screen_width: c_int,
    screen_height: c_int,
    alloc_cb: ?*c.VkAllocationCallbacks = null,
    raw_input: input.RawInput = input.RawInput{},
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

        self.raw_input.buttons_pressed = 0;
        self.raw_input.mouse_delta = math.Vec2.ZERO;
        self.raw_input.scroll = 0.0;

        var evt: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&evt)) {

            switch (evt.type) {
                c.SDL_EVENT_QUIT => self.should_close = true,
                c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => self.should_close = true,
                c.SDL_EVENT_KEY_DOWN => _ = input.MapSDLScancode(evt.key.scancode),
                c.SDL_EVENT_KEY_UP =>_ = input.MapSDLScancode(evt.key.scancode) ,
                c.SDL_EVENT_MOUSE_WHEEL=> {
                  
                    self.raw_input.scroll = evt.wheel.y; // zoom in
                    std.debug.print("Scrolling\n", .{});
                    
                },
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => {

                    if (input.MapSDLMouseButton(evt.button.button)) |key| {
                        const m = input.Bit(key);
                        if ((self.raw_input.buttons_down & m) == 0) {

                            self.raw_input.buttons_pressed |= m;

                        }
                        self.raw_input.buttons_down |= m;

                        std.debug.print("Mouse {s} DOWN\n", .{@tagName(key)});
                    }
                },

                c.SDL_EVENT_MOUSE_BUTTON_UP => {

                    if (input.MapSDLMouseButton(evt.button.button)) |key| {
                        self.raw_input.buttons_down &= ~input.Bit(key);
                        std.debug.print("Mouse {s} UP\n", .{@tagName(key)});
                    }

                },
                c.SDL_EVENT_MOUSE_MOTION => {

                    self.raw_input.mouse_pos = .{
                        .x = evt.motion.x,
                        .y = evt.motion.y,
                    };

                    self.raw_input.mouse_delta.x += evt.motion.xrel;
                    self.raw_input.mouse_delta.y += evt.motion.yrel;

                    std.debug.print("Mouse moved\n", .{});

                },
                c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                     var drawable_w: c_int = 0;
                     var drawable_h: c_int = 0;
                    _ = c.SDL_GetWindowSizeInPixels(self.window, &drawable_w, &drawable_h);
                    self.screen_width = drawable_w;
                    self.screen_height = drawable_h; 
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
