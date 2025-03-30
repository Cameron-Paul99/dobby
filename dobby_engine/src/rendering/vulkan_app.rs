#![allow(dead_code, unused_variables, clippy::manual_slice_size_calculation, clippy::too_many_arguments, clippy::unnecessary_wraps)]

use winit::window::Window;
use anyhow::{anyhow, Result};
use log::*;
use vulkanalia::loader::{LibloadingLoader, LIBRARY};
use vulkanalia::window as vk_window;
use vulkanalia::prelude::v1_0::*;
use vulkanalia::Version;
use vulkanalia::vk::KhrSurfaceExtension;
use crate::debug::vulkan::{VALIDATION_ENABLED, validation_layers, debug_messenger_info,};
use vulkanalia::vk::ExtDebugUtilsExtension;
use super::device::{pick_physical_device, create_logical_device};
use super::swapchain::{create_swapchain, create_swapchain_image_views};
use vulkanalia::vk::KhrSwapchainExtension;
// Some hardware isn't compatible with Vulkan like macOS
pub const PORTABILITY_MACOS_VERSION: Version = Version::new(1, 3, 216);

#[derive(Debug)]
pub struct VulkanApp {
    
    entry: Entry,
    instance: Instance,
    data: AppData,
    device: Device,

}


// Unsafe functions are for the vulkan commands. Rust cannot keep it safe
impl VulkanApp {
    
    pub unsafe fn create(_window: &Window) -> Result<Self> {

        let loader = LibloadingLoader::new(LIBRARY)?;
        let entry = Entry::new(loader).map_err(|b| anyhow!("{}", b))?;

        let mut data = AppData::default();
        let instance = create_instance(_window, &entry, &mut data )?;

        data.surface = vk_window::create_surface(&instance, &_window, &_window)?;

        pick_physical_device(&instance, &mut data)?;
        let device = create_logical_device(&entry, &instance, &mut data)?;
        create_swapchain(_window, &instance, &mut data, &device);
        create_swapchain_image_views(&device, &mut data)?;
        println!("Creating Vulkan App");
        Ok(Self {entry, instance, data, device})

    }


    pub unsafe fn render(&mut self, _window: &Window) -> Result<()> {

//        println!("Rendering frame...");
        Ok(())

    }

    pub unsafe fn destroy(&mut self) {

        self.data.swapchain_image_views
            .iter()
            .for_each(|v| self.device.destroy_image_view(*v, None));

        self.device.destroy_swapchain_khr(self.data.swapchain, None);
        self.device.destroy_device(None);
    
        if VALIDATION_ENABLED {
            self.instance.destroy_debug_utils_messenger_ext(self.data.messenger, None);
        
         }

        self.instance.destroy_surface_khr(self.data.surface, None);
        self.instance.destroy_instance(None);

        println!("Destroying Vulkan App (unsafe)");
         
    }

}

    // Window is app window
    // Entry is the vulkan entry point

unsafe fn create_instance(window: &Window, entry: &Entry, data: &mut AppData) -> Result<Instance> {
    
    // (Optional) Provides application info for instance that connects app to vulkan library
    let application_info = vk::ApplicationInfo::builder()
        .application_name(b"Dobby\0")
        .application_version(vk::make_version(1,0,0))
        .engine_name(b"Dobby Engine\0")
        .engine_version(vk::make_version(1,0,0))
        .api_version(vk::make_version(1,0,0));

    let layers = validation_layers(entry)?;

    // Mandatory: Tells Vulkan driver what extensions/validation layers we want to use. Global so
    // entire program
    //
    // vk_window enumerate the global extensions and convert them into null-terminated C strings
    let mut extensions = vk_window::get_required_instance_extensions(window)
        .iter()
        .map(|e| e.as_ptr())
        .collect::<Vec<_>>();

    // Flags are used for some hardware/drivers that don't fully support Vulkan such as macOS
    let flags = if
        cfg!(target_os = "macos") &&
        entry.version()? >= PORTABILITY_MACOS_VERSION
    {
        info!("Enabling extensions for macOS portability.");
        extensions.push(vk::KHR_GET_PHYSICAL_DEVICE_PROPERTIES2_EXTENSION.name.as_ptr());
        extensions.push(vk::KHR_PORTABILITY_ENUMERATION_EXTENSION.name.as_ptr());
        vk::InstanceCreateFlags::ENUMERATE_PORTABILITY_KHR

    }else{

        vk::InstanceCreateFlags::empty()

    };

    if VALIDATION_ENABLED {
        extensions.push(vk::EXT_DEBUG_UTILS_EXTENSION.name.as_ptr());
    }

    let mut debug_info = debug_messenger_info();

    let mut info = vk::InstanceCreateInfo::builder()
        .application_info(&application_info)
        .enabled_layer_names(&layers)
        .enabled_extension_names(&extensions)
        .flags(flags);

    if VALIDATION_ENABLED {
        info = info.push_next(&mut debug_info)
    }

    let instance = entry.create_instance(&info, None)?;

    if VALIDATION_ENABLED {

        data.messenger = instance.create_debug_utils_messenger_ext(&debug_info, None)?;
        
    }

    Ok(instance)
}

#[derive(Clone, Debug, Default)]
pub struct AppData {

    // Debug callback handler that needs to be destroyed. This is apart of vulkans debug validation
    // layers
    messenger: vk::DebugUtilsMessengerEXT,
    pub physical_device: vk::PhysicalDevice,
    pub graphics_queue: vk::Queue,
    pub surface: vk::SurfaceKHR,
    pub present_queue: vk::Queue,
    pub swapchain_extent: vk::Extent2D,
    pub swapchain_format: vk::Format,
    pub swapchain: vk::SwapchainKHR,
    pub swapchain_images: Vec<vk::Image>,
    pub swapchain_image_views: Vec<vk::ImageView>,


}
