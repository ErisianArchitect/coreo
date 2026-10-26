
const std = @import("std");
const CFG = @import("CFG");

pub fn checkAllDecls(comptime check: bool, comptime types: []const type) void {comptime {
    if (!check) return;
    for (types) |t| {
        std.testing.refAllDecls(t);
    }
}}
