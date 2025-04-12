// Triangle Vertex Definition and Buffer Creation using Macro + Builder

// TODO: Find and and another family queue type: TRANSFER for optimization

use std::mem::size_of;
use anyhow::Result;
use cgmath::{vec2, vec3, Vector2, Vector3};
use vulkanalia::prelude::v1_0::*;
use crate::rendering::vulkan_app::AppData;
use crate::rendering::memory::{get_memory_type_index, copy_buffer, create_buffer} ;
use std::ptr::copy_nonoverlapping as memcpy;

pub type Vec2 = Vector2<f32>;
pub type Vec3 = Vector3<f32>;

// Declare vertex layout using macro + builder

pub static VERTICES: [Vertex; 4] = [
    Vertex { pos: vec2(-0.5, -0.5), color: vec3(1.0, 0.0, 0.0)},
    Vertex { pos: vec2(0.5, -0.5), color: vec3(0.0, 1.0, 0.0) },
    Vertex { pos: vec2(0.5, 0.5),  color: vec3(0.0, 0.0, 1.0) },
    Vertex { pos: vec2(-0.5, 0.5), color: vec3(1.0, 1.0, 1.0) },
];

// TODO: Can switch to u32 if we need more unique vertices
pub const INDICES: &[u16] = &[0, 1, 2, 2, 3 , 0];

// INFO: Index buffer removes unnesscary vertices on meshes

#[macro_export]
macro_rules! vertex_type {
    (
        pub name: $name:ident,
        pub binding: $binding:expr,
        pub input_rate: $input_rate:ident,
        fields: [
            $(
                { name: $field_name:ident, ty: $field_ty:ty, location: $location:expr $(, format: $format:ident)? },
            )*
        ]
    ) => {
        #[repr(C)]
        #[derive(Copy, Clone, Debug)]
        pub struct $name {
            $(pub $field_name: $field_ty,)*
        }

        pub struct VertexInputBuilder {
            pub binding: u32,
            pub input_rate: vk::VertexInputRate,
            pub stride: u32,
            pub attributes: Vec<vk::VertexInputAttributeDescription>,
        }

        impl VertexInputBuilder {
            pub fn new() -> Self {
                Self {
                    binding: $binding,
                    input_rate: vk::VertexInputRate::$input_rate,
                    stride: size_of::<$name>() as u32,
                    attributes: <$name>::build_attributes(),
                }
            }

            pub fn binding_description(&self) -> vk::VertexInputBindingDescription {
                vk::VertexInputBindingDescription::builder()
                    .binding(self.binding)
                    .stride(self.stride)
                    .input_rate(self.input_rate)
                    .build()
            }

            pub fn attribute_descriptions(&self) -> &[vk::VertexInputAttributeDescription] {
                &self.attributes
            }
        }

        impl $name {
            pub fn build_attributes() -> Vec<vk::VertexInputAttributeDescription> {
                let mut offset = 0;
                let mut descriptions = Vec::new();
                $(
                    let format = vertex_type!(@resolve_format $field_ty $(, $format)?);
                    descriptions.push(
                        vk::VertexInputAttributeDescription::builder()
                            .binding($binding)
                            .location($location)
                            .format(format)
                            .offset(offset)
                            .build()
                    );
                    offset += size_of::<$field_ty>() as u32;
                )*
                descriptions
            }

            pub fn binding_description() -> vk::VertexInputBindingDescription {
                VertexInputBuilder::new().binding_description()
            }

            pub fn attribute_descriptions() -> Vec<vk::VertexInputAttributeDescription> {
                VertexInputBuilder::new().attributes
            }
        }
    };

    (@resolve_format $ty:ty, $fmt:ident) => { vk::Format::$fmt };
    (@resolve_format $ty:ty) => { <$ty as $crate::rendering::vertex::HasVulkanFormat>::format() };
}

/// Trait for automatic Vulkan format inference
pub trait HasVulkanFormat {
    fn format() -> vk::Format;
}

