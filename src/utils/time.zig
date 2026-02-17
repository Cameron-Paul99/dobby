const std = @import("std");
const Self = @This();

start_time: i128,
paused_ns_time: i128,
paused_start_ns: i128,
paused_ns_total: i128 = 0.0,
pause: bool = true,
time_sec: f64 = 0,

pub fn Start() Self{
    return .{
         .start_time = std.time.nanoTimestamp(),
         .paused_ns_time = 0,
         .paused_start_ns = 0,
    };
}

pub fn PauseCal(self: *Self) void {
    if (self.pause){
        self.pause = false;
        self.paused_start_ns = std.time.nanoTimestamp();

    }else{
        self.pause = true;
        self.paused_ns_total += std.time.nanoTimestamp() - self.paused_start_ns;
    }
}

pub fn Runnin(self: *Self) void {
    const now = std.time.nanoTimestamp();
    const effective_ns = now - self.start_time - self.paused_ns_total;
    self.time_sec = @as(f64, @floatFromInt(effective_ns)) / 1_000_000_000.0;
}
