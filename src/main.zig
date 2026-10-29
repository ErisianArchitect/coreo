const std = @import("std");
const coreo = @import("coreo");

const ObjectPool = coreo.dsa.ObjectPoolUnmanaged;
const VecUnmanaged = coreo.dsa.VecUnmanaged;
const VecManaged = coreo.dsa.VecManaged;

const comp = coreo.comp;
const typing = comp.typing;
const debug = coreo.debug;
const ffi = coreo.ffi;

const print = debug.print;
const println = debug.println;
const qprint = debug.qprint;
const qprintln = debug.qprintln;

pub fn UT(comptime tag: @EnumLiteral()) type {
    return struct {
        const _ = tag;
    };
}

fn fail() noreturn {
    if (@inComptime()) {
        @compileError("Failure.");
    } else {
        @panic("Failure.");
    }
}

fn orFail(result: anytype) @typeInfo(@TypeOf(result)).error_union.payload {
    return result catch fail();
}

const testFailure = debug.assert.failure("Test Failure");

fn Uni(comptime tag: anytype) type {
    return struct {
        const TAG = tag;
    };
}

fn non_inline() void {
    qprintln("This is a test.");
}

const VkEnum = struct {
    pub const Foo: u8 = 1;
    pub const Bar: u8 = 2;
    pub const Baz: u8 = 4;
    pub const FooBar = Foo | Bar;
    pub const FooBaz = Foo | Baz;
    pub const BarBaz = Bar | Baz;
    pub const FooBarBaz = Foo | Bar | Baz;
};

const HashMap = std.HashMapUnmanaged;

const Alloc = std.mem.Allocator;

// const TypeMap = struct {
//     const Self = @This();
//     const Context = struct {
//         pub fn hash(_: Context, k: u32) u64 {
//             const SEED: u64 = comptime 10142869613977478491;
//             var hasher = std.hash.XxHash64.init(SEED);
//             std.hash.autoHash(&hasher, k);
//             return hasher.final();
//         }

//         pub fn eql(_: Context, a: u32, b: u32) bool {
//             return a == b;
//         }
//     };
//     const Map = HashMap(u32, []const u8, Context, 80);
//     map: Map = .empty,

//     pub const empty: Self = .{.map = .empty};

//     const PrivateToken = opaque{};

//     const Seal = comp.typing.GenericOpaqueSeal(PrivateToken);

//     pub inline fn keyFor(comptime Key: type) u32 {
//         return comptime comp.typing.uniqueId(Seal(Key));
//     }

//     pub inline fn insert(self: *Self, alloc: Alloc, comptime Key: type, value: []const u8) !void {
//         try self.map.put(alloc, keyFor(Key), value);
//     }

//     pub inline fn get(self: *const Self, comptime Key: type) ?[]const u8 {
//         return self.map.get(keyFor(Key));
//     }

//     pub inline fn contains(self: *const Self, comptime Key: type) bool {
//         return self.map.contains(keyFor(Key));
//     }

//     pub inline fn remove(self: *Self, comptime Key: type) ?[]const u8 {
//         return if (self.map.fetchRemove(keyFor(Key))) |kv| kv.value else null;
//     }
// };

const TypeMap = coreo.dsa.TypeMapUnmanaged;

pub fn main(init: std.process.Init) !void {
    @setEvalBranchQuota(std.math.maxInt(u32));

    const gpa = init.gpa;
    var map = TypeMap([]const u8).empty;
    defer map.map.deinit(gpa);

    // map.insert(gpa, u32, "Type(u32)") catch @panic("Failure");
    // map.insert(gpa, u64, "Type(u64)") catch @panic("Failure");

    // println("Contains u32: {}", .{map.contains(u32)});
    // println("Contains u64: {}", .{map.contains(u64)});
    // println("Contains u16: {}", .{map.contains(u16)});
    // println("Value of u32: {s}", .{map.get(u32).?});
    // println("Value of u64: {s}", .{map.get(u64).?});

    const ids: []const u32 = ManyIds(256);

    for (ids) |id| {
        if (map.map.contains(id)) @panic("Key collision.");
        try map.map.put(gpa, id, "");
    }

    qprintln(comp.typing.uniqueId(u32));
    qprintln(comp.typing.uniqueId(u64));
    qprintln(comp.typing.uniqueName(u32));
    qprintln(comp.typing.uniqueName(u64));

    // const id: usize = comp.typing.uniqueId(FredA);
    // println("Name: {s}", .{@typeName(FredA)});
    // println("Name: {s}", .{@typeName(FredB)});
    // println("Id: {d}", .{id});
    // println("Id: {d}", .{comp.typing.uniqueId(FredB)});
    // inline for (comptime 0..1000) |i| {
    //     println("Id({d}): {d}", .{i, comp.typing.uniqueId(i)});
    // }
}

pub fn ManyIds(comptime count: usize) []const u32 {
    return comptime blk: {
        @setEvalBranchQuota(std.math.maxInt(u32));
        var ids: [count]u32 = undefined;
        for (0..count) |i| {
            ids[i] = comp.typing.uniqueId(i);
        }
        break :blk comp.internArray(.immut, u32, ids);
    };
}

fn uniqueNameTest() !void {
    // qprintln(@typeName(comp.typing.Unique(u16)));
    // qprintln(@typeName(comp.typing.Unique(u32)));
    // qprintln(@typeName(comp.typing.Unique(u64)));
    // qprintln(comp.typing.uniqueName(u16));
    // qprintln(comp.typing.uniqueName(u32));
    // qprintln(comp.typing.uniqueName(u64));
    // qprintln(comp.typing.uniqueName(.{"foo"}));
    // qprintln(comp.typing.uniqueName(.{"bar"}));
    // qprintln(comp.typing.uniqueName(.{"baz"}));
}
