
const std = @import("std");
const comp = @import("comp");

const PrivateToken = struct{};

const typeHash = comp.typeHash;

const BucketCalc = struct {
    const Self = @This();
    
    shift: u32,

    pub fn init(comptime bucket_count: usize) Self {
        comptime if (!std.math.isPowerOfTwo(bucket_count)) @compileError("bucket_count must be power of two.");
        const low_mask = bucket_count - 1;
        const low_bits: u32 = @ctz(~low_mask);
        const shift: u32 = 64 - low_bits;
        return .{.shift = shift};
    }

    pub inline fn index(comptime self: Self, comptime hash: u64) usize {
        return @as(usize, hash >> self.shift);
    }

    pub inline fn indexFor(comptime self: Self, comptime T: type) usize {
        return self.index(typeHash(T));
    }
};

pub inline fn bucketIndex(comptime bucket_count: usize, comptime T: type) usize {
    const calc = comptime BucketCalc.init(bucket_count);
    return comptime calc.indexFor(T);
}

pub const NotFound = error{NotFound};

pub fn StaticTypeMap(comptime ItemT: type) type {
    return struct {
        const Self = @This();
        pub const Item = ItemT;
        pub const Slot = struct {
            key: type,
            id: usize,
        };
        pub const Pair = struct {type, ItemT};
        
        buckets: []const []const Slot,
        pairs: []const Pair,
        len: usize,

        pub inline fn init(comptime items: []const struct { type, ItemT }) Self {
            return struct {
                pub const result: Self = ret: {
                    @setEvalBranchQuota(std.math.maxInt(u32));
                    const bucket_count = std.math.ceilPowerOfTwoAssert(usize, items.len);
                    const calc = BucketCalc.init(bucket_count);
                    var counts: [bucket_count]usize = @splat(0);
                    var slots: [items.len]Slot = undefined;
                    for (items) |item| {
                        const bucket = calc.indexFor(item[0]);
                        counts[bucket] += 1;
                    }
                    var offsets: [bucket_count]usize = @splat(0);
                    var count_offset = 0;
                    for (counts, 0..) |count, i| {
                        offsets[i] = count_offset;
                        count_offset += count;
                    }
                    for (items, 0..) |item, i| {
                        const bucket = calc.indexFor(item[0]);
                        slots[offsets[bucket]] = .{
                            .key = item[0],
                            .id = i,
                        };
                        offsets[bucket] += 1;
                    }
                    const interned_slots = comp.internArray(.immut, Slot, slots);
                    var buckets: [bucket_count][]const Slot = @splat(&.{});
                    var offset = 0;
                    for (counts, 0..) |count, i| {
                        if (count == 0) continue;
                        const bucket = interned_slots[offset..][0..count];
                        for (0..bucket.len - 1) |j| {
                            for (j+1..bucket.len) |k| {
                                if (bucket[j].key == bucket[k].key) @compileError("Duplicate type key: " ++ @typeName(bucket[j].key));
                            }
                        }
                        buckets[i] = bucket;
                        offset += count;
                    }
                    break :ret .{
                        .buckets = comp.internArray(.immut, []const Slot, buckets),
                        .pairs = items,
                        .len = items.len,
                    };
                };
            }.result;
        }

        pub inline fn bucketFor(comptime self: Self, comptime T: type) []const Slot {
            return self.buckets[bucketIndex(self.buckets.len, T)];
        }

        pub inline fn maxBucketSize(comptime self: Self) usize {
            return struct {
                pub const result = ret: {
                    @setEvalBranchQuota(std.math.maxInt(u32));
                    var max = 0;
                    for (self.buckets) |bucket| {
                        max = @max(bucket.len, max);
                    }
                    break :ret max;
                };
            }.result;
        }

        pub inline fn keys(comptime self: Self) []const type {
            return struct {
                pub const result = ret: {
                    @setEvalBranchQuota(std.math.maxInt(u32));
                    var buf: [self.len]type = undefined;
                    for (self.pairs, 0..) |p, i| {
                        buf[i] = p[0];
                    }
                    break :ret comp.internArray(.immut, type, buf);
                };
            }.result;
        }

        pub inline fn values(comptime self: Self) []const ItemT {
            return struct {
                pub const result = ret: {
                    @setEvalBranchQuota(std.math.maxInt(u32));
                    var buf: [self.len]ItemT = undefined;
                    for (self.pairs, 0..) |p, i| {
                        buf[i] = p[1];
                    }
                    break :ret comp.internArray(.immut, type, buf);
                };
            }.result;
        }

        pub inline fn find(comptime self: Self, comptime T: type) ?*const Slot {
            return struct {
                pub const result: ?*const Slot = ret: {
                    @setEvalBranchQuota(std.math.maxInt(u32));
                    const bucket_index = bucketIndex(self.buckets.len, T);
                    for (self.buckets[bucket_index]) |*slot| {
                        if (slot.key == T) break :ret slot;
                    }
                    break :ret null;
                };
            }.result;
        }

        pub inline fn has(comptime self: Self, comptime T: type) bool {
            return struct {
                pub const result = self.find(T) != null;
            }.result;
        }

        pub inline fn pairRef(comptime self: Self, comptime index: usize) *const Pair {
            comptime if (index >= self.len) @compileError("Index out of bounds.");
            return struct {
                pub const result = &self.pairs[index];
            }.result;
        }

        pub inline fn pair(comptime self: Self, comptime index: usize) Pair {
            comptime if (index >= self.len) @compileError("Index out of bounds.");
            return self.pairRef(index).*;
        }

        pub inline fn id(comptime self: Self, comptime T: type) usize {
            comptime if(!self.has(T)) @compileError("Type not found: " ++ @typeName(T));
            return struct {
                pub const result = self.find(T).?.id;
            }.result;
        }

        pub inline fn tryGetId(comptime self: Self, comptime T: type) NotFound!usize {
            if (comptime !self.has(T)) return error.NotFound;
            return self.id(T);
        }

        pub inline fn valRef(comptime self: Self, comptime T: type) *const ItemT {
            comptime if(!self.has(T)) @compileError("Type not found: " ++ @typeName(T));
            return struct {
                pub const result = &self.pairs[self.id(T)][1];
            }.result;
        }

        pub inline fn tryGetValRef(comptime self: Self, comptime T: type) NotFound!*const ItemT {
            if (comptime !self.has(T)) return error.NotFound;
            return self.valRef(T);
        }

        pub inline fn val(comptime self: Self, comptime T: type) ItemT {
            comptime if(!self.has(T)) @compileError("Type not found: " ++ @typeName(T));
            return self.valRef(T).*;
        }

        pub inline fn tryGetVal(comptime self: Self, comptime T: type) NotFound!ItemT {
            if (comptime !self.has(T)) return error.NotFound;
            return self.val(T);
        }
    };
}

pub const StaticTypeSet = struct {
    const Self = @This();

    map: StaticTypeMap(void),
    types: []const type,

    pub inline fn init(comptime type_list: []const type) Self {
        return struct {
            pub const result: Self = ret: {
                break :ret .{
                    .map = .init(comp.zipWithRight(.immut, type, {}, type_list)),
                    .types = type_list,
                };
            };
        }.result;
    }

    pub inline fn has(comptime self: Self, comptime T: type) bool {
        return self.map.has(T);
    }

    pub inline fn id(comptime self: Self, comptime T: type) usize {
        return self.map.id(T);
    }

    pub inline fn tryGetId(comptime self: Self, comptime T: type) NotFound!usize {
        return self.map.tryGetId(T);
    }
};

