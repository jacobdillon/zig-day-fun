const std = @import("std");
const Io = std.Io;

const req = @import("req_handler.zig");

pub fn main(init: std.process.Init) !void {
    var req_engine = req.RequestEngine.init(init.gpa, init.io);
    defer req_engine.deinit();

    const uri = try std.Uri.parse("https://api-v3.mbta.com/vehicles?page%5Blimit%5D=1&filter%5Broute%5D=Orange");
    var res = try req_engine.req(init.gpa, .GET, uri);
    defer res.deinit(init.gpa);

    std.debug.print("Response:\n{s}\n", .{res.items});
}
