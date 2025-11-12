const std = @import("std");
const tg = @import("taugine");
const pi = std.math.pi;

var mesh: tg.Mesh = undefined;
var program: tg.gl.Program = undefined;

fn appStart() void {
    mesh = tg.Mesh.init("cube.obj") catch unreachable;

    program = tg.compileProgram("shaders/object.vert", "shaders/basic.frag") catch unreachable;
    program.use();

    const projection = glm.perspective(
        45.0 / 180.0 * 3.141,
        @as(f32, @floatFromInt(app.screenWidth)) / @as(f32, @floatFromInt(app.screenHeight)),
        0.1,
        100.0,
    );
    program.uniformMatrix4(
        program.uniformLocation("projection"),
        false,
        @ptrCast(&projection.vals),
    );
}

const glm = tg.glm;
var camPos = glm.vec3(0.0, 0.0, 3.0);
var camFront = glm.vec3(0.0, 0.0, -1.0);

var yaw: f32 = -0.5;
var pitch: f32 = 0.0;

fn appProcess() void {
    const camSpeed = 0.1;
    const up = glm.vec3(0.0, 1.0, 0.0);
    if (tg.Input.moveForwards) {
        camPos = camPos.add(camFront.mulScalar(camSpeed));
    }
    if (tg.Input.moveBackwards) {
        camPos = camPos.sub(camFront.mulScalar(camSpeed));
    }
    if (tg.Input.moveLeft) {
        const move = camFront.cross(up).normalize();
        camPos = camPos.sub(move.mulScalar(camSpeed));
    }
    if (tg.Input.moveRight) {
        const move = camFront.cross(up).normalize();
        camPos = camPos.add(move.mulScalar(camSpeed));
    }
    if (tg.Input.lookLeft) {
        yaw -= 0.01;
    }
    if (tg.Input.lookRight) {
        yaw += 0.01;
    }

    const direction = glm.vec3(
        std.math.cos(yaw * pi) * std.math.cos(pitch * pi),
        std.math.sin(pitch * pi),
        std.math.sin(yaw * pi) * std.math.cos(pitch * pi),
    );
    camFront = direction.normalize();

    const view = glm.lookAt(camPos, camPos.add(camFront), up);

    program.uniformMatrix4(
        program.uniformLocation("view"),
        false,
        @ptrCast(&view.vals),
    );

    var model = glm.translation(tg.glm.vec3(0.0, 0.0, 0.0));
    const angle = 20.0;
    model = model.matmul(tg.glm.rotation(angle / 180.0 * 3.141, tg.glm.vec3(1.0, 0.3, 0.5)));
    program.uniformMatrix4(
        program.uniformLocation("model"),
        false,
        @ptrCast(&model.vals),
    );
    tg.gl.drawElements(.triangles, mesh.indices.len, .unsigned_int, 0);
}

var app: tg.App = undefined;

pub fn main() !void {
    app = try tg.App.init(
        "Taugine",
        800,
        600,
        appStart,
        appProcess,
    );
    defer app.deinit();

    try app.run();
}
