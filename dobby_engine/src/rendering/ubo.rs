#![allow(dead_code, unused_variables, clippy::manual_slice_size_calculation, clippy::too_many_arguments, clippy::unnecessary_wraps)]

use crate::rendering::memory::create_buffer;
use crate::rendering::vulkan_app::AppData;
use vulkanalia::prelude::v1_0::*;
use anyhow::Result;
use std::ptr::copy_nonoverlapping as memcpy;
use std::time::Instant;

use cgmath::{point3, Deg, vec3};

type Mat4 = cgmath::Matrix4<f32>;

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct UniformBufferObject {

    model: Mat4,
    view: Mat4,
    proj: Mat4,

}

pub unsafe fn create_uniform_buffers(
    instance: &Instance,
    device: &Device,
    data: &mut AppData,

) -> Result<()> {

    data.uniform_buffers.clear();
    data.uniform_buffers_memory.clear();

    for _ in 0..data.swapchain_images.len() {

        let (uniform_buffers, uniform_buffers_memory) = create_buffer(
            instance,
            device,
            data,
            size_of::<UniformBufferObject>() as u64,
            vk::BufferUsageFlags::UNIFORM_BUFFER,
            vk::MemoryPropertyFlags::HOST_COHERENT | vk::MemoryPropertyFlags::HOST_VISIBLE,
        )?;

        data.uniform_buffers.push(uniform_buffers);
        data.uniform_buffers_memory.push(uniform_buffers_memory);
        
    }

    Ok(())


}

pub unsafe fn update_uniform_buffers(start: &Instant , device: &Device, data: &mut AppData, image_index: usize,) -> Result<()>{

    let time = start.elapsed().as_secs_f32();

    let model = Mat4::from_axis_angle(
        vec3(0.0, 0.0, 1.0),
        Deg(90.0) * time
    );

    let view = Mat4::look_at_rh(

        point3(2.0, 2.0, 2.0),
        point3(0.0, 0.0, 0.0),
        vec3(0.0, 0.0, 1.0),

    );

    let mut proj = cgmath::perspective(
        Deg(45.0),
        data.swapchain_extent.width as f32 / data.swapchain_extent.height as f32,
        0.1,
        10.0,
    );
    
    // OpenGL flip to vulkan
    proj[1][1] *= -1.0;

    let ubo = UniformBufferObject {model, view, proj};

    let memory = device.map_memory(
        data.uniform_buffers_memory[image_index],
        0,
        size_of::<UniformBufferObject>() as u64,
        vk::MemoryMapFlags::empty(),
    )?;

    memcpy(&ubo, memory.cast(), 1);

    // Will be changed to push constants
    device.unmap_memory(data.uniform_buffers_memory[image_index]);



    Ok(())


}
