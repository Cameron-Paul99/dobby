#![allow(dead_code, unused_variables, clippy::manual_slice_size_calculation, clippy::too_many_arguments, clippy::unnecessary_wraps)]

use crate::rendering::vulkan_app::AppData;
use vulkanalia::prelude::v1_0::*;
use anyhow::Result;
use std::mem::size_of;
use crate::rendering::ubo::UniformBufferObject;

/// Describes a single descriptor binding (e.g., a uniform buffer)
pub struct DescriptorBinding {
    /// The Vulkan descriptor type (UBO, storage buffer, sampler, etc.)
    pub descriptor_type: vk::DescriptorType,
    /// The shader binding index
    pub binding: u32,
    /// Number of descriptors in this binding (usually 1)
    pub descriptor_count: u32,
    /// Stages that will access this descriptor
    pub stage_flags: vk::ShaderStageFlags,
}

/// Builder for descriptor set layout, pool, allocation, and writes
/// Does not hold AppData borrow, to avoid conflicts; each method accepts `&mut AppData`
pub struct DescriptorSystemBuilder<'a> {
    device: &'a Device,
    bindings: Vec<DescriptorBinding>,
    max_sets: u32,
}

impl<'a> DescriptorSystemBuilder<'a> {
    /// Create a new builder
    pub fn new(device: &'a Device) -> Self {
        Self { device, bindings: Vec::new(), max_sets: 0 }
    }

    /// Add a descriptor binding to the layout
    pub fn add_binding(mut self, binding: DescriptorBinding) -> Self {
        self.bindings.push(binding);
        self
    }

    /// Specify how many descriptor sets to allocate
    pub fn max_sets(mut self, sets: u32) -> Self {
        self.max_sets = sets;
        self
    }

    /// Creates only the descriptor set layout
    pub unsafe fn create_set_layout(&self, data: &mut AppData) -> Result<()> {
        let layout_bindings: Vec<_> = self.bindings.iter().map(|b| {
            vk::DescriptorSetLayoutBinding::builder()
                .binding(b.binding)
                .descriptor_type(b.descriptor_type)
                .descriptor_count(b.descriptor_count)
                .stage_flags(b.stage_flags)
                .build()
        }).collect();

        let info = vk::DescriptorSetLayoutCreateInfo::builder()
            .bindings(&layout_bindings);
        data.descriptor_set_layout = self.device.create_descriptor_set_layout(&info, None)?;
        Ok(())
    }

    /// Creates only the descriptor pool
    pub unsafe fn create_descriptor_pool(&self, data: &mut AppData) -> Result<()> {
        let pool_sizes: Vec<_> = self.bindings.iter().map(|b| {
            vk::DescriptorPoolSize::builder()
                .type_(b.descriptor_type)
                .descriptor_count(b.descriptor_count * self.max_sets)
                .build()
        }).collect();

        let info = vk::DescriptorPoolCreateInfo::builder()
            .pool_sizes(&pool_sizes)
            .max_sets(self.max_sets);
        data.descriptor_pool = self.device.create_descriptor_pool(&info, None)?;
        Ok(())
    }

