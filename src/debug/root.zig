
const std = @import("std");
const builtin = @import("builtin");

const comp = @import("comp");

pub const checking = @import("checking.zig");
pub const assert = @import("assert.zig");

comptime {
    @import("debug").checking.checkAllDecls(
        @import("CFG").CHECK,
        &.{
            checking,
            assert,
        },
    );
}

pub const print = std.debug.print;

pub inline fn println(comptime fmt: []const u8, args: anytype) void {
    print(fmt ++ "\n", args);
}

inline fn autoFmt(comptime T: type) []const u8 {
    return comptime switch (comp.typing.isString(T)) {
        false => "{any}",
        true => "{s}",
    };
}

pub inline fn qprint(value: anytype) void {
    print(autoFmt(@TypeOf(value)), .{value});
}

pub inline fn qprintln(value: anytype) void {
    print(autoFmt(@TypeOf(value)) ++ "\n", .{value});
}

pub fn srcMessage(comptime msg: []const u8, src: std.debug.SourceLocation) []const u8 {
    return std.fmt.comptimePrint("{s}: {s}:{d}:{d}", .{msg, src.file_name, src.line, src.column});
}

pub inline fn unimplemented(loc: ?std.debug.SourceLocation, use: anytype) noreturn {
    _ = use;
    const msg = if (loc) |src| srcMessage("Unimplemented", src) else "Unimplmented.";
    if (@inComptime()) {
        @compileError(msg);
    } else {
        @panic(msg);
    }
}

pub fn isSafeBuild() bool {
    return switch (builtin.mode) {
        .debug => true,
        .safe => true,
        else => false,
    };
}

pub const SAFE_BUILD = isSafeBuild();
