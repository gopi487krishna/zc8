const std = @import("std");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
});
const Chip8Context = @import("chip8_context.zig").Chip8Context;
const Chip8 = @import("chip8.zig").Chip8;
const KeyPad = @import("chip8_context.zig").KeyPad;
const builtin = @import("builtin");
const testing = std.testing;

// Preloaded Games
const pong = @embedFile("assets/pong.ch8");
const breakout = @embedFile("assets/breakout.ch8");
const space_invaders = @embedFile("assets/space_invaders.ch8");

// Beep sound
const beep = @embedFile("assets/beep.wav");
// Not sure yet as to why we need to do this.
pub const os = if (builtin.os.tag != .emscripten and builtin.os.tag != .wasi) std.os else struct {
    pub const heap = struct {
        pub const page_allocator = std.heap.c_allocator;
    };
};

const AppState = struct {
    allocator: std.mem.Allocator = undefined,
    chip8_context: Chip8Context = undefined,
    chip8: Chip8 = undefined,
    width: c_int = 64,
    height: c_int = 32,
    window: ?*c.SDL_Window = undefined,
    renderer: ?*c.SDL_Renderer = undefined,
    scale: c_int = 20,
    paused: bool = false,
    cycle_delay: i64 = 16,
    last_cycle_time: i64 = 0,
    requires_reset: bool = false,
    audio_paused: bool = false,
    wav_data: [*c]u8 = undefined,
    wav_data_len: c.Uint32 = undefined,
    stream: *c.SDL_AudioStream = undefined,

    pub fn reset(self: *AppState) void {
        self.chip8.reset();
        self.paused = false;
        self.requires_reset = false;
        self.last_cycle_time = std.time.milliTimestamp();
    }

    pub fn pause_audio(self: *AppState) !void {
        try errify(c.SDL_PauseAudioStreamDevice(self.stream));
        self.audio_paused = true;
    }

    pub fn resume_audio(self: *AppState) !void {
        if (self.audio_paused)
            try errify(c.SDL_ResumeAudioStreamDevice(self.stream));
    }
};

pub fn clearScreen(appstate: *AppState) void {
    _ = c.SDL_SetRenderDrawColor(appstate.renderer, 0, 0, 0, 255);
    _ = c.SDL_RenderClear(appstate.renderer);
}
fn translateKeyCode(keycode: c.SDL_Keycode) ?KeyPad.Key {
    switch (keycode) {
        c.SDLK_1 => {
            return KeyPad.Key.Key1;
        },
        c.SDLK_2 => {
            return KeyPad.Key.Key2;
        },
        c.SDLK_3 => {
            return KeyPad.Key.Key3;
        },
        c.SDLK_4 => {
            return KeyPad.Key.KeyC;
        },
        c.SDLK_Q => {
            return KeyPad.Key.Key4;
        },
        c.SDLK_W => {
            return KeyPad.Key.Key5;
        },
        c.SDLK_E => {
            return KeyPad.Key.Key6;
        },
        c.SDLK_R => {
            return KeyPad.Key.KeyD;
        },
        c.SDLK_A => {
            return KeyPad.Key.Key7;
        },
        c.SDLK_S => {
            return KeyPad.Key.Key8;
        },
        c.SDLK_D => {
            return KeyPad.Key.Key9;
        },
        c.SDLK_F => {
            return KeyPad.Key.KeyE;
        },
        c.SDLK_Z => {
            return KeyPad.Key.KeyA;
        },
        c.SDLK_X => {
            return KeyPad.Key.Key0;
        },
        c.SDLK_C => {
            return KeyPad.Key.KeyB;
        },
        c.SDLK_V => {
            return KeyPad.Key.KeyF;
        },
        else => {
            return null;
        },
    }
}

pub fn render(appstate: *AppState) !void {
    _ = c.SDL_SetRenderDrawColor(appstate.renderer, 0, 255, 0, 255);
    for (0..32) |y_usize| {
        for (0..64) |x_usize| {
            const pixel_pos = y_usize * 64 + x_usize;
            if (appstate.chip8_context.frame_buffer[pixel_pos] == 1) {
                // Draw the rectangle on the screen
                const x: c_int = @intCast(x_usize);
                const y: c_int = @intCast(y_usize);
                const rect = c.SDL_FRect{ .x = @floatFromInt(x * appstate.scale), .y = @floatFromInt(y * appstate.scale), .w = @floatFromInt(appstate.scale), .h = @floatFromInt(appstate.scale) };
                _ = c.SDL_RenderFillRect(appstate.renderer, &rect);
            }
        }
    }

    if (!c.SDL_RenderPresent(appstate.renderer)) {
        c.SDL_Log("SDL_RenderPresent Failed: %s", c.SDL_GetError());
        return error.SDLRenderPresentFailed;
    }
}

