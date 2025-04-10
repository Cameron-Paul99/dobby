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
use super::pipeline::create_pipeline;
use super::renderer::Renderer;
use super::render_pass::create_render_pass;
use super::framebuffer::create_framebuffers;
use super::command::create_command_pool;
use super::sync::{create_sync_objects, MAX_FRAMES_IN_FLIGHT};
use vulkanalia::vk::KhrSwapchainExtension;
// Some hardware isn't compatible with Vulkan like macOS
pub const PORTABILITY_MACOS_VERSION: Version = Version::new(1, 3, 216);

#[derive(Debug)]
pub struct VulkanApp {
    
    entry: Entry,
    instance: Instance,
    data: AppData,
    device: Device,
    frame: usize,

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
        create_render_pass(&instance, &device, &mut data)?;
        create_pipeline(&device, &mut data)?;
        create_framebuffers(&device, &mut data)?;
        create_command_pool(&instance, &device, &mut data)?;
        create_sync_objects(&device, &mut data)?;
        println!("Creating Vulkan App");

        Ok(Self {entry, instance, data, device, frame: 0})

    }


    pub unsafe fn render(&mut self, _window: &Window) -> Result<()> {
       
        let in_flight_fence = self.data.in_flight_fences[self.frame];

        self.device.wait_for_fences(&[in_flight_fence], true, u64::MAX)?;

        let image_index = self
            .device
            .acquire_next_image_khr(
                self.data.swapchain,
                u64::MAX,
                self.data.image_available_semaphores[self.frame],
                vk::Fence::null(),
            )?
            .0 as usize;

        let image_in_flight = self.data.images_in_flight[image_index];
        if !image_in_flight.is_null() {
            self.device.wait_for_fences(&[image_in_flight], true, u64::MAX)?;
        }

        self.data.images_in_flight[image_index] = in_flight_fence;

        let wait_semaphores = &[self.data.image_available_semaphores[self.frame]];
        let wait_stages = &[vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT];
        let command_buffers = &[self.data.command_buffers[image_index]];
        let signal_semaphores = &[self.data.render_finished_semaphores[self.frame]];
        let submit_info = vk::SubmitInfo::builder()
            .wait_semaphores(wait_semaphores)
            .wait_dst_stage_mask(wait_stages)
            .command_buffers(command_buffers)
            .signal_semaphores(signal_semaphores);

        self.device.reset_fences(&[in_flight_fence])?;

        self.device
            .queue_submit(self.data.graphics_queue, &[submit_info], in_flight_fence)?;

        let swapchains = &[self.data.swapchain];
        let image_indices = &[image_index as u32];
        let present_info = vk::PresentInfoKHR::builder()
            .wait_semaphores(signal_semaphores)
            .swapchains(swapchains)
            .image_indices(image_indices);

        self.device.queue_present_khr(self.data.present_queue, &present_info)?;

        self.frame = (self.frame + 1) % MAX_FRAMES_IN_FLIGHT;

        Ok(())
    }

    pub unsafe fn destroy(&mut self) {
        self.data.in_flight_fences
            .iter()
            .for_each(|f| self.device.destroy_fence(*f, None));
        self.data.render_finished_semaphores
            .iter()
            .for_each(|s| self.device.destroy_semaphore(*s, None));
        self.data.image_available_semaphores
            .iter()
            .for_each(|s| self.device.destroy_semaphore(*s, None));
        self.device.destroy_command_pool(self.data.command_pool, None);
        self.data.framebuffers.iter().for_each(|f| self.device.destroy_framebuffer(*f, None));
        self.device.destroy_pipeline(self.data.pipeline, None);
        self.device.destroy_pipeline_layout(self.data.pipeline_layout, None);
        self.device.destroy_render_pass(self.data.render_pass, None);
        self.data.swapchain_image_views.iter().for_each(|v| self.device.destroy_image_view(*v, None));
        self.device.destroy_swapchain_khr(self.data.swapchain, None);
        self.device.destroy_device(None);
        self.instance.destroy_surface_khr(self.data.surface, None);

        if VALIDATION_ENABLED {
            self.instance.destroy_debug_utils_messenger_ext(self.data.messenger, None);
        }

        self.instance.destroy_instance(None);
         
    }

}

impl Renderer for VulkanApp{
    
    unsafe fn create(_window: &Window) -> Result<Self>{

        VulkanApp::create(_window)

    }

    unsafe fn render(&mut self, _window: &Window) ->Result<()>{

        self.render(_window)

    }

    unsafe fn destroy(&mut self){
        
        self.destroy()

    }    

    fn device(&self) -> &Device {
        &self.device
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
    pub pipeline_layout: vk::PipelineLayout,
    pub pipeline: vk::Pipeline,
    pub render_pass: vk::RenderPass,
    pub framebuffers: Vec<vk::Framebuffer>,
    pub command_buffers: Vec<vk::CommandBuffer>,
    pub command_pool: vk::CommandPool,
    pub image_available_semaphores: Vec<vk::Semaphore>,
    pub render_finished_semaphores: Vec<vk::Semaphore>,
    pub in_flight_fences: Vec<vk::Fence>,
    pub images_in_flight: Vec<vk::Fence>,


}
