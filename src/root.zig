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

        // Im unsure of whether or not to include in the App struct
        projection = glm.perspective(
            pi / 3.0,
            @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
            0.1,
            100.0,
        );

        // Set view to identity matrix by default
        view = glm.Mat4{
            .vals = [4][4]f32{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };

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

            // Set view matrix if camera is set
            if (camera) |cam| view = cam.getView();

            self.appProcess();

            try sdlgl.swapWindow(self.window);

            Input.get(); // Updating inputs
        }
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

pub var projection: glm.Mat4 = undefined;
pub var view: glm.Mat4 = undefined;
pub var camera: ?*Camera = null;

/// Holds some universal uniforms,
/// keeps space for custom defined ones
pub const Uniforms = struct {
    projection: bool,
    view: bool,
    model: ?glm.Mat4,
};

pub const Shader = struct {
    program: gl.Program,

    uniforms: Uniforms,

    pub fn create(
        vertPath: []const u8,
        fragPath: []const u8,
        uniforms: Uniforms,
    ) !Shader {
        var program = try compileProgram(vertPath, fragPath);

        if (uniforms.projection) {
            program.uniformMatrix4(
                program.uniformLocation("projection"),
                false,
                @ptrCast(&projection.vals),
            );
        }

        return Shader{
            .program = program,
            .uniforms = uniforms,
        };
    }

    pub fn use(self: *Shader) void {
        self.program.use();
    }

    pub fn setUniforms(self: *Shader) void {
        if (self.uniforms.view) {
            self.program.uniformMatrix4(
                self.program.uniformLocation("view"),
                false,
                @ptrCast(&view.vals),
            );
        }
        if (self.uniforms.model) |model| {
            self.program.uniformMatrix4(
                self.program.uniformLocation("model"),
                false,
                @ptrCast(&model.vals),
            );
        }
    }
};

pub const Vertex = struct {
    pos: glm.Vec3,
    norm: glm.Vec3,
    tex: glm.Vec2,
};

pub const Mesh = struct {
    vao: gl.VertexArray,
    vbo: gl.Buffer,
    ebo: gl.Buffer,

    vertices: []Vertex,
    indices: []u32,

    pub fn init(path: []const u8) !Mesh {
        const allocator = std.heap.page_allocator;
        const cubeData = try std.fs.cwd().readFileAlloc(path, allocator, .limited(2048));
        defer allocator.free(cubeData);
        const data = try obj.parseObj(allocator, cubeData);

        const quads = data.meshes[0].indices;
        const quad_count = quads.len / 4;
        const vertex_count = quad_count * 6;

        var vertices = try allocator.alloc(Vertex, vertex_count);
        var indices = try allocator.alloc(u32, vertex_count);

        var j: usize = 0;
        for (0..quad_count) |i| {
            // Objects are exported as quads (for some reason),
            // so we need to convert them
            const qi = i * 4;
            const triangles = [6]obj.Mesh.Index{
                quads[qi + 0], quads[qi + 1], quads[qi + 2],
                quads[qi + 0], quads[qi + 2], quads[qi + 3],
            };

            for (triangles) |f| {
                // Create all our vertices
                const vi = f.vertex.? * 3;
                const ni = f.normal.? * 3;

                vertices[j].pos = glm.vec3(
                    data.vertices[vi],
                    data.vertices[vi + 1],
                    data.vertices[vi + 2],
                );

                vertices[j].norm = glm.vec3(
                    data.normals[ni],
                    data.normals[ni + 1],
                    data.normals[ni + 2],
                ).normalize();

                if (f.tex_coord) |ti| {
                    const t = ti * 2;
                    vertices[j].tex = glm.Vec2{ .vals = .{
                        data.tex_coords[t],
                        data.tex_coords[t + 1],
                    } };
                }

                indices[j] = @as(u32, @intCast(j));
                j += 1;
            }
        }

        var mesh = Mesh{
            .vao = gl.genVertexArray(),
            .vbo = gl.genBuffer(),
            .ebo = gl.genBuffer(),

            .vertices = vertices,
            .indices = indices,
        };
        mesh.bind();

        mesh.vbo.data(Vertex, mesh.vertices, .static_draw);
        mesh.ebo.data(u32, mesh.indices, .static_draw);

        gl.vertexAttribPointer(0, 3, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "pos"));
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(1, 3, .float, false, @sizeOf(Vertex), @offsetOf(Vertex, "norm"));
        gl.enableVertexAttribArray(1);

        return mesh;
    }
    pub fn deinit(self: *Mesh) void {
        // Free allocated memory
        const allocator = std.heap.page_allocator;
        allocator.free(self.vertices);
        allocator.free(self.indices);

        // Delete OpenGL objects
        gl.deleteVertexArray(self.vao);
        gl.deleteBuffer(self.vbo);
        gl.deleteBuffer(self.ebo);
    }
    pub fn bind(self: *const Mesh) void {
        self.vao.bind();
        self.vbo.bind(.array_buffer);
        self.ebo.bind(.element_array_buffer);
    }
    pub fn draw(self: *const Mesh) void {
        gl.drawElements(.triangles, self.indices.len, .unsigned_int, 0);
    }
};

const pi = std.math.pi;
const up = glm.vec3(0.0, 1.0, 0.0);

pub const Camera = struct {
    pos: glm.Vec3 = glm.Vec3{ .vals = [3]f32{ 0.0, 0.0, 0.0 } },
    front: glm.Vec3,

    yaw: f32,
    pitch: f32,

    pub fn getView(self: *Camera) glm.Mat4 {
        const direction = glm.vec3(
            std.math.cos(self.yaw * pi) * std.math.cos(self.pitch * pi),
            std.math.sin(self.pitch * pi),
            std.math.sin(self.yaw * pi) * std.math.cos(self.pitch * pi),
        );
        self.front = direction.normalize();

        return glm.lookAt(self.pos, self.pos.add(self.front), up);
    }

    /// Returns x axis relative to the camera
    pub fn relativeX(self: *Camera) glm.Vec3 {
        return self.front.cross(up).normalize();
    }

    /// Set camera to be main
    pub fn setMain(self: *Camera) void {
        camera = self;
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
