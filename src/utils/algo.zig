const std = @import("std");

pub fn PrefixSum(
    counts: []const u16,
    allocator: std.mem.Allocator) ![]u32 {

    var offsets = try allocator.alloc(u32, counts.len);

    var sum: u32 = 0;
    for(counts, 0..) | c, i | {
        offsets[i] = sum;
        sum += c;
    }

    return offsets;
}


