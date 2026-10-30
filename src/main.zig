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


const HashMap = std.HashMapUnmanaged;

const Alloc = std.mem.Allocator;

const TypeMap = coreo.dsa.TypeMapUnmanaged;
const String = coreo.str.string.StringManaged;

pub fn main(init: std.process.Init) !void {
    @setEvalBranchQuota(std.math.maxInt(u32));
    
    const gpa = init.gpa;
    var map = TypeMap([]const u8).empty;
    defer map.map.deinit(gpa);

    var buf = String.init(gpa);
    defer buf.deinit();

    try buf.pushStr("The quick brown fox jumps over the lazy dog.");
    try buf.push('\n');
    try buf.pushStr("Line two.");

    println("{f}", .{buf});

    println("Hash for u32: {d}", .{comp.typing.typeHash(u32)});

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
        break :blk comp.internArray(u32, ids);
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
