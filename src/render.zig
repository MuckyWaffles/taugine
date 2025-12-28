const std = @import("std");
const gl = @import("zgl");
const obj = @import("obj");
const glm = @import("glm.zig");

/// Holds shader uniform data
pub const Uniform = struct {
    /// Name we use to locate uniform
    name: [:0]const u8,
    loc: ?u32 = null,

    // I'll expand this union at some point
    // but at the moment these two are all I need
    /// Tagged union holding possible uniform types
    value: union(enum) {
        vec3: glm.Vec3,
        mat4: glm.Mat4,
    },

    /// Save uniform location
    // TODO: This doesn't matter right now, but I'll enforce it soon!
    pub fn saveLoc(self: *Uniform, program: gl.Program) void {
        self.loc = gl.getUniformLocation(program, self.name);
    }

    /// Set uniform with information in struct.
    /// Binding a shader is still necessary.
    pub fn set(self: *const Uniform, program: gl.Program) void {
        const loc = gl.getUniformLocation(program, self.name);
        switch (self.value) {
            .vec3 => |*v| gl.uniform3f(loc, v.vals[0], v.vals[1], v.vals[2]),
            .mat4 => |*m| gl.uniformMatrix4fv(loc, false, @ptrCast(&m.vals)),
        }
    }
};

pub const identityMat4 = glm.Mat4{
    .vals = [4][4]f32{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    },
};

// TODO: I don't like the state here, I'll probably create
// a RenderContext struct to be passed around for this purpose
pub var projection: glm.Mat4 = identityMat4;
pub var view: glm.Mat4 = identityMat4;

pub const Vertex = struct {
    pos: glm.Vec3,
    norm: glm.Vec3,
    tex: glm.Vec2,
};

pub const Shader = struct {
    program: gl.Program,

    pub fn create(
        vertPath: []const u8,
        fragPath: []const u8,
    ) !Shader {
        const program = try compileProgram(vertPath, fragPath);

        return Shader{
            .program = program,
        };
    }

    pub fn use(self: *Shader) void {
        self.program.use();
    }

    // Uniforms are held in Meshes, which maybe isn't ideal because
    // we're then resetting uniforms with the same universal
    // values multiple times per object rather than per shader
    pub fn setUniforms(self: *Shader, uniforms: []Uniform) void {
        // Find global uniforms
        self.program.use();
        for (uniforms) |*uniform| {
            // TODO: This is stupid and really bad
            if (std.mem.eql(u8, uniform.name, "view")) {
                uniform.value = .{ .mat4 = view };
            }
            uniform.set(self.program);
        }
    }
};

pub const Mesh = struct {
    vao: gl.VertexArray,
    vbo: gl.Buffer,
    ebo: gl.Buffer,

    vertices: []Vertex,
    indices: []u32,

    shader: Shader,
    uniforms: []Uniform,

    pub fn init(path: []const u8, shader: Shader, uniforms: []const Uniform) !Mesh {
        const allocator = std.heap.page_allocator;
        const cubeData = try std.fs.cwd().readFileAlloc(path, allocator, .unlimited);
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

            .shader = shader,
            .uniforms = try allocator.dupe(Uniform, uniforms),
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
        allocator.free(self.uniforms);

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
    pub fn draw(self: *Mesh) void {
        self.shader.setUniforms(self.uniforms);
        gl.drawElements(.triangles, self.indices.len, .unsigned_int, 0);
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
