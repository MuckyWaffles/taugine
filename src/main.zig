const std = @import("std");
const tg = @import("taugine");
const pi = std.math.pi;

var mesh: tg.Mesh = undefined;
var lightMesh: tg.Mesh = undefined;
var cubeShader: tg.Shader = undefined;
var lightShader: tg.Shader = undefined;

fn appStart() void {
    mesh = tg.Mesh.init("cube.obj") catch unreachable;
    lightMesh = tg.Mesh.init("cube.obj") catch unreachable;

    lightShader = tg.Shader.create(
        "shaders/object.vert",
        "shaders/basic.frag",
        tg.Uniforms{
            .projection = true,
            .view = true,
            .model = glm.translation(glm.vec3(0.0, 0.0, 0.0)),
        },
    ) catch unreachable;
    lightShader.use();

    cubeShader = tg.Shader.create(
        "shaders/object.vert",
        "shaders/object.frag",
        tg.Uniforms{
            .projection = true,
            .view = true,
            .model = glm.translation(glm.vec3(0.0, 0.0, 0.0)),
        },
    ) catch unreachable;
    cubeShader.use();

    cubeShader.program.uniform3f(cubeShader.program.uniformLocation("objectColor"), 1.0, 0.5, 0.2);
    cubeShader.program.uniform3f(cubeShader.program.uniformLocation("lightColor"), 1.0, 1.0, 1.0);
    cubeShader.program.uniform3f(cubeShader.program.uniformLocation("lightPos"), 0.0, 4.0, -4.0);

    camera.yaw = -0.5;
    camera.pos = glm.vec3(0.0, 0.0, 5.0);
    camera.setMain();
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
    if (tg.Input.lookLeft) camera.yaw -= 0.01;
    if (tg.Input.lookRight) camera.yaw += 0.01;

    // Drawing main cube
    mesh.bind();
    cubeShader.use();

    var model = glm.translation(glm.vec3(0.0, 0.0, 0.0));
    model = model.matmul(glm.rotation(pi / 12.0, glm.vec3(1.0, 0.3, 0.5)));
    cubeShader.uniforms.model = model;

    cubeShader.setUniforms();

    mesh.draw();

    // Drawing light cube
    lightMesh.bind();
    lightShader.use();

    const lightModel = glm.translation(glm.vec3(0.0, 4.0, -4.0));
    lightShader.uniforms.model = lightModel;
    lightShader.setUniforms();

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
