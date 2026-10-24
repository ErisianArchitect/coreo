
const std = @import("std");

const comp = @import("comp");

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

pub const FailureInput = struct {
    src: ?std.lang.SourceLocation = null,
    msg: ?[]const u8 = null,
};

/// `message` should not include trailing punctuation.
pub fn failure(comptime prefix: ?[]const u8) fn(comptime FailureInput) noreturn {
    return struct {
        const _prefix = prefix orelse "Error";
        pub fn failFn(comptime input: FailureInput) noreturn {
            const err_msg = comptime ret: {
                if (input.msg) |msg| {
                    break :ret std.fmt.comptimePrint("{s}: {s}", .{_prefix, msg});
                } else {
                    break :ret _prefix;
                }
            };
            const msg = comptime ret: {
                if (input.src) |src| {
                    break :ret std.fmt.comptimePrint("{s}\n{s}:{d}:{d}", .{err_msg, src.file, src.line, src.column});
                } else {
                    break :ret err_msg;
                }
            };
            if (@inComptime()) {
                @compileError(msg);
            } else {
                @panic(msg);
            }
        }
    }.failFn;
}

pub const outOfMemory = failure("Out of memory");
pub const todo = failure("TODO");
