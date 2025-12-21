pub const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
    @cInclude("vulkan/vulkan.h");
    @cInclude("vk_mem_alloc.h");
});



pub const SDL = struct {
    pub const Window = c.SDL_Window;
    pub const Event = c.SDL_Event;
    pub const Bool = c.SDL_bool;

    pub const CreateWindow = c.SDL_CreateWindow;
    pub const DestroyWindow = c.SDL_DestroyWindow;
    pub const GetError = c.SDL_GetError;
    pub const GetWindowSize = c.SDL_GetWindowSize;
    pub const Init = c.SDL_Init;
    pub const PollEvent = c.SDL_PollEvent;
    pub const Quit = c.SDL_Quit;
    pub const SetWindowTitle = c.SDL_SetWindowTitle;
    pub const ShowWindow = c.SDL_ShowWindow;
    pub const Vulkan_CreateSurface = c.SDL_Vulkan_CreateSurface;
    pub const Vulkan_GetInstanceExtensions = c.SDL_Vulkan_GetInstanceExtensions;
    pub const Vulkan_GetVkGetInstanceProcAddr = c.SDL_Vulkan_GetVkGetInstanceProcAddr;

    pub const EVENT_KEY_DOWN = c.SDL_EVENT_KEY_DOWN;
    pub const EVENT_KEY_UP = c.SDL_EVENT_KEY_UP;
    pub const EVENT_QUIT = c.SDL_EVENT_QUIT;
    pub const EVENT_WINDOW_MAXIMIZED = c.SDL_EVENT_WINDOW_MAXIMIZED;
    pub const EVENT_WINDOW_MINIMIZED = c.SDL_EVENT_WINDOW_MINIMIZED;
    pub const EVENT_WINDOW_RESIZED = c.SDL_EVENT_WINDOW_RESIZED;
    pub const FALSE = c.SDL_FALSE;
    pub const INIT_VIDEO = c.SDL_INIT_VIDEO;
    pub const SCANCODE_A = c.SDL_SCANCODE_A;
    pub const SCANCODE_D = c.SDL_SCANCODE_D;
    pub const SCANCODE_E = c.SDL_SCANCODE_E;
    pub const SCANCODE_ESCAPE = c.SDL_SCANCODE_ESCAPE;
    pub const SCANCODE_M = c.SDL_SCANCODE_M;
    pub const SCANCODE_Q = c.SDL_SCANCODE_Q;
    pub const SCANCODE_S = c.SDL_SCANCODE_S;
    pub const SCANCODE_SPACE = c.SDL_SCANCODE_SPACE;
    pub const SCANCODE_W = c.SDL_SCANCODE_W;
    pub const TRUE = c.SDL_TRUE;
    pub const WINDOW_FULLSCREEN = c.SDL_WINDOW_FULLSCREEN;
    pub const WINDOW_RESIZABLE = c.SDL_WINDOW_RESIZABLE;
    pub const WINDOW_VULKAN = c.SDL_WINDOW_VULKAN;
};
