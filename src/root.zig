//! By convention, root.zig is the root source file when making a package.
const std = @import("std");

pub const dsa = @import("dsa");
pub const comp = @import("comp");
pub const debug = @import("debug");

comptime {
    std.testing.refAllDecls(dsa);
}
