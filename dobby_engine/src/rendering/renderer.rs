use anyhow::Result;
use winit::window::Window;
use vulkanalia::prelude::v1_0::*;


pub trait Renderer {
    
    unsafe fn create(_window: &Window) -> Result<Self>
        where
            Self: Sized;

    unsafe fn render(&mut self, window: &Window) -> Result<()>;
    
    unsafe fn destroy (&mut self);

    fn device(&self) -> &Device;

}
