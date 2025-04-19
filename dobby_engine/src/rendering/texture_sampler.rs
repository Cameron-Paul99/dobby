#![allow(dead_code, unused_variables, clippy::manual_slice_size_calculation, clippy::too_many_arguments, clippy::unnecessary_wraps)]

use std::fs::File;
use crate::rendering::memory::{get_memory_type_index, create_buffer};
use vulkanalia::prelude::v1_0::*;
use crate::rendering::vulkan_app::AppData;
use crate::rendering::command::{begin_single_time_commands, end_single_time_commands};
use anyhow::{anyhow, Result};
use std::ptr::copy_nonoverlapping as memcpy;

pub unsafe fn create_texture_sampler(device: &Device, data: &mut AppData) -> Result<()> {
    
    let info = vk::SamplerCreateInfo::builder()
        .mag_filter(vk::Filter::LINEAR)
        .min_filter(vk::Filter::LINEAR)
        .address_mode_u(vk::SamplerAddressMode::REPEAT)
        .address_mode_v(vk::SamplerAddressMode::REPEAT)
        .address_mode_w(vk::SamplerAddressMode::REPEAT)
        .anisotropy_enable(true)
        .max_anisotropy(16.0)
        .border_color(vk::BorderColor::INT_OPAQUE_BLACK)
        .unnormalized_coordinates(false)
        .compare_enable(false)
        .compare_op(vk::CompareOp::ALWAYS)
        .mipmap_mode(vk::SamplerMipmapMode::LINEAR)
        .mip_lod_bias(0.0)
        .min_lod(0.0)
        .max_lod(0.0);
    
    data.texture_sampler = device.create_sampler(&info, None)?;

    Ok(())

}
