const std = @import("std");
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const tup = @import("tuple.zig");

const black = cnv.color(0, 0, 0);
const white = cnv.color(1, 1, 1);

pub const StripePattern = struct {
    a: cnv.Color = white,
    b: cnv.Color = black,

    pub fn stripeAt(self: *const StripePattern, point: tup.Point) cnv.Color {
        return if (@mod(@floor(point[0]), 2) == 0) self.a else self.b;
    }
};

test "creating a stripe pattern" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.a, white);
    try expectEqual(pattern.b, black);
}

test "a stripe pattern is constant in y" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 1, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 2, 0)), white);
}

test "a stripe pattern is constant in z" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 1)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 2)), white);
}

test "a striple pattern alternates in x" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0.9, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(1, 0, 0)), black);
    try expectEqual(pattern.stripeAt(tup.point(-0.1, 0, 0)), black);
    try expectEqual(pattern.stripeAt(tup.point(-1, 0, 0)), black);
    try expectEqual(pattern.stripeAt(tup.point(-1.1, 0, 0)), white);
}
