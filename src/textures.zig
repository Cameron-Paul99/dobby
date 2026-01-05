const std = @import("std");
const c = @import("clibs.zig").c;
const helper = @import("helper.zig");
const core_mod = @import("core.zig");

pub const TextureId = u32;

pub const TextureManager = struct {
    vma: c.VmaAllocator,
    device: c.VkDevice,
    textures: std.ArrayList(AllocatedImage),
    textures_by_name: std.StringHashMap(TextureId),
    // plus sampler presets or references
};

pub fn CreateTextureImage() void{


}
