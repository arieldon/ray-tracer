const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const cone = rt.Cone{
        .common_attrs = .{
            .transform = rt.mat.rotationX(-std.math.pi / 6.0),
        },
        .minimum = -2.0,
        .maximum = 2.0,
        .closed = false,
    };

    const world = rt.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(0, 0, -10),
            .intensity = rt.Color{1, 1, 1},
        },
        .cones = &.{ cone },
    };

    const image_width = 512;
    const image_height = 512;
    const field_of_view = std.math.pi / 2.0;
    const from = rt.tup.point(0, 0, -5);
    const to = rt.tup.point(0, 0.3, 0);
    const up = rt.tup.vector(0, 1, 0);
    var camera = rt.camera(image_width, image_height, field_of_view, from, to, up);

    var canvas = try rt.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("cone.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
