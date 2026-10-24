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

fn orFail(result: anytype) @typeInfo(@TypeOf(result)).error_union.payload {
    return result catch fail();
}

const testFailure = debug.failure("Test Failure");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    var pool = ObjectPool([]const u8).init(alloc);
    defer pool.deinit(alloc);
    const hello = pool.push(alloc, "Hello, world!");
    const fox = pool.push(alloc, "The quick brown fox jumps over the lazy dog.");

    const get_hello = pool.get(hello) catch fail();
    const get_fox = pool.get(fox) catch fail();
    println("{s}", .{get_hello.*});
    println("{s}", .{get_fox.*});
    qprintln("--------");
    for (pool.slice()) |it| {
        println("It: {s}", .{it});
    }
    const pop_hello = orFail(pool.pop(hello));
    println("pop_hello: {s}", .{pop_hello});
    qprintln("--------");
    for (pool.slice()) |it| {
        println("It: {s}", .{it});
    }
    const foo = pool.push(alloc, "foo");
    qprintln("--------");
    for (pool.slice()) |it| {
        println("It: {s}", .{it});
    }
    _=orFail(pool.pop(foo));
    qprintln("--------");
    for (pool.slice()) |it| {
        println("It: {s}", .{it});
    }
    const bar = pool.push(alloc, "bar");
    qprintln("--------bar");
    for (pool.slice()) |it| {
        println("It: {s}", .{it});
    }
    _=orFail(pool.pop(bar));
    qprintln("--------");
    for (pool.slice()) |it| {
        println("It: {s}", .{it});
    }
    println("Size of ObjectPool: {d}", .{@sizeOf(ObjectPool(void))});
}
