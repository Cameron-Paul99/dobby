use anyhow::{anyhow, Result};
use vulkanalia::prelude::v1_0::*;
use crate::rendering::vulkan_app::AppData;

macro_rules! render_pass {
    ({
        color_format: $color_format:expr,
        $(samples: $samples:expr,)?
        $(load_op: $load_op:expr,)?
        $(store_op: $store_op:expr,)?
        $(initial_layout: $initial_layout:expr,)?
        $(final_layout: $final_layout:expr,)?
        $(subpass: $subpass:expr,)?
        $(dependencies: $dependencies:expr,)?
    }) => {{
        RenderPassBuilder {
            color_format: $color_format,
            samples: render_pass!(@default $($samples)?, vk::SampleCountFlags::_1),
            load_op: render_pass!(@default $($load_op)?, vk::AttachmentLoadOp::CLEAR),
            store_op: render_pass!(@default $($store_op)?, vk::AttachmentStoreOp::STORE),
            initial_layout: render_pass!(@default $($initial_layout)?, vk::ImageLayout::UNDEFINED),
            final_layout: render_pass!(@default $($final_layout)?, vk::ImageLayout::PRESENT_SRC_KHR),
            subpass: render_pass!(@default $($subpass)?, subpass!({})),
            dependencies: render_pass!(@opt $($dependencies)?),
        }
    }};

    // Helpers
    (@opt $val:expr) => { Some($val) };
    (@opt) => { None };
    (@default $val:expr, $default:expr) => { $val };
    (@default, $default:expr) => { $default };
}

macro_rules! subpass {
    ({
        $(bind_point: $bind_point:expr,)?
        $(color_attachments: $color_attachments:expr,)?
        $(input_attachments: $input_attachments:expr,)?
        $(resolve_attachments: $resolve_attachments:expr,)?
        $(preserve_attachments: $preserve_attachments:expr,)?
        $(depth_stencil_attachment: $depth_stencil_attachment:expr,)?
    }) => {{
        SubpassBuilder {
            bind_point: subpass!(@default $($bind_point)?, vk::PipelineBindPoint::GRAPHICS),
            color_attachments: subpass!(@opt $($color_attachments)?),
            input_attachments: subpass!(@opt $($input_attachments)?),
            resolve_attachments: subpass!(@opt $($resolve_attachments)?),
            preserve_attachments: subpass!(@opt $($preserve_attachments)?),
            depth_stencil_attachment: subpass!(@opt $($depth_stencil_attachment)?),
        }
    }};

    // Helpers
    (@opt $val:expr) => { Some($val) };
    (@opt) => { None };
    (@default $val:expr, $default:expr) => { $val };
    (@default, $default:expr) => { $default };
}

#[derive(Default)]
pub struct SubpassBuilder<'a> {
    pub bind_point: vk::PipelineBindPoint,
    pub color_attachments: Option<&'a [vk::AttachmentReference]>,
    pub input_attachments: Option<&'a [vk::AttachmentReference]>,
    pub resolve_attachments: Option<&'a [vk::AttachmentReference]>,
    pub preserve_attachments: Option<&'a [u32]>,
    pub depth_stencil_attachment: Option<&'a vk::AttachmentReference>,
}

impl<'a> SubpassBuilder<'a> {
    pub fn build(&self) -> vk::SubpassDescription {
        let mut builder = vk::SubpassDescription::builder()
            .pipeline_bind_point(self.bind_point);

        if let Some(color) = self.color_attachments {
            builder = builder.color_attachments(color);
        }
        if let Some(input) = self.input_attachments {
            builder = builder.input_attachments(input);
        }
        if let Some(resolve) = self.resolve_attachments {
            builder = builder.resolve_attachments(resolve);
        }
        if let Some(preserve) = self.preserve_attachments {
            builder = builder.preserve_attachments(preserve);
        }
        if let Some(depth) = self.depth_stencil_attachment {
            builder = builder.depth_stencil_attachment(depth);
        }

        builder.build()
    }
}

pub struct RenderPassBuilder<'a> {
    pub color_format: vk::Format,
    pub samples: vk::SampleCountFlags,
    pub load_op: vk::AttachmentLoadOp,
    pub store_op: vk::AttachmentStoreOp,
    pub initial_layout: vk::ImageLayout,
    pub final_layout: vk::ImageLayout,
    pub subpass: SubpassBuilder<'a>,
    pub dependencies: Option<&'a [vk::SubpassDependency]>,
}

impl<'a> RenderPassBuilder<'a> {
    pub unsafe fn build(self, device: &Device) -> Result<vk::RenderPass> {
        let color_attachment = vk::AttachmentDescription::builder()
            .format(self.color_format)
            .samples(self.samples)
            .load_op(self.load_op)
            .store_op(self.store_op)
            .stencil_load_op(vk::AttachmentLoadOp::DONT_CARE)
            .stencil_store_op(vk::AttachmentStoreOp::DONT_CARE)
            .initial_layout(self.initial_layout)
            .final_layout(self.final_layout)
            .build();

        let subpass = &[self.subpass.build()];
        let attachments = &[color_attachment];
        
        let info = vk::RenderPassCreateInfo::builder()
            .attachments(attachments)
            .subpasses(subpass)
            .dependencies(self.dependencies.unwrap_or(&[]));

        Ok(device.create_render_pass(&info, None)?)
    }
}

pub unsafe fn create_render_pass( instance: &Instance, device: &Device, data: &mut AppData,) -> Result<()> {
    let color_attachment_ref = vk::AttachmentReference::builder()
        .attachment(0)
        .layout(vk::ImageLayout::COLOR_ATTACHMENT_OPTIMAL)
        .build();
    
    let color_attachments = &[color_attachment_ref];

    let dependency = vk::SubpassDependency::builder()
        .src_subpass(vk::SUBPASS_EXTERNAL)
        .dst_subpass(0)
        .src_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
        .src_access_mask(vk::AccessFlags::empty())
        .dst_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
        .dst_access_mask(vk::AccessFlags::COLOR_ATTACHMENT_WRITE)
        .build();

    let dependencies = &[dependency];

    let builder = render_pass!({
        color_format: data.swapchain_format,
        subpass: subpass!({
            color_attachments: color_attachments,
            
        }),
        dependencies: dependencies,
    });

    data.render_pass = unsafe { builder.build(device)? };

    Ok(())
}

