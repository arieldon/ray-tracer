const std = @import("std");
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const tup = @import("tuple.zig");

pub const PointLight = struct {
    position: tup.Point,
    intensity: cnv.Color,
};
