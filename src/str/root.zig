
const std = @import("std");

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

pub inline fn startsWith(s: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, s, prefix);
}

pub inline fn endsWith(s: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, s, suffix);
}

pub inline fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub inline fn lessThan(lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

pub const Comparison = enum(i8) {
    const Self = @This();
    
    Less = -1,
    Equal = 0,
    Greater = 1,

    pub fn isLess(self: Self) bool {
        return self == .Less;
    }
};

pub fn compare(lhs: []const u8, rhs: []const u8) Comparison {
    const min_len = @min(lhs.len, rhs.len);
    for (lhs[0..min_len], rhs[0..min_len]) |l, r| {
        if (l == r) continue;
        if (l < r) return .Less;
        return .Greater;
    }
    if (lhs.len == rhs.len) {
        return .Equal;
    }
    if (lhs.len < rhs.len) {
        return .Less;
    }
    return .Greater;
}
