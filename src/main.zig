const std = @import("std");

pub const cnv = @import("canvas.zig");
pub const int = @import("intersection.zig");
pub const lht = @import("light.zig");
pub const mat = @import("matrix.zig");
pub const mtl = @import("material.zig");
pub const ray = @import("ray.zig");
pub const sph = @import("sphere.zig");
pub const tup = @import("tuple.zig");
pub const wrd = @import("world.zig");

test {
    std.testing.refAllDecls(@This());
}
