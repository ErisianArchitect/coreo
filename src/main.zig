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

fn uniName(comptime tag: anytype) []const u8 {
    // main.Uni__struct_
    const type_name = comptime @typeName(Uni(tag));
    return comptime type_name;
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

pub fn main(init: std.process.Init) !void {
    _=init;
    const f = VkEnum.Foo | VkEnum.Bar;
}

fn uniqueNameTest() !void {
    qprintln(@typeName(comp.typing.Unique(u16)));
    qprintln(@typeName(comp.typing.Unique(u32)));
    qprintln(@typeName(comp.typing.Unique(u64)));
    qprintln(comp.typing.uniqueName(u16));
    qprintln(comp.typing.uniqueName(u32));
    qprintln(comp.typing.uniqueName(u64));
    qprintln(comp.typing.uniqueName(.{"foo"}));
    qprintln(comp.typing.uniqueName(.{"bar"}));
    qprintln(comp.typing.uniqueName(.{"baz"}));
}
