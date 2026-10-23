const std = @import("std");

const tool = @import("build_tool.zig");

const connectModules = tool.connectModules;
const Module = tool.Module;
const Import = tool.Import;
const imp = tool.imp;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const coreo_mod = b.addModule("coreo", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const dsa_mod = b.createModule(.{
        .root_source_file = b.path("src/dsa/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const comp_mod = b.createModule(.{
        .root_source_file = b.path("src/comp/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const debug_mod = b.createModule(.{
        .root_source_file = b.path("src/debug/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const imports: []const Import = &.{
        imp(.coreo, coreo_mod),
        imp(.dsa, dsa_mod),
        imp(.comp, comp_mod),
        imp(.debug, debug_mod),
    };

    connectModules(imports);
    
    const exe = b.addExecutable(.{
        .name = "coreo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    b.installArtifact(exe);

    const lib = b.addLibrary(.{
        .name = "coreo",
        .root_module = coreo_mod,
    });
    b.installArtifact(lib);
    
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const mod_tests = b.addTest(.{
        .root_module = coreo_mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
