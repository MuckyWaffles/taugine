//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl3");
const gl = @import("zgl");
const sdlgl = sdl.video.gl;
const c = sdl.c;

fn getProcAddressWrapper(comptime _: type, symbolName: [:0]const u8) ?*const anyopaque {
    return c.SDL_GL_GetProcAddress(symbolName);
}

const vertShader = [1][]const u8{
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\
    \\void main()
    \\{
    \\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\}
};

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

    /// Initialize app
    pub fn init(title: []const u8, width: u16, height: u16) App {
        return App{
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

        var vertices = [9]f32{
            -0.5, -0.5, 0.0,
            0.0,  0.5,  0.0,
            0.5,  -0.5, 0.0,
        };
        var vao = gl.genVertexArray();
        vao.bind();

        var vbo = gl.genBuffer();
        vbo.bind(gl.BufferTarget.array_buffer);
        vbo.data(
            f32,
            &vertices,
            .static_draw,
        );

        const vertexShader = gl.createShader(.vertex);
        vertexShader.source(1, &vertShader);
        vertexShader.compile();

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
            gl.clearColor(0.8, 0.2, 0.6, 1.0);
            gl.drawArrays(.triangles, 0, 3);
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
