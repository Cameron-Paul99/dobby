use std::ffi::CStr;
use std::os::raw::c_void;
use std::collections::HashSet;
use anyhow::Result;

use log::*;
use vulkanalia::prelude::v1_0::*;
use vulkanalia::vk::{self, ExtDebugUtilsExtension};

// Whether validation layers should be enabled
pub const VALIDATION_ENABLED: bool = cfg!(debug_assertions);

// The name of the validation layers.
pub const VALIDATION_LAYER: vk::ExtensionName = vk::ExtensionName::from_bytes(b"VK_LAYER_KHRONOS_validation");

// Returns the validation layers (if enabled), or an empty vector.
pub fn validation_layers(entry: &Entry) -> Result<Vec<*const i8>> {

    if !VALIDATION_ENABLED {

        return Ok(Vec::new());

    }

    let available_layers = unsafe { entry
        .enumerate_instance_layer_properties()
        .map_err(|e| anyhow::anyhow!("Failed to enumerate instance layers: {e}"))?
    };

    let available_names = available_layers
        .iter()
        .map(|l| l.layer_name)
        .collect::<HashSet<_>>();

    if !available_names.contains(&VALIDATION_LAYER) {
        
        return Err(anyhow::anyhow!("Validation layer requested but not supported."));

    }

    Ok(vec![VALIDATION_LAYER.as_ptr()])

}

pub fn debug_messenger_info() -> vk::DebugUtilsMessengerCreateInfoEXTBuilder<'static> {
    
    vk::DebugUtilsMessengerCreateInfoEXT::builder()
        .message_severity(vk::DebugUtilsMessageSeverityFlagsEXT::all())
        .message_type(
            vk::DebugUtilsMessageTypeFlagsEXT::GENERAL
                | vk::DebugUtilsMessageTypeFlagsEXT::VALIDATION
                | vk::DebugUtilsMessageTypeFlagsEXT::PERFORMANCE,
        )
        .user_callback(Some(debug_callback))

}

// This allows Vulkan to call rust and it is used to customize our error messages
//
//
// Paramters: 
//
// vk::DebugUtilsMessageSeverityFlagsEXT - Severity of Error
//
// vk::DebugUtilsMessageTypeFlagsEXT - Either is (GENERAL - unrelated to specification or
// performance, VALIDATION - Something has happend that violates the specification or indicates a
// mistake, PERFORMANCE - Potential non-optimal use of Vulkan
//
// vk::DebugUtilsMessengerCallbackDataEXT - contains info of error message
//
// Last Parameter is ignored and allows you to pass your own data to it. Its a pointer
//
// RETURNS a (Vulkan) bool that indicates if the vulkan call that triggered the validation layer
// message should be aborted
//
extern "system" fn debug_callback(
    severity: vk::DebugUtilsMessageSeverityFlagsEXT /* Severity of Error */,
    type_: vk::DebugUtilsMessageTypeFlagsEXT /* General - unrelated to specificication or performance, Validation - Something hase happed  */,
    data: *const vk::DebugUtilsMessengerCallbackDataEXT,
    _: *mut c_void,
) -> vk::Bool32 {

    let data = unsafe {*data};
    let message = unsafe { CStr::from_ptr(data.message) }.to_string_lossy();

    if severity >= vk::DebugUtilsMessageSeverityFlagsEXT::ERROR {

        error!("({:?}) {}", type_, message);

    }else if severity >= vk::DebugUtilsMessageSeverityFlagsEXT::WARNING {

        warn!("({:?}) {}", type_, message);

    }else if severity >= vk::DebugUtilsMessageSeverityFlagsEXT::INFO {

        debug!("({:?}) {}", type_, message);

    }else {

        trace!("({:?}) {}", type_, message);
    }

    vk::FALSE



}