    /// Allocates descriptor sets and writes descriptors for all supported types
    pub unsafe fn create_descriptor_sets(&self, data: &mut AppData) -> Result<()> {
        if self.bindings.is_empty() || self.max_sets == 0 {
            return Ok(());
        }

        let layouts = vec![data.descriptor_set_layout; self.max_sets as usize];
        let alloc_info = vk::DescriptorSetAllocateInfo::builder()
            .descriptor_pool(data.descriptor_pool)
            .set_layouts(&layouts);
        data.descriptor_sets = self.device.allocate_descriptor_sets(&alloc_info)?;

        for i in 0..(self.max_sets as usize) {
            let set = data.descriptor_sets[i];
            let mut writes = Vec::new();

            for b in &self.bindings {
                let write = match b.descriptor_type {
                    // vk::DescriptorType::SAMPLER => {
                    //     let img_info = vk::DescriptorImageInfo::builder()
                    //         .sampler(data.texture_sampler)
                    //         .build();
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .image_info(std::slice::from_ref(&img_info))
                    //         .build()
                    // }
                    // vk::DescriptorType::COMBINED_IMAGE_SAMPLER => {
                    //     let img_info = vk::DescriptorImageInfo::builder()
                    //         .image_layout(vk::ImageLayout::SHADER_READ_ONLY_OPTIMAL)
                    //         .image_view(data.texture_image_view)
                    //         .sampler(data.texture_sampler)
                    //         .build();
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .image_info(std::slice::from_ref(&img_info))
                    //         .build()
                    // }
                    // vk::DescriptorType::SAMPLED_IMAGE => {
                    //     let img_info = vk::DescriptorImageInfo::builder()
                    //         .image_layout(vk::ImageLayout::SHADER_READ_ONLY_OPTIMAL)
                    //         .image_view(data.some_image_view)
                    //         .build();
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .image_info(std::slice::from_ref(&img_info))
                    //         .build()
                    // }
                    // vk::DescriptorType::STORAGE_IMAGE => {
                    //     let img_info = vk::DescriptorImageInfo::builder()
                    //         .image_layout(vk::ImageLayout::GENERAL)
                    //         .image_view(data.storage_image_view)
                    //         .build();
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .image_info(std::slice::from_ref(&img_info))
                    //         .build()
                    // }
                    // vk::DescriptorType::UNIFORM_TEXEL_BUFFER => {
                    //     let view = data.uniform_texel_buffer_view;
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .texel_buffer_view(std::slice::from_ref(&view))
                    //         .build()
                    // }
                    // vk::DescriptorType::STORAGE_TEXEL_BUFFER => {
                    //     let view = data.storage_texel_buffer_view;
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .texel_buffer_view(std::slice::from_ref(&view))
                    //         .build()
                    // }
                    vk::DescriptorType::UNIFORM_BUFFER => {
                        let buf_info = vk::DescriptorBufferInfo::builder()
                            .buffer(data.uniform_buffers[i])
                            .offset(0)
                            .range(size_of::<UniformBufferObject>() as u64)
                            .build();
                        vk::WriteDescriptorSet::builder()
                            .dst_set(set)
                            .dst_binding(b.binding)
                            .descriptor_type(b.descriptor_type)
                            .buffer_info(std::slice::from_ref(&buf_info))
                            .build()
                    }
                    // vk::DescriptorType::STORAGE_BUFFER => {
                    //     let buf_info = vk::DescriptorBufferInfo::builder()
                    //         .buffer(data.storage_buffer)
                    //         .offset(0)
                    //         .range(size_of::<MyStorageObject>() as u64)
                    //         .build();
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .buffer_info(std::slice::from_ref(&buf_info))
                    //         .build()
                    // }
                    // vk::DescriptorType::INPUT_ATTACHMENT => {
                    //     let img_info = vk::DescriptorImageInfo::builder()
                    //         .image_layout(vk::ImageLayout::SHADER_READ_ONLY_OPTIMAL)
                    //         .image_view(data.input_attachment_view)
                    //         .build();
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .image_info(std::slice::from_ref(&img_info))
                    //         .build()
                    // }
                    // vk::DescriptorType::INLINE_UNIFORM_BLOCK_EXT => {
                    //     // Inline uniform blocks need manual write descriptors
                    //     unimplemented!()
                    // }
                    // vk::DescriptorType::ACCELERATION_STRUCTURE_KHR => {
                    //     let accel = data.acceleration_structure;
                    //     let as_info = vk::WriteDescriptorSetAccelerationStructureKHR::builder()
                    //         .acceleration_structures(std::slice::from_ref(&accel))
                    //         .build();
                    //     vk::WriteDescriptorSet::builder()
                    //         .dst_set(set)
                    //         .dst_binding(b.binding)
                    //         .descriptor_type(b.descriptor_type)
                    //         .push_next(&as_info)
                    //         .build()
                    // }
                    other => unimplemented!("Descriptor type {:?} not supported yet", other),
                };
                writes.push(write);
            }
            self.device.update_descriptor_sets(&writes, &[] as &[vk::CopyDescriptorSet]);
        }
        Ok(())
    }
}


/// Creates and returns a descriptor system builder with one UBO binding preset
/// Caller should then call:
/// ```ignore
/// let mut builder = descriptor_init(&device, &data);
/// unsafe {
///     builder.create_set_layout(&mut data)?;
///     builder.create_descriptor_pool(&mut data)?;
///     builder.create_descriptor_sets(&mut data)?;
/// }
/// ```

pub fn descriptor_init<'a>(
     device: &'a Device,
     data: &AppData,
) -> Result<DescriptorSystemBuilder<'a>> {
    let builder = DescriptorSystemBuilder::new(device)
        .add_binding(DescriptorBinding {
            descriptor_type: vk::DescriptorType::UNIFORM_BUFFER,
            binding: 0,
            descriptor_count: 1,
            stage_flags: vk::ShaderStageFlags::VERTEX,
        })
        .max_sets(data.swapchain_images.len() as u32);

    Ok(builder)

}