impl HasVulkanFormat for [f32; 2] {
    fn format() -> vk::Format { vk::Format::R32G32_SFLOAT }
}
impl HasVulkanFormat for [f32; 3] {
    fn format() -> vk::Format { vk::Format::R32G32B32_SFLOAT }
}
impl HasVulkanFormat for [f32; 4] {
    fn format() -> vk::Format { vk::Format::R32G32B32A32_SFLOAT }
}
impl HasVulkanFormat for [u8; 4] {
    fn format() -> vk::Format { vk::Format::R8G8B8A8_UNORM }
}
impl HasVulkanFormat for u32 {
    fn format() -> vk::Format { vk::Format::R32_UINT }
}

pub unsafe fn create_vertex_buffer(
    instance: &Instance,
    device: &Device,
    data: &mut AppData,
) -> Result<()> {


    let size = (size_of::<Vertex>() * VERTICES.len()) as u64;

    let (staging_buffer, staging_buffer_memory) = create_buffer(
        instance,
        device,
        data,
        size,
        vk::BufferUsageFlags::TRANSFER_SRC,
        vk::MemoryPropertyFlags::HOST_COHERENT | vk::MemoryPropertyFlags::HOST_VISIBLE,
    )?;

    // Copy (staging)

    let memory = device.map_memory(staging_buffer_memory, 0, size, vk::MemoryMapFlags::empty())?;

    memcpy(VERTICES.as_ptr(), memory.cast(), VERTICES.len());

    device.unmap_memory(staging_buffer_memory);

    // Create (vertex)

    let (vertex_buffer, vertex_buffer_memory) = create_buffer(
        instance,
        device,
        data,
        size,
        vk::BufferUsageFlags::TRANSFER_DST | vk::BufferUsageFlags::VERTEX_BUFFER,
        vk::MemoryPropertyFlags::DEVICE_LOCAL,
    )?;

    data.vertex_buffer = vertex_buffer;
    data.vertex_buffer_memory = vertex_buffer_memory;

    // Copy (vertex)

    copy_buffer(device, data, staging_buffer, vertex_buffer, size)?;

    // Cleanup

    device.destroy_buffer(staging_buffer, None);
    device.free_memory(staging_buffer_memory, None);

    Ok(())
    
}

//INFO: Only 1 index buffer
pub unsafe fn create_index_buffer(instance: &Instance, device: &Device, data: &mut AppData) -> Result<()>{

    let size = (size_of::<u16>() * INDICES.len()) as u64;

    let (staging_buffer, staging_buffer_memory) = create_buffer(
        instance,
        device,
        data,
        size,
        vk::BufferUsageFlags::TRANSFER_SRC,
        vk::MemoryPropertyFlags::HOST_COHERENT | vk::MemoryPropertyFlags::HOST_VISIBLE,
    )?;

    let memory = device.map_memory(
        staging_buffer_memory,
        0,
        size,
        vk::MemoryMapFlags::empty()
    )?;

    memcpy(INDICES.as_ptr(), memory.cast(), INDICES.len());

    device.unmap_memory(staging_buffer_memory);

    let (index_buffer, index_buffer_memory) = create_buffer(
        instance,
        device,
        data,
        size,
        vk::BufferUsageFlags::TRANSFER_DST | vk::BufferUsageFlags::INDEX_BUFFER,
        vk::MemoryPropertyFlags::DEVICE_LOCAL,
    )?;

    data.index_buffer = index_buffer;
    data.index_buffer_memory = index_buffer_memory;

    copy_buffer(device, data, staging_buffer, index_buffer, size)?;

    device.destroy_buffer(staging_buffer, None);
    device.free_memory(staging_buffer_memory, None);

    Ok(())
}


vertex_type! {
    pub name: Vertex,
    pub binding: 0,
    pub input_rate: VERTEX,
    fields: [
        { name: pos, ty: Vec2, location: 0 , format: R32G32_SFLOAT },
        { name: color, ty: Vec3, location: 1, format: R32G32B32_SFLOAT },
    ]
}

