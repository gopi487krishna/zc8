const std = @import("std");
const chip8_context = @import("chip8_context.zig");

pub const Chip8 = struct {
    // Running at 60Hz
    const target_frame_time = 1_000_000 / 60;

    fn execute(_: *chip8_context.Chip8Context) !void {
        @compileError("Function not yet implemented");
    }

    pub fn loadRom(_: *chip8_context.Chip8Context) !void {
        @compileError("Function not implemented");
    }

    pub fn run(ctx: *chip8_context.Chip8Context) !void {
        const emulator_running = true;
        var start_time: i64 = 0;
        var end_time: i64 = 0;
        var time_accumulated = 0;

        while (emulator_running) {
            const delta_time = end_time - start_time;
            start_time = std.time.microTimestamp();
            time_accumulated += delta_time;
            if (time_accumulated > target_frame_time) {
                execute(&ctx);
                time_accumulated = 0;
            }
            end_time = std.time.microTimestamp();
        }
    }
};
