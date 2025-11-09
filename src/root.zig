//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl3");

pub const App = struct {
    title: []const u8,
    screenWidth: u16,
    screenHeight: u16,

    pub fn init(title: []const u8, width: u16, height: u16) App {
        return App{
            .title = title,
            .screenWidth = width,
            .screenHeight = height,
        };
    }

    pub fn run(self: *App) !void {
        defer sdl.shutdown();

        // Init SDL3
        const initFlags = sdl.InitFlags{ .video = true };
        try sdl.init(initFlags);
        defer sdl.quit(initFlags);

        // Setup window
        const window = try sdl.video.Window.init(
            @ptrCast(self.title),
            self.screenWidth,
            self.screenHeight,
            .{},
        );
        defer window.deinit();

        var exitRequested = false;
        while (!exitRequested) {
            // Update logic.
            const surface = try window.getSurface();
            try surface.fillRect(null, surface.mapRgb(128, 30, 255));
            try window.updateSurface();

            // Event logic.
            while (sdl.events.poll()) |event| {
                switch (event) {
                    .quit => exitRequested = true,
                    .terminating => exitRequested = true,
                    else => {},
                }
            }
        }
    }
};

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
