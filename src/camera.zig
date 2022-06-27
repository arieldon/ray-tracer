const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const trm = @import("transformation.zig");
const tup = @import("tuple.zig");
const wrd = @import("world.zig");

pub const Camera = struct {
    horizontal_size: u32,
    vertical_size: u32,
    field_of_view: f32,
    half_width: f32,
    half_height: f32,
    pixel_size: f32,
    transform: mat.Matrix,
};

pub fn camera(horizontal_size: u32, vertical_size: u32, field_of_view: f32) Camera {
    const h = @intToFloat(f32, horizontal_size);
    const v = @intToFloat(f32, vertical_size);

    var c: Camera = undefined;

    c.horizontal_size = horizontal_size;
    c.vertical_size = vertical_size;
    c.field_of_view = field_of_view;
    c.transform = mat.identity;

    const half_view = std.math.tan(c.field_of_view / 2.0);
    const aspect_ratio = h / v;
    if (aspect_ratio >= 1) {
        c.half_width = half_view;
        c.half_height = half_view / aspect_ratio;
    } else {
        c.half_width = half_view * aspect_ratio;
        c.half_height = half_view;
    }
    c.pixel_size = (c.half_width * 2) / h;

    return c;
}

pub fn rayForPixel(c: Camera, px: u32, py: u32) ray.Ray {
    const x_offset = (@intToFloat(f32, px) + 0.5) * c.pixel_size;
    const y_offset = (@intToFloat(f32, py) + 0.5) * c.pixel_size;

    const world_x = c.half_width - x_offset;
    const world_y = c.half_height - y_offset;

    const pixel = mat.mul(mat.inverse(c.transform), tup.point(world_x, world_y, -1));
    const origin = mat.mul(mat.inverse(c.transform), tup.point(0, 0, 0));
    const direction = tup.normalize(pixel - origin);

    return ray.ray(origin, direction);
}

pub fn render(allocator: std.mem.Allocator, c: Camera, w: wrd.World) !cnv.Canvas {
    // The responsibility to free this canvas lies on the environment to which
    // this function returns it.
    var image = try cnv.canvas(allocator, c.horizontal_size, c.vertical_size);

    var y: u32 = 0;
    while (y < c.vertical_size) : (y += 1) {
        var x: u32 = 0;
        while (x < c.horizontal_size) : (x += 1) {
            const r = rayForPixel(c, x, y);
            const color = try wrd.colorAt(w, r);
            image.writePixel(x, y, color);
        }
    }

    return image;
}

test "constructing a camera" {
    const horizontal_size = 160;
    const vertical_size = 120;
    const field_of_view = std.math.pi / 2.0;
    const c = camera(horizontal_size, vertical_size, field_of_view);
    try expectEqual(c.horizontal_size, 160);
    try expectEqual(c.vertical_size, 120);
    try expectEqual(c.field_of_view, std.math.pi / 2.0);
    try expectEqual(c.transform, mat.identity);
}

test "the pixel size for a horizontal canvas" {
    const c = camera(200, 125, std.math.pi / 2.0);
    try expectEqual(c.pixel_size, 0.01);
}

test "the pixel size for a vertical canvas" {
    const c = camera(125, 200, std.math.pi / 2.0);
    try expectEqual(c.pixel_size, 0.01);
}

test "constructing a ray through the center of the canvas" {
    const c = camera(201, 101, std.math.pi / 2.0);
    const r = rayForPixel(c, 100, 50);
    try expect(tup.equal(r.origin, tup.point(0, 0, 0), 0.00001));
    try expect(tup.equal(r.direction, tup.vector(0, 0, -1), 0.00001));
}

test "constructing a ray through a corner of the canvas" {
    const c = camera(201, 101, std.math.pi / 2.0);
    const r = rayForPixel(c, 0, 0);
    try expect(tup.equal(r.origin, tup.point(0, 0, 0), 0.00001));
    try expect(tup.equal(r.direction, tup.vector(0.66519, 0.33259, -0.66851), 0.00001));
}

test "constructing a ray when the camera is transformed" {
    var c = camera(201, 101, std.math.pi / 2.0);
    c.transform = mat.mul(mat.rotationY(std.math.pi / 4.0), mat.translation(0, -2, 5));
    const r = rayForPixel(c, 100, 50);
    const a = @sqrt(2.0) / 2.0;
    try expect(tup.equal(r.origin, tup.point(0, 2, -5), 0.00001));
    try expect(tup.equal(r.direction, tup.vector(a, 0, -a), 0.00001));
}

test "rendering a world with a camera" {
    var w = try wrd.defaultWorld(std.testing.allocator);
    defer w.deinit();

    const from = tup.point(0, 0, -5);
    const to = tup.point(0, 0, 0);
    const up = tup.vector(0, 1, 0);
    var c = camera(11, 11, std.math.pi / 2.0);
    c.transform = trm.viewTransform(from, to, up);

    var image = try render(std.testing.allocator, c, w);
    defer image.deinit();

    try expect(cnv.equal(image.pixelAt(5, 5), cnv.color(0.38066, 0.47583, 0.2855)));
}
