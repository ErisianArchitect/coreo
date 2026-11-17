
const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn Bitmask(comptime bits: usize) type {
    return extern struct {
        const Self = @This();

        pub const BITSIZE: usize = bits;
        const MASK_COUNT: usize = (bits + 7) / 8;

        masks: [MASK_COUNT]u8,

        pub inline fn init() Self {
            return .{ .masks=@splat(0) };
        }

        inline fn assertInRange(bit: usize) void {
            if (comptime std.debug.runtime_safety) {
                if (bit > BITSIZE) {
                    const errmsg = comptime "Bit index is out of range.";
                    if (@inComptime()) {
                        @compileError(errmsg);
                    } else {
                        @panic(errmsg);
                    }
                }
            }
        }

        pub fn get(self: Self, bit: usize) bool {
            assertInRange(bit);
            const mask_index = bit >> 3;
            const bit_index: u3 = @truncate(bit);
            return (self.masks[mask_index] & (1 << bit_index)) != 0;
        }

        pub fn set(self: *Self, bit: usize, value: bool) void {
            assertInRange(bit);
            const mask_index = bit >> 3;
            const bit_index: u3 = @truncate(bit);
            if (value) {
                self.masks[mask_index] |= (1 << bit_index);
            } else {
                self.masks[mask_index] &= ~(1 << bit_index);
            }
        }

        pub fn toggle(self: *Self, bit: usize) void {
            assertInRange(bit);
            const mask_index = bit >> 3;
            const bit_index: u3 = @truncate(bit);
            self.masks[mask_index] ^= (1 << bit_index);
        }

        pub fn clear(self: *Self) void {
            @memset(&self.masks, 0);
        }
    };
}

pub const BitsetUnmanaged = extern struct {
    const Self = @This();

    masks: []u8,

    pub const Error = Allocator.Error || error {};

    pub fn init(alloc: Allocator, bits: usize) (Error!Self) {
        const mask_count = (bits + 7) / 8;
        const masks: []u8 = try alloc.alloc(u8, mask_count);
        return .{ .masks = masks };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        alloc.free(self.masks);
        self.* = undefined;
    }

    pub fn get(self: Self, bit: usize) bool {
        if (std.debug.runtime_safety and bit > self.masks.len)
            @panic("Bit index is out of range.");
        const mask_index = bit >> 3;
        const bit_index: u3 = @truncate(bit);
        return (self.masks[mask_index] & (1 << bit_index)) != 0;
    }

    pub fn set(self: *Self, bit: usize, value: bool) void {
        if (std.debug.runtime_safety and bit > self.masks.len)
            @panic("Bit index is out of range.");
        const mask_index = bit >> 3;
        const bit_index: u3 = @truncate(bit);
        if (value) {
            self.masks[mask_index] |= (1 << bit_index);
        } else {
            self.masks[mask_index] &= ~(1 << bit_index);
        }
    }

    pub fn toggle(self: *Self, bit: usize) void {
        if (std.debug.runtimee_safety and bit > self.masks.len)
            @panic("Bit index is out of range.");
        const mask_index = bit >> 3;
        const bit_index: u3 = @truncate(bit);
        self.masks[mask_index] ^= (1 << bit_index);
    }

    pub fn clear(self: *Self) void {
        @memset(&self.masks, 0);
    }
};
