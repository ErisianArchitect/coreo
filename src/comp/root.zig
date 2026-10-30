
const std = @import("std");
const CFG = @import("CFG");

const dsa = @import("dsa");

const typemap = @import("typemap.zig");
pub const typing = @import("typing.zig");

comptime {
    @import("debug").checking.checkAllDecls(
        @import("CFG").CHECK,
        &.{
            typemap,
            typing,
        },
    );
}

const XxHash64 = std.hash.XxHash64;

const StackVec = dsa.StackVec;

pub const StaticTypeMap = typemap.StaticTypeMap;
pub const StaticTypeSet = typemap.StaticTypeSet;



pub const MAX_BRANCH_QUOTA: u32 = std.math.maxInt(u32);



pub fn undefFields(comptime T: type, obj: *T) void {
    inline for (comptime std.meta.fieldNames(T)) |name| {
        @field(obj, name) = undefined;
    }
}

pub const Mutability = enum {
    const Self = @This();
    
    immut,
    mut,

    pub fn Slice(comptime self: Self, comptime T: type) type {
        switch (self) {
            .immut => return []const T,
            .mut => return []T,
        }
    }

    pub fn TerminatedSlice(comptime self: Self, comptime T: type, comptime terminator: T) type {
        switch (self) {
            .immut => return [:terminator]const T,
            .mut => return [:terminator]T,
        }
    }

    pub fn Pointer(comptime self: Self, comptime T: type) type {
        switch (self) {
            .immut => return *const T,
            .mut => return *T,
        }
    }
};

pub inline fn dupeSlice(
    comptime T: type,
    comptime slice: []const T,
) []const T {
    return struct {
        const storage = blk: {
            var items: [slice.len]T = undefined;
            @memcpy(&items, slice);
            break :blk items;
        };
        const result: []const T = &storage;
    }.result;
}

pub inline fn dupeSliceMut(comptime T: type, comptime slice: []const T) []T {
    return struct {
        var storage = blk: {
            var items: [slice.len]T = undefined;
            @memcpy(&items, slice);
            break :blk items;
        };
        const result: []T = &storage;
    }.result;
}

pub inline fn internArrayAdv(
    comptime mutability: Mutability,
    comptime T: type,
    comptime arr: anytype,
) switch (mutability) {
    .immut => []const T,
    .mut => []T,
} {
    switch (comptime mutability) {
        .immut => return struct {
            const storage = arr;
            pub const result: mutability.Slice(T) = &storage;
        }.result,
        .mut => return struct {
            var storage = arr;
            pub const result: mutability.Slice(T) = &storage;
        }.result,
    }
}

pub inline fn internArray(
    comptime T: type,
    comptime arr: anytype,
) []const T {
    return internArrayAdv(.immut, T, arr);
}

pub inline fn internArrayMut(
    comptime T: type,
    comptime arr: anytype,
) []T {
    return internArrayAdv(.mut, T, arr);
}

pub inline fn internObjectAdv(
    comptime mutability: Mutability,
    comptime obj: anytype,
) switch (mutability) {
    .immut => *const @TypeOf(obj),
    .mut => *@TypeOf(obj),
} {
    switch (comptime mutability) {
        .immut => return struct {
            const storage = obj;
            pub const result = &storage;
        }.result,
        .mut => return struct {
            var storage = obj;
            pub const result = &storage;
        }.result,
    }
}

pub inline fn internObject(
    comptime obj: anytype,
) *const @TypeOf(obj) {
    return internObjectAdv(.immut, obj);
}

pub inline fn internObjectMut(
    comptime obj: anytype,
) *@TypeOf(obj) {
    return internObjectAdv(.mut, obj);
}


pub inline fn joinSlicesAdv(
    comptime mutability: Mutability,
    comptime T: type,
    comptime separator: ?[]const T,
    comptime slices: []const []const T,
) switch (mutability) {
    .immut => []const T,
    .mut => []T,
} {
    return struct {
        pub const result = ret: {
            @setEvalBranchQuota(std.math.maxInt(u32));
            if (slices.len == 0) break :ret &.{};
            const sep = blk:{ if (separator) |s| {
                break :blk s;
            } else {
                break :blk &.{};
            }};
            var size: usize = sep.len * (slices.len - 1);
            for (slices) |s| {
                size += s.len;
            }
            var buf: [size]T = undefined;
            var offset = 0;
            for (slices) |s| {
                if (sep.len != 0 and offset != 0) {
                    @memcpy(buf[offset..][0..sep.len], sep);
                    offset += sep.len;
                }
                @memcpy(buf[offset..][0..s.len], s);
                offset += s.len;
            }
            break :ret internArrayAdv(mutability, T, buf);
        };
    }.result;
}

pub fn joinSlices(
    comptime T: type,
    comptime separator: ?[]const T,
    comptime slices: []const []const T,
) []const T {
    return joinSlicesAdv(.immut, T, separator, slices);
}

pub fn joinSlicesMut(
    comptime T: type,
    comptime separator: ?[]const T,
    comptime slices: []const []const T,
) []T {
    return joinSlicesAdv(.mut, T, separator, slices);
}

pub fn zipWithRight(
    comptime mutability: Mutability,
    comptime T: type,
    comptime rhs: anytype,
    comptime items: []const T,
) switch (mutability) {
    .immut => []const struct {T, @TypeOf(rhs)},
    .mut => []struct {T, @TypeOf(rhs)},
} {
    return struct {
        pub const result = ret: {
            @setEvalBranchQuota(std.math.maxInt(u32));
            if (items.len == 0) break :ret &.{};
            const Tup = struct {T, @TypeOf(rhs)};
            var new_items: [items.len]Tup = undefined;
            for (items, 0..) |lhs, i| {
                new_items[i].@"0" = lhs;
                new_items[i].@"1" = rhs;
            }
            break :ret internArrayAdv(mutability, Tup, new_items);
        };
    }.result;
}

pub fn zipWithLeft(
    comptime mutability: Mutability,
    comptime T: type,
    comptime lhs: anytype,
    comptime items: []const T,
) switch (mutability) {
    .immut => []const struct {@TypeOf(lhs), T},
    .mut => []struct {@TypeOf(lhs), T},
} {
    return struct {
        pub const result = ret: {
            @setEvalBranchQuota(std.math.maxInt(u32));
            if (items.len == 0) break :ret &.{};
            const Tup = struct {@TypeOf(lhs), T};
            var new_items: [items.len]Tup = undefined;
            for (items, 0..) |rhs, i| {
                new_items[i].@"0" = lhs;
                new_items[i].@"1" = rhs;
            }
            break :ret internArrayAdv(mutability, Tup, new_items);
        };
    }.result;
}

pub fn uniqueCount(comptime arr: anytype) usize {
    return comptime ret: {
        @setEvalBranchQuota(std.math.maxInt(u32));
        var items = StackVec(@typeInfo(@TypeOf(arr)).array.child, arr.len).init();
        outer: for (arr) |item| {
            for (items.slice()) |ded| {
                if (item == ded) continue :outer;
            }
            items.push(item);
        }
        break :ret items.len;
    };
}

pub fn dedup(comptime T: type, comptime arr: anytype) [uniqueCount(arr)]T {
    var items = StackVec(T, uniqueCount(arr)).init();
    outer: for (arr) |item| {
        @setEvalBranchQuota(std.math.maxInt(u32));
        for (items.slice()) |ded| {
            if (item == ded) continue :outer;
        }
        items.push(item);
    }
    return items.items;
}

pub inline fn inlineCall(comptime func: anytype, args: anytype) typing.FnReturn(func) {
    return @call(.always_inline, func, args);
}
