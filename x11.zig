const std = @import("std");
const c = @import("clibs.zig").c;

pub const WindowBackend = enum {
    x11,
    wayland,
    win32,
    win64,
    macos,
};


pub const Window = struct {
    backend: WindowBackend,
    display: *c.Display,
    screen : c_int,
    screen_width: c_int,
    screen_height: c_int,
    window: c.Window,
    alloc_cb: ?*c.VkAllocationCallbacks = undefined,

    pub fn init(width: c_int, height: c_int) !Window {

        // Window values
        const display = c.XOpenDisplay(null) orelse return error.FailedToOpenDisplay;

        const screen = c.XDefaultScreen(display);
        const screen_ptr = c.XDefaultScreenOfDisplay(display);

        const screen_width = c.WidthOfScreen(screen_ptr);
        const screen_height = c.HeightOfScreen(screen_ptr);
        
        // Creating window
        const window = c.XCreateSimpleWindow(
            display,
            c.XRootWindow(display, screen),
            10, 
            10, 
            @intCast(width), 
            @intCast(height), 
            1,
            c.XWhitePixel(display, screen),
            c.XBlackPixel(display, screen),
        );

        // Display input
       _ = c.XSelectInput(
            display, 
            window, 
            c.ExposureMask | 
            c.KeyPressMask | 
            c.ButtonPressMask | 
            c.PointerMotionMask |
            c.ButtonReleaseMask);
        
        // Maping window to display
        _ = c.XMapWindow(display, window);

        return Window {
            .display = display,
            .screen = screen,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .window = window,
            .backend = WindowBackend.x11,
        };
    }

    pub fn pollEvents(self: *Window) void {

        var evt:c.XEvent = undefined;

        while(c.XPending(self.display) > 0){

            _ = c.XNextEvent(self.display, &evt);

            switch(evt.type){
                c.Expose => std.debug.print("Expose event\n", .{}),
                c.KeyPress => std.debug.print("Key pressed event\n", .{}),
                c.KeyRelease => std.debug.print("Key released event\n", .{}),
                c.ButtonPress => std.debug.print("Mouse button pressed\n", .{}),
                c.ButtonRelease => std.debug.print("Mouse button released\n", .{}),
                c.MotionNotify => std.debug.print("Mouse moved\n", .{}),
                c.EnterNotify => std.debug.print("Mouse entered window\n", .{}),
                c.LeaveNotify => std.debug.print("Mouse left window\n", .{}),
                c.FocusIn => std.debug.print("Window focus in\n", .{}),
                c.FocusOut => std.debug.print("Window focus out\n", .{}),
                c.DestroyNotify => std.debug.print("Window destroy event\n", .{}),
                else => std.debug.print("Other event: {}\n", .{evt.type}),
            }
        }
    }

    pub fn deinit(self: *Window) void {
        
        _ = c.XDestroyWindow(self.display, self.window);
        _ = c.XCloseDisplay(self.display);
    
    }
};
