
const CFG = @import("CFG");

const checking = @import("debug").checking;

pub const string = @import("string.zig");

comptime {
    checking.checkAllDecls(
        CFG.CHECK,
        &.{
            string,
        },
    );
}

pub fn isString(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |p| switch (@typeInfo(p.child)) {
            .array => |a| a.child == u8,
            else => p.child == u8 and p.size == .slice,
        },
        else => return false,
    };
}
