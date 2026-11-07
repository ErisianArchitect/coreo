const std = @import("std");
const coreo = @import("coreo");

const ObjectPool = coreo.dsa.ObjectPoolUnmanaged;
const VecUnmanaged = coreo.dsa.VecUnmanaged;
const VecManaged = coreo.dsa.VecManaged;

const comp = coreo.comp;
const interface = comp.interface;
const typing = comp.typing;
const debug = coreo.debug;
const ffi = coreo.ffi;
const str = coreo.str;

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

fn foo(input: []const u8) void {
    println("{s}", .{input});
}

const State = enum(usize) {
    unlocked,
    locked,
    _,
};

pub const VTableTest = struct {
    const Self = @This();

    ptr: *anyopaque,
    vtable: interface.VTable(struct {
        foo: *const fn(self: *anyopaque) void,
    }),

    pub fn init(ptr: anytype) Self {
        const Child = typing.PointerChild(@TypeOf(ptr));
        return .{
            .ptr = ptr,
            .vtable = .of(Child),
        };
    }

    pub fn foo(self: Self) void {
        self.vtable.ptr.foo(self.ptr);
    }
};

pub const FooFighter = struct {
    name: []const u8,
    
    pub fn foo(self: *@This()) void {
        println("Name: {s}", .{self.name});
    }
};

pub fn main(init: std.process.Init) !void {
    _=init;
    var fighter = FooFighter{.name = "Fred"};
    const erased = VTableTest.init(&fighter);
    erased.foo();
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
