use thiserror::Error;
use anyhow::{anyhow, Result};
use super::vulkan_app::{AppData, PORTABILITY_MACOS_VERSION};
use vulkanalia::prelude::v1_0::*;
use log::*;
use crate::debug::vulkan::{VALIDATION_ENABLED, validation_layers, VALIDATION_LAYER};
use std::collections::HashSet;
use vulkanalia::vk::KhrSurfaceExtension;
use vulkanalia::vk::KhrSwapchainExtension;
use super::swapchain::SwapchainSupport;

const DEVICE_EXTENSIONS: &[vk::ExtensionName] = &[vk::KHR_SWAPCHAIN_EXTENSION.name];

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

        // For the graphics and present queue
    let mut unique_indices = HashSet::new();
    unique_indices.insert(indices.graphics);
    unique_indices.insert(indices.present);

        // Queue Priority 
    let queue_priorities = &[1.0];

        // Creating of queue from family
    let queue_infos = unique_indices.iter().map(|i| {

            vk::DeviceQueueCreateInfo::builder()
                .queue_family_index(*i)
                .queue_priorities(queue_priorities)
        })
        .collect::<Vec<_>>();
    
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

    let mut extensions = DEVICE_EXTENSIONS.iter().map (|n| n.as_ptr()).collect::<Vec<_>>();

    // Required by Vulkan SDK on macOS since 1.3.216.
    if cfg!(target_os = "macos") && entry.version()? >= PORTABILITY_MACOS_VERSION {

        extensions.push(vk::KHR_PORTABILITY_SUBSET_EXTENSION.name.as_ptr());

    }

    // Features
    //
    let features = vk::PhysicalDeviceFeatures::builder();

    // Create
    //
    let info = vk::DeviceCreateInfo::builder()
        .queue_create_infos(&queue_infos)
        .enabled_layer_names(&layers)
        .enabled_extension_names(&extensions)
        .enabled_features(&features);

    let device = instance.create_device(data.physical_device, &info, None)?;

    // Queues
    
    data.graphics_queue = device.get_device_queue(indices.graphics, 0);
    data.present_queue = device.get_device_queue(indices.present, 0);

    Ok(device)

}

unsafe fn check_physical_device(instance: &Instance, data: &AppData, physical_device: vk::PhysicalDevice,) -> Result<()>{

    QueueFamilyIndices::get(instance, data, physical_device)?;

    check_physical_device_extensions(instance, physical_device)?;

    let support = SwapchainSupport::get(instance, data, physical_device)?;
    if support.formats.is_empty() || support.present_modes.is_empty() {

        return Err(anyhow!(SuitabilityError("Insufficient swapchain support.")));

    }

    Ok(())

}

unsafe fn check_physical_device_extensions( instance: &Instance, physical_device: vk::PhysicalDevice) -> Result<()>{

    let extensions = instance.enumerate_device_extension_properties(physical_device, None)?
        .iter()
        .map(|e| e.extension_name)
        .collect::<HashSet<_>>();

    if DEVICE_EXTENSIONS.iter().all(|e| extensions.contains(e)) {

        Ok(())

    }else{
        
        Err(anyhow!(SuitabilityError("Missing required device extensions.")))

    }

}

#[derive(Copy, Clone, Debug)]
pub struct QueueFamilyIndices{
    
  pub  graphics: u32,
  pub  present: u32,

}

impl QueueFamilyIndices {

   pub unsafe fn get(instance: &Instance, data: &AppData, physical_device: vk::PhysicalDevice) -> Result<Self> {
        
        let properties = instance.get_physical_device_queue_family_properties(physical_device);

        let mut present = None;

        for (index, properties) in properties.iter().enumerate(){
            
            if instance.get_physical_device_surface_support_khr(

                physical_device,
                index as u32,
                data.surface,
            )? {
                
                present = Some(index as u32);
                break;

            }

        }

        let graphics = properties
            .iter()
            .position(|p| p.queue_flags.contains(vk::QueueFlags::GRAPHICS))
            .map(|i| i as u32);

        if let ( Some(graphics) , Some(present) ) = (graphics, present){

            Ok( Self { graphics, present } )

        }else {

            Err(anyhow!(SuitabilityError("Missing required queue families.")))

        }
    
    }

}
