const c = @import("clibs.zig").c;
const std = @import("std");

pub const MaterialTemplateId_u32 = u32;
pub const MaterialInstanceId_u32 = u32;

pub const MaterialTemplate = struct {
    name: []const u8,
    pipeline: c.VkPipeline,
    pipeline_layout: c.VkPipelineLayout,
    bind_point: c.VkPipelineBindPoint,
};

pub const MaterialInstance = struct {
    name: []const u8,
    template_id: u32,
    texture_set: c.VkDescriptorSet,
};

pub const MaterialSystem = struct {
    templates: std.ArrayListUnmanaged(MaterialTemplate),
    instances: std.ArrayListUnmanaged(MaterialInstance),

    pub fn init() MaterialSystem {
        return .{
            .templates = .empty,
            .instances = .empty,
        };
    }

    pub fn deinit(self: *MaterialSystem, allocator: std.mem.Allocator) void {
        self.templates.deinit(allocator);
        self.instances.deinit(allocator);
    }

    pub fn deinitGpu(
        self: *MaterialSystem,
        device: c.VkDevice,
        alloc_cb: ?*const c.VkAllocationCallbacks,
    ) void {
        for (self.templates.items) |t| {
            c.vkDestroyPipeline(device, t.pipeline, alloc_cb);
            c.vkDestroyPipelineLayout(device, t.pipeline_layout, alloc_cb);
        }
    }

    pub fn AddTemplate(
        self: *MaterialSystem,
        name: []const u8,
        pipeline: c.VkPipeline,
        pipeline_layout: c.VkPipelineLayout,
        bind_point: c.VkPipelineBindPoint,
        allocator: std.mem.Allocator,
    ) !u32 {
        const id: u32 = @intCast(self.templates.items.len);
        try self.templates.append(allocator, .{
            .name = name,
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .bind_point = bind_point,
        });
        return id;
    }

    pub fn AddInstance(
        self: *MaterialSystem,
        name: []const u8,
        template_id: u32,
        texture_set: c.VkDescriptorSet,
        allocator: std.mem.Allocator,
    ) !u32 {
        const id: u32 = @intCast(self.instances.items.len);
        try self.instances.append(allocator, .{
            .name = name,
            .template_id = template_id,
            .texture_set = texture_set,
        });
        return id;
    }

    pub fn AddTemplateAndInstance(
        self: *MaterialSystem,
        template_name: []const u8,
        instance_name: []const u8,
        pipeline: c.VkPipeline,
        pipeline_layout: c.VkPipelineLayout,
        bind_point: c.VkPipelineBindPoint,
        texture_set: c.VkDescriptorSet,
        allocator: std.mem.Allocator,
    ) !u32 {
        const template_id = try self.AddTemplate(template_name, pipeline, pipeline_layout, bind_point, allocator);
        return self.AddInstance(instance_name, template_id, texture_set, allocator);
    }

    pub fn FindTemplate(self: *MaterialSystem, name: []const u8) ?*MaterialTemplate {
        for (self.templates.items) |*t| {
            if (std.mem.eql(u8, t.name, name)) return t;
        }
        return null;
    }

    pub fn FindInstance(self: *MaterialSystem, name: []const u8) ?*MaterialInstance {
        for (self.instances.items) |*i| {
            if (std.mem.eql(u8, i.name, name)) return i;
        }
        return null;
    }

    pub fn BindPipeline(
        self: *MaterialSystem,
        cmd: c.VkCommandBuffer,
        name: []const u8,
    ) !*MaterialTemplate {
        const tpl = self.FindTemplate(name) orelse return error.MissingTemplate;
        c.vkCmdBindPipeline(cmd, tpl.bind_point, tpl.pipeline);
        return tpl;
    }

    pub fn ClearRetainingCapacity(self: *MaterialSystem) void {
        self.templates.clearRetainingCapacity();
        self.instances.clearRetainingCapacity();
    }
};
    
