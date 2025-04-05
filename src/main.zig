const std = @import("std");
const Chip8Context = @import("chip8_context.zig").Chip8Context;
const Chip8 = @import("chip8.zig").Chip8;
const DisplayDriver = @import("sdl_displaydriver.zig").DisplayDriver;
const testing = std.testing;


pub fn main() !void {
    var display = DisplayDriver {
        .scale = 10,
        .window = null,
        .renderer = null,
        .width = 64,
        .height = 32
    };

    try display.init();
    defer display.deinit();
    display.clearScreen();


    var ctx = try Chip8Context.initContext();
    defer ctx.deinit();

    var args = std.process.args(); 
    _ = args.skip(); //to skip the zig call

    var chip8_logo_rom_path: []const u8 = undefined; 
    if (args.next()) |path| {
        chip8_logo_rom_path = try std.fs.cwd().realpathAlloc(std.heap.page_allocator, path);
        std.debug.print("Path : {s}\n", .{chip8_logo_rom_path});
    }
    else {
        std.debug.print("No path provided!\n", .{});
        std.process.exit(1);
    }

    var chip8 = Chip8{ .ctx = &ctx};
    try chip8.loadRomFromFile(std.heap.page_allocator, chip8_logo_rom_path);
    chip8.loadFont();

    var start_time: i64 = 0;
    var end_time: i64 = 0;
    var time_accumulated: i64 = 0;
    const target_frame_time = 1_000_000 / 60; // 60Hz

    var quit = false;

    while (!quit) {
        const delta_time = end_time - start_time;
        start_time = std.time.microTimestamp();
        time_accumulated += delta_time;
        if (time_accumulated > target_frame_time) {
            display.clearScreen();
            quit = DisplayDriver.handleEvents(&ctx);
            var cycles:u8 = 17;
            while (cycles != 0) {
                try chip8.execute();
                cycles -= 1;
            }

            if (ctx.draw_flag) {
                try display.update(&ctx);
                ctx.draw_flag = false;
            }
            ctx.delay_timer = if (ctx.delay_timer == 0) 0 else ctx.delay_timer - 1;
            ctx.sound_timer = if (ctx.sound_timer == 0) 0 else ctx.sound_timer - 1;
            time_accumulated = 0;
        }
        end_time = std.time.microTimestamp();

    }
}
