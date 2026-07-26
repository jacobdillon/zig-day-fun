const std = @import("std");

pub fn csv_to_struct(comptime content: []const u8) type {
    const idx = std.mem.indexOf(u8, content, "\n") orelse content.len;

    comptime var count_it = std.mem.tokenizeSequence(u8, content[0..idx], ",");

    comptime var field_count = 0;
    inline while (count_it.next()) |_| {
        field_count += 1;
    }

    var field_names: [field_count][]const u8 = undefined;
    var field_types: [field_count]type = undefined;
    var field_attrs: [field_count]std.builtin.Type.StructField.Attributes = undefined;

    comptime var populate_iter = std.mem.splitScalar(u8, content[0..idx], ',');
    comptime var i: usize = 0;
    inline while (populate_iter.next()) |raw_name| {
        const name: [:0]const u8 = (raw_name ++ .{0})[0..raw_name.len :0];

        field_types[i] = []const u8;
        field_names[i] = name;
        field_attrs[i] = .{
            .@"align" = @alignOf([]const u8),
            .@"comptime" = false,
            .default_value_ptr = null,
        };

        i += 1;
    }

    return @Struct(
        .auto,
        null,
        &field_names,
        &field_types,
        &field_attrs,
    );
}

pub fn parse_csv(comptime content: []const u8) []csv_to_struct(content) {
    const T = csv_to_struct(content);
    comptime var length = 0;
    comptime var count_iter = std.mem.splitScalar(u8, content, '\n');
    inline while (count_iter.next()) {
        length += 1;
    }

    comptime var ret: [length]T = undefined;

    comptime var iter = std.mem.splitScalar(u8, content, '\n');

    comptime var idx = 0;
    const fieldnames = comptime std.meta.fieldNames(T);
    inline while (iter.next()) |line| : (idx += 1) {
        comptime var field_iter = std.mem.splitScalar(u8, line, ',');

        comptime var field_idx = 0;
        inline while (field_iter.next()) |field_val| : (field_idx += 1) {
            comptime var cur_struct: T = csv_to_struct(content){};
            @field(cur_struct, fieldnames[field_idx]) = field_val;
            ret[idx] = cur_struct;
        }
    }
}
