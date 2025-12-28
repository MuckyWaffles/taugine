// This file holds rendering related structs.
// Though this was meant just for mesh related stuff, that happens
// to include uniforms and shaders, so I may rename it to "render.zig"

const std = @import("std");
const glm = @import("glm.zig");
const gl = @import("zgl");

/// Holds shader uniform data
pub const Uniform = struct {
    /// Name we use to locate uniform
    name: [:0]const u8,
    loc: u32 = 0,

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