// pub fn main() !void {
//     var display = DisplayDriver {
//         .scale = 10,
//         .window = null,
//         .renderer = null,
//         .width = 64,
//         .height = 32
//     };
//
//     try display.init();
//     defer display.deinit();
//     display.clearScreen();
//
//
//     var ctx = try Chip8Context.initContext(allocator);
//     defer ctx.deinit();
//
//     var args = std.process.args();
//     _ = args.skip(); //to skip the zig call
//
//
//
//     // var chip8_logo_rom_path: []const u8 = undefined;
//     // if (args.next()) |path| {
//         // chip8_logo_rom_path = try std.fs.cwd().realpathAlloc(std.heap.page_allocator, path);
//         // std.debug.print("Path : {s}\n", .{chip8_logo_rom_path});
//     // }
//     // else {
//         // std.debug.print("No path provided!\n", .{});
//         // std.process.exit(1);
//     // }
//
//     var chip8 = Chip8{ .ctx = &ctx};
//     try chip8.loadRomFromArray(&test_rom);
//     // try chip8.loadRomFromFile(std.heap.page_allocator, chip8_logo_rom_path);
//     chip8.loadFont();
//
//     var start_time: i64 = 0;
//     var end_time: i64 = 0;
//     var time_accumulated: i64 = 0;
//     const target_frame_time = 1_000_000 / 60; // 60Hz
//
//     var quit = false;
//
//     while (!quit) {
//         std.time.sleep(200);
//         const delta_time = end_time - start_time;
//         start_time = std.time.microTimestamp();
//         time_accumulated += delta_time;
//         if (time_accumulated > target_frame_time) {
//             display.clearScreen();
//             quit = DisplayDriver.handleEvents(&ctx);
//             var cycles:u8 = 1;
//             while (cycles != 0) {
//                 try chip8.execute();
//                 cycles -= 1;
//             }
//
//             if (ctx.draw_flag) {
//                 try display.update(&ctx);
//                 ctx.draw_flag = false;
//             }
//             ctx.delay_timer = if (ctx.delay_timer == 0) 0 else ctx.delay_timer - 1;
//             ctx.sound_timer = if (ctx.sound_timer == 0) 0 else ctx.sound_timer - 1;
//             time_accumulated = 0;
//         }
//         end_time = std.time.microTimestamp();
//
//     }
// }

fn sdlAppQuit(appstate_ptr: ?*anyopaque, _: anyerror!c.SDL_AppResult) void {
    if (appstate_ptr) |ptr| {
        const appstate: *AppState = @ptrCast(@alignCast(ptr));
        appstate.chip8_context.deinit();
        // Destroy the AppState itself
        const allocator = appstate.allocator;
        c.SDL_free(appstate.wav_data);
        allocator.destroy(appstate);
    }
}

