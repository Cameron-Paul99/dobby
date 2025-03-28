use thiserror::Error;
use anyhow::{anyhow, Result};
use super::vulkan_app::{AppData, PORTABILITY_MACOS_VERSION};
use vulkanalia::prelude::v1_0::*;
use log::*;
use crate::debug::vulkan::{VALIDATION_ENABLED, validation_layers, VALIDATION_LAYER};

#[derive(Debug, Error)]
#[error("Missing {0}.")]
pub struct SuitabilityError(pub &'static str);

pub unsafe fn pick_physical_device(instance: &Instance, data: &mut AppData) -> Result<()> {

    for physical_device in instance.enumerate_physical_devices()?{
        
        let properties = instance.get_physical_device_properties(physical_device);

        if let Err(error) = check_physical_device(instance, data, physical_device){

            warn!("Skipping physical device (`{}`): {} " , properties.device_name, error);

        }else{

            info!("Selected physical device (`{}`).", properties.device_name);
            data.physical_device = physical_device;
            return Ok(());
            
        }
    }
    Ok(())

}

pub unsafe fn create_logical_device(entry: &Entry, instance: &Instance, data: &mut AppData,) -> Result<Device>{
    // Queue Create Infos
    //
    let indices = QueueFamilyIndices::get(instance, data, data.physical_device)?;

        // Queue Priority 
    let queue_priorities = &[1.0];

        // Creating of queue from family
    let queue_info = vk::DeviceQueueCreateInfo::builder()
        .queue_family_index(indices.graphics)
        .queue_priorities(queue_priorities);
    
    // Layers
    //
        // Validation Layers for device
    let layers = if VALIDATION_ENABLED {

        vec![VALIDATION_LAYER.as_ptr()]

    }else {

        vec![]

    };
    
    // Extensions
    //

    let mut extensions = vec![];

    // Required by Vulkan SDK on macOS since 1.3.216.
    if cfg!(target_os = "macos") && entry.version()? >= PORTABILITY_MACOS_VERSION {

        extensions.push(vk::KHR_PORTABILITY_SUBSET_EXTENSION.name.as_ptr());

    }

    // Features
    //
    let features = vk::PhysicalDeviceFeatures::builder();

    // Create
    //
    let queue_infos = &[queue_info];
    let info = vk::DeviceCreateInfo::builder()
        .queue_create_infos(queue_infos)
        .enabled_layer_names(&layers)
        .enabled_extension_names(&extensions)
        .enabled_features(&features);

    let device = instance.create_device(data.physical_device, &info, None)?;

    // Queues
    
    data.graphics_queue = device.get_device_queue(indices.graphics, 0);

    Ok(device)

}

unsafe fn check_physical_device(instance: &Instance, data: &AppData, physical_device: vk::PhysicalDevice,) -> Result<()>{

    QueueFamilyIndices::get(instance, data, physical_device)?;
    Ok(())

}

#[derive(Copy, Clone, Debug)]
struct QueueFamilyIndices{
    
    graphics: u32,

}

impl QueueFamilyIndices {

    unsafe fn get(instance: &Instance, data: &AppData, physical_device: vk::PhysicalDevice) -> Result<Self> {

        let properties = instance.get_physical_device_queue_family_properties(physical_device);

        let graphics = properties
            .iter()
            .position(|p| p.queue_flags.contains(vk::QueueFlags::GRAPHICS))
            .map(|i| i as u32);

        if let Some(graphics) = graphics{

            Ok( Self { graphics } )

        }else {

            Err(anyhow!(SuitabilityError("Missing required queue families.")))

        }
    
    }

}
