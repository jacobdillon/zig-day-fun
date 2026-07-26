const std = @import("std");
const Io = std.Io;

const req = @import("req_handler.zig");
const pb = @import("proto/transit_realtime.pb.zig");

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

    const uri = try std.Uri.parse("https://cdn.mbta.com/realtime/VehiclePositions.pb");
    var res = try req_engine.req(init.gpa, .GET, uri, &headers);
    defer res.deinit(init.gpa);

    var res_reader = std.Io.Reader.fixed(res.items);
    var fm = try pb.FeedMessage.decode(&res_reader, init.gpa);
    defer fm.deinit(init.gpa);

    for (fm.entity.items) |entity| {
        if (entity.vehicle == null) continue;
        const vehicle_position = entity.vehicle.?;
        const stop = vehicle_position.stop_id orelse "NULL";
        std.debug.print("vehicle id {s} is on trip {s} at stop {s}\n", .{ vehicle_position.vehicle.?.id.?, vehicle_position.trip.?.trip_id.?, stop });
    }

    const jsonOut = try fm.jsonEncode(.{}, .{}, init.gpa);
    defer init.gpa.free(jsonOut);

    // std.debug.print("{s}", .{jsonOut});
}
