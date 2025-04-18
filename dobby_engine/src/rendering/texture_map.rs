use std::fs::File;
use anyhow::Result;


pub unsafe fn create_texture_image(instance: &Instance, device: &Device, data: &mut AppData) -> Result<()>{

    let image = File::open("../resource/mountains.png");

    let decoder = png::Decoder::new(image);
    let mut reader = decoder.read_info()?;

    let mut pixels = vec![0; reader.info().raw_bytes()];
    reader.next_frame(&mut pixels)?;

    let size = reader.info().raw_bytes() as u64;
    let (width, height) = reader.info().size();

    let (staging_buffer, staging_buffer_memory) = create_buffer(
        instance,
        device,
        data,
        size,
        vk::BufferUsageFlags::TRANSFER_SRC,
        vk::MemoryPropertyFlags::HOST_COHERENT | vk::MemoryPropertyFlags::VISIBLE,
    )?;

    let memory = device.map_memory(
        
        staging_buffer_memory,
        0,
        size,
        vk::MemoryMapFlags::empty(),

    )?;

    memcpy(pixels.as_ptr(), memory.cast(), pixels.len());

    device.unmap_memory(staging_buffer_memory);

    let info = vk::ImageCreateInfo::builder()
        .image_type(vk::ImageType::_2D)
        .extent(vk::Extent3D {width, height, depth: 1 })
        .mip_levels(1)
        .array_layers(1)
        .format(vk::Format::R8G8B8A8_SRGB)
        .tiling(vk::ImageTiling::OPTIMAL)

    Ok(())




}
