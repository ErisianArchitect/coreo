
const std = @import("std");
const builtin = @import("builtin");

const debug = @import("debug");

/// Optionally provide a source location and a message.
pub const FailureInput = struct {
    src: ?std.lang.SourceLocation = null,
    msg: ?[]const u8 = null,
};

/// `message` should not include trailing punctuation.
pub fn failure(comptime prefix: ?[]const u8) fn(comptime input: FailureInput) noreturn {
    return struct {
        const _prefix = prefix orelse "Error";
        pub fn failFn(comptime input: FailureInput) noreturn {
            const err_msg = comptime ret: {
                if (input.msg) |msg| {
                    break :ret std.fmt.comptimePrint("{s}: {s}", .{_prefix, msg});
                } else {
                    break :ret std.fmt.comptimePrint("{s}.", .{_prefix});
                }
            };
            const msg = comptime ret: {
                if (input.src) |src| {
                    break :ret std.fmt.comptimePrint("{s}\n{s} in {s}\n{s}:{d}:{d}", .{err_msg, src.fn_name, src.module, src.file, src.line, src.column});
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

pub fn safeAssert(condition: bool, comptime input: FailureInput) void {
    const assertFailure = comptime failure("Assertion Failed");
    if (debug.SAFE_BUILD and !condition) assertFailure(input);
}
