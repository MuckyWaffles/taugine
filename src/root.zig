//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl3");
const gl = @import("zgl");
const sdlgl = sdl.video.gl;
const c = sdl.c;

const obj = @import("obj");

const glm = @import("glm.zig");

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

    pub fn run(self: *App) !void {
        self.appStart();

        const allocator = std.heap.page_allocator;
        const cubeData = try std.fs.cwd().readFileAlloc(allocator, "cube.obj", 2048);
        var cube = try obj.parseObj(allocator, cubeData);
        var indices: [24]u32 = undefined;
        std.debug.print("{d}", .{cube.meshes[0].indices.len});
        for (indices, 0..) |_, i| {
            indices[i] = cube.meshes[0].indices[i].vertex.?;
        }
        defer cube.deinit(allocator);

        var mesh = Mesh.init();
        mesh.bind();

        mesh.vbo.data(f32, cube.vertices, .static_draw);
        mesh.ebo.data(u32, &indices, .static_draw);

        gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);

        // const program = try compileProgram("shaders/basic.vert", "shaders/basic.frag");
        // program.use();

        const program = try compileProgram("shaders/object.vert", "shaders/basic.frag");
        program.use();

        const view = glm.translation(glm.vec3(0.0, 0.0, -3.0));
        const projection = glm.perspective(
            45.0 / 180.0 * 3.141,
            @as(f32, @floatFromInt(self.screenWidth)) / @as(f32, @floatFromInt(self.screenHeight)),
            0.1,
            100.0,
        );
        program.uniformMatrix4(
            program.uniformLocation("projection"),
            false,
            @ptrCast(&projection.vals),
        );
        program.uniformMatrix4(
            program.uniformLocation("view"),
            false,
            @ptrCast(&view.vals),
        );

        var exitRequested = false;
        while (!exitRequested) {
            // Update logic.
            self.appProcess();
            gl.clearColor(0.8, 0.2, 0.6, 1.0);
            gl.clear(.{});

            var model = glm.translation(glm.vec3(0.0, 0.0, 0.0));
            const angle = 20.0;
            model = model.matmul(glm.rotation(angle / 180.0 * 3.141, glm.vec3(1.0, 0.3, 0.5)));
            program.uniformMatrix4(
                program.uniformLocation("model"),
                false,
                @ptrCast(&model.vals),
            );
            gl.drawElements(.triangle_strip, indices.len, .unsigned_int, 0);
            //gl.drawArrays(.triangles, 0, 36);

            try sdlgl.swapWindow(self.window);

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

const Mesh = struct {
    vao: gl.VertexArray,
    vbo: gl.Buffer,
    ebo: gl.Buffer,

    pub fn init() Mesh {
        return Mesh{
            .vao = gl.genVertexArray(),
            .vbo = gl.genBuffer(),
            .ebo = gl.genBuffer(),
        };
    }
    pub fn bind(self: *Mesh) void {
        self.vao.bind();
        self.vbo.bind(.array_buffer);
        self.ebo.bind(.element_array_buffer);
    }
};

pub fn compileProgram(vertPath: []const u8, fragPath: []const u8) !gl.Program {
    const allocator = std.heap.page_allocator;

    var vertCode = try std.fs.cwd().readFileAlloc(allocator, vertPath, 1024);
    defer allocator.free(vertCode);

    const vertexShader = gl.createShader(.vertex);
    vertexShader.source(1, &vertCode);
    vertexShader.compile();
    if (vertexShader.get(.compile_status) == 0) {
        const err = try vertexShader.getCompileLog(allocator);
        std.debug.print("{s}\n", .{err});
    }
    defer vertexShader.delete();

    var fragCode = try std.fs.cwd().readFileAlloc(allocator, fragPath, 1024);
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
