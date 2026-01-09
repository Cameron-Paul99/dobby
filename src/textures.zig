const std = @import("std");
const c = @import("clibs.zig").c;
const helper = @import("helper.zig");
const core_mod = @import("core.zig");
const render = @import("render.zig");

pub const TextureId_u32 = u32;

pub const TextureManager = struct {
    textures: std.ArrayList(helper.AllocatedImage),
    textures_by_name: std.StringHashMap(TextureId_u32),
    // plus sampler presets or references
    pub fn AddTexture(
        self: *TextureManager, 
        texture_name: []const u8,
        texture: helper.AllocatedImage,
        allocator: std.mem.Allocator,
    )!TextureId_u32{

        const texture_id: TextureId_u32 = @intCast(self.textures.items.len);

        try self.textures.append(allocator, texture);

        try self.textures_by_name.put(texture_name, texture_id);

        return texture_id;
    }
    pub fn GetTextureByName(
        self: *TextureManager,
        name: []const u8,
    ) ?*helper.AllocatedImage {
        const id = self.textures_by_name.get(name) orelse return null;
        return &self.textures.items[@intCast(id)];
    }

    pub fn init(allocator: std.mem.Allocator) !TextureManager {
        return .{
            .textures = try std.ArrayList(helper.AllocatedImage).initCapacity(allocator, 0),
            .textures_by_name = std.StringHashMap(TextureId_u32).init(allocator),
        };
    }

    pub fn deinit(self: *TextureManager, allocator: std.mem.Allocator) void {
        self.textures.deinit(allocator);
        self.textures_by_name.deinit();
    }

  };


pub fn CreateTextureImage(
    name: []const u8,
    renderer: *render.Renderer,
    core: *core_mod.Core,
    allocator: std.mem.Allocator,
    color_space: helper.KtxColorSpace,
    path_z: [:0]const u8 ) !void{

    var tex2: ?*c.ktxTexture2 = null;
    const create_flags: c.ktxTextureCreateFlags = c.KTX_TEXTURE_CREATE_LOAD_IMAGE_DATA_BIT;
    const rc0 = c.ktxTexture2_CreateFromNamedFile(path_z, create_flags, &tex2);

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

    const data_size: c.VkDeviceSize = @as(c.VkDeviceSize, @intCast(tex2.?.dataSize));
    const src_ptr: [*]const u8 = @ptrCast(tex2.?.pData);

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

    _ = try renderer.texture_manager.AddTexture(
        name, 
        texture_image, 
        allocator
    );
    
    try helper.TransitionImageLayout(renderer, core, &texture_image, c.VK_IMAGE_LAYOUT_UNDEFINED, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

    try helper.CopyBufferToImage(core, renderer, &texture_image, &staging_buffer);

    try helper.TransitionImageLayout(renderer, core, &texture_image,  c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

}

pub fn CreateTextureImageView(core: *core_mod.Core, renderer: *render.Renderer, name: []const u8) !void{

    const allocated_image = renderer.texture_manager.GetTextureByName(name);

    allocated_image.?.view = try helper.CreateImageView(
        core.device.handle,
        allocated_image.?.image,
        allocated_image.?.format,
        c.VK_IMAGE_ASPECT_COLOR_BIT,
        core.alloc_cb,
    );
}
