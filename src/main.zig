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

    var ts: std.c.timespec = std.mem.zeroes(std.c.timespec);
    _ = std.c.clock_gettime(std.c.clockid_t.MONOTONIC, &ts);
    var prng = std.Random.DefaultPrng.init(@bitCast(ts.nsec));

    const rand = prng.random();
    var entity: ?pb.FeedEntity = null;
    while (true) {
        const random_pick = rand.intRangeLessThan(usize, 0, fm.entity.items.len);
        entity = fm.entity.items[random_pick];
        if (entity.?.vehicle != null and entity.?.vehicle.?.stop_id != null) break;
    }

    const vehicle = entity.?.vehicle.?;
    const vehicle_id = vehicle.vehicle.?.id.?;

    var sb_backing: [512]u8 = undefined;
    var sb = std.Io.Writer.fixed(&sb_backing);
    try sb.writeAll("https://api-v3.mbta.com/vehicles/");
    try sb.writeAll(vehicle_id);
    try sb.writeAll("?include=trip,route,stop");
    const vehicle_uri = try std.Uri.parse(sb.buffered());
    var vehicle_res = try req_engine.req(init.gpa, .GET, vehicle_uri, &headers);
    defer vehicle_res.deinit(init.gpa);

    std.debug.print("{s}\n", .{vehicle_res.items});
}
