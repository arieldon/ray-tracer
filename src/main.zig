const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const Tuple = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn init(x: f32, y: f32, z: f32, w: f32) Tuple {
        return Tuple{
            .x = x,
            .y = y,
            .z = z,
            .w = w,
        };
    }

    pub fn initPoint(x: f32, y: f32, z: f32) Tuple {
        return Tuple{
            .x = x,
            .y = y,
            .z = z,
            .w = 1,
        };
    }

    pub fn initVector(x: f32, y: f32, z: f32) Tuple {
        return Tuple{
            .x = x,
            .y = y,
            .z = z,
            .w = 0,
        };
    }

    pub fn isPoint(self: Tuple) bool {
        return self.w == 1;
    }

    pub fn isVector(self: Tuple) bool {
        return self.w == 0;
    }

    pub fn add(self: Tuple, other: Tuple) Tuple {
        return Tuple{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
            .w = self.w + other.w,
        };
    }

    pub fn sub(self: Tuple, other: Tuple) Tuple {
        return Tuple{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
            .w = self.w - other.w,
        };
    }

    pub fn neg(self: Tuple) Tuple {
        return Tuple{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
            .w = -self.w,
        };
    }

    pub fn mul(self: Tuple, other: f32) Tuple {
        return Tuple{
            .x = self.x * other,
            .y = self.y * other,
            .z = self.z * other,
            .w = self.w * other,
        };
    }

    pub fn div(self: Tuple, other: f32) Tuple {
        return Tuple{
            .x = self.x / other,
            .y = self.y / other,
            .z = self.z / other,
            .w = self.w / other,
        };
    }
};

test "a tuple with w=1.0 is a point" {
    const a = Tuple.init(4.3, -4.2, 3.1, 1.0);

    try expect(a.x == 4.3);
    try expect(a.y == -4.2);
    try expect(a.z == 3.1);
    try expect(a.w == 1.0);

    try expect(a.isPoint() == true);
    try expect(a.isVector() == false);
}

test "a tuple with w=0 is a vector" {
    const a = Tuple.init(4.3, -4.2, 3.1, 0.0);

    try expect(a.x == 4.3);
    try expect(a.y == -4.2);
    try expect(a.z == 3.1);
    try expect(a.w == 0.0);

    try expect(a.isPoint() == false);
    try expect(a.isVector() == true);
}

test "point() creates tuples with w=1" {
    const p = Tuple.initPoint(4, -4, 3);
    try expectEqual(p, Tuple.init(4, -4, 3, 1));
}

test "vector() creates tuples with w=0" {
    const v = Tuple.initVector(4, -4, 3);
    try expectEqual(v, Tuple.init(4, -4, 3, 0));
}

test "adding two tuples" {
    const a1 = Tuple.init(3, -2, 5, 1);
    const a2 = Tuple.init(-2, 3, 1, 0);
    try expectEqual(Tuple.add(a1, a2), Tuple.init(1, 1, 6, 1));
}

test "subtracting two points" {
    const p1 = Tuple.initPoint(3, 2, 1);
    const p2 = Tuple.initPoint(5, 6, 7);
    try expectEqual(Tuple.sub(p1, p2), Tuple.initVector(-2, -4, -6));
}

test "subtracting a vector from a point" {
    const p = Tuple.initPoint(3, 2, 1);
    const v = Tuple.initVector(5, 6, 7);
    try expectEqual(Tuple.sub(p, v), Tuple.initPoint(-2, -4, -6));
}

test "subtracting two vectors" {
    const v1 = Tuple.initVector(3, 2, 1);
    const v2 = Tuple.initVector(5, 6, 7);
    try expectEqual(Tuple.sub(v1, v2), Tuple.initVector(-2, -4, -6));
}

test "subtracting a vector from the zero vector" {
    const zero = Tuple.initVector(0, 0, 0);
    const v = Tuple.initVector(1, -2, 3);
    try expectEqual(Tuple.sub(zero, v), Tuple.initVector(-1, 2, -3));
}

test "negating a tuple" {
    const a = Tuple.init(1, -2, 3, -4);
    try expectEqual(Tuple.neg(a), Tuple.init(-1, 2, -3, 4));
}

test "multiplying a tuple by a scalar" {
    const a = Tuple.init(1, -2, 3, -4);
    try expectEqual(Tuple.mul(a, 3.5), Tuple.init(3.5, -7, 10.5, -14));
}

test "multiplying a tuple by a fraction" {
    const a = Tuple.init(1, -2, 3, -4);
    try expectEqual(Tuple.mul(a, 0.5), Tuple.init(0.5, -1, 1.5, -2));
}

test "dividing a tuple by a scalar" {
    const a = Tuple.init(1, -2, 3, -4);
    try expectEqual(Tuple.div(a, 2), Tuple.init(0.5, -1, 1.5, -2));
}
