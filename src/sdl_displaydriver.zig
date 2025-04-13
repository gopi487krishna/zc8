const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    // @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    // @cInclude("SDL3/SDL_main.h");
});
// const c = @cImport({
//     @cInclude("SDL2/SDL.h");
// });
const std = @import("std");
const Chip8Context = @import("chip8_context.zig").Chip8Context;
const KeyPad = @import("chip8_context.zig").KeyPad;

pub const DisplayDriver = struct {
    width: c_int,
    height: c_int,
    window: ?*c.SDL_Window,
    renderer: ?*c.SDL_Renderer,
    scale: c_int,
    pub fn init(self: *DisplayDriver) !void {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            c.SDL_Log("Init failed: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        }
        self.window = c.SDL_CreateWindow("zc8", self.width * self.scale, self.height * self.scale, c.SDL_WINDOW_UTILITY) orelse {
            c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        self.renderer = c.SDL_CreateRenderer(self.window, null) orelse {
            c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        _ = c.SDL_UpdateWindowSurface(self.window);
        _ = c.SDL_RenderPresent(self.renderer);
    }

    pub fn deinit(self: *DisplayDriver) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
    pub fn clearScreen(self: *DisplayDriver) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(self.renderer);
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

    pub fn handleEvents(chip8_context: *Chip8Context) bool {
        // Process SDL Events
        var quit = false;
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    quit = true;
                },
                c.SDL_EVENT_KEY_DOWN => {
                    const keycode = event.key.key;
                    const translated_keycode = translateKeyCode(keycode);
                    if (translated_keycode) |value| {
                        chip8_context.keypad.pressKey(value);
                    }
                },
                c.SDL_EVENT_KEY_UP => {
                    const keycode = event.key.key;
                    const translated_keycode = translateKeyCode(keycode);
                    if (translated_keycode) |value| {
                        chip8_context.keypad.releaseKey(value);
                    }
                },
                else => {},
            }
        }
        return quit;
    }
    pub fn update(self: *DisplayDriver, chip8_context: *Chip8Context) !void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0, 255, 0, 255);
        for (0..32) |y_usize| {
            for (0..64) |x_usize| {
                const pixel_pos = y_usize * 64 + x_usize;
                if (chip8_context.frame_buffer[pixel_pos] == 1) {
                    // Draw the rectangle on the screen
                    const x: c_int = @intCast(x_usize);
                    const y: c_int = @intCast(y_usize);
                    const rect = c.SDL_FRect{ .x = @floatFromInt(x * self.scale), .y = @floatFromInt(y * self.scale), .w = @floatFromInt(self.scale), .h = @floatFromInt(self.scale) };
                    _ = c.SDL_RenderFillRect(self.renderer, &rect);
                }
            }
        }

        if (!c.SDL_RenderPresent(self.renderer)) {
            c.SDL_Log("SDL_RenderPresent Failed: %s", c.SDL_GetError());
            return error.SDLRenderPresentFailed;
        }
    }
};
