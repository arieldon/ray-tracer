const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const tup = @import("tuple.zig");
const tri = @import("triangle.zig");

const Vertex = tup.Point;
const Face = tri.Triangle;
const Group = std.ArrayList(Face);

const ParserCommand = enum {
    /// Define a new vertex.
    vertex,

    /// Define a new face, where a face consists of three points that form a
    /// triangle or four or more points that form a polygon. The parser then
    /// converts the latter into triangles.
    face,

    /// Specify a group name for the next face.
    group,
};

const ParserError = error {
    InvalidCommandArity,
};

const ObjFile = struct {
    allocator: std.mem.Allocator,

    vertices: std.ArrayList(Vertex),
    faces: std.ArrayList(Face),
    groups: std.StringHashMap(Group),

    number_of_ignored_commands: usize = 0,

    pub fn deinit(self: *ObjFile) void {
        self.vertices.deinit();
        self.faces.deinit();

        var group_iter = self.groups.iterator();
        while (group_iter.next()) |named_group| {
            self.allocator.free(named_group.key_ptr.*);
            named_group.value_ptr.deinit();
        }
        self.groups.deinit();
    }
};

pub fn parseObjFile(allocator: std.mem.Allocator, file: std.fs.File) !ObjFile {
    // FIXME What if there are two spaces in between parameters?

    var obj = ObjFile{
        .allocator = allocator,
        .vertices = std.ArrayList(Vertex).init(allocator),
        .faces = std.ArrayList(Face).init(allocator),
        .groups = std.StringHashMap(Group).init(allocator),
    };
    errdefer obj.deinit();

    // In OBJ file format, index count begins from 1 instead of 0. Fill the
    // zeroth slot of the list of vertices with a sentinel -- it shouldn't be
    // referenced at any point.
    try obj.vertices.append(undefined);

    var contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(contents);

    var current_group_name: ?[]const u8 = null;
    var line_start: usize = 0;
    iterate_contents: for (contents) |contents_character, contents_index| {
        if (contents_character == '\n') {
            // At the end of this block, update start of line marker for
            // interpretation of next command. Use `defer` to update the this
            // marker after `continue` statements as well.
            defer line_start = contents_index + 1;

            // Handle blank lines.
            if (contents_index - line_start == 0) {
                // Blank lines end groups of faces.
                current_group_name = null;
                continue :iterate_contents;
            }

            // Increment copy of index in contents to include newline character.
            const line_end = contents_index + 1;
            const line = contents[line_start..line_end];

            // Define variables and separate command.
            var command_start: usize = 0;
            var command_end: usize =
                for (line) |literal_character, line_index| {
                    if (literal_character == ' ') break line_index;
                } else 0;
            var command_string = line[command_start..command_end];

            // Parse command.
            var command: ParserCommand = undefined;
            if (std.mem.eql(u8, command_string, "v")) {
                command = .vertex;
            } else if (std.mem.eql(u8, command_string, "f")) {
                command = .face;
            } else if (std.mem.eql(u8, command_string, "g")) {
                command = .group;
            } else {
                // Ignore invalid or unsupported commands silently.
                obj.number_of_ignored_commands += 1;
                continue :iterate_contents;
            }

            // Parse and handle command parameters.
            var literal_start: usize = command_end + 1;
            var literal_end: usize = undefined;
            switch (command) {
                .vertex => {
                    var vertex_component: usize = 0;
                    var vertex = tup.point(undefined, undefined, undefined);
                    for (line[literal_start..]) |literal_character, literal_index| {
                        if (literal_character == ' ' or literal_character == '\n') {
                            literal_end = command_end + 1 + literal_index;
                            vertex[vertex_component] = try std.fmt.parseFloat(
                                f64,
                                line[literal_start..literal_end]);
                            literal_start = literal_end + 1;
                            vertex_component += 1;
                        }
                    }

                    if (vertex_component != 3) return ParserError.InvalidCommandArity;
                    try obj.vertices.append(vertex);

                    // Assign face to group if specified.
                    if (current_group_name) |group_name| {
                        const entry = try obj.groups.getOrPut(try allocator.dupe(u8, group_name));
                        if (!entry.found_existing) {
                            // Initialize array list for new sequence of faces
                            // in this group.
                            entry.value_ptr.* = Group.init(allocator);
                        }

                        // Append face to named group.
                        try entry.value_ptr.append(obj.faces.items[obj.faces.items.len - 1]);
                    }
                },
                .face => {
                    var vertex_indeces = try std.ArrayList(usize).initCapacity(allocator, 3);
                    defer vertex_indeces.deinit();

                    for (line[literal_start..]) |literal_character, literal_index| {
                        if (literal_character == ' ' or literal_character == '\n') {
                            literal_end = command_end + 1 + literal_index;
                            const vertex_index = try std.fmt.parseInt(
                                usize, line[literal_start..literal_end], 10);
                            try vertex_indeces.append(vertex_index);
                            literal_start = literal_end + 1;
                        }
                    }

                    if (vertex_indeces.items.len < 3) {
                        return ParserError.InvalidCommandArity;
                    } else if (vertex_indeces.items.len > 3) {
                        try triangulatePolygon(&obj, vertex_indeces.items);
                    } else {
                        try obj.faces.append(Face.init(
                            obj.vertices.items[vertex_indeces.items[0]],
                            obj.vertices.items[vertex_indeces.items[1]],
                            obj.vertices.items[vertex_indeces.items[2]]));
                    }

                    // Assign face to group if specified.
                    if (current_group_name) |group_name| {
                        const entry = try obj.groups.getOrPut(try allocator.dupe(u8, group_name));
                        if (!entry.found_existing) {
                            // Initialize array list for new sequence of faces
                            // in this group.
                            entry.value_ptr.* = Group.init(allocator);
                        }

                        // Append face to named group.
                        try entry.value_ptr.append(obj.faces.items[obj.faces.items.len - 1]);
                    }
                },
                .group => {
                    for (line[literal_start..]) |literal_character, literal_index| {
                        if (literal_character == ' ' or literal_character == '\n') {
                            literal_end = command_end + 1 + literal_index;
                            current_group_name = line[literal_start..literal_end];
                            break;
                        }
                    } else return ParserError.InvalidCommandArity;
                },
            }
        }
    }

    // NOTE Caller owns returned memory.
    return obj;
}

