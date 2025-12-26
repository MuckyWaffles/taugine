//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl3");

pub const gl = @import("zgl");

const sdlgl = sdl.video.gl;
const c = sdl.c;

const obj = @import("obj");

pub const glm = @import("glm.zig");

fn getProcAddressWrapper(comptime _: type, symbolName: [:0]const u8) ?*const anyopaque {
    return c.SDL_GL_GetProcAddress(symbolName);
}

pub const App = struct {
    title: []const u8,
    screenWidth: u16,
    screenHeight: u16,

    initFlags: sdl.InitFlags,
    context: sdlgl.Context,
    window: sdl.video.Window,

    appStart: *const fn () void,
    appProcess: *const fn () void,

    /// Initialize app
    pub fn init(
        title: []const u8,
        width: u16,
        height: u16,
        appStart: *const fn () void,
        appProcess: *const fn () void,
    ) !App {
        // Init SDL3
        const initFlags = sdl.InitFlags{ .video = true };
        sdl.init(initFlags) catch |err| {
            std.debug.print("Failed to initialize SDL3! {}\n", .{err});
        };

        // Setting OpenGL attributes
        sdlgl.setAttribute(
            .context_profile_mask,
            c.SDL_GL_CONTEXT_PROFILE_CORE,
        ) catch |err| {
            std.debug.print("Failed to initialize OpenGL! {}\n", .{err});
        };

        // Enabling anti-aliasing
        sdlgl.setAttribute(.multi_sample_buffers, 1) catch |err| {
            std.debug.print("Failed to set OpenGL attribute! {}\n", .{err});
        };
        sdlgl.setAttribute(.multi_sample_samples, 4) catch |err| {
            std.debug.print("Failed to set OpenGL attribute! {}\n", .{err});
        };

        // Setup window
        const windowFlags = sdl.video.Window.Flags{ .open_gl = true };
        const window = try sdl.video.Window.init(
            @ptrCast(title),
            width,
            height,
            windowFlags,
        );

        // Init OpenGL context
        const context = try sdlgl.Context.init(window);
        try context.makeCurrent(window);

        try gl.loadExtensions(void, getProcAddressWrapper);

        gl.enable(.multisample);
        gl.enable(.depth_test);
        gl.frontFace(.ccw);
        gl.enable(.cull_face);
        gl.cullFace(.back);

        return App{
            .appStart = appStart,
            .appProcess = appProcess,

            .title = title,
            .screenWidth = width,
            .screenHeight = height,
            .initFlags = initFlags,
            .context = context,
            .window = window,
        };
    }
    pub fn deinit(self: *App) void {
        self.context.deinit() catch |err| {
            std.debug.print("Error destroying OpenGL context! {}\n", .{err});
        };
        self.window.deinit();
        sdl.quit(self.initFlags);
        sdl.shutdown();
    }

    /// Run given appStart and appProcess in a handled loop
    pub fn run(self: *App) !void {
        self.appStart();

        while (!Input.exitRequested) {
            // Update logic.

            gl.clearColor(0.8, 0.2, 0.6, 1.0);
            gl.clear(.{ .depth = true, .color = true });

            self.appProcess();

            try sdlgl.swapWindow(self.window);

            Input.get(); // Updating inputs
        }
    }
};

pub const Input = struct {
    pub var exitRequested: bool = false;
    pub var moveForwards: bool = false;
    pub var moveBackwards: bool = false;
    pub var moveLeft: bool = false;
    pub var moveRight: bool = false;
    pub var lookLeft: bool = false;
    pub var lookRight: bool = false;

    // Event logic.
    fn get() void {
        while (sdl.events.poll()) |event| {
            switch (event) {
                .quit => Input.exitRequested = true,
                .terminating => Input.exitRequested = true,
                .key_down => switch (event.key_down.scancode.?) {
                    .w => Input.moveForwards = true,
                    .s => Input.moveBackwards = true,
                    .a => Input.moveLeft = true,
                    .d => Input.moveRight = true,
                    .left => Input.lookLeft = true,
                    .right => Input.lookRight = true,
                    else => {},
                },
                .key_up => switch (event.key_up.scancode.?) {
                    .w => Input.moveForwards = false,
                    .s => Input.moveBackwards = false,
                    .a => Input.moveLeft = false,
                    .d => Input.moveRight = false,
                    .left => Input.lookLeft = false,
                    .right => Input.lookRight = false,
                    else => {},
                },
                else => {},
            }
        }
    }
};

