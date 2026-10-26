const std = @import("std");

const build_tools = @import("./build_tools/root.zig");

const project = build_tools.project;

const connectModules = project.connectModules;
const Module = project.Module;
const Import = project.Import;
const imp = project.imp;
const Imports = project.Imports;
const Project = project.Project;
const CheckImports = project.BuildCheckImports;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const proj = Project.init(b);
    var imports = CheckImports(16).init();

    const coreo_mod_create_options: Module.CreateOptions = .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    };

    const coreo_mod = proj.addModule("coreo", coreo_mod_create_options);
    const check_coreo_mod = proj.addModule("coreo_check", coreo_mod_create_options);

    imports.connect("coreo", coreo_mod, check_coreo_mod);

    imports.connectDuped("dsa", proj.dupedCreateModule(2, .{
        .root_source_file = b.path("src/dsa/root.zig"),
        .target = target,
        .optimize = optimize,
    }));

    imports.connectDuped("comp", proj.dupedCreateModule(2, .{
        .root_source_file = b.path("src/comp/root.zig"),
        .target = target,
        .optimize = optimize,
    }));

    imports.connectDuped("debug", proj.dupedCreateModule(2, .{
        .root_source_file = b.path("src/debug/root.zig"),
        .target = target,
        .optimize = optimize,
    }));

    imports.connectDuped("ffi", proj.dupedCreateModule(2, .{
        .root_source_file = b.path("src/ffi/root.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const build_options = b.addOptions();
    const check_options = b.addOptions();

    build_options.addOption(bool, "CHECK", false);
    check_options.addOption(bool, "CHECK", true);
    
    imports.build.addOptions("CFG", build_options);
    imports.check.addOptions("CFG", check_options);
    
    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = imports.build.slice(),
    });
    
    const exe = b.addExecutable(.{
        .name = "coreo",
        .root_module = main_mod,
    });
    b.installArtifact(exe);

    const lib = b.addLibrary(.{
        .name = "coreo",
        .root_module = coreo_mod,
    });
    b.installArtifact(lib);

    const check = b.addLibrary(.{
        .name = "coreo-check",
        .root_module = check_coreo_mod,
    });
    
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const check_step = b.step("check", "Perform checking");
    check_step.dependOn(&check.step);
    
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
