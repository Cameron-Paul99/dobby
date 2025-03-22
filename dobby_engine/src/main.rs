mod platform;
mod rendering;
mod debug;
use platform::window::App;
use log::{debug, info, warn, error, trace};

fn main() {
    pretty_env_logger::init();
    debug!("Testing logging...");
    let app = App::new("Dobby Engine");
    app.run();

}