// pub const Vertex = struct {
// pos: glm.Vec3,
// norm: glm.Vec3,
// tex: glm.Vec3,
// };

pub const Mesh = struct {
    vao: gl.VertexArray,
    vbo: gl.Buffer,
    ebo: gl.Buffer,

    data: obj.ObjData,
    // verticies: []Vertex,
    indices: []u32,
    indexCount: u32,

    pub fn init(path: []const u8) !Mesh {
        const allocator = std.heap.page_allocator;
        const cubeData = try std.fs.cwd().readFileAlloc(path, allocator, .limited(2048));
        const data = try obj.parseObj(allocator, cubeData);

        // num_vertices gives the amount of faces, multiply by the
        // 6 indices we need per face
        const indexCount = data.meshes[0].num_vertices.len * 6;
        var indices = try allocator.alloc(u32, indexCount);

        var processed: u32 = 0;

        // For some reason the indices are done as quads,
        // so we need to convert them to triangles
        for (0..6) |i| {
            const quad = [_]u32{
                data.meshes[0].indices[processed].vertex.?,
                data.meshes[0].indices[processed + 1].vertex.?,
                data.meshes[0].indices[processed + 2].vertex.?,
                data.meshes[0].indices[processed + 3].vertex.?,
            };
            indices[i * 6] = quad[0];
            indices[i * 6 + 1] = quad[1];
            indices[i * 6 + 2] = quad[2];
            indices[i * 6 + 3] = quad[0];
            indices[i * 6 + 4] = quad[2];
            indices[i * 6 + 5] = quad[3];
            processed += 4;
        }

        var mesh = Mesh{
            .vao = gl.genVertexArray(),
            .vbo = gl.genBuffer(),
            .ebo = gl.genBuffer(),

            .data = data,
            .indices = indices,
            .indexCount = @intCast(data.meshes[0].indices.len),
        };
        mesh.bind();

        mesh.vbo.data(f32, mesh.data.vertices, .static_draw);
        mesh.ebo.data(u32, mesh.indices, .static_draw);

        gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);

        return mesh;
    }
    pub fn deinit(self: *Mesh) void {
        const allocator = std.heap.page_allocator;
        self.data.deinit(allocator);
    }
    pub fn bind(self: *Mesh) void {
        self.vao.bind();
        self.vbo.bind(.array_buffer);
        self.ebo.bind(.element_array_buffer);
    }
};

pub fn compileProgram(vertPath: []const u8, fragPath: []const u8) !gl.Program {
    const allocator = std.heap.page_allocator;

    var vertCode = try std.fs.cwd().readFileAlloc(vertPath, allocator, .limited(1024));
    defer allocator.free(vertCode);

    const vertexShader = gl.createShader(.vertex);
    vertexShader.source(1, &vertCode);
    vertexShader.compile();
    if (vertexShader.get(.compile_status) == 0) {
        const err = try vertexShader.getCompileLog(allocator);
        std.debug.print("{s}\n", .{err});
    }
    defer vertexShader.delete();

    var fragCode = try std.fs.cwd().readFileAlloc(fragPath, allocator, .limited(1024));
    defer allocator.free(fragCode);

    const fragmentShader = gl.createShader(.fragment);
    fragmentShader.source(1, &fragCode);
    fragmentShader.compile();
    if (fragmentShader.get(.compile_status) == 0) {
        const err = try vertexShader.getCompileLog(allocator);
        std.debug.print("{s}\n", .{err});
    }
    defer fragmentShader.delete();

    const shaderProgram = gl.createProgram();
    shaderProgram.attach(vertexShader);
    shaderProgram.attach(fragmentShader);
    shaderProgram.link();

    return shaderProgram;
}
