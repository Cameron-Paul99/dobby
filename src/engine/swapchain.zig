const std = @import("std");
const c = @import("clibs.zig").c;
const utils = @import("utils");
const helper = @import("helper.zig");
const core_mod = @import("core.zig");
const sdl = @import("sdl.zig");
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
    vma: c.VmaAllocator = undefined,
    swapchain_device: SwapchainDevice = .{},
    config: SwapchainConfig = .{},
    depth_image: helper.AllocatedImage = .{},
    framebuffers: []c.VkFramebuffer = undefined,
    pub fn init(
        allocator: std.mem.Allocator,
        core: *core_mod.Core,
        window: *sdl.Window,
        config: SwapchainConfig,
        old: c.VkSwapchainKHR,
    ) !Swapchain {

        var self: Swapchain = .{};
        self.config = config;

        self.vma = try helper.CreateVMAAllocator(core);

        const support = try helper.SwapchainSupportInfo.init(allocator, core.physical_device.handle, core.physical_device.surface);
        defer support.deinit(allocator);

        self.format = helper.PickSwapchainFormat(support.formats);
        const present_mode = helper.PickSwapchainPresentMode(config, support.present_modes);

        log.info("Present mode: {}", .{present_mode});


        // IMPORTANT: extent needs window size inputs, not stored forever in the swapchain struct
        self.extent = helper.MakeSwapchainExtent(
            support.capabilities, 
            @as(u32, @intCast(window.screen_width)), 
            @as(u32, @intCast(window.screen_height)),
        );

        self.depth_image.format = c.VK_FORMAT_D32_SFLOAT;

        var ci = std.mem.zeroInit(c.VkSwapchainCreateInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = core.physical_device.surface,
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

        var qfis = [_]u32{ core.physical_device.graphics_queue_family, core.physical_device.present_queue_family };
        if (core.physical_device.graphics_queue_family != core.physical_device.present_queue_family) {
            ci.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
            ci.queueFamilyIndexCount = 2;
            ci.pQueueFamilyIndices = &qfis;
        } else {
            ci.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        }

        try helper.check_vk(c.vkCreateSwapchainKHR(core.device.handle, &ci, core.alloc_cb, &self.handle));
        errdefer self.deinit(core, allocator, core.alloc_cb);

        var count: u32 = 0;
        try helper.check_vk(c.vkGetSwapchainImagesKHR(core.device.handle, self.handle, &count, null));

        self.images = try allocator.alloc(c.VkImage, count);
        errdefer allocator.free(self.images);
        try helper.check_vk(c.vkGetSwapchainImagesKHR(core.device.handle, self.handle, &count, self.images.ptr));

        self.views = try allocator.alloc(c.VkImageView, count);
        errdefer allocator.free(self.views);

        for (self.images, self.views) |img, *view| {
            view.* = try helper.CreateImageView(core.device.handle, img, self.format, c.VK_IMAGE_ASPECT_COLOR_BIT, core.alloc_cb);
        }

        self.depth_image = try helper.CreateImage(
            self.vma, 
            .{.width = self.extent.width, .height = self.extent.height, .depth = 1}, 
            c.VK_FORMAT_D32_SFLOAT, 
            c.VK_IMAGE_TILING_OPTIMAL,
            c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            helper.ImageMemoryClass.gpu_only
        );

        self.depth_image.view = try helper.CreateImageView(
            core.device.handle,
            self.depth_image.image,
            self.depth_image.format,
            c.VK_IMAGE_ASPECT_DEPTH_BIT,
            core.alloc_cb,
        );

        return self;
    }

    pub fn deinit(
        self: *Swapchain, 
        core: *core_mod.Core ,
        allocator: std.mem.Allocator, 
        alloc_cb: ?*c.VkAllocationCallbacks) void {

        // 1) framebuffers
        for (self.framebuffers) |fb| {
            if (fb != null) c.vkDestroyFramebuffer(core.device.handle, fb, alloc_cb);
        }

        allocator.free(self.framebuffers);

        for (self.views) |view| {
            if (view != null) c.vkDestroyImageView(core.device.handle, view, alloc_cb);
        }
        helper.DestroyImage(core, self.vma, &self.depth_image);

        if (self.views.len != 0) allocator.free(self.views);
        if (self.images.len != 0) allocator.free(self.images);

        if (self.vma != null){
            c.vmaDestroyAllocator(self.vma);
        }

        if (self.handle != null) c.vkDestroySwapchainKHR(core.device.handle, self.handle, alloc_cb);

        self.* = .{};
    }
};

