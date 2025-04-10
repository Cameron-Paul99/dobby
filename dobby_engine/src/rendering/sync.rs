// === sync.rs ===

use vulkanalia::prelude::v1_0::*;
use crate::rendering::vulkan_app::AppData;
use anyhow::Result;


//================================================
// Sync Builders
//================================================
pub const MAX_FRAMES_IN_FLIGHT: usize = 2;

pub struct SemaphoreBuilder<'a> {
    pub device: &'a Device,
    pub flags: vk::SemaphoreCreateFlags, // ✅ Add this
}

impl<'a> SemaphoreBuilder<'a> {
    pub unsafe fn build(&self) -> Result<vk::Semaphore> {
        let info = vk::SemaphoreCreateInfo {
            s_type: vk::StructureType::SEMAPHORE_CREATE_INFO,
            next: std::ptr::null(),
            flags: self.flags, // ✅ Use it
        };
        Ok(self.device.create_semaphore(&info, None)?)
    }
}

pub struct FenceBuilder<'a> {
    pub device: &'a Device,
    pub signaled: bool,
}

impl<'a> FenceBuilder<'a> {
    pub unsafe fn build(&self) -> Result<vk::Fence> {
        let info = vk::FenceCreateInfo {
            s_type: vk::StructureType::FENCE_CREATE_INFO,
            next: std::ptr::null(),
            flags: if self.signaled {
                vk::FenceCreateFlags::SIGNALED
            } else {
                vk::FenceCreateFlags::empty()
            },
        };
        Ok(self.device.create_fence(&info, None)?)
    }
}

//================================================
// Macros
//================================================
macro_rules! semaphore {
    // With optional `flags` specified
    ({ device: $device:expr, flags: $flags:expr }) => {{
        SemaphoreBuilder {
            device: $device,
            flags: $flags,
        }.build()
    }};

    // Without flags (use default)
    ({ device: $device:expr }) => {{
        SemaphoreBuilder {
            device: $device,
            flags: vk::SemaphoreCreateFlags::empty(),
        }.build()
    }};
}

macro_rules! fence {
    // With `signaled`
    ({ device: $device:expr, signaled: $signaled:expr }) => {{
        FenceBuilder {
            device: $device,
            signaled: $signaled,
        }.build()
    }};

    // Without `signaled` (default to true)
    ({ device: $device:expr }) => {{
        FenceBuilder {
            device: $device,
            signaled: true, // ✅ Default here
        }.build()
    }};
}

//================================================
// Public Function
//================================================

pub unsafe fn create_sync_objects(device: &Device, data: &mut AppData) -> Result<()> {
    for _ in 0..MAX_FRAMES_IN_FLIGHT {
        data.image_available_semaphores.push(semaphore!({ device: device })?);
        data.render_finished_semaphores.push(semaphore!({ device: device })?);
        data.in_flight_fences.push(fence!({ device: device })?);
    }

    data.images_in_flight = data.swapchain_images.iter().map(|_| vk::Fence::null()).collect();

    Ok(())
}
