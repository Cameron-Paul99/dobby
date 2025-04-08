use anyhow::{anyhow, Result, Context};
use shaderc::{Compiler, ShaderKind, CompileOptions, OptimizationLevel};
use vulkanalia::prelude::v1_0::*;
use vulkanalia::bytecode::Bytecode;
use bytemuck::cast_slice;

use crate::rendering::vulkan_app::AppData;

macro_rules! graphics_pipeline {
    ({
        vert: $vert:expr,
        $(frag: $frag:expr,)?
        $(layout: $layout:expr,)?
        $(render_pass: $render_pass:expr,)?
        $(tesc: $tesc:expr,)?
        $(tese: $tese:expr,)?
        $(topology: $topology:expr,)?
        $(control_points: $control_points:expr,)?
        $(polygon_mode: $polygon_mode:expr,)?
        $(cull_mode: $cull_mode:expr,)?
        $(samples: $samples:expr,)?
        $(enable_depth: $enable_depth:expr,)?
        $(dynamic_state: $dynamic_state:expr,)?
        $(vertex_bindings: $vertex_bindings:expr,)?
        $(vertex_attributes: $vertex_attributes:expr,)?
        $(viewports: $viewports:expr,)?
        $(scissors: $scissors:expr,)?
        $(blend_attachments: $blend_attachments:expr,)?
        $(front_face: $front_face:expr,)?
        $(logic_op_enable: $logic_op_enable:expr,)?
        $(logic_op: $logic_op:expr,)?
        $(is_derivative: $is_derivative:expr,)?
        $(base_pipeline: $base_pipeline:expr,)?
    }) => {{
        PipelineBuilder {
            vert: $vert,
            layout: graphics_pipeline!(@default $($layout)?, vk::PipelineLayout::null()),
            render_pass: graphics_pipeline!(@default $($render_pass)?, vk::RenderPass::null()),
            frag: graphics_pipeline!(@opt $($frag)?),
            tesc: graphics_pipeline!(@opt $($tesc)?),
            tese: graphics_pipeline!(@opt $($tese)?),
            topology: graphics_pipeline!(@default $($topology)?, vk::PrimitiveTopology::TRIANGLE_LIST),
            control_points: graphics_pipeline!(@opt $($control_points)?),
            polygon_mode: graphics_pipeline!(@default $($polygon_mode)?, vk::PolygonMode::FILL),
            cull_mode: graphics_pipeline!(@default $($cull_mode)?, vk::CullModeFlags::BACK),
            samples: graphics_pipeline!(@default $($samples)?, vk::SampleCountFlags::_1),
            enable_depth: graphics_pipeline!(@default $($enable_depth)?, false),
            dynamic_state: graphics_pipeline!(@opt $($dynamic_state)?),
            vertex_bindings: graphics_pipeline!(@default $($vertex_bindings)?, &[]),
            vertex_attributes: graphics_pipeline!(@default $($vertex_attributes)?, &[]),
            viewports: graphics_pipeline!(@default $($viewports)?, &[]),
            scissors: graphics_pipeline!(@default $($scissors)?, &[]),
            blend_attachments: graphics_pipeline!(@default $($blend_attachments)?, &[]),
            front_face: graphics_pipeline!(@default $($front_face)?, vk::FrontFace::CLOCKWISE),
            logic_op_enable: graphics_pipeline!(@default $($logic_op_enable)?, false),
            logic_op: graphics_pipeline!(@default $($logic_op)?, vk::LogicOp::COPY),
            is_derivative: graphics_pipeline!(@default $($is_derivative)?, false),
            base_pipeline: graphics_pipeline!(@opt $($base_pipeline)?),
        }
    }};

    // internal helpers
    (@opt $val:expr) => { Some($val) };
    (@opt) => { None };
    (@default $val:expr, $default:expr) => { $val };
    (@default, $default:expr) => { $default };
}



pub unsafe fn create_pipeline(device: &Device, data: &mut AppData) -> Result<()> {
    // Stages

    let vert = include_bytes!("../shaders/vert.spv");
    let frag = include_bytes!("../shaders/frag.spv");

    let layout_info = vk::PipelineLayoutCreateInfo::builder();
    let layout = device.create_pipeline_layout(&layout_info, None)?;  

    let builder = graphics_pipeline!({
        vert: include_bytes!("../shaders/vert.spv"),
        frag: frag,
        layout: layout,
        render_pass: data.render_pass,
        topology: vk::PrimitiveTopology::TRIANGLE_LIST,
    });

    data.pipeline_layout = layout;

    data.pipeline = builder.build(device, data)?;

    Ok(())
}



unsafe fn create_shader_module(device: &Device, bytecode: &[u8]) -> Result<vk::ShaderModule> {
    
    let bytecode = Bytecode::new(bytecode).unwrap();
    let info = vk::ShaderModuleCreateInfo::builder()
    .code_size(bytecode.code_size())    
    .code(bytecode.code());
    Ok(device.create_shader_module(&info, None)?)
}

