
const std = @import("std");
const CFG = @import("CFG");

pub fn checkAllDecls(comptime types: []const type) void {comptime {
    if (!CFG.CHECK) return;
    for (types) |t| {
        std.testing.refAllDecls(t);
    }
}}
