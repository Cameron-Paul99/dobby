pub usingnamespace @cImport({
    @cDefine("VK_USE_PLATFORM_XLIB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
    @cInclude("vulkan/vulkan_xlib.h");
    @cInclude("X11/Xlib.h");
   // @cInclude("vk_mem_alloc.h");
  //  @cInclude("stb_image.h");
   // @cInclude("cimgui.h");
   // @cInclude("cimgui_impl_vulkan.h");
   // @cInclude("cimgui_impl_sdl3.h");
});




