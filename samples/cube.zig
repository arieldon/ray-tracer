const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const cube = rt.cub.Cube{
        .shape = .{
            .shape_type = .cube,
            .transform = rt.mat.rotationY(std.math.pi / 4.0),
        },
    };

    var world = rt.wrd.world(allocator);
    defer world.deinit();

    world.light = rt.lht.PointLight{
        .intensity = rt.cnv.Color{0.9, 0.9, 0.9},
        .position = rt.tup.point(0, 0, -10),
    };

    try world.cubes.append(cube);

    const image_width = 1024;
    const image_height = 1024;
    const field_of_view = std.math.pi / 3.0;
    var camera = rt.cam.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(0, 5, -5);
    const to = rt.tup.point(0, 0, 0);
    const up = rt.tup.vector(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("cube.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
