const std = @import("std");

// const build_tools = @import("build_tools/root.zig");

// const project = build_tools.project;

// const Module = project.Module;
// const Project = project.Project;
// const CheckImports = project.BuildCheckImports;

const project = @import("zig-build-tools/root.zig").project;

const ProjectBuilder = project.ProjectBuilder;

pub fn build(_b: *std.Build) void {
    const b = ProjectBuilder.init(_b);

    b.buildSimple(.{
        .info = .{
            .name = "coreo",
            .version = "0.1.0",
        },
        .root = "src/root.zig",
        .main = "src/main.zig",
    });
}
