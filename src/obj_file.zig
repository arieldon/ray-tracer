const std = @import("std");
const expectEqual = std.testing.expectEqual;
const tup = @import("tuple.zig");
const tri = @import("triangle.zig");

const Vertex = tup.Point;
const Face = tri.Triangle;

const ParserCommand = enum {
    /// Define a new vertex.
    vertex,
    /// Define a new face, where a face consists of three points that form a
    /// triangle.
    face,
};

const ParserError = error {
    InvalidCommandArity,
};

// TODO Rename this to ObjFile and create a separate struct named Parser to
// manage state in parseObjFile().
const Parser = struct {
    vertices: std.ArrayList(Vertex),
    faces: std.ArrayList(Face),
    number_of_ignored_commands: usize = 0,

    pub fn deinit(self: *Parser) void {
        self.vertices.deinit();
        self.faces.deinit();
    }
};

pub fn parseObjFile(allocator: std.mem.Allocator, file: std.fs.File) !Parser {
    var parser = Parser{
        .vertices = std.ArrayList(Vertex).init(allocator),
        .faces = std.ArrayList(Face).init(allocator),
    };
    errdefer parser.deinit();

    // In OBJ file format, index count begins from 1 instead of 0. Fill the
    // zeroth slot of the list of vertices with a sentinel -- it shouldn't be
    // referenced at any point.
    try parser.vertices.append(undefined);

    var contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(contents);

    var line_start: usize = 0;
    iterate_contents: for (contents) |contents_character, contents_index| {
        if (contents_character == '\n') {
            // At the end of this block, update start of line marker for
            // interpretation of next command. Use `defer` to update the this
            // marker after `continue` statements as well.
            defer line_start = contents_index + 1;

            // Skip blank lines.
            if (contents_index - line_start == 0) continue :iterate_contents;

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
            } else {
                // Ignore invalid or unsupported commands silently.
                parser.number_of_ignored_commands += 1;
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
                    try parser.vertices.append(vertex);
                },
                .face => {
                    var point_number: usize = 0;
                    var point_indeces = [_]usize{ undefined, undefined, undefined };
                    for (line[literal_start..]) |literal_character, literal_index| {
                        if (literal_character == ' ' or literal_character == '\n') {
                            literal_end = command_end + 1 + literal_index;
                            point_indeces[point_number] = try std.fmt.parseInt(
                                usize, line[literal_start..literal_end], 10);
                            literal_start = literal_end + 1;
                            point_number += 1;
                        }
                    }

                    if (point_number != 3) return ParserError.InvalidCommandArity;
                    try parser.faces.append(Face.init(
                        parser.vertices.items[point_indeces[0]],
                        parser.vertices.items[point_indeces[1]],
                        parser.vertices.items[point_indeces[2]]));
                }
            }
        }
    }

    // NOTE Caller owns returned memory.
    return parser;
}

test "ignoring unrecognized lines" {
    // This file contains nonsense.
    const file = try std.fs.cwd().openFile("foo.txt", .{});
    defer file.close();

    var parser = try parseObjFile(std.testing.allocator, file);
    defer parser.deinit();

    try expectEqual(parser.number_of_ignored_commands, 5);
}

test "vertex records" {
    const file = try std.fs.cwd().openFile("vertex_records.txt", .{});
    defer file.close();

    var parser = try parseObjFile(std.testing.allocator, file);
    defer parser.deinit();

    try expectEqual(parser.vertices.items[1], tup.point(-1, 1, 0));
    try expectEqual(parser.vertices.items[2], tup.point(-1, 0.5, 0));
    try expectEqual(parser.vertices.items[3], tup.point(1, 0, 0));
    try expectEqual(parser.vertices.items[4], tup.point(1, 1, 0));
}

test "parsing triangle faces" {
    const file = try std.fs.cwd().openFile("triangle_faces.txt", .{});
    defer file.close();

    var parser = try parseObjFile(std.testing.allocator, file);
    defer parser.deinit();

    const p1 = tup.point(-1, 1, 0);
    const p2 = tup.point(-1, 0, 0);
    const p3 = tup.point(1, 0, 0);
    const p4 = tup.point(1, 1, 0);

    const t0 = Face.init(p1, p2, p3);
    const t1 = Face.init(p1, p3, p4);

    try expectEqual(parser.vertices.items[1], p1);
    try expectEqual(parser.vertices.items[2], p2);
    try expectEqual(parser.vertices.items[3], p3);
    try expectEqual(parser.vertices.items[4], p4);
    try expectEqual(parser.faces.items[0], t0);
    try expectEqual(parser.faces.items[1], t1);
}
