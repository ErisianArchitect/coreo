
const std = @import("std");
const meta = std.meta;

const comp = @import("root.zig");
const typing = comp.typing;

const fnInfo = typing.fnInfo;
const fnPtrInfo = typing.fnPtrInfo;
const PointerChild = typing.PointerChild;

const VTField = struct {
    name: [:0]const u8,
    Type: type,
};

const VTInfo = struct {
    const Self = @This();
    
    VTableT: type,
    fields: []const VTField,
};

fn vtInfo(comptime VTableT: type) VTInfo {
    return comptime ret:{
        const field_names = meta.fieldNames(VTableT);
        var fields: [field_names.len]VTField = undefined;
        @setEvalBranchQuota(1000 + field_names.len * 4);
        for (0.., field_names) |i, field_name| {
            fields[i] = .{
                .name = field_name,
                .Type = @FieldType(VTableT, field_name),
            };
        }
        break:ret VTInfo{
            .fields = fields,
            .VTableT = VTableT,
        };
    };
}

ignore_this_error_for_design;

pub const Fred = extern struct {

    ptr: *anyopaque,
    vtable: *const struct {
        foo: *const fn(self: Fred) void,
        bar: *const fn(self: Fred) void,
        baz: *const fn(self: Fred) void,
    };

    pub const init = createVTableInit(@This());
};
