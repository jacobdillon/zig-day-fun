const std = @import("std");

pub const RequestEngineError = error{BadStatus};

pub const RequestEngine = struct {
    client: std.http.Client,

    pub fn req(self: *RequestEngine, alloc: std.mem.Allocator, method: std.http.Method, uri: std.Uri, headers: []const std.http.Header) !std.ArrayList(u8) {
        var output = try std.ArrayList(u8).initCapacity(alloc, 0);
        var redirect_buf: [1024]u8 = undefined;

        var request = try self.client.request(method, uri, .{ .extra_headers = headers });
        defer request.deinit();
        try request.sendBodiless();

        var response = try request.receiveHead(&redirect_buf);
        if (response.head.status == .ok) {
            // Create buffers for response decompression
            var compressed_window: [64]u8 = undefined;
            const decompressed_window = try self.client.allocator.alloc(u8, std.compress.flate.max_window_len);
            var decompress: std.http.Decompress = undefined;
            defer self.client.allocator.free(decompressed_window);

            // Create decompressing reader and reading slice
            var outslice: [4096]u8 = undefined;
            const body_reader = response.readerDecompressing(&compressed_window, &decompress, decompressed_window);
            while (true) {
                const bytes_read = try body_reader.readSliceShort(&outslice);
                try output.appendSlice(alloc, outslice[0..bytes_read]);
                if (bytes_read < @sizeOf(@TypeOf(outslice))) break;
            }
            return output;
        } else {
            return RequestEngineError.BadStatus;
        }
    }

    pub fn init(allocator: std.mem.Allocator, io: std.Io) RequestEngine {
        return .{ .client = std.http.Client{ .allocator = allocator, .io = io } };
    }
    pub fn deinit(self: *RequestEngine) void {
        self.client.deinit();
        return;
    }
};
