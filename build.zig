
const std = @import("std");

const project = @import("zig-build-tools/root.zig").project;

const ProjectBuilder = project.ProjectBuilder;

pub fn build(_b: *std.Build) void {
    const b = ProjectBuilder.init(_b);

    b.buildSimple(.{
        .info = .{
            .name = "coreo",
            .description = "A library of useful functionality.",
            .version = "0.1.0",
            .repository = "https://github.com/ErisianArchitect/coreo",
            .authors = &.{
                "Ada F. <https://github.com/ErisianArchitect> [\x65\x72\x69\x73\x69\x61\x6E\x61\x72\x63\x68\x69\x74\x65\x63\x74\x40\x67\x6D\x61\x69\x6C\x2E\x63\x6F\x6D]",
            },
            .licenses = &.{
                "Apache-2.0",
            },
        },
        .root = "src/root.zig",
        // .main = "src/main.zig",
    });
}
