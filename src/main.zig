const std = @import("std");
const tg = @import("taugine");
const pi = std.math.pi;

var mesh: tg.Mesh = undefined;
var lightMesh: tg.Mesh = undefined;
var cubeShader: tg.Shader = undefined;
var lightCube: tg.Shader = undefined;

fn appStart() void {
    mesh = tg.Mesh.init("cube.obj") catch unreachable;
    lightMesh = tg.Mesh.init("cube.obj") catch unreachable;

    lightCube = tg.Shader.create(
        "shaders/object.vert",
        "shaders/basic.frag",
        tg.Uniforms{
            .projection = true,
            .view = true,
            .model = true,
        },
    ) catch unreachable;
    lightCube.use();

    cubeShader = tg.Shader.create(
        "shaders/object.vert",
        "shaders/object.frag",
        tg.Uniforms{
            .projection = true,
            .view = true,
            .model = false,
        },
    ) catch unreachable;
    cubeShader.use();

    cubeShader.program.uniform3f(cubeShader.program.uniformLocation("objectColor"), 1.0, 0.5, 0.2);
    cubeShader.program.uniform3f(cubeShader.program.uniformLocation("lightColor"), 1.0, 1.0, 1.0);
    cubeShader.program.uniform3f(cubeShader.program.uniformLocation("lightPos"), 0.0, 4.0, -4.0);

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
    cubeShader.use();
    cubeShader.setUniforms();
    cubeShader.program.uniformMatrix4(
        cubeShader.program.uniformLocation("view"),
        false,
        @ptrCast(&view.vals),
    );

    var model = glm.translation(glm.vec3(0.0, 0.0, 0.0));
    model = model.matmul(glm.rotation(pi / 12.0, glm.vec3(1.0, 0.3, 0.5)));
    cubeShader.program.uniformMatrix4(
        cubeShader.program.uniformLocation("model"),
        false,
        @ptrCast(&model.vals),
    );

    mesh.draw();

    // Drawing light cube
    lightMesh.bind();
    lightCube.use();
    lightCube.setUniforms();
    lightCube.program.uniformMatrix4(
        lightCube.program.uniformLocation("view"),
        false,
        @ptrCast(&view.vals),
    );

    lightMesh.draw();
}

var app: tg.App = undefined;

pub fn main() !void {
    app = try tg.App.init(
        "Taugine",
        950,
        750,
        appStart,
        appProcess,
    );
    defer app.deinit();

    try app.run();
}
