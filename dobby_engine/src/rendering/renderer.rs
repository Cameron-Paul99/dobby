#![allow(dead_code, unused_variables, clippy::manual_slice_size_calculation, clippy::too_many_arguments, clippy::unnecessary_wraps)]

use anyhow::Result;
use winit::window::Window;
use crate::rendering::vulkan_app::AppData;
use vulkanalia::prelude::v1_0::*;



pub trait Renderer {
    
    unsafe fn create(_window: &Window) -> Result<Self>
        where
            Self: Sized;

    unsafe fn render(&mut self, window: &Window) -> Result<()>;
    
    unsafe fn destroy (&mut self);

    fn device(&self) -> &Device;

    fn set_resized(&mut self, resized: bool);

}
