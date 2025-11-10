const std = @import("std");
const taugine = @import("taugine");

pub fn main() !void {
    var app = taugine.App.init("Taugine", 800, 600);
    defer app.deinit();

    try app.run();
}