pub fn CreateRenderPass(sc: *Swapchain, device: c.VkDevice, alloc_cb: ?*c.VkAllocationCallbacks ) !c.VkRenderPass{

    var render_pass: c.VkRenderPass = helper.VK_NULL_HANDLE;
    
    // Color Attachment
    const color_attachment = std.mem.zeroInit(c.VkAttachmentDescription, .{
        .format = sc.format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    });

    const color_attachment_ref = std.mem.zeroInit(c.VkAttachmentReference, .{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    });


    // Depth Attachment
    const depth_attachment = std.mem.zeroInit(c.VkAttachmentDescription, .{
        .format = sc.depth_image.format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    });

    const depth_attachment_ref = std.mem.zeroInit(c.VkAttachmentReference, .{
        .attachment = 1,
        .layout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    });

    //_ = depth_attachment_ref;
    //_ = depth_attachment;

    // Subpass
    const subpass = std.mem.zeroInit(c.VkSubpassDescription, .{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,
        .pDepthStencilAttachment = &depth_attachment_ref,
        //.pDepthStencilAttachment = null,
    });

    const attachment_descriptions = [_]c.VkAttachmentDescription{
        color_attachment,
        depth_attachment,
    };

    // Subpass color and depth dependencies
    const color_dependency = std.mem.zeroInit(c.VkSubpassDependency, .{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
    });

    const depth_dependency = std.mem.zeroInit(c.VkSubpassDependency, .{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
        .srcAccessMask = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
        .dstAccessMask = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
    });

    //_ = depth_dependency;

    const dependencies = [_]c.VkSubpassDependency{
        color_dependency,
        depth_dependency,
    };

    const render_pass_create_info = std.mem.zeroInit(c.VkRenderPassCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = @as(u32, @intCast(attachment_descriptions.len)),
        .pAttachments = attachment_descriptions[0..].ptr,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = @as(u32, @intCast(dependencies.len)),
        .pDependencies = &dependencies[0],
    });

    try helper.check_vk(c.vkCreateRenderPass(device, &render_pass_create_info, alloc_cb, &render_pass));


    return render_pass;

}

pub fn CreateFrameBuffers(
    device: c.VkDevice, 
    sc: *Swapchain ,
    render_pass: c.VkRenderPass, 
    allocator: std.mem.Allocator, alloc_cb: ?*c.VkAllocationCallbacks) void {
    
    var framebuffer_ci = std.mem.zeroInit(c.VkFramebufferCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        .renderPass = render_pass,
        .attachmentCount = 2,
        .width = sc.extent.width,
        .height = sc.extent.height,
        .layers = 1,
    });

    sc.framebuffers = allocator.alloc(c.VkFramebuffer, sc.views.len) catch @panic("Out of memory");

    for (sc.views, sc.framebuffers) |view, *framebuffer| {

        const attachments = [2]c.VkImageView{
            view,
            sc.depth_image.view,
        };
        framebuffer_ci.pAttachments = &attachments[0];
        helper.check_vk(c.vkCreateFramebuffer(device, &framebuffer_ci, alloc_cb, framebuffer))
            catch @panic("Failed to create framebuffer");

    }

    log.info("Created {} framebuffers", .{ sc.framebuffers.len });

}








