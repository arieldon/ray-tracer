const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const obj_file = try std.fs.cwd().openFile("teapot.obj", .{});
    defer obj_file.close();

    var obj = try rt.obj.parseObjFile(allocator, obj_file);
    defer obj.deinit();

    // Convert data that describes teapot from OBJ file into a group that the
    // ray tracer understands.
    var obj_group = try obj.toShapeGroup(allocator);
    defer obj_group.deinit();

    // Create a bounding box for the group.
    obj_group.bound();

    const world = rt.World{
        .allocator = allocator,
        .light = .{
            .intensity = rt.Color{1, 1, 1},
            .position = rt.tup.point(0, 0, -10),
        },
        .groups = &.{ obj_group },
    };

    const image_width = 256;
    const image_height = 256;
    const field_of_view = std.math.pi / 3.0;
    var camera = rt.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(0, 3, -10);
    const to = rt.tup.point(0, 0, 0);
    const up = rt.tup.vector(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.render(allocator, camera, world);
    defer canvas.deinit();

    const ppm_file = try std.fs.cwd().createFile("teapot.ppm", .{});
    defer ppm_file.close();

    try canvas.toPPM(ppm_file.writer());
}