fn sdlAppInit(appstate_ptr: ?*?*anyopaque, _: [][*:0]u8) !c.SDL_AppResult {
    const allocator = std.heap.page_allocator;
    const appstate = try allocator.create(AppState);
    appstate.* = AppState{
        .allocator = allocator,
        .last_cycle_time = std.time.milliTimestamp(),
    };

    try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO));
    appstate.window = try errify(c.SDL_CreateWindow("zc8", appstate.width * appstate.scale, appstate.height * appstate.scale, c.SDL_WINDOW_UTILITY));
    appstate.renderer = try errify(c.SDL_CreateRenderer(appstate.window, null));
    _ = c.SDL_UpdateWindowSurface(appstate.window);
    _ = c.SDL_RenderPresent(appstate.renderer);

    // Setup the audio
    var spec: c.SDL_AudioSpec = undefined;
    try errify(c.SDL_LoadWAV_IO(c.SDL_IOFromConstMem(beep, beep.len), true, &spec, &appstate.wav_data, &appstate.wav_data_len));
    appstate.stream = try errify(c.SDL_OpenAudioDeviceStream(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, null, null));

    appstate.chip8_context = try Chip8Context.initContext(allocator);

    // var chip8_logo_rom_path: []const u8 = undefined;
    // if (args.next()) |path| {
    // chip8_logo_rom_path = try std.fs.cwd().realpathAlloc(std.heap.page_allocator, path);
    // std.debug.print("Path : {s}\n", .{chip8_logo_rom_path});
    // }
    // else {
    // std.debug.print("No path provided!\n", .{});
    // std.process.exit(1);
    // }

    appstate.chip8 = Chip8{ .ctx = &appstate.chip8_context };
    try appstate.chip8.loadRomFromArray(pong);
    // try chip8.loadRomFromFile(std.heap.page_allocator, chip8_logo_rom_path);
    appstate.chip8.loadFont();

    if (appstate_ptr) |ptr| {
        ptr.* = @constCast(appstate);
    }

    return c.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate_ptr: ?*anyopaque) !c.SDL_AppResult {
    const appstate: *AppState = @ptrCast(@alignCast(appstate_ptr.?));

    // Audio
    if (c.SDL_GetAudioStreamQueued(appstate.stream) < appstate.wav_data_len) {
        try errify(c.SDL_PutAudioStreamData(appstate.stream, appstate.wav_data, @intCast(appstate.wav_data_len)));
    }

    if (appstate.paused) {
        return c.SDL_APP_CONTINUE;
    }

    if (appstate.requires_reset) {
        appstate.reset();
        try appstate.chip8.loadRomFromArray(breakout);
        appstate.chip8.loadFont();
        return c.SDL_APP_CONTINUE;
    }

    const current_time = std.time.milliTimestamp();
    const delay_time = current_time - appstate.last_cycle_time;

    if (delay_time > appstate.cycle_delay) {
        appstate.last_cycle_time = current_time;
        var i: usize = 0;
        // 500Hz with 60FPS
        const cycles_per_frame: usize = 8;
        while (i < cycles_per_frame) : (i += 1) {
            try appstate.chip8.execute();
        }
        if (appstate.chip8_context.draw_flag) {
            clearScreen(appstate);
            try render(appstate);
        }
        if (appstate.chip8_context.sound_timer == 0) {
            try appstate.pause_audio();
        } else {
            try appstate.resume_audio();
            appstate.chip8_context.sound_timer -= 1;
        }
        appstate.chip8_context.draw_flag = false;
        appstate.chip8_context.delay_timer = if (appstate.chip8_context.delay_timer == 0) 0 else appstate.chip8_context.delay_timer - 1;
    }
    return c.SDL_APP_CONTINUE;
}

fn sdlAppEvent(appstate_ptr: ?*anyopaque, event: *c.SDL_Event) !c.SDL_AppResult {
    const appstate: *AppState = @ptrCast(@alignCast(appstate_ptr.?));
    switch (event.type) {
        c.SDL_EVENT_QUIT => {
            return c.SDL_APP_SUCCESS;
        },
        c.SDL_EVENT_KEY_DOWN => {
            const keycode = event.key.key;
            // Toggle Pause on Escape Key
            if (keycode == c.SDLK_ESCAPE) {
                appstate.paused = !appstate.paused;
                return c.SDL_APP_CONTINUE;
            }

            if (keycode == c.SDLK_R) {
                appstate.requires_reset = true;
            }

            const translated_keycode = translateKeyCode(keycode);
            if (translated_keycode) |value| {
                appstate.chip8_context.keypad.pressKey(value);
            }
        },
        c.SDL_EVENT_KEY_UP => {
            const keycode = event.key.key;
            const translated_keycode = translateKeyCode(keycode);
            if (translated_keycode) |value| {
                appstate.chip8_context.keypad.releaseKey(value);
            }
        },
        else => {},
    }
    return c.SDL_APP_CONTINUE;
}

/// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}

//#region SDL main callbacks boilerplate

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}

fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return c.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.SDL_AppResult {
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

fn sdlAppEventC(appstate: ?*anyopaque, event: ?*c.SDL_Event) callconv(.c) c.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

fn sdlAppQuitC(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}

var app_err: ErrorStore = .{};

const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: c.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = c.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    fn store(es: *ErrorStore, err: anyerror) c.SDL_AppResult {
        if (c.SDL_CompareAndSwapAtomicInt(&es.status, status_not_stored, status_storing)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = c.SDL_SetAtomicInt(&es.status, status_stored);
        }
        return c.SDL_APP_FAILURE;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (c.SDL_GetAtomicInt(&es.status) != status_stored) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};
//#endregion SDL main callbacks boilerplate
