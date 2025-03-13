mod platform;

use platform::window::App;

fn main() {
    let app = App::new("Dobby Engine");
    app.run();
}
