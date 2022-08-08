const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const tuple = @import("tuple.zig");

pub const Color = @Vector(3, f64);

pub const Canvas = @This();

allocator: std.mem.Allocator,
width: u32,
height: u32,
pixels: []Color,

pub fn canvas(allocator: std.mem.Allocator, width: u32, height: u32) !Canvas {
    var c = Canvas{
        .allocator = allocator,
        .width = width,
        .height = height,
        .pixels = try allocator.alloc(Color, width * height),
    };

    for (c.pixels) |*pixel| {
        pixel.* = .{ 0, 0, 0 };
    }

    return c;
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

pub fn toPPM(self: *Canvas, writer: anytype) !void {
    try std.fmt.format(writer, "P3\n{d} {d}\n255\n", .{ self.width, self.height });
    for (self.pixels) |pixel| {
        const red = @round(std.math.clamp(pixel[0] * 255, 0, 255));
        const green = @round(std.math.clamp(pixel[1] * 255, 0, 255));
        const blue = @round(std.math.clamp(pixel[2] * 255, 0, 255));
        try std.fmt.format(writer, "{d} {d} {d}\n", .{ red, green, blue });
    }
}

inline fn index(self: *Canvas, x: u32, y: u32) u32 {
    return y * self.width + x;
}
