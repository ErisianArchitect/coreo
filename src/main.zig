const std = @import("std");
const coreo = @import("coreo");

const ObjectPool = coreo.dsa.ObjectPoolUnmanaged;

const comp = coreo.comp;

const typing = comp.typing;

const debug = coreo.debug;

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

pub fn main(init: std.process.Init) !void {
    // _ = init;
    const alloc = init.gpa;
    var pool = ObjectPool([]const u8).init(alloc);
    defer pool.deinit(alloc);
    const hello = pool.push(alloc, "Hello, world!");
    const fox = pool.push(alloc, "The quick brown fox jumps over the lazy dog.");

    const get_hello = pool.get(hello) catch fail();
    const get_fox = pool.get(fox) catch fail();
    println("{s}", .{get_hello.*});
    println("{s}", .{get_fox.*});
}
