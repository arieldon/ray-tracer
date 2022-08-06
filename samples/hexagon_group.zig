const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var hexagon = try createHexagon(allocator);
    hexagon.transform = rt.mat.mul(
        rt.mat.rotationX(std.math.pi / 3.0),
        rt.mat.rotationY(std.math.pi / 4.0));
    defer hexagon.deinit();

    const world = rt.wrd.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(0, 0, -10),
            .intensity = rt.cnv.Color{1, 1, 1},
        },
        .groups = &.{ hexagon },
    };

    const image_width = 512;
    const image_height = 512;
    const field_of_view = std.math.pi / 4.0;
    var camera = rt.cam.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(0, 0, -5);
    const to = rt.tup.point(0, 0, 0);
    const up = rt.tup.vector(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("hexagon_group.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}

fn createHexagonCorner() rt.sph.Sphere {
    return rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(0, 0, -1), rt.mat.scaling(0.25, 0.25, 0.25)),
        },
    };
}

fn createHexagonEdge() rt.cyl.Cylinder {
    return rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 1.0,
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.mul(rt.mat.translation(0, 0, -1), rt.mat.rotationY(-std.math.pi / 6.0)),
                rt.mat.mul(rt.mat.rotationZ(-std.math.pi / 2.0), rt.mat.scaling(0.25, 1, 0.25))),
        },
    };
}

fn createHexagonSide(allocator: std.mem.Allocator) !rt.grp.Group {
    var side = rt.grp.Group.init(allocator, rt.mat.identity);
    try side.spheres.append(createHexagonCorner());
    try side.cylinders.append(createHexagonEdge());
    return side;
}

fn createHexagon(allocator: std.mem.Allocator) !rt.grp.Group {
    var hexagon = rt.grp.Group.init(allocator, rt.mat.identity);

    var n: u8 = 0;
    while (n < 6) : (n += 1) {
        var side = try createHexagonSide(allocator);
        side.transform = rt.mat.rotationY(@intToFloat(f64, n) * std.math.pi / 3.0);
        try hexagon.subgroups.append(side);
    }

    return hexagon;
}
