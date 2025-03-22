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

    const test_roms_dir: []const u8 = @import("build_options").test_roms_dir;
    // const chip8_logo_rom_path = test_roms_dir ++ "/chip8-logo.ch8";
    // const chip8_logo_rom_path = test_roms_dir ++ "/2-ibm-logo.ch8";
    const chip8_logo_rom_path = test_roms_dir ++ "/pong.ch8";
    // const chip8_logo_rom_path = test_roms_dir ++ "/particle_demo.ch8";

    var chip8 = Chip8{ .ctx = &ctx };
    try chip8.loadRomFromFile(std.heap.page_allocator, chip8_logo_rom_path);

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
            try chip8.execute();
            display.clearScreen();
            quit = DisplayDriver.handleEvents(&ctx);
            display.update(&ctx);
            time_accumulated = 0;
        }
        end_time = std.time.microTimestamp();

    }
}
