use winit::{
        event::{Event, WindowEvent},
        event_loop::{ControlFlow, EventLoop},
        window::WindowBuilder,

};


pub struct App {
    window: winit::window::Window,
    event_loop: EventLoop<()>,
}

impl App {

    pub fn new (title : &str) -> Self{

        let event_loop = EventLoop::new();

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

    pub fn run(self){
        
        self.event_loop.run(move | event, _, control_flow|{

            *control_flow = ControlFlow::Wait;

            match event {
                
                Event::WindowEvent {event, .. } => match event {

                    WindowEvent::CloseRequested => {
                    
                        println!("Window close requested");

                        *control_flow = ControlFlow::Exit;
                    
                    }

                    WindowEvent::Resized(size) => {
                    
                        println!("Window resized: {:?}", size);

                    }

                    WindowEvent::KeyboardInput { input, .. } => {

                        println!("Keyboard input: {:?}", input);

                    }

                    _ => {}

                }

                Event::MainEventsCleared => {

                    // Update Logic (physics, AI, etc.)                
                    self.window.request_redraw();
                
                }

                Event::RedrawRequested(_) => {

                    // Render here (vulkan, WGPU, etc)
                    println!("Redrawing the window");
                    
                }

                _ => {}

            }

        });

    }

}
