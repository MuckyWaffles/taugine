//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl3");

pub const gl = @import("zgl");

const sdlgl = sdl.video.gl;
const c = sdl.c;

pub const glm = @import("glm.zig");
pub const render = @import("render.zig");

fn getProcAddressWrapper(comptime _: type, symbolName: [:0]const u8) ?*const anyopaque {
    return c.SDL_GL_GetProcAddress(symbolName);
}

pub const App = struct {
    title: [:0]const u8,
    screenWidth: u16,
    screenHeight: u16,

    initFlags: sdl.InitFlags,
    context: sdlgl.Context,
    window: sdl.video.Window,

    /// Reference to user's main camera
    mainCamera: ?*Camera = null,

    appStart: *const fn () void,
    appProcess: *const fn () void,

    /// Initialize app
    pub fn init(
        title: [:0]const u8,
        width: u16,
        height: u16,
        appStart: *const fn () void,
        appProcess: *const fn () void,
    ) App {
        // Init SDL3
        const initFlags = sdl.InitFlags{ .video = true };
        sdl.init(initFlags) catch |err| {
            std.debug.print("Failed to initialize SDL3! {}\n", .{err});
        };

        // Setting OpenGL attributes
        sdlgl.setAttribute(
            .context_profile_mask,
            @intFromEnum(sdlgl.Profile.core),
        ) catch |err| {
            std.debug.print("Failed to set OpenGL attribute! {}\n", .{err});
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
        const window = sdl.video.Window.init(
            title,
            width,
            height,
            windowFlags,
        ) catch unreachable;

        // Init OpenGL context
        const context = sdlgl.Context.init(window) catch unreachable;
        context.makeCurrent(window) catch |err| {
            std.debug.print("Failed to make window current! {}\n", .{err});
        };

        gl.loadExtensions(void, getProcAddressWrapper) catch |err| {
            std.debug.print("Failed to load OpenGL extensions! {}\n", .{err});
        };

        gl.enable(.multisample);
        gl.enable(.depth_test);

        // There's some issue's with loading
        // our objects that makes these settings
        // look a little odd...
        gl.frontFace(.ccw);
        //gl.enable(.cull_face);
        //gl.cullFace(.back);

        // Im unsure of whether or not to include in the App struct
        render.projection = glm.perspective(
            pi / 3.0,
            @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
            0.1,
            100.0,
        );

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
    pub fn run(self: *App) void {
        self.appStart();

        while (!Input.exitRequested) {
            // Update logic.

            gl.clearColor(0.8, 0.2, 0.6, 1.0);
            gl.clear(.{ .depth = true, .color = true });

            // Set view matrix if camera is set
            if (self.mainCamera) |cam| render.view = cam.getView();

            self.appProcess();

            sdlgl.swapWindow(self.window) catch |err| {
                std.debug.print("Failed to update window! {}\n", .{err});
            };

            Input.get(); // Updating inputs
        }
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
    pub fn setMain(self: *Camera, app: *App) void {
        app.mainCamera = self;
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
