const std = @import("std");
const Self = @This();
const atlas_mod = @import("atlas.zig");
const log = std.log.scoped(.scene);
// Opaque = 0
// Alpha = 1
// UI = 2

// INVARIANTS:
// 1. atlases.json is sorted by id
// 2. atlas_list is always sorted by id
// 3. IDs are stable and never renumbered
// 4. Editor never invents IDs
//

    atlas_list: std.ArrayList(atlas_mod.AtlasAsset),
    metadata_dirty: bool = false,
    manifest: ?atlas_mod.ParsedManifest = null,
    desired: []const atlas_mod.AtlasEntry,
    

    pub fn ApplyMetadata(self: *Self, allocator: std.mem.Allocator) !usize{

        var i: usize = 0; // current
        var j: usize = 0; // desired
       
        while (i < self.atlas_list.items.len or j < self.desired.len) {
            
            self.RemoveAtlas(&i, &j, allocator);
            try self.AddAtlas(&i, &j, allocator);
            self.SameAtlas(&i, &j);

        }

        return self.atlas_list.items.len;

    }

    pub fn RemoveAtlas(self: *Self, i: *usize, j: *usize, allocator: std.mem.Allocator) void{

        if (i.* < self.atlas_list.items.len and (j.* >= self.desired.len or self.atlas_list.items[i.*].id < self.desired[j.*].id))
        {
                allocator.free(self.atlas_list.items[i.*].path);
                _ = self.atlas_list.orderedRemove(i.*); 
        }

    }

    pub fn AddAtlas(self: *Self, i: *usize, j: *usize, allocator: std.mem.Allocator) !void {
            
            if (j.* < self.desired.len and (i.* >= self.atlas_list.items.len or self.desired[j.*].id < self.atlas_list.items[i.*].id))
            {  
                const meta = self.desired[j.*];

                const owned_path = try allocator.dupe(u8, meta.path);

                const atlas = atlas_mod.AtlasAsset{
                    .id = meta.id,
                    .path = owned_path,
                    .version_hash = meta.rev,
                };
                try self.atlas_list.append(allocator, atlas);

                j.* += 1;
            }

    }

    pub fn SameAtlas(self: *Self, i: *usize, j: *usize) void {

        if (self.atlas_list.items[i.*].id == self.desired[j.*].id) {

            if (self.atlas_list.items[i.*].version_hash != self.desired[j.*].rev) {
                self.atlas_list.items[i.*].version_hash = self.desired[j.*].rev;
            }

            i.* += 1;
            j.* += 1;
        }

    }
    

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void{

        if (self.manifest) |*manifest| {
            manifest.deinit(allocator);
        }
        self.manifest = null;
        self.atlas_list.deinit(allocator);
        allocator.free(self.desired);

    }

