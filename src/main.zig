const std = @import("std");
const tg = @import("taugine");
const pi = std.math.pi;

var mesh: tg.Mesh = undefined;
var lightMesh: tg.Mesh = undefined;
var program: tg.gl.Program = undefined;
var lightCube: tg.gl.Program = undefined;

fn appStart() void {
    mesh = tg.Mesh.init("cube.obj") catch unreachable;
    lightMesh = tg.Mesh.init("cube.obj") catch unreachable;

    const projection = glm.perspective(
        pi / 4.0,
        @as(f32, @floatFromInt(app.screenWidth)) / @as(f32, @floatFromInt(app.screenHeight)),
        0.1,
        100.0,
    );

    lightCube = tg.compileProgram("shaders/object.vert", "shaders/basic.frag") catch unreachable;
    lightCube.use();

    lightCube.uniformMatrix4(
        lightCube.uniformLocation("projection"),
        false,
        @ptrCast(&projection.vals),
    );

    program = tg.compileProgram("shaders/object.vert", "shaders/object.frag") catch unreachable;
    program.use();

    program.uniformMatrix4(
        program.uniformLocation("projection"),
        false,
        @ptrCast(&projection.vals),
    );
    program.uniform3f(program.uniformLocation("objectColor"), 1.0, 0.5, 0.2);
    program.uniform3f(program.uniformLocation("lightColor"), 1.0, 1.0, 1.0);

    camera.yaw = -0.5;
    camera.pos = glm.vec3(0.0, 0.0, 5.0);
}

const glm = tg.glm;
var camera: tg.Camera = undefined;

fn appProcess() void {
    const camSpeed = 0.1;
    if (tg.Input.moveForwards) {
        camera.pos = camera.pos.add(camera.front.mulScalar(camSpeed));
    }
    if (tg.Input.moveBackwards) {
        camera.pos = camera.pos.sub(camera.front.mulScalar(camSpeed));
    }
    if (tg.Input.moveLeft) {
        const move = camera.relativeX().mulScalar(camSpeed);
        camera.pos = camera.pos.sub(move);
    }
    if (tg.Input.moveRight) {
        const move = camera.relativeX().mulScalar(camSpeed);
        camera.pos = camera.pos.add(move);
    }
    if (tg.Input.lookLeft) {
        camera.yaw -= 0.01;
    }
    if (tg.Input.lookRight) {
        camera.yaw += 0.01;
    }

    const view = camera.getView();

    // Drawing main cube
    mesh.bind();
    program.use();

    program.uniformMatrix4(
        program.uniformLocation("view"),
        false,
        @ptrCast(&view.vals),
    );

    var model = glm.translation(glm.vec3(0.0, 0.0, 0.0));
    model = model.matmul(glm.rotation(pi / 12.0, glm.vec3(1.0, 0.3, 0.5)));
    program.uniformMatrix4(
        program.uniformLocation("model"),
        false,
        @ptrCast(&model.vals),
    );

    program.uniform3f(program.uniformLocation("lightPos"), 0.0, 4.0, -4.0);

    // tg.gl.drawElements(.triangles, mesh.indices.len, .unsigned_int, 0);
    mesh.draw();

    // Drawing light cube
    lightMesh.bind();
    lightCube.use();

    lightCube.uniformMatrix4(
        lightCube.uniformLocation("view"),
        false,
        @ptrCast(&view.vals),
    );

    var lightModel = glm.translation(glm.vec3(0.0, 4.0, -4.0));
    lightCube.uniformMatrix4(
        lightCube.uniformLocation("model"),
        false,
        @ptrCast(&lightModel.vals),
    );
    tg.gl.drawElements(.triangles, lightMesh.indices.len, .unsigned_int, 0);
}

var app: tg.App = undefined;

pub fn main() !void {
    app = try tg.App.init(
        "Taugine",
        900,
        700,
        appStart,
        appProcess,
    );
    defer app.deinit();

    try app.run();
}
