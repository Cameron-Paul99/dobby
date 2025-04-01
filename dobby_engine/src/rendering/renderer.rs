use anyhow::Result;
use winit::window::Window;


pub trait Renderer {
    
    unsafe fn create(_window: &Window) -> Result<Self>
        where
            Self: Sized;

    unsafe fn render(&mut self, window: &Window) -> Result<()>;
    
    unsafe fn destroy (&mut self);


}
