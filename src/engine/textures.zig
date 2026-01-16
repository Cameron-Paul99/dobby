const std = @import("std");
const c = @import("clibs.zig").c;
const helper = @import("helper.zig");
const core_mod = @import("core.zig");
const render = @import("render.zig");
const log = std.log;

pub Atlas = struct {
    width: u32,
    height: u32,
    pixels: []u8,
    cursor_x: u32 = 0,
    cursor_y: u32 = 0,
    row_h: u32 = 0,
    pub fn init(allocator: std.mem.Allocator) !void{
        try allocator.alloc(u8, width * height * 4);
        @memset(atlas.pixels, 0); 
    };
}



pub fn CreateTextureImage(
    renderer: *render.Renderer,
    core: *core_mod.Core,
    allocator: std.mem.Allocator,
    color_space: helper.KtxColorSpace,
    path_z: [:0]const u8 ) !helper.AllocatedImage{

    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);

    const full_path_z = try std.fs.path.joinZ(allocator, &.{ exe_dir, "..", path_z }); 
    defer allocator.free(full_path_z);

    var tex2: ?*c.ktxTexture2 = null;
    const create_flags: c.ktxTextureCreateFlags = c.KTX_TEXTURE_CREATE_LOAD_IMAGE_DATA_BIT;
    const rc0 = c.ktxTexture2_CreateFromNamedFile(full_path_z, create_flags, &tex2);

    if (rc0 != c.KTX_SUCCESS or tex2 == null) return error.KtxLoadFailed;
    const base_tex: [*c]c.ktxTexture = @ptrCast(tex2.?);
    defer {
        if (base_tex.*.vtbl) |vtbl| {
            if (vtbl.*.Destroy) |destroy_fn| {
                destroy_fn(base_tex);
            }
        }
    }

    const choice = helper.ChooseTranscodeFormat(color_space);

    if (c.ktxTexture2_NeedsTranscoding(tex2.?)){
        const rcT = c.ktxTexture2_TranscodeBasis(tex2.?, choice.ktx_fmt, 0);
        if (rcT != c.KTX_SUCCESS) return error.KtxTranscodeFailed;
    }

    const base_w: u32 = @intCast(tex2.?.baseWidth);
    const base_h: u32 = @intCast(tex2.?.baseHeight);
    const mip_levels: u32 = @intCast(tex2.?.numLevels);

    _ = mip_levels;

    const extent: c.VkExtent3D = .{.width = base_w, .height = base_h, .depth = 1};


    var offset: usize = 0;
    var level0_size: usize = 0;

    if (base_tex.*.vtbl) |vtbl| {
        // GetImageOffset
        const get_off_fn = vtbl.*.GetImageOffset orelse return error.KtxLoadFailed;
        const rc_off = get_off_fn(base_tex, 0, 0, 0, &offset);
        if (rc_off != c.KTX_SUCCESS) return error.KtxLoadFailed;

        // GetImageSize
        const get_size_fn = vtbl.*.GetImageSize orelse return error.KtxLoadFailed;
        level0_size = get_size_fn(base_tex, 0);

    } else {
        return error.KtxLoadFailed;
    }

    const data_size: c.VkDeviceSize = @as(c.VkDeviceSize, @intCast(level0_size));
    const src_ptr: [*]const u8 = @ptrCast(tex2.?.pData + offset);

    var staging_buffer = try helper.CreateBuffer(
        renderer.vma,
        data_size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VMA_MEMORY_USAGE_AUTO,
        c.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT | c.VMA_ALLOCATION_CREATE_MAPPED_BIT,
    );

    defer helper.DestroyBuffer(renderer.vma, &staging_buffer);

    var mapped: ?*anyopaque = null;
    _ = c.vmaMapMemory(renderer.vma, staging_buffer.allocation, &mapped);
    defer c.vmaUnmapMemory(renderer.vma, staging_buffer.allocation);
    @memcpy( @as( [*]u8 , @ptrCast(mapped.?))[0..data_size], src_ptr[0..data_size]);

    var texture_image = try helper.CreateImage(
        renderer.vma,
        extent,
        choice.vk_fmt,
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        helper.ImageMemoryClass.gpu_only,
    );

    
    try helper.TransitionImageLayout(renderer, core, &texture_image, c.VK_IMAGE_LAYOUT_UNDEFINED, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

    try helper.CopyBufferToImage(core, renderer, &texture_image, &staging_buffer);

    try helper.TransitionImageLayout(renderer, core, &texture_image,  c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

     log.info("Created Textures", .{});
     return texture_image;
}

pub fn CreateTextureImageView(core: *core_mod.Core, allocated_image: *helper.AllocatedImage) !void{

    allocated_image.view = try helper.CreateImageView(
        core.device.handle,
        allocated_image.image,
        allocated_image.format,
        c.VK_IMAGE_ASPECT_COLOR_BIT,
        core.alloc_cb,
    );
}
