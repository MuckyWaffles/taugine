//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl3");
const gl = @import("zgl");
const sdlgl = sdl.video.gl;
const c = sdl.c;

fn getProcAddressWrapper(comptime _: type, symbolName: [:0]const u8) ?*const anyopaque {
    return c.SDL_GL_GetProcAddress(symbolName);
}

const fragShader = [1][]const u8{
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\void main()
    \\{
    \\    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\}
};

pub const App = struct {
    title: []const u8,
    screenWidth: u16,
    screenHeight: u16,

    context: sdlgl.Context,

    appStart: *const fn () void,
    appProcess: *const fn () void,

    /// Initialize app
    pub fn init(
        title: []const u8,
        width: u16,
        height: u16,
        appStart: *const fn () void,
        appProcess: *const fn () void,
    ) App {
        return App{
            .appStart = appStart,
            .appProcess = appProcess,

            .title = title,
            .screenWidth = width,
            .screenHeight = height,
            .context = undefined,
        };
    }
    pub fn deinit(self: *App) void {
        self.context.deinit() catch |err| {
            std.debug.print("Error destroying OpenGL context! {}", .{err});
        };
    }

    pub fn run(self: *App) !void {
        defer sdl.shutdown();

        // Init SDL3
        const initFlags = sdl.InitFlags{ .video = true };
        try sdl.init(initFlags);
        defer sdl.quit(initFlags);

        // TODO: As you can see, I have some strange mix of wrapped and unwrapped sdl here
        // Setup window
        try sdlgl.setAttribute(
            .context_profile_mask,
            c.SDL_GL_CONTEXT_PROFILE_CORE,
        );

        // Enabling anti-aliasing
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLEBUFFERS, 1);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLESAMPLES, 4);

        const windowFlags = sdl.video.Window.Flags{ .open_gl = true };
        const window = try sdl.video.Window.init(
            @ptrCast(self.title),
            self.screenWidth,
            self.screenHeight,
            windowFlags,
        );
        defer window.deinit();

        self.context = try sdlgl.Context.init(window);
        try self.context.makeCurrent(window);

        try gl.loadExtensions(void, getProcAddressWrapper);

        //_ = gl.enable(gl.Capabilities.multisample);

        self.appStart();
        const vertices = [12]f32{
            0.5, 0.5, 0.0, // top right
            0.5, -0.5, 0.0, // bottom right
            -0.5, -0.5, 0.0, // bottom left
            -0.5, 0.5, 0.0, // top left
        };
        const indices = [6]u32{
            0, 1, 3,
            1, 2, 3,
        };

        var mesh = Mesh.init();
        mesh.bind();

        mesh.vbo.data(f32, &vertices, .static_draw);
        mesh.ebo.data(u32, &indices, .static_draw);

        const allocator = std.heap.page_allocator;

        // Read file into an allocator-owned buffer (max 10 MiB here).
        var data = try std.fs.cwd().readFileAlloc(allocator, "shaders/basic.vert", 1024);
        defer allocator.free(data);

        const vertexShader = gl.createShader(.vertex);
        vertexShader.source(1, &data);
        vertexShader.compile();

        if (vertexShader.get(.compile_status) == 0) {
            const err = try vertexShader.getCompileLog(allocator);
            std.debug.print("{s}", .{err});
        }

        const fragmentShader = gl.createShader(.fragment);
        fragmentShader.source(1, &fragShader);
        fragmentShader.compile();

        const shaderProgram = gl.createProgram();
        shaderProgram.attach(vertexShader);
        shaderProgram.attach(fragmentShader);
        shaderProgram.link();
        shaderProgram.use();

        vertexShader.delete();
        fragmentShader.delete();

        gl.vertexAttribPointer(0, 3, .float, false, 3 * @sizeOf(f32), 0);
        gl.enableVertexAttribArray(0);

        var exitRequested = false;
        while (!exitRequested) {
            // Update logic.
            self.appProcess();
            gl.clearColor(0.8, 0.2, 0.6, 1.0);
            gl.drawElements(.triangles, 6, .unsigned_int, 0);
            try sdlgl.swapWindow(window);

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

const Shader = struct {
    vertexCode: []u8,
    fragmentCode: []u8,
};
