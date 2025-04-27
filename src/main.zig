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
const blinky = @embedFile("assets/blinky.ch8");
const tank = @embedFile("assets/tank.ch8");
const astrododge = @embedFile("assets/astrododge.ch8");
const filter = @embedFile("assets/filter.ch8");
const animal_race = @embedFile("assets/animal_race.ch8");
const tetris = @embedFile("assets/tetris.ch8");

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
    scale: c_int = 10,
    paused: bool = false,
    cycle_delay: i64 = 16,
    last_cycle_time: i64 = 0,
    audio_paused: bool = false,
    previous_audio_state: bool = false,
    wav_data: [*c]u8 = undefined,
    wav_data_len: c.Uint32 = undefined,
    stream: *c.SDL_AudioStream = undefined,
    shift_quirk_enabled: bool = false,
    load_store_quirk: bool = false,
    disable_audio_state: bool = false,

    pub fn reset_emulator(self: *AppState) void {
        self.chip8.reset();
        self.previous_audio_state = false;
        self.last_cycle_time = std.time.milliTimestamp();
    }

    pub fn pause_audio(self: *AppState) !void {
        self.previous_audio_state = self.audio_paused;
        try errify(c.SDL_PauseAudioStreamDevice(self.stream));
        self.audio_paused = true;
    }

    pub fn resume_audio(self: *AppState) !void {
        if (self.audio_paused and !self.disable_audio_state)
            try errify(c.SDL_ResumeAudioStreamDevice(self.stream));
    }

    pub fn disable_audio(self: *AppState) void {
        self.disable_audio_state = true;
    }

    pub fn enable_audio(self: *AppState) void {
        self.disable_audio_state = false;
    }

    pub fn pause_app(self: *AppState) !void {
        self.paused = true;
        try self.pause_audio();
    }
    pub fn resume_app(self: *AppState) void {
        self.audio_paused = self.previous_audio_state;
        self.paused = false;
    }
};

// Only to be used by exported functions below
var gl_appstate_ptr: ?*AppState = null;

// JS Exported API's
export fn pause_app() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
    }
}

export fn resume_app() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.resume_app();
    }
}

export fn load_pong() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(pong) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_breakout() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(breakout) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_spaceinvaders() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(space_invaders) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_blinky() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(blinky) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_tank() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(tank) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_astrododge() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(astrododge) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_filter() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(filter) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_animalrace() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(animal_race) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn load_tetris() void {
    if (gl_appstate_ptr) |appstate| {
        appstate.pause_app() catch {
            return;
        };
        appstate.reset_emulator();
        appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
        appstate.chip8.load_store_quirk = appstate.load_store_quirk;
        appstate.chip8.loadRomFromArray(tetris) catch {
            return;
        };
        appstate.chip8.loadFont();
        appstate.resume_app();
    }
}

export fn enable_shiftquirk(state: bool) void {
    if (gl_appstate_ptr) |appstate| {
        appstate.shift_quirk_enabled = state;
    }
}

export fn enable_loadstore_quirk(state: bool) void {
    if (gl_appstate_ptr) |appstate| {
        appstate.load_store_quirk = state;
    }
}

export fn disable_audio(state: bool) void {
    if (gl_appstate_ptr) |appstate| {
        if (state) {
            appstate.disable_audio();
        } else {
            appstate.enable_audio();
        }
    }
}

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

fn sdlAppQuit(appstate_ptr: ?*anyopaque, _: anyerror!c.SDL_AppResult) void {
    if (appstate_ptr) |ptr| {
        const appstate: *AppState = @ptrCast(@alignCast(ptr));
        appstate.chip8_context.deinit();
        // Destroy the AppState itself
        const allocator = appstate.allocator;
        c.SDL_free(appstate.wav_data);
        gl_appstate_ptr = null;
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
    appstate.chip8 = Chip8{ .ctx = &appstate.chip8_context };
    appstate.chip8.shift_quirk_enabled = appstate.shift_quirk_enabled;
    appstate.chip8.load_store_quirk = appstate.load_store_quirk;
    try appstate.pause_app();
    // try appstate.chip8.loadRomFromArray(pong);
    // appstate.chip8.loadFont();

    if (appstate_ptr) |ptr| {
        ptr.* = @constCast(appstate);
    }

    gl_appstate_ptr = appstate;

    return c.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate_ptr: ?*anyopaque) !c.SDL_AppResult {
    const appstate: *AppState = @ptrCast(@alignCast(appstate_ptr.?));

    if (appstate.paused) {
        return c.SDL_APP_CONTINUE;
    }

    // Audio
    if (c.SDL_GetAudioStreamQueued(appstate.stream) < appstate.wav_data_len) {
        try errify(c.SDL_PutAudioStreamData(appstate.stream, appstate.wav_data, @intCast(appstate.wav_data_len)));
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
