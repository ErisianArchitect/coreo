
const std = @import("std");

pub const Module = std.Build.Module;
pub const Import = std.Build.Module.Import;

pub fn imp(name: @EnumLiteral(), module: *Module) Import {
    return .{.name = @tagName(name), .module = module};
}

pub fn connectModules(modules: []const Import) void {
    for (modules) |a| {
        for (modules) |b| {
            a.module.addImport(b.name, b.module);
        }
    }
}
