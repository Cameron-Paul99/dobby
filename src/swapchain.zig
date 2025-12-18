const std = @import("std");
const c = @import("clibs.zig").c;
const sdl = @import("sdl.zig");
const helper = @import("helper.zig");
const core = @import("core.zig");
const log = std.log;

pub const SwapchainConfig = struct {
    vsync: bool = false,
    triple_buffer: bool = false,
};

pub const SwapchainDevice = struct{
    device: c.VkDevice = null,
    physical_device: c.VkPhysicalDevice = null,
    surface: c.VkSurfaceKHR = undefined,
    graphics_qfi: u32 = helper.INVALID,
    present_qfi: u32 = helper.INVALID, 
};

    // The Creation of a Swapchain
pub const Swapchain = struct {
    handle: c.VkSwapchainKHR = null,
    images: []c.VkImage = &.{},
    views: []c.VkImageView = &.{},
    extent: c.VkExtent2D = .{ .width = 0, .height = 0 },
    format: c.VkFormat = c.VK_FORMAT_UNDEFINED,
    swapchain_device: SwapchainDevice = .{},
    config: SwapchainConfig = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        alloc_cb: ?*c.VkAllocationCallbacks,
        window_width: u32,
        window_height: u32,
        sc_d: SwapchainDevice,
        config: SwapchainConfig,
        old: c.VkSwapchainKHR,
    ) !Swapchain {

        var self: Swapchain = .{};
        self.config = config;

        const support = try helper.SwapchainSupportInfo.init(allocator, sc_d.physical_device, sc_d.surface);
        defer support.deinit(allocator);

        self.format = helper.PickSwapchainFormat(support.formats);
        const present_mode = helper.PickSwapchainPresentMode(config, support.present_modes);

        // IMPORTANT: extent needs window size inputs, not stored forever in the swapchain struct
        self.extent = helper.MakeSwapchainExtent(support.capabilities, window_width, window_height);

        var ci = std.mem.zeroInit(c.VkSwapchainCreateInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = sc_d.surface,
            .minImageCount = support.capabilities.minImageCount + 1,
            .imageFormat = self.format,
            .imageColorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            .imageExtent = self.extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .preTransform = support.capabilities.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = present_mode,
            .clipped = c.VK_TRUE,
            .oldSwapchain = old,
        });

        var qfis = [_]u32{ sc_d.graphics_qfi, sc_d.present_qfi };
        if (sc_d.graphics_qfi != sc_d.present_qfi) {
            ci.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
            ci.queueFamilyIndexCount = 2;
            ci.pQueueFamilyIndices = &qfis;
        } else {
            ci.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        }

        try helper.check_vk(c.vkCreateSwapchainKHR(sc_d.device, &ci, alloc_cb, &self.handle));
        errdefer self.deinit(allocator, sc_d.device, alloc_cb);

        var count: u32 = 0;
        try helper.check_vk(c.vkGetSwapchainImagesKHR(sc_d.device, self.handle, &count, null));

        self.images = try allocator.alloc(c.VkImage, count);
        errdefer allocator.free(self.images);
        try helper.check_vk(c.vkGetSwapchainImagesKHR(sc_d.device, self.handle, &count, self.images.ptr));

        self.views = try allocator.alloc(c.VkImageView, count);
        errdefer allocator.free(self.views);

        for (self.images, self.views) |img, *view| {
            view.* = try helper.CreateImageView(sc_d.device, img, self.format, c.VK_IMAGE_ASPECT_COLOR_BIT, alloc_cb);
        }

        return self;
    }

    pub fn deinit(self: *Swapchain, allocator: std.mem.Allocator, device: c.VkDevice, alloc_cb: ?*c.VkAllocationCallbacks) void {
        for (self.views) |view| {
            if (view != null) c.vkDestroyImageView(device, view, alloc_cb);
        }
        if (self.views.len != 0) allocator.free(self.views);
        if (self.images.len != 0) allocator.free(self.images);

        if (self.handle != null) c.vkDestroySwapchainKHR(device, self.handle, alloc_cb);

        self.* = .{};
    }
};









