use crate::rendering::vulkan_app::VulkanApp;
use crate::rendering::renderer::Renderer;
use winit::event_loop::EventLoop;
use winit::event::{Event, WindowEvent};
use winit::window::{WindowBuilder, Window};
use anyhow::Result;

pub struct App {
    window: Window,
    event_loop: EventLoop<()>,
}

impl App {

    pub fn new (title : &str) -> Self{

        let event_loop = EventLoop::new().unwrap();

        let window = WindowBuilder::new()
            .with_title(title)
            .with_inner_size(winit::dpi::LogicalSize::new(800, 600))
            .build(&event_loop)
            .expect("Failed to create window");

        println!("Window created {:?}", window);
        
        Self {

            window,
            event_loop,
        
        }
    }

    pub fn run(self) -> Result<()>{

        let App {window, event_loop } = self;

        let mut renderer : Box<dyn Renderer> = Box::new( unsafe { VulkanApp::create(&window)? });
        
        event_loop.run(move |event, elwt|{


            match event {
                
                Event::WindowEvent {event, .. } => match event {

                    WindowEvent::CloseRequested => {
                    
                        println!("Window close requested");

                        elwt.exit();
                        unsafe { renderer.destroy(); }
                    
                    }

                    WindowEvent::Resized(size) => {
                    
                        println!("Window resized: {:?}", size);

                    }

                    WindowEvent::RedrawRequested if !elwt.exiting() => {
                        
                        unsafe { renderer.render(&window) }.unwrap()

                    }

                    _ => {}

                }
                // Use for About wait
                Event::AboutToWait => {

                    // Update Logic (physics, AI, etc.)                
                    window.request_redraw();
                
                }

                _ => {}

            }

        });

        Ok(())
    }

}
