const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
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
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            return error.SDLInitializationFailed;
        }
        self.window = c.SDL_CreateWindow("zc8", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, self.width * self.scale, self.height * self.scale, c.SDL_WINDOW_SHOWN) orelse {
            c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        self.renderer = c.SDL_CreateRenderer(self.window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
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

    fn translateKeyCode(keycode: c.SDL_Keycode) ?KeyPad.Key  {
        switch(keycode) {
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
            c.SDLK_q => {
                return KeyPad.Key.Key4;
            },
            c.SDLK_w => {
                return KeyPad.Key.Key5;
            },
            c.SDLK_e => {
                return KeyPad.Key.Key6;
            },
            c.SDLK_r => {
                return KeyPad.Key.KeyD;
            },
            c.SDLK_a => {
                return KeyPad.Key.Key7;
            },
            c.SDLK_s => {
                return KeyPad.Key.Key8;
            },
            c.SDLK_d => {
                return KeyPad.Key.Key9;
            },
            c.SDLK_f => {
                return KeyPad.Key.KeyE;
            },
            c.SDLK_z => {
                return KeyPad.Key.KeyA;
            },
            c.SDLK_x => {
                return KeyPad.Key.Key0;
            },
            c.SDLK_c => {
                return KeyPad.Key.KeyB;
            },
            c.SDLK_v => {
                return KeyPad.Key.KeyF;
            },
            else => {
                return null;
            }
        }
    }

    pub fn handleEvents(chip8_context: *Chip8Context) bool {
        // Process SDL Events
        var quit = false;
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => {
                    const keycode = event.key.keysym.sym;
                    const translated_keycode = translateKeyCode(keycode);
                    if (translated_keycode) |value| {
                        chip8_context.keypad.pressKey(value);
                    }
                },
                c.SDL_KEYUP => {
                    const keycode = event.key.keysym.sym;
                    const translated_keycode = translateKeyCode(keycode);
                    if (translated_keycode) |value| {
                        chip8_context.keypad.releaseKey(value);
                    }
                },
                else => {
                }
            }
        }
        return quit; 
    }
    pub fn update(self: *DisplayDriver, chip8_context: *Chip8Context) void {
       _ = c.SDL_SetRenderDrawColor(self.renderer, 0, 255, 0, 255);
        for (0..32) |y_usize| {
            for (0..64) |x_usize| {
                const pixel_pos = y_usize * 64 + x_usize;
                if (chip8_context.frame_buffer[pixel_pos] == 1) {
                    // Draw the rectangle on the screen
                    const x: c_int = @intCast(x_usize);
                    const y: c_int = @intCast(y_usize);
                    const rect = c.SDL_Rect {
                        .x = x * self.scale,
                        .y = y * self.scale,
                        .w = self.scale,
                        .h = self.scale,
                    };
                    _ = c.SDL_RenderFillRect(self.renderer, &rect);
                }
            }
        }

        c.SDL_RenderPresent(self.renderer);
    }
};