pub struct PipelineBuilder<'a> {

    pub vert: &'a [u8],
    pub frag: Option<&'a [u8]>,
    pub tesc: Option<&'a [u8]>,
    pub tese: Option<&'a [u8]>,


    pub topology: vk::PrimitiveTopology,
    pub control_points: Option<u32>,
    pub layout: vk::PipelineLayout,
    pub render_pass: vk::RenderPass,

    pub vertex_bindings: &'a [vk::VertexInputBindingDescription],
    pub vertex_attributes: &'a [vk::VertexInputAttributeDescription],

    pub viewports: &'a [vk::Viewport],
    pub scissors: &'a [vk::Rect2D],
    pub dynamic_state: Option<&'a [vk::DynamicState]>,

    pub polygon_mode: vk::PolygonMode,
    pub cull_mode: vk::CullModeFlags,
    pub front_face: vk::FrontFace,

    pub enable_depth: bool,

    pub samples: vk::SampleCountFlags,

    pub blend_attachments: &'a [vk::PipelineColorBlendAttachmentState],
    pub logic_op_enable: bool,
    pub logic_op: vk::LogicOp,

    pub is_derivative: bool,
    pub base_pipeline: Option<vk::Pipeline>,

}

impl <'a> PipelineBuilder<'a> {
    
    pub unsafe fn build(self, device: &Device, data: &mut AppData ) -> Result<vk::Pipeline> {

        let vert_module = create_shader_module(device, self.vert)?;
        let frag_module = match self.frag {
            Some(code) => Some(create_shader_module(device, code)?),
            None => None,
        };

        let tesc_module = match self.tesc{
            Some(code) => Some(create_shader_module(device, code)?),
            None => None,
        };

        let tese_module = match self.tese{
            Some(code) => Some(create_shader_module(device, code)?),
            None => None,
        };

        let mut stages = vec![
            vk::PipelineShaderStageCreateInfo::builder()
                .stage(vk::ShaderStageFlags::VERTEX)
                .module(vert_module)
                .name(b"main\0")
                .build()
        ];

        if let Some(tesc) = tesc_module {
            
            stages.push(vk::PipelineShaderStageCreateInfo::builder()
                .stage(vk::ShaderStageFlags::TESSELLATION_CONTROL)
                .module(tesc)
                .name(b"main\0")
                .build());
        }

        if let Some(tese) = tese_module {

            stages.push(vk::PipelineShaderStageCreateInfo::builder()
                .stage(vk::ShaderStageFlags::TESSELLATION_EVALUATION)
                .module(tese)
                .name(b"main\0")
                .build());

        }

        let input_assembly = vk::PipelineInputAssemblyStateCreateInfo::builder()
            .topology(self.topology)
            .primitive_restart_enable(false);

        let tess_state = if self.topology == vk::PrimitiveTopology::PATCH_LIST {
           
            Some(vk::PipelineTessellationStateCreateInfo::builder()
                .patch_control_points(self.control_points.unwrap_or(3))
                .build())
        }else{
            
            None
    
        };

        let viewport = vk::Viewport::builder().x(0.0).y(0.0)
            .width(data.swapchain_extent.width as f32)
            .height(data.swapchain_extent.height as f32)
            .min_depth(0.0)
            .max_depth(1.0)
            .build();

        let viewports = [viewport];

        let scissor = vk::Rect2D::builder()
            .offset(vk::Offset2D {x:0, y:0})
            .extent(data.swapchain_extent)
            .build();

        let scissors = [scissor];

        let viewport_state = vk::PipelineViewportStateCreateInfo::builder().viewports(&viewports).scissors(&scissors);

        let raster_state = vk::PipelineRasterizationStateCreateInfo::builder()
            .depth_clamp_enable(false)
            .rasterizer_discard_enable(false)
            .polygon_mode(self.polygon_mode)
            .line_width(1.0)
            .cull_mode(self.cull_mode)
            .front_face(vk::FrontFace::CLOCKWISE)
            .depth_bias_enable(false);

        let multisample_state = vk::PipelineMultisampleStateCreateInfo::builder()
            .sample_shading_enable(false)
            .rasterization_samples(vk::SampleCountFlags::_1);

         let binding = [vk::PipelineColorBlendAttachmentState::builder()
            .color_write_mask(vk::ColorComponentFlags::all())
            .blend_enable(false)
            .build()];
  
        let blend_state = vk::PipelineColorBlendStateCreateInfo::builder()
            .logic_op_enable(false)
            .logic_op(vk::LogicOp::COPY)
            .attachments(&binding)
            .blend_constants([0.0, 0.0, 0.0, 0.0]);
        
        let vert_input_state = vk::PipelineVertexInputStateCreateInfo::default();

        let mut pipeline_info = vk::GraphicsPipelineCreateInfo::builder()
            .stages(&stages)
            .vertex_input_state(&vert_input_state)
            .input_assembly_state(&input_assembly)
            .viewport_state(&viewport_state)
            .rasterization_state(&raster_state)
            .multisample_state(&multisample_state)
            .color_blend_state(&blend_state)
            .layout(self.layout)
            .render_pass(self.render_pass)
            .subpass(0);
        
        if let Some(ref tess) = tess_state {
            
            pipeline_info = pipeline_info.tessellation_state(tess);

        }

        let pipeline = device
            .create_graphics_pipelines(vk::PipelineCache::null(), &[pipeline_info.build()], None)?
            .0[0];

        device.destroy_shader_module(vert_module, None);
        if let Some(f) = frag_module {device.destroy_shader_module(f, None);}

        if let Some(t) = tesc_module {device.destroy_shader_module(t, None);}
        
        if let Some(t) = tese_module {device.destroy_shader_module(t, None);}

        Ok(pipeline)
    }



    

}


