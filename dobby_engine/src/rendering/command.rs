// === command.rs ===

use vulkanalia::prelude::v1_0::*;
use crate::rendering::vulkan_app::AppData;
use crate::rendering::device::QueueFamilyIndices;
use anyhow::Result;
use crate::rendering::vertex_data::{VERTICES, INDICES};

//================================================
// Command Pool Builder
//================================================

pub struct CommandPoolBuilder<'a> {
    pub device: &'a Device,
    pub queue_family_index: u32,
    pub flags: vk::CommandPoolCreateFlags,
}

impl<'a> CommandPoolBuilder<'a> {
    pub unsafe fn build(&self) -> Result<vk::CommandPool> {
        let info = vk::CommandPoolCreateInfo {
            s_type: vk::StructureType::COMMAND_POOL_CREATE_INFO,
            next: std::ptr::null(),
            flags: self.flags,
            queue_family_index: self.queue_family_index,
        };
        Ok(self.device.create_command_pool(&info, None)?)
    }
}

//================================================
// Command Buffer Allocator & Recorder
//================================================

pub struct CommandBufferAllocator<'a> {
    pub device: &'a Device,
    pub pool: vk::CommandPool,
    pub count: u32,
    pub level: vk::CommandBufferLevel,
    pub framebuffers: Option<&'a [vk::Framebuffer]>,
    pub render_pass: Option<vk::RenderPass>,
    pub extent: Option<vk::Extent2D>,
    pub pipeline: Option<vk::Pipeline>,
    pub vertex_buffer: Option<vk::Buffer>,
    pub index_buffer: Option<vk::Buffer>,
}

impl<'a> CommandBufferAllocator<'a> {
    pub unsafe fn build(&self) -> Result<Vec<vk::CommandBuffer>> {
        let info = vk::CommandBufferAllocateInfo {
            s_type: vk::StructureType::COMMAND_BUFFER_ALLOCATE_INFO,
            next: std::ptr::null(),
            command_pool: self.pool,
            level: self.level,
            command_buffer_count: self.count,
        };

        let buffers = self.device.allocate_command_buffers(&info)?;

        if let (Some(framebuffers), Some(render_pass), Some(extent), Some(pipeline)) =
            (self.framebuffers, self.render_pass, self.extent, self.pipeline)
        {
            for (i, &command_buffer) in buffers.iter().enumerate() {
                let begin_info = vk::CommandBufferBeginInfo {
                    s_type: vk::StructureType::COMMAND_BUFFER_BEGIN_INFO,
                    next: std::ptr::null(),
                    flags: vk::CommandBufferUsageFlags::empty(),
                    inheritance_info: std::ptr::null(),
                };

                self.device.begin_command_buffer(command_buffer, &begin_info)?;

                let render_area = vk::Rect2D::builder()
                    .offset(vk::Offset2D::default())
                    .extent(extent);

                let clear_value = vk::ClearValue {
                    color: vk::ClearColorValue {
                        float32: [0.0, 0.0, 0.0, 1.0],
                    },
                };

                let render_pass_info = vk::RenderPassBeginInfo::builder()
                    .render_pass(render_pass)
                    .framebuffer(framebuffers[i])
                    .render_area(render_area)
                    .clear_values(std::slice::from_ref(&clear_value))
                    .build();

                self.device.cmd_begin_render_pass(command_buffer, &render_pass_info, vk::SubpassContents::INLINE);
                self.device.cmd_bind_pipeline(command_buffer, vk::PipelineBindPoint::GRAPHICS, pipeline);

                if let Some(vertex_buffer) = self.vertex_buffer {
                    self.device.cmd_bind_vertex_buffers(command_buffer, 0, &[vertex_buffer], &[0]);
                }

                if let Some(index_buffer) = self.index_buffer{
                
                    self.device.cmd_bind_index_buffer(command_buffer, index_buffer, 0, vk::IndexType::UINT16);

                }

                self.device.cmd_draw_indexed(command_buffer, INDICES.len() as u32, 1, 0, 0, 0);

                self.device.cmd_end_render_pass(command_buffer);

                self.device.end_command_buffer(command_buffer)?;
            }
        }

        Ok(buffers)
    }
}

//================================================
// Macros
//================================================

macro_rules! command_buffer {
    ({
        device: $device:expr,
        pool: $pool:expr,
        $(count: $count:expr,)?
        $(level: $level:expr,)?
        $(framebuffers: $framebuffers:expr,)?
        $(render_pass: $render_pass:expr,)?
        $(extent: $extent:expr,)?
        $(pipeline: $pipeline:expr,)?
        $(vertex_buffer: $vertex_buffer:expr,)?
        $(index_buffer: $index_buffer:expr,)?
    }) => {{
        CommandBufferAllocator {
            device: $device,
            pool: $pool,
            count: command_buffer!(@default $($count)?, 1),
            level: command_buffer!(@default $($level)?, vk::CommandBufferLevel::PRIMARY),
            framebuffers: command_buffer!(@opt $($framebuffers)?),
            render_pass: command_buffer!(@opt $($render_pass)?),
            extent: command_buffer!(@opt $($extent)?),
            pipeline: command_buffer!(@opt $($pipeline)?),
            vertex_buffer: command_buffer!(@opt $($vertex_buffer)?),
            index_buffer: command_buffer!(@opt $($index_buffer)?),

        }.build()
    }};

    (@default $val:expr, $default:expr) => { $val };
    (@default, $default:expr) => { $default };
    (@opt $val:expr) => { Some($val) };
    (@opt) => { None };
}

pub(crate) use command_buffer;

//================================================
// Public Functions
//================================================

pub unsafe fn create_command_pool(instance: &Instance, device: &Device, data: &mut AppData) -> Result<()> {
    let indices = QueueFamilyIndices::get(instance, data, data.physical_device)?;

    let pool = CommandPoolBuilder {
        device: device,
        queue_family_index: indices.graphics,
        flags: vk::CommandPoolCreateFlags::empty(),
    }.build()?;

    data.command_pool = pool;

    Ok(())
}

pub unsafe fn create_command_buffers(device: &Device, data: &mut AppData) -> Result<()> {
    data.command_buffers = command_buffer!({
        device: device,
        pool: data.command_pool,
        count: data.framebuffers.len() as u32,
        framebuffers: &data.framebuffers,
        render_pass: data.render_pass,
        extent: data.swapchain_extent,
        pipeline: data.pipeline,
        vertex_buffer: data.vertex_buffer,
        index_buffer: data.index_buffer,
    })?;
    Ok(())
}

