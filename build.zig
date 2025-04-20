const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = target.result.os.tag == .emscripten,
    });

    // Add SDL3 dependency to the module
    if (target.query.isNativeOs() and target.result.os.tag == .linux) {
        // The SDL package doesn't work for Linux yet, so we rely on system
        // packages for now.
        app_mod.linkSystemLibrary("SDL3", .{});
    } else {
        const sdl_dep = b.dependency("sdl", .{
            .optimize = .ReleaseFast,
            .target = target,
        });
        app_mod.linkLibrary(sdl_dep.artifact("SDL3"));
    }

    const run = b.step("run", "Run the app");

    if (target.result.os.tag == .emscripten) {
        // Build for web
        var emscripten_system_include_path: ?std.Build.LazyPath = null;

        // Passing sysroot is necessary
        if (b.sysroot) |sysroot| {
            emscripten_system_include_path = .{ .cwd_relative = b.pathJoin(&.{ sysroot, "include" }) };
        } else {
            std.log.err("'--sysroot' is required when building for emscripten", .{});
            std.process.exit(1);
        }

        if (emscripten_system_include_path) |path| {
            app_mod.addSystemIncludePath(path);
        }

        const app_lib = b.addLibrary(.{
            .linkage = .static,
            .name = "zc8",
            .root_module = app_mod,
        });

        app_lib.want_lto = optimize != .Debug;

        const run_emcc = b.addSystemCommand(&.{"emcc"});

        // Pass everything
        for (app_lib.getCompileDependencies(false)) |compile| {
            run_emcc.addArtifactArg(compile);
        }

        run_emcc.addArgs(&.{
            "-sUSE_OFFSET_CONVERTER", // Required by Zig's '@returnAddress'
            "-sLEGACY_RUNTIME", // Currently required by SDL
            "-sMIN_WEBGL_VERSION=2",
            "-sFULL_ES3", // Currently required by zigglgen
            "-sEXPORTED_FUNCTIONS=['_main', '_load_pong', '_load_spaceinvaders', '_load_breakout', '_enable_shiftquirk', '_disable_audio']",
            "-sEXPORTED_RUNTIME_METHODS=['ccall','cwrap']",
        });

        // Patch the default HTML shell to also display messages printed to stderr.
        run_emcc.addArg("--pre-js");
        run_emcc.addFileArg(b.addWriteFiles().add("pre.js", (
            \\Module['printErr'] ??= Module['print'];
            \\
        )));

        run_emcc.addArg("-o");
        const app_html = run_emcc.addOutputFileArg("zc8.html");

        b.getInstallStep().dependOn(&b.addInstallDirectory(.{
            .source_dir = app_html.dirname(),
            .install_dir = .{ .custom = "www" },
            .install_subdir = "",
        }).step);

        const run_emrun = b.addSystemCommand(&.{"emrun"});
        run_emrun.addArg(b.pathJoin(&.{ b.install_path, "www", "zc8.html" }));
        if (b.args) |args| run_emrun.addArgs(args);
        run_emrun.step.dependOn(b.getInstallStep());

        run.dependOn(&run_emrun.step);
    } else {
        // Desktop config
        // Move everything here
        app_mod.link_libc = true;
        const app_exe = b.addExecutable(.{
            .name = "zc8",
            .root_module = app_mod,
        });
        app_exe.want_lto = optimize != .Debug;
        b.installArtifact(app_exe);
        const run_cmd = b.addRunArtifact(app_exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        run.dependOn(&run_cmd.step);

        const test_roms_dir = b.path("test_roms");
        const build_options = b.addOptions();
        build_options.addOptionPath("test_roms_dir", test_roms_dir);

        app_exe.root_module.addOptions("build_options", build_options);

        const app_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        app_unit_tests.root_module.addOptions("build_options", build_options);

        // Context State Tests
        const chip8_context_tests = b.addTest(.{
            .root_source_file = b.path("src/chip8_context.zig"),
            .target = target,
            .optimize = optimize,
            .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
        });
        chip8_context_tests.root_module.addOptions("build_options", build_options);

        const chip8_tests = b.addTest(.{
            .root_source_file = b.path("src/chip8.zig"),
            .target = target,
            .optimize = optimize,
            .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
        });
        chip8_tests.root_module.addOptions("build_options", build_options);

        const run_app_unit_tests = b.addRunArtifact(app_unit_tests);
        const run_chip8_context_tests = b.addRunArtifact(chip8_context_tests);
        const run_chip8_tests = b.addRunArtifact(chip8_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_app_unit_tests.step);
        test_step.dependOn(&run_chip8_context_tests.step);
        test_step.dependOn(&run_chip8_tests.step);
    }
}
