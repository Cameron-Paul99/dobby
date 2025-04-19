#![allow(dead_code, unused_variables, clippy::manual_slice_size_calculation, clippy::too_many_arguments, clippy::unnecessary_wraps)]

use vulkanalia::prelude::v1_0::*;
use anyhow::{Result, anyhow};
use crate::rendering::vulkan_app::AppData;

macro_rules! framebuffer {
    ({
        $(render_pass: $render_pass:expr,)?
        $(attachments: $attachments:expr,)?
        $(width: $width:expr,)?
        $(height: $height:expr,)?
        $(layers: $layers:expr,)?
        $(flags: $flags:expr,)?
        $(p_next: $p_next:expr,)?
    }) => {{
        FramebufferBuilder {
            render_pass: framebuffer!(@opt $($render_pass)?),
            attachments: framebuffer!(@opt $($attachments)?),
            width: framebuffer!(@default $($width)?, 1),
            height: framebuffer!(@default $($height)?, 1),
            layers: framebuffer!(@default $($layers)?, 1),
            flags: framebuffer!(@default $($flags)?, vk::FramebufferCreateFlags::empty()),
            p_next: framebuffer!(@default_ptr $($p_next)?),
        }
    }};

    (@opt $val:expr) => { Some($val) };
    (@opt) => { None };
    (@default $val:expr, $default:expr) => { $val };
    (@default, $default:expr) => { $default };
    (@default_ptr $val:expr) => { $val };
    (@default_ptr) => { std::ptr::null() };
}

pub struct FramebufferBuilder<'a> {
    pub render_pass: Option<vk::RenderPass>,
    pub attachments: Option<&'a [vk::ImageView]>,
    pub width: u32,
    pub height: u32,
    pub layers: u32,
    pub flags: vk::FramebufferCreateFlags,
    pub p_next: *const std::ffi::c_void,
}

impl<'a> FramebufferBuilder<'a> {
    pub unsafe fn build(self, device: &Device) -> Result<vk::Framebuffer> {
        let render_pass = self.render_pass.ok_or_else(|| anyhow!("FramebufferBuilder: missing render_pass"))?;
        let attachments = self.attachments.ok_or_else(|| anyhow!("FramebufferBuilder: missing attachments"))?;

        let create_info = vk::FramebufferCreateInfo::builder()
            .render_pass(render_pass)
            .attachments(attachments)
            .width(self.width)
            .height(self.height)
            .layers(self.layers)
            .flags(self.flags)
            .build();

        Ok(device.create_framebuffer(&create_info, None)?)
    }
}

pub unsafe fn create_framebuffers(device: &Device, data: &mut AppData) -> Result<()> {
    data.framebuffers = data
        .swapchain_image_views
        .iter()
        .map(|i| {
            let attachments = &[*i];

            framebuffer!({
                render_pass: data.render_pass,
                attachments: attachments,
                width: data.swapchain_extent.width,
                height: data.swapchain_extent.height,
                layers: 1,
            }).build(device)
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(())
}

