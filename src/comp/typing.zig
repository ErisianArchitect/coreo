
const std = @import("std");

const lang = std.lang;

const ContainerLayout = lang.Type.ContainerLayout;

pub fn fieldCount(comptime T: type) comptime_int {
    return comptime std.meta.fieldTypes(T).len;
}

pub fn paramCount(comptime F: type) comptime_int {
    return comptime @typeInfo(F).@"fn".param_types.len;
}

pub fn FnReturn(comptime F: type) type {
    if (@typeInfo(F).@"fn".return_type) |ty| {
        return ty;
    } else {
        return void;
    }
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

// This is a bit of a hack, and is dependent on the compiler version.
// COMPILER(VERSION): '0.17.0'
pub fn UniqueType(comptime T: type) type {
    return struct {
        const TYPE = opaque {
            const _TAG = T;
        };
        pub fn @"$T"(comptime Inner: type) type {
            return struct {
                const _TAG = Inner;
            };
        }
    }.@"$T"(T);
}

inline fn isDigit(chr: u8) bool {
    return chr >= '0' and chr <= '9';
}

// This is a bit of a hack, and is dependent on the compiler version.
// COMPILER(VERSION): '0.17.0'
pub inline fn uniqueName(comptime tag: anytype) []const u8 {
    const full_name = comptime @typeName(Unique(tag));
    const PREFIX_LEN: usize = comptime blk: {
        for (full_name, 0..) |c, i| {
            if (isDigit(c)) break :blk i;
        } else @compileError("Failed to find first digit.");
    };
    return comptime full_name[PREFIX_LEN..];
}

// This is a bit of a hack, and is dependent on the compiler version.
// COMPILER(VERSION): '0.17.0'
pub inline fn uniqueId(comptime tag: anytype) u32 {
    const SUB_ID = comptime blk: {
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
    // Add 1 to the SUB_ID to ensure it is greater than 0. I don't expect a max value.
    return comptime SUB_ID + 1;
}

// This is a bit of a hack, and is dependent on the compiler version.
// COMPILER(VERSION): '0.17.0'
fn TypeIdUniqueType(comptime T: type) type {
    return struct {
        const TYPE = opaque {
            const _TAG = T;
        };
        pub fn @"$T"(comptime Inner: type) type {
            return struct {
                const _TAG = Inner;
            };
        }
    }.@"$T"(T);
}

pub const TypeId = enum(u32) {
    const Self = @This();
    
    null = 0,
    _,

    pub const HashContext = struct {
        pub fn hash(_: HashContext, key: TypeId) u64 {
            return key.hash64();
        }

        pub fn eql(_: HashContext, lhs: TypeId, rhs: TypeId) bool {
            return lhs == rhs;
        }
    };

    pub inline fn init(val: u32) Self {
        @setRuntimeSafety(false);
        return @fromBackingInt(val);
    }

    pub inline fn of(comptime T: type) Self {
        const Result = struct {
            pub const result = ret: {
                const name = @typeName(TypeIdUniqueType(T));
                @setEvalBranchQuota(1000 + name.len * 10);
                const prefix_len: usize = blk: {
                    for (0.., name) |i, c| {
                        if (isDigit(c)) break :blk i;
                    } else @compileError("Failed to find first digit.");
                };
                const suffix = name[prefix_len..];
                const suffix_len: usize = blk: {
                    for (0.., suffix) |i, c| {
                        if (!isDigit(c)) break :blk i;
                    } else break :blk suffix.len;
                };
                const digits = suffix[0..suffix_len];
                const id_raw: u32 = std.fmt.parseInt(u32, digits, 10) catch @compileError("Failed to parse int.");
                // Add 1 to id_raw to ensure non-zero value.
                break :ret TypeId.init(id_raw + 1);
            };
        };
        return comptime Result.result;
    }

    pub inline fn value(self: Self) u32 {
        return @backingInt(self);
    }

    pub fn hash64(self: Self) u64 {
        const SEED: u64 = comptime 8072947542518565804;
        var hasher = std.hash.XxHash64.init(SEED);
        std.hash.autoHash(&hasher, self);
        return hasher.final();
    }

    pub fn hash32(self: Self) u32 {
        const SEED: u64 = comptime 3276423977;
        var hasher = std.hash.XxHash32.init(SEED);
        std.hash.autoHash(&hasher, self);
        return hasher.final();
    }
};

pub inline fn typeId(comptime T: type) TypeId {
    return comptime TypeId.of(T);
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

pub inline fn anyHash(comptime tag: anytype) u64 {
    return struct {
        const SEED: u64 = 17761616753254605693;
        pub const HASH: u64 = blk: {
            var hasher = std.hash.XxHash64.init(SEED);
            const type_id = uniqueId(tag);
            std.hash.autoHash(&hasher, type_id);
            break :blk hasher.final();
        };
    }.HASH;
}

pub inline fn typeHash(comptime T: type) u64 {
    return comptime TypeId.of(T).hash64();
}
