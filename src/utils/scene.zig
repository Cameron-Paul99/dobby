const std = @import("std");
const Self = @This();
const log = std.log.scoped(.scene);

pub const IndexRange = struct {
    offset: u32 = 0,
    count: u32 = 0,
};
pub const SceneId_u32 = u32;

pub const Scene = struct {
    scene_index: u32 = 0,
    atlas_aliases: IndexRange = .{},
    connected_scenes: IndexRange = .{},
};

    scenes: std.ArrayList(Scene),
    atlas_alias_table: std.ArrayList(u32),
    scene_connection_table: std.ArrayList(SceneId_u32),

    pub fn MakeScene(
        self: *Self, 
        allocator: std.mem.Allocator,
        alias_ids: []const u32,
        connected_scene_ids: []const SceneId_u32) !void{
        
        // Reserve space
        try self.atlas_alias_table.appendSlice(allocator, alias_ids);
        try self.scene_connection_table.appendSlice(allocator, connected_scene_ids);

        const alias_offset = self.atlas_alias_table.items.len - alias_ids.len;
        const conn_offset  = self.scene_connection_table.items.len - connected_scene_ids.len;
        
        // Make New Scene
        const scene = Scene{
            .scene_index = @intCast(self.scenes.items.len),
            .atlas_aliases = .{
                .offset = @intCast(alias_offset),
                .count = @intCast(alias_ids.len),
            },
            .connected_scenes = .{
                .offset = @intCast(conn_offset),
                .count = @intCast(connected_scene_ids.len),
            },
        };

        try self.scenes.append(allocator, scene);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void{
        self.scenes.deinit(allocator);
        self.atlas_alias_table.deinit(allocator);
        self.scene_connection_table.deinit(allocator);
    }

