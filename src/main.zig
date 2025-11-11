const std = @import("std");
const taugine = @import("taugine");

fn appStart() void {}
fn appProcess() void {}

pub fn main() !void {
    var app = try taugine.App.init(
        "Taugine",
        800,
        600,
        appStart,
        appProcess,
    );
    defer app.deinit();

    try app.run();
}
