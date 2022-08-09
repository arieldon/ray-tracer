const std = @import("std");
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const tup = @import("tuple.zig");
const wrd = @import("world.zig");

const ThreadContext = struct {
    canvas: *cnv.Canvas,
    camera: *const Camera,
    world: *const wrd.World,
    rows_per_thread: u32,
};

pub const Camera = @This();

horizontal_size: u32,
vertical_size: u32,
field_of_view: f32,
half_width: f32,
half_height: f32,
pixel_size: f32,
transform: mat.Matrix,

pub fn camera(
    horizontal_size: u32, vertical_size: u32, field_of_view: f32,
    from: tup.Point, to: tup.Point, up: tup.Vector,
) Camera {
    const h = @intToFloat(f32, horizontal_size);
    const v = @intToFloat(f32, vertical_size);

    var c: Camera = undefined;

    c.horizontal_size = horizontal_size;
    c.vertical_size = vertical_size;
    c.field_of_view = field_of_view;
    c.transform = transformCameraPerspective(from, to, up);

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

fn transformCameraPerspective(from: tup.Point, to: tup.Point, up: tup.Vector) mat.Matrix {
    // Parameter `from` specifies the point *from* which the scene is viewed;
    // parameter `to` specifies the point at which *to* look; and parameter
    // `up` specifies which direction is up.
    const forward = tup.normalize(to - from);
    const left = tup.cross(forward, tup.normalize(up));
    const true_up = tup.cross(left, forward);
    const orientation = mat.Matrix{
        .{left[0], left[1], left[2], 0},
        .{true_up[0], true_up[1], true_up[2], 0},
        .{-forward[0], -forward[1], -forward[2], 0},
        .{0, 0, 0, 1},
    };
    return mat.mul(orientation, mat.translation(-from[0], -from[1], -from[2]));
}


pub fn rayForPixel(c: *const Camera, px: u32, py: u32) ray.Ray {
    const x_offset = (@intToFloat(f32, px) + 0.5) * c.pixel_size;
    const y_offset = (@intToFloat(f32, py) + 0.5) * c.pixel_size;

    const world_x = c.half_width - x_offset;
    const world_y = c.half_height - y_offset;

    const pixel = mat.mul(mat.inverse(c.transform), tup.point(world_x, world_y, -1));
    const origin = mat.mul(mat.inverse(c.transform), tup.point(0, 0, 0));
    const direction = tup.normalize(pixel - origin);

    return .{ .origin = origin, .direction = direction };
}

pub fn render(allocator: std.mem.Allocator, cam: Camera, world: wrd.World) !cnv.Canvas {
    var image = try cnv.canvas(allocator, cam.horizontal_size, cam.vertical_size);

    const number_of_threads = 8;
    const rows_per_thread = cam.vertical_size / number_of_threads;
    const context = ThreadContext{
        .canvas = &image,
        .camera = &cam,
        .world = &world,
        .rows_per_thread = rows_per_thread,
    };

    var i: u32 = 0;
    var threads: [number_of_threads]std.Thread = undefined;
    while (i < number_of_threads) : (i += 1)
        threads[i] = try std.Thread.spawn(.{}, renderInternal, .{&context, i * rows_per_thread});

    for (threads) |thread| thread.join();

    // NOTE Caller owns returned memory.
    return image;
}

fn renderInternal(context: *const ThreadContext, start_row: u32) void {
    const final_row = start_row + context.rows_per_thread;

    var y: u32 = start_row;
    while (y < final_row) : (y += 1) {
        var x: u32 = 0;
        while (x < context.camera.horizontal_size) : (x += 1) {
            const r = rayForPixel(context.camera, x, y);
            const color = wrd.colorAt(context.world, r);
            context.canvas.writePixel(x, y, color);
        }
    }
}
