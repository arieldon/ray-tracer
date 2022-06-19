const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const tuple = @import("tuple.zig");

pub const Color = @Vector(3, f32);

pub fn color(r: f32, g: f32, b: f32) Color {
    return .{ r, g, b };
}

pub const Canvas = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    pixels: []Color,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Canvas {
        var canvas = Canvas{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = try allocator.alloc(Color, width * height),
        };

        for (canvas.pixels) |*pixel| {
            pixel.* = .{ 0, 0, 0 };
        }

        return canvas;
    }

    pub fn deinit(self: *Canvas) void {
        self.allocator.free(self.pixels);
    }

    pub fn writePixel(self: *Canvas, x: u32, y: u32, pixel_color: Color) void {
        self.pixels[self.index(x, y)] = pixel_color;
    }

    pub fn pixelAt(self: *Canvas, x: u32, y: u32) Color {
        return self.pixels[self.index(x, y)];
    }

    pub fn toPPM(self: *Canvas, ppm_string: *std.ArrayList(u8)) !void {
        try std.fmt.format(ppm_string.writer(), "P3\n{d} {d}\n255\n", .{ self.width, self.height });
        for (self.pixels) |pixel| {
            const red = @round(std.math.clamp(pixel[0] * 255, 0, 255));
            const green = @round(std.math.clamp(pixel[1] * 255, 0, 255));
            const blue = @round(std.math.clamp(pixel[2] * 255, 0, 255));
            try std.fmt.format(ppm_string.writer(), "{d} {d} {d}\n", .{ red, green, blue });
        }
    }

    inline fn index(self: *Canvas, x: u32, y: u32) u32 {
        return y * self.width + x;
    }
};

test "creating a canvas" {
    var c = try Canvas.init(std.testing.allocator, 10, 20);
    defer c.deinit();

    for (c.pixels) |pixel| {
        try expectEqual(pixel, color(0, 0, 0));
    }
}

test "writing pixels to a canvas" {
    const red = color(1, 0, 0);

    var c = try Canvas.init(std.testing.allocator, 10, 20);
    defer c.deinit();

    c.writePixel(2, 3, red);
    try expectEqual(c.pixelAt(2, 3), red);
}

test "constructing the PPM header" {
    var c = try Canvas.init(std.testing.allocator, 0, 0);
    defer c.deinit();

    var ppm = std.ArrayList(u8).init(std.testing.allocator);
    defer ppm.deinit();

    try c.toPPM(&ppm);
    try expectEqualStrings("P3\n0 0\n255\n", ppm.items);
}

test "constructing the PPM pixel data" {
    const c1 = color(1.5, 0, 0);
    const c2 = color(0, 0.5, 0);
    const c3 = color(-0.5, 0, 1);

    var c = try Canvas.init(std.testing.allocator, 5, 3);
    defer c.deinit();

    c.writePixel(0, 0, c1);
    c.writePixel(2, 1, c2);
    c.writePixel(4, 2, c3);

    var ppm = std.ArrayList(u8).init(std.testing.allocator);
    defer ppm.deinit();

    try c.toPPM(&ppm);
    try expectEqualStrings(
        \\255 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 128 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 0
        \\0 0 255
        \\
    , ppm.items[11..]);
}
