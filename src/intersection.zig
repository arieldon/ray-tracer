const std = @import("std");
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");
const wrd = @import("world.zig");

pub const Intersection = struct {
    t: f64,
    shape: shp.Shape,
};

pub fn sortIntersections(xs: []Intersection) void {
    const static = struct {
        fn cmp(context: void, a: Intersection, b: Intersection) bool {
            _ = context;
            return a.t < b.t;
        }
    };
    std.sort.sort(Intersection, xs, {}, comptime static.cmp);
}

pub fn hit(xs: []Intersection) ?Intersection {
    sortIntersections(xs);
    for (xs) |x| if (x.t >= 0) return x;
    return null;
}

pub const Computation = struct {
    t: f64,
    shape_attrs: shp.CommonShapeAttributes,

    point: tup.Point,
    eye: tup.Vector,
    normal: tup.Vector,

    n1: f64,
    n2: f64,
    reflect: tup.Vector,
};

pub fn prepareComputations(i: Intersection, r: ray.Ray) Computation {
    var comps: Computation = undefined;

    // Copy properties of intersection.
    comps.t = i.t;

    // Precompute useful values.
    comps.point = r.position(i.t);
    comps.eye = -r.direction;

    switch (i.shape) {
        .sphere => |sphere| {
            comps.shape_attrs = sphere.common_attrs;
            comps.normal = sphere.normalAt(comps.point);
        },
        .plane => |plane| {
            comps.shape_attrs = plane.common_attrs;
            comps.normal = plane.normalAt(comps.point);
        },
        .cube => |cube| {
            comps.shape_attrs = cube.common_attrs;
            comps.normal = cube.normalAt(comps.point);
        },
        .cylinder => |cylinder| {
            comps.shape_attrs = cylinder.common_attrs;
            comps.normal = cylinder.normalAt(comps.point);
        },
        .cone => |cone| {
            comps.shape_attrs = cone.common_attrs;
            comps.normal = cone.normalAt(comps.point);
        },
        .triangle => |triangle| {
            comps.shape_attrs = triangle.common_attrs;
            comps.normal = triangle.normalAt(comps.point);
        },
    }
    if (tup.dot(comps.normal, comps.eye) < 0) comps.normal = -comps.normal;

    // Precompute reflection vector.
    comps.reflect = tup.reflect(r.direction, comps.normal);

    // Leave n1 and n2 undefined. Use prepareComputationsForRefraction() to
    // calculate these values.
    comps.n1 = undefined;
    comps.n2 = undefined;

    return comps;
}

pub fn prepareComputationsForRefraction(i: Intersection, r: ray.Ray, xs: []Intersection) Computation {
    // Calculate values of struct unrelated to refractive indices.
    var comps = prepareComputations(i, r);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ShapeList = std.TailQueue(Intersection);
    var containers = ShapeList{};

    for (xs) |x| {
        if (std.meta.eql(x, i)) {
            if (containers.len == 0) {
                comps.n1 = 1.0;
            } else {
                const last_intersection = containers.last.?.data;
                const material = switch (last_intersection.shape) {
                    .sphere => |sphere| sphere.common_attrs.material,
                    .plane => |plane| plane.common_attrs.material,
                    .cube => |cube| cube.common_attrs.material,
                    .cylinder => |cylinder| cylinder.common_attrs.material,
                    .cone => |cone| cone.common_attrs.material,
                    .triangle => |triangle| triangle.common_attrs.material,
                };
                comps.n1 = material.refractive_index;
            }
        }

        // If the intersection occurs with a shape already hit once by the ray,
        // then this subsequent intersection must be the ray exiting shape:
        // It's no longer necessary to track this shape. If the intersection
        // occurs with a shape not yet stored in the list, then append it to
        // calculate the subsequent intersection.
        var it = containers.first;
        while (it) |node| : (it = node.next) {
            if (std.meta.eql(node.data, x)) {
                _ = containers.remove(node);
                break;
            }
        } else {
            // FIXME Handle OutOfMemory error gracefully.
            const node = allocator.create(ShapeList.Node) catch unreachable;
            node.data = x;
            containers.append(node);
        }

        if (std.meta.eql(x, i)) {
            if (containers.len == 0) {
                comps.n2 = 1.0;
            } else {
                const last_intersection = containers.last.?.data;
                const material = switch (last_intersection.shape) {
                    .sphere => |sphere| sphere.common_attrs.material,
                    .plane => |plane| plane.common_attrs.material,
                    .cube => |cube| cube.common_attrs.material,
                    .cylinder => |cylinder| cylinder.common_attrs.material,
                    .cone => |cone| cone.common_attrs.material,
                    .triangle => |triangle| triangle.common_attrs.material,
                };
                comps.n2 = material.refractive_index;
            }
            break;
        }
    }

    return comps;
}

pub fn schlick(comps: Computation) f64 {
    // Schlick's approximation serves as an approximation for the Fresnel
    // equation, which determines the amounts of light reflected and refracted
    // at an intersection.
    var r0 = (comps.n1 - comps.n2) / (comps.n1 + comps.n2);
    r0 *= r0;

    var cos = tup.dot(comps.eye, comps.normal);
    if (comps.n1 > comps.n2) {
        const n = comps.n1 / comps.n2;
        const sin2_t = n * n * (1.0 - cos * cos);

        // Total internal reflection occurs in this case.
        if (sin2_t > 1.0) return 1.0;

        cos = @sqrt(1.0 - sin2_t);
    }

    return r0 + (1 - r0) * std.math.pow(f64, 1 - cos, 5);
}
