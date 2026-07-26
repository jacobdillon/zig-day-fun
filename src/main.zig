const std = @import("std");
const Io = std.Io;

const req = @import("req_handler.zig");

fn get_api_key(allocator: std.mem.Allocator, io: std.Io, relpath: []const u8) ![]u8 {
    const cwd = std.Io.Dir.cwd();
    const api_keyfile = try cwd.openFile(io, relpath, .{ .mode = .read_only });
    defer api_keyfile.close(io);

    var readbuf: [128]u8 = std.mem.zeroes([128]u8);
    var api_reader = api_keyfile.reader(io, &readbuf);
    const api_key: []u8 = try allocator.alloc(u8, try api_keyfile.length(io) - 1);
    try api_reader.interface.readSliceAll(api_key);
    return api_key;
}

pub fn main(init: std.process.Init) !void {
    const api_key = try get_api_key(init.gpa, init.io, ".apikey");
    defer init.gpa.free(api_key);

    const x_api_key: std.http.Header = .{ .name = "x-api-key", .value = api_key };
    const headers = [_]std.http.Header{x_api_key};

    var req_engine = req.RequestEngine.init(init.gpa, init.io);
    defer req_engine.deinit();

    const uri = try std.Uri.parse("https://api-v3.mbta.com/vehicles?page%5Blimit%5D=1&filter%5Broute%5D=Orange");
    var res = try req_engine.req(init.gpa, .GET, uri, &headers);
    defer res.deinit(init.gpa);

    std.debug.print("Response:\n{s}\n", .{res.items});
}
