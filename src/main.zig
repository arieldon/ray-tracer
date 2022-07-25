const std = @import("std");

pub const cam = @import("camera.zig");
pub const cnv = @import("canvas.zig");
pub const con = @import("cone.zig");
pub const cub = @import("cube.zig");
pub const cyl = @import("cylinder.zig");
pub const int = @import("intersection.zig");
pub const lht = @import("light.zig");
pub const mat = @import("matrix.zig");
pub const mtl = @import("material.zig");
pub const pat = @import("pattern.zig");
pub const pln = @import("plane.zig");
pub const ray = @import("ray.zig");
pub const shp = @import("shape.zig");
pub const sph = @import("sphere.zig");
pub const trm = @import("transformation.zig");
pub const tup = @import("tuple.zig");
pub const wrd = @import("world.zig");

test {
    std.testing.refAllDecls(@This());
}
