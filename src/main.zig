const std = @import("std");
const tg = @import("taugine");
const pi = std.math.pi;

var cubeMesh: tg.Mesh = undefined;
var cubeShader: tg.Shader = undefined;

var lightMesh: tg.Mesh = undefined;
var lightShader: tg.Shader = undefined;

var drumMesh: tg.Mesh = undefined;
var drumShader: tg.Shader = undefined;

fn appStart() void {
    lightShader = tg.Shader.create(
        "shaders/object.vert",
        "shaders/basic.frag",
    ) catch unreachable;

    cubeShader = tg.Shader.create(
        "shaders/object.vert",
        "shaders/object.frag",
    ) catch unreachable;

    camera.yaw = -0.5;
    camera.pos = glm.vec3(0.0, 0.0, 5.0);
    camera.setMain();
    const view = camera.getView();

    const lightModel = glm.translation(glm.vec3(0.0, 4.0, -4.0));
    lightMesh = tg.Mesh.init(
        "cube.obj",
        lightShader,
        &[_]tg.mesh.Uniform{
            .{ .name = "projection", .value = .{ .mat4 = tg.projection } },
            .{ .name = "view", .value = .{ .mat4 = view } },
            .{ .name = "model", .value = .{ .mat4 = lightModel } },
        },
    ) catch unreachable;

    const cubeModel = glm.translation(glm.vec3(0.0, 0.0, 0.0)).matmul(glm.rotation(
        pi / 12.0,
        glm.vec3(1.0, 0.3, 0.5),
    ));
    cubeMesh = tg.Mesh.init(
        "cube.obj",
        cubeShader,
        &[_]tg.mesh.Uniform{
            .{ .name = "projection", .value = .{ .mat4 = tg.projection } },
            .{ .name = "view", .value = .{ .mat4 = view } },
            .{ .name = "model", .value = .{ .mat4 = cubeModel } },
            .{ .name = "objectColor", .value = .{ .vec3 = glm.vec3(1.0, 0.5, 0.2) } },
            .{ .name = "lightColor", .value = .{ .vec3 = glm.vec3(1.0, 1.0, 1.0) } },
            .{ .name = "lightPos", .value = .{ .vec3 = glm.vec3(0.0, 4.0, -4.0) } },
        },
    ) catch unreachable;

    const drumModel = glm.translation(glm.vec3(4.0, 0.0, 0.0));
    drumMesh = tg.Mesh.init(
        "drum.obj",
        cubeShader,
        &[_]tg.mesh.Uniform{
            .{ .name = "projection", .value = .{ .mat4 = tg.projection } },
            .{ .name = "view", .value = .{ .mat4 = view } },
            .{ .name = "model", .value = .{ .mat4 = drumModel } },
            .{ .name = "objectColor", .value = .{ .vec3 = glm.vec3(0.2, 0.5, 1.0) } },
            .{ .name = "lightColor", .value = .{ .vec3 = glm.vec3(1.0, 1.0, 1.0) } },
            .{ .name = "lightPos", .value = .{ .vec3 = glm.vec3(0.0, 4.0, -4.0) } },
        },
    ) catch unreachable;
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

    // Drawing light cube
    lightMesh.bind();
    lightMesh.draw();

    // Drawing main cube
    cubeMesh.bind();
    cubeMesh.draw();

    // Drawing barrel
    drumMesh.bind();
    drumMesh.draw();
}

var app: tg.App = undefined;

pub fn main() !void {
    app = try tg.App.init(
        "Taugine",
        960,
        760,
        appStart,
        appProcess,
    );
    defer app.deinit();

    try app.run();
}
