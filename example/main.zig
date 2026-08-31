const std = @import("std");
const tg = @import("taugine");
const pi = std.math.pi;

var cubeMesh: tg.render.Mesh = undefined;
var cubeShader: tg.render.Shader = undefined;

var lightMesh: tg.render.Mesh = undefined;
var lightShader: tg.render.Shader = undefined;

var drumMesh: tg.render.Mesh = undefined;
var drumShader: tg.render.Shader = undefined;

fn appStart(io: std.Io) void {
    lightShader = tg.render.Shader.create(
        io,
        "shaders/object.vert",
        "shaders/basic.frag",
    ) catch unreachable;

    cubeShader = tg.render.Shader.create(
        io,
        "shaders/object.vert",
        "shaders/object.frag",
    ) catch unreachable;

    camera.yaw = -0.5;
    camera.pos = glm.vec3(0.0, 0.0, 5.0);
    camera.setMain(&app);

    const lightModel = glm.translation(glm.vec3(0.0, 4.0, -4.0));
    lightMesh = tg.render.Mesh.init(
        io,
        "cube.obj",
        lightShader,
        &[_]tg.render.Uniform{
            .{ .name = "projection", .value = .{ .mat4 = tg.render.projection } },
            .{ .name = "view", .value = .{ .mat4 = undefined } },
            .{ .name = "model", .value = .{ .mat4 = lightModel } },
        },
    ) catch unreachable;

    const cubeModel = glm.translation(glm.vec3(0.0, 0.0, 0.0)).matmul(glm.rotation(
        pi / 12.0,
        glm.vec3(1.0, 0.3, 0.5),
    ));
    cubeMesh = tg.render.Mesh.init(
        io,
        "cube.obj",
        cubeShader,
        &[_]tg.render.Uniform{
            .{ .name = "projection", .value = .{ .mat4 = tg.render.projection } },
            .{ .name = "view", .value = .{ .mat4 = undefined } },
            .{ .name = "model", .value = .{ .mat4 = cubeModel } },
            .{ .name = "objectColor", .value = .{ .vec3 = glm.vec3(1.0, 0.5, 0.2) } },
            .{ .name = "lightColor", .value = .{ .vec3 = glm.vec3(1.0, 1.0, 1.0) } },
            .{ .name = "lightPos", .value = .{ .vec3 = glm.vec3(0.0, 4.0, -4.0) } },
        },
    ) catch unreachable;

    const drumModel = glm.translation(glm.vec3(4.0, 0.0, 0.0));
    drumMesh = tg.render.Mesh.init(
        io,
        "drum.obj",
        cubeShader,
        &[_]tg.render.Uniform{
            .{ .name = "projection", .value = .{ .mat4 = tg.render.projection } },
            .{ .name = "view", .value = .{ .mat4 = undefined } },
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

pub fn main(init: std.process.Init) !void {
    app = tg.App.init("Taugine", 960, 760, appStart, appProcess);
    app.run(init.io);
    app.deinit();
}
