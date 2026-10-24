
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

pub fn Unique(comptime tag: anytype) type {
    return struct {
        const _ = tag;
    };
}

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
