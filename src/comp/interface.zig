
const std = @import("std");

const typing = @import("root.zig").typing;

const meta = std.meta;

pub const Error = error {
    IsGeneric,
    IsVarArgs,
};

pub fn expectInterfaceFunction(comptime T: type) (Error!void) {
    const fninf = @typeInfo(T).@"fn";
    if (fninf.is_generic) return Error.IsGeneric;
    if (fninf.return_type == null) return Error.IsGeneric;
    if (fninf.attrs.varargs) return Error.IsVarArgs;
    if (fninf.param_types.len > 0) {
        for (fninf.param_types) |param| {
            if (param == null) return Error.IsGeneric;
        }
    }
}

const VT = struct {
    foo: *const fn(self: *anyopaque)
};

pub fn expectMatchesInterfaceFunction(comptime Host: type, comptime InterfaceFn: type, comptime ImplFn: type) bool {
    comptime expectInterfaceFunction(InterfaceFn) catch |err| @compileError("Error for Interface function: " ++ @errorName(err));
    comptime expectInterfaceFunction(ImplFn) catch |err| @compileError("Error for Impl function: " ++ @errorName(err));
    
}

pub fn VTable(comptime Host: type, comptime Interface: type) type {
    comptime {
        for (meta.fieldNames(Interface)) |field_name| {
            expectInterfaceFunction(typing.PointerChild(@TypeOf(@field(Interface, field_name))));
        }
    }
    return extern struct {
        const Self = @This();
        
        ptr: *const Interface,

        pub fn of(comptime T: type) Self {
            return struct {
                pub const storage = ret: {
                    var vtable: Interface = undefined;
                    for (meta.fieldNames(Interface)) |field_name| {
                        if (!@hasDecl(T, field_name)) @compileError("Missing decl: " ++ field_name);
                        // TODO: Check parameters.
                        if (matchesInterfaceFunction(Host, @FieldType(Interface, field_name), @TypeOf(@field(T, field_name)));
                        expectInterfaceFunction(@TypeOf(@field(T, field_name)));
                        @field(vtable, field_name) = @ptrCast(&@field(T, field_name));
                    }
                    break :ret vtable;
                };
                pub const result: Self = .{.ptr = &storage};
            }.result;
        }
    };
}

