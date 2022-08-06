const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var triangle = rt.tri.Triangle.init(
        rt.tup.point(-5, -5, 10), rt.tup.point(0, 2.5, 0), rt.tup.point(5, -5, 3));
    triangle.common_attrs.material = .{
        .color = rt.cnv.Color{1, 1, 0.25},
        .ambient = 0.5,
        .specular = 0,
    };

    const world = rt.wrd.World{
        .allocator = allocator,
        .light = .{
            .intensity = rt.cnv.Color{0.9, 0.9, 0.9},
            .position = rt.tup.point(0, 0, -10),
        },
        .triangles = &.{ triangle },
    };

    const image_width = 512;
    const image_height = 512;
    const field_of_view = std.math.pi / 2.0;
    var camera = rt.cam.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(0, 0, -10);
    const to = rt.tup.point(0, 0, 0);
    const up = rt.tup.vector(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("skewed_triangle.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