/// Convert some convex polygon to a set of triangles, where a convex polygon
/// is a polygon whose interior angles are all less than or equal to 180
/// degrees.
fn triangulatePolygon(obj: *ObjFile, vertex_indeces: []usize) !void {
    std.debug.assert(vertex_indeces.len > 3);
    for (vertex_indeces[1..vertex_indeces.len]) |_, index| {
        try obj.faces.append(Face.init(
            obj.vertices.items[vertex_indeces[0]],
            obj.vertices.items[vertex_indeces[index]],
            obj.vertices.items[vertex_indeces[index + 1]]));
    }
}

test "ignoring unrecognized lines" {
    // This file contains nonsense.
    const file = try std.fs.cwd().openFile("foo.obj", .{});
    defer file.close();

    var obj = try parseObjFile(std.testing.allocator, file);
    defer obj.deinit();

    try expectEqual(obj.number_of_ignored_commands, 5);
}

test "vertex records" {
    const file = try std.fs.cwd().openFile("vertex_records.obj", .{});
    defer file.close();

    var obj = try parseObjFile(std.testing.allocator, file);
    defer obj.deinit();

    try expectEqual(obj.vertices.items[1], tup.point(-1, 1, 0));
    try expectEqual(obj.vertices.items[2], tup.point(-1, 0.5, 0));
    try expectEqual(obj.vertices.items[3], tup.point(1, 0, 0));
    try expectEqual(obj.vertices.items[4], tup.point(1, 1, 0));
}

test "parsing triangle faces" {
    const file = try std.fs.cwd().openFile("triangle_faces.obj", .{});
    defer file.close();

    var obj = try parseObjFile(std.testing.allocator, file);
    defer obj.deinit();

    const p1 = tup.point(-1, 1, 0);
    const p2 = tup.point(-1, 0, 0);
    const p3 = tup.point(1, 0, 0);
    const p4 = tup.point(1, 1, 0);

    const t0 = Face.init(p1, p2, p3);
    const t1 = Face.init(p1, p3, p4);

    try expectEqual(obj.vertices.items[1], p1);
    try expectEqual(obj.vertices.items[2], p2);
    try expectEqual(obj.vertices.items[3], p3);
    try expectEqual(obj.vertices.items[4], p4);
    try expectEqual(obj.faces.items[0], t0);
    try expectEqual(obj.faces.items[1], t1);
}

test "triangulating polygons" {
    const file = try std.fs.cwd().openFile("triangulating_polygons.obj", .{});
    defer file.close();

    var obj = try parseObjFile(std.testing.allocator, file);
    defer obj.deinit();

    const t0 = Face.init(tup.point(-1, 1, 0), tup.point(-1, 0, 0), tup.point(1, 0, 0));
    const t1 = Face.init(tup.point(-1, 1, 0), tup.point(1, 0, 0), tup.point(1, 1, 0));
    const t2 = Face.init(tup.point(-1, 1, 0), tup.point(1, 1, 0), tup.point(0, 2, 0));

    try expectEqual(t0.p0, obj.vertices.items[1]);
    try expectEqual(t0.p1, obj.vertices.items[2]);
    try expectEqual(t0.p2, obj.vertices.items[3]);

    try expectEqual(t1.p0, obj.vertices.items[1]);
    try expectEqual(t1.p1, obj.vertices.items[3]);
    try expectEqual(t1.p2, obj.vertices.items[4]);

    try expectEqual(t2.p0, obj.vertices.items[1]);
    try expectEqual(t2.p1, obj.vertices.items[4]);
    try expectEqual(t2.p2, obj.vertices.items[5]);
}

test "triangles in groups" {
    const file = try std.fs.cwd().openFile("triangles.obj", .{});
    defer file.close();

    var obj = try parseObjFile(std.testing.allocator, file);
    defer obj.deinit();

    try expect(obj.groups.contains("FirstGroup"));
    try expect(obj.groups.contains("SecondGroup"));

    const g0 = obj.groups.get("FirstGroup").?;
    const g1 = obj.groups.get("SecondGroup").?;

    const t0 = g0.items[0];
    const t1 = g1.items[0];

    try expectEqual(t0.p0, obj.vertices.items[1]);
    try expectEqual(t0.p1, obj.vertices.items[2]);
    try expectEqual(t0.p2, obj.vertices.items[3]);

    try expectEqual(t1.p0, obj.vertices.items[1]);
    try expectEqual(t1.p1, obj.vertices.items[3]);
    try expectEqual(t1.p2, obj.vertices.items[4]);
}
