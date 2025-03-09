const std = @import("std");
const Chip8Context = @import("chip8_context.zig").Chip8Context;
const Chip8 = @import("chip8.zig").Chip8;

const testing = std.testing;

pub fn main() !void {
    var ctx = Chip8Context.initContext();
    defer ctx.deinit();
    try Chip8.loadRom(&ctx);
    var chip8 = Chip8{ .ctx = &ctx };

    const emulator_running = true;
    var start_time: i64 = 0;
    var end_time: i64 = 0;
    var time_accumulated = 0;
    const target_frame_time = 1_000_000 / 60; // 60Hz

    while (emulator_running) {
        const delta_time = end_time - start_time;
        start_time = std.time.microTimestamp();
        time_accumulated += delta_time;
        if (time_accumulated > target_frame_time) {
            chip8.execute();
            time_accumulated = 0;
        }
        end_time = std.time.microTimestamp();
    }
}
