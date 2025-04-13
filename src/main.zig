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
const builtin = @import("builtin");
const testing = std.testing;

// Not sure yet as to why we need to do this.
pub const os = if (builtin.os.tag != .emscripten and builtin.os.tag != .wasi) std.os else struct {
    pub const heap = struct {
        pub const page_allocator = std.heap.c_allocator;
    };
};

const AppState = struct {
    allocator: std.mem.Allocator,
    chip8_context: Chip8Context,
    chip8: Chip8,
    width: c_int,
    height: c_int,
    window: ?*c.SDL_Window,
    renderer: ?*c.SDL_Renderer,
    scale: c_int,
};

const test_rom = [_]u8{
    0x6A, 0x02, 0x6B, 0x0C, 0x6C, 0x3F, 0x6D, 0x0C, 0xA2, 0xEA, 0xDA, 0xB6, 0xDC, 0xD6, 0x6E, 0x00,
    0x22, 0xD4, 0x66, 0x03, 0x68, 0x02, 0x60, 0x60, 0xF0, 0x15, 0xF0, 0x07, 0x30, 0x00, 0x12, 0x1A,
    0xC7, 0x17, 0x77, 0x08, 0x69, 0xFF, 0xA2, 0xF0, 0xD6, 0x71, 0xA2, 0xEA, 0xDA, 0xB6, 0xDC, 0xD6,
    0x60, 0x01, 0xE0, 0xA1, 0x7B, 0xFE, 0x60, 0x04, 0xE0, 0xA1, 0x7B, 0x02, 0x60, 0x1F, 0x8B, 0x02,
    0xDA, 0xB6, 0x8D, 0x70, 0xC0, 0x0A, 0x7D, 0xFE, 0x40, 0x00, 0x7D, 0x02, 0x60, 0x00, 0x60, 0x1F,
    0x8D, 0x02, 0xDC, 0xD6, 0xA2, 0xF0, 0xD6, 0x71, 0x86, 0x84, 0x87, 0x94, 0x60, 0x3F, 0x86, 0x02,
    0x61, 0x1F, 0x87, 0x12, 0x46, 0x02, 0x12, 0x78, 0x46, 0x3F, 0x12, 0x82, 0x47, 0x1F, 0x69, 0xFF,
    0x47, 0x00, 0x69, 0x01, 0xD6, 0x71, 0x12, 0x2A, 0x68, 0x02, 0x63, 0x01, 0x80, 0x70, 0x80, 0xB5,
    0x12, 0x8A, 0x68, 0xFE, 0x63, 0x0A, 0x80, 0x70, 0x80, 0xD5, 0x3F, 0x01, 0x12, 0xA2, 0x61, 0x02,
    0x80, 0x15, 0x3F, 0x01, 0x12, 0xBA, 0x80, 0x15, 0x3F, 0x01, 0x12, 0xC8, 0x80, 0x15, 0x3F, 0x01,
    0x12, 0xC2, 0x60, 0x20, 0xF0, 0x18, 0x22, 0xD4, 0x8E, 0x34, 0x22, 0xD4, 0x66, 0x3E, 0x33, 0x01,
    0x66, 0x03, 0x68, 0xFE, 0x33, 0x01, 0x68, 0x02, 0x12, 0x16, 0x79, 0xFF, 0x49, 0xFE, 0x69, 0xFF,
    0x12, 0xC8, 0x79, 0x01, 0x49, 0x02, 0x69, 0x01, 0x60, 0x04, 0xF0, 0x18, 0x76, 0x01, 0x46, 0x40,
    0x76, 0xFE, 0x12, 0x6C, 0xA2, 0xF2, 0xFE, 0x33, 0xF2, 0x65, 0xF1, 0x29, 0x64, 0x14, 0x65, 0x00,
    0xD4, 0x55, 0x74, 0x15, 0xF2, 0x29, 0xD4, 0x55, 0x00, 0xEE, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
    0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
};

pub fn clearScreen(appstate: *AppState) void {
    _ = c.SDL_SetRenderDrawColor(appstate.renderer, 0, 0, 0, 255);
    _ = c.SDL_RenderClear(appstate.renderer);
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
        allocator.destroy(appstate);
    }
}

fn sdlAppInit(appstate_ptr: ?*?*anyopaque, _: [][*:0]u8) !c.SDL_AppResult {
    const allocator = std.heap.page_allocator;
    const appstate = try allocator.create(AppState);
    appstate.allocator = allocator;
    appstate.scale = 10;
    appstate.width = 64;
    appstate.height = 32;

    try errify(c.SDL_Init(c.SDL_INIT_VIDEO));
    appstate.window = try errify(c.SDL_CreateWindow("zc8", appstate.width * appstate.scale, appstate.height * appstate.scale, c.SDL_WINDOW_UTILITY));
    appstate.renderer = try errify(c.SDL_CreateRenderer(appstate.window, null));
    _ = c.SDL_UpdateWindowSurface(appstate.window);
    _ = c.SDL_RenderPresent(appstate.renderer);

    clearScreen(appstate);
    appstate.chip8_context = try Chip8Context.initContext();

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
    try appstate.chip8.loadRomFromArray(&test_rom);
    // try chip8.loadRomFromFile(std.heap.page_allocator, chip8_logo_rom_path);
    appstate.chip8.loadFont();

    if (appstate_ptr) |ptr| {
        ptr.* = @constCast(appstate);
    }

    return c.SDL_APP_CONTINUE;
}

fn sdlAppIterate(_: ?*anyopaque) !c.SDL_AppResult {
    return c.SDL_APP_CONTINUE;
}

fn sdlAppEvent(_: ?*anyopaque, _: *c.SDL_Event) !c.SDL_AppResult {
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
