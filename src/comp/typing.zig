
const std = @import("std");

const comp = @import("root.zig");

const lang = std.lang;

const ContainerLayout = lang.Type.ContainerLayout;

pub fn fieldCount(comptime T: type) comptime_int {
    return comptime std.meta.fieldTypes(T).len;
}

pub fn paramCount(comptime F: type) comptime_int {
    return comptime @typeInfo(F).@"fn".param_types.len;
}

pub fn paramTypes(comptime F: type) []const ?type {
    return comptime @typeInfo(F).@"fn".param_types;
}

pub fn isConcreteFn(comptime F: type) bool {
    const fun = @typeInfo(F).@"fn";
    if (fun.attrs.varargs) return false;
    if (fun.is_generic) return false;
    if (fun.return_type == null) return false;
    for (fun.param_types) |param_type| {
        if (param_type == null) return false;
    }
    return true;
}

pub fn concreteParamTypes(comptime F: type) []const type {
    return comptime ret:{
        const fun = @typeInfo(F).@"fn";
        var types: [fun.param_types.len]type = undefined;
        @setEvalBranchQuota(1000 + fun.param_types.len * 100);
        for (0.., fun.param_types) |i, param_type| {
            if (param_type == null) @compileError("Must have all concrete parameter types.");
            types[i] = param_type.?;
        }
        break:ret comp.internArray(type, types);
    };
}

pub fn fnInfo(comptime F: type) std.builtin.Type.Fn {
    return @typeInfo(F).@"fn";
}

pub fn ptrInfo(comptime P: type) std.builtin.Type.Pointer {
    return @typeInfo(P).pointer;
}

pub fn fnPtrInfo(comptime F: type) std.builtin.Type.Fn {
    return fnInfo(ptrInfo(F).child);
}

pub fn optInfo(comptime O: type) std.builtin.Type.Optional {
    return @typeInfo(O).optional;
}

pub fn arrInfo(comptime A: type) std.builtin.Type.Array {
    return @typeInfo(A).array;
}

pub fn enumInfo(comptime E: type) std.builtin.Type.Enum {
    return @typeInfo(E).@"enum";
}

pub fn structInfo(comptime S: type) std.builtin.Type.Struct {
    return @typeInfo(S).@"struct";
}

pub fn opaqueInfo(comptime O: type) std.builtin.Type.Opaque {
    return @typeInfo(O).@"opaque";
}

pub fn unionInfo(comptime U: type) std.builtin.Type.Union {
    return @typeInfo(U).@"union";
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

/// A type that can be used as a field to set the alignment of a type.
/// This is not strictly necessary, you can just use the `align` keyword
/// on your first field, but this can be useful if you want to have a
/// field that is specifically used to force alignment without using the
/// `align` keyword.
///
/// This type takes up no memory, it only sets the alignment.
///
/// Use this as the first field in an extern struct.
///
/// ```zig
/// const Foo = extern struct {
///     _: Aligner(32),
///     bytes: [32]u8,
/// };
/// ```
pub fn Aligner(comptime alignment: usize) type {
    if (@popCount(alignment) != 1) @compileError("Alignment must be a non-zero power of two.");
    return extern struct {
        const Self = @This();
        pub const ALIGNMENT: usize = alignment;

        _: void align(alignment) = {},

        pub const def: Self = .{._ = {}};
    };
}

/// A type that can be used to add padding to a type.
///
/// ```zig
/// const Foo = packed struct {
///     byte: u8,
///     _pad0: Padding(3) = .def,
///     aligned: u32,
/// };
/// ```
pub fn Padding(comptime size: usize) type {
    return extern struct {
        const Self = @This();
        pub const SIZE: usize = size;
        
        _: [size]u8 = @splat(0),

        pub const def: Self = std.mem.zeroes(Self);
    };
}
