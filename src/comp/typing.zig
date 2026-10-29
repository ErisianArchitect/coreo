
const std = @import("std");

const lang = std.lang;

const ContainerLayout = lang.Type.ContainerLayout;

pub fn isString(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |p| switch (@typeInfo(p.child)) {
            .array => |a| a.child == u8,
            else => p.child == u8 and p.size == .slice,
        },
        else => return false,
    };
}

pub fn PointerChild(comptime T: type) type {
    return @typeInfo(T).pointer.child;
}

pub fn ArrayChild(comptime T: type) type {
    return @typeInfo(T).array.child;
}

pub fn Child(comptime T: type) type {
    const inf = @typeInfo(T);
    // inf.@"anyframe".child
    return switch (inf) {
        .array => |a| a.child,
        .pointer => |p| p.child,
        .optional => |o| o.child,
        else => @compileError("Childless."),
    };
}

pub fn arrayLen(comptime T: type) comptime_int {
    return @typeInfo(T).array.len;
}

pub fn isLayout(comptime T: type, comptime layout: ContainerLayout) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| s.layout == layout,
        .@"union" => |u| u.layout == layout,
        .@"enum" => |e| e.layout == layout,
        else => @compileError("Must be struct, union, or enum."),
    };
}

pub fn isExternLayout(comptime T: type) bool {
    return isLayout(T, .@"extern");
}

pub fn isPackedLayout(comptime T: type) bool {
    return isLayout(T, .@"packed");
}

pub fn isAutoLayout(comptime T: type) bool {
    return isLayout(T, .@"auto");
}

// This is a bit of a hack, and is dependent on the compiler version.
// COMPILER(VERSION): '0.17.0'
pub fn Unique(comptime tag: anytype) type {
    return struct {
        const TYPE = opaque {
            const _TAG = tag;
        };
        pub fn @"$T"(comptime _tag: anytype) type {
            return struct {
                const _TAG = _tag;
            };
        }
    }.@"$T"(tag);
}

inline fn isDigit(chr: u8) bool {
    return chr >= '0' and chr <= '9';
}

// This is a bit of a hack, and is dependent on the compiler version.
// COMPILER(VERSION): '0.17.0'
pub inline fn uniqueName(comptime tag: anytype) []const u8 {
    const PREFIX_LEN: usize = comptime blk: {
        const sample_name = @typeName(Unique(tag));
        for (sample_name, 0..) |c, i| {
            if (isDigit(c)) break :blk i;
        } else @compileError("Failed to find first digit.");
    };
    return comptime @typeName(Unique(tag))[PREFIX_LEN..];
}

// This is a bit of a hack, and is dependent on the compiler version.
// COMPILER(VERSION): '0.17.0'
pub inline fn uniqueId(comptime tag: anytype) u32 {
    return comptime blk: {
        const name = uniqueName(tag);
        var count: usize = 0;
        for (name) |chr| {
            if (!isDigit(chr)) {
                break;
            }
            count += 1;
        }
        const digits = name[0..count];
        break :blk std.fmt.parseInt(u32, digits, 10) catch unreachable;
    };
}

pub const NULL_ID: u32 = uniqueId(null);

pub fn GenericOpaqueSeal(comptime outer_tag: anytype)
fn(comptime tag: anytype) type {
    return struct {
        const OUTER_TAG = outer_tag;

        pub fn Inner(comptime tag: anytype) type {
            return opaque {
                const INNER_TAG = .{tag, OUTER_TAG};
            };
        }
    }.Inner;
}

