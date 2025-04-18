

// Final version of the pipeline module with hardcoded elements removed and full macro + builder flexibility

use anyhow::{Result};
use vulkanalia::prelude::v1_0::*;
use vulkanalia::bytecode::Bytecode;
use crate::rendering::vulkan_app::AppData;
use crate::rendering::vertex_data::Vertex;
use crate::rendering::vertex_data::VertexInputBuilder;

#[macro_export]
macro_rules! graphics_pipeline {
    ({
        vert: $vert:expr,
        $(frag: $frag:expr,)?
        $(tesc: $tesc:expr,)?
        $(tese: $tese:expr,)?
        $(render_pass: $render_pass:expr,)?
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
        $(blend_constants: $blend_constants:expr,)?
        $(front_face: $front_face:expr,)?
        $(logic_op_enable: $logic_op_enable:expr,)?
        $(logic_op: $logic_op:expr,)?
        $(is_derivative: $is_derivative:expr,)?
        $(base_pipeline: $base_pipeline:expr,)?
        $(primitive_restart_enable: $primitive_restart_enable:expr,)?
        $(depth_clamp_enable: $depth_clamp_enable:expr,)?
        $(rasterizer_discard_enable: $rasterizer_discard_enable:expr,)?
        $(depth_bias_enable: $depth_bias_enable:expr,)?
        $(sample_shading_enable: $sample_shading_enable:expr,)?
        $(line_width: $line_width:expr,)?
        $(descriptors: $descriptors:expr,)?
    }) => {{
        PipelineBuilder {
            vert: $vert,
            frag: graphics_pipeline!(@opt $($frag)?),
            tesc: graphics_pipeline!(@opt $($tesc)?),
            tese: graphics_pipeline!(@opt $($tese)?),
            render_pass: graphics_pipeline!(@default $($render_pass)?, vk::RenderPass::null()),
            topology: graphics_pipeline!(@default $($topology)?, vk::PrimitiveTopology::TRIANGLE_LIST),
            control_points: graphics_pipeline!(@opt $($control_points)?),
            polygon_mode: graphics_pipeline!(@default $($polygon_mode)?, vk::PolygonMode::FILL),
            cull_mode: graphics_pipeline!(@default $($cull_mode)?, vk::CullModeFlags::BACK),
            front_face: graphics_pipeline!(@default $($front_face)?, vk::FrontFace::COUNTER_CLOCKWISE),
            samples: graphics_pipeline!(@default $($samples)?, vk::SampleCountFlags::_1),
            enable_depth: graphics_pipeline!(@default $($enable_depth)?, false),
            dynamic_state: graphics_pipeline!(@opt $($dynamic_state)?),
            vertex_bindings: graphics_pipeline!(@default $($vertex_bindings)?, &[]),
            vertex_attributes: graphics_pipeline!(@default $($vertex_attributes)?, &[]),
            viewports: graphics_pipeline!(@default $($viewports)?, &[]),
            scissors: graphics_pipeline!(@default $($scissors)?, &[]),
            blend_attachments: graphics_pipeline!(@default $($blend_attachments)?, &[]),
            blend_constants: graphics_pipeline!(@default $($blend_constants)?, [0.0, 0.0, 0.0, 0.0]),
            logic_op_enable: graphics_pipeline!(@default $($logic_op_enable)?, false),
            logic_op: graphics_pipeline!(@default $($logic_op)?, vk::LogicOp::COPY),
            is_derivative: graphics_pipeline!(@default $($is_derivative)?, false),
            base_pipeline: graphics_pipeline!(@opt $($base_pipeline)?),
            primitive_restart_enable: graphics_pipeline!(@default $($primitive_restart_enable)?, false),
            depth_clamp_enable: graphics_pipeline!(@default $($depth_clamp_enable)?, false),
            rasterizer_discard_enable: graphics_pipeline!(@default $($rasterizer_discard_enable)?, false),
            depth_bias_enable: graphics_pipeline!(@default $($depth_bias_enable)?, false),
            sample_shading_enable: graphics_pipeline!(@default $($sample_shading_enable)?, false),
            line_width: graphics_pipeline!(@default $($line_width)?, 1.0),
            descriptors: graphics_pipeline!(@opt $($descriptors)?),
        }
    }};

    (@opt $val:expr) => { Some($val) };
    (@opt) => { None };
    (@default $val:expr, $default:expr) => { $val };
    (@default, $default:expr) => { $default };
}

pub struct PipelineBuilder<'a> {
    pub vert: &'a [u8],
    pub frag: Option<&'a [u8]>,
    pub tesc: Option<&'a [u8]>,
    pub tese: Option<&'a [u8]>,
    pub render_pass: vk::RenderPass,
    pub topology: vk::PrimitiveTopology,
    pub control_points: Option<u32>,
    pub polygon_mode: vk::PolygonMode,
    pub cull_mode: vk::CullModeFlags,
    pub front_face: vk::FrontFace,
    pub samples: vk::SampleCountFlags,
    pub enable_depth: bool,
    pub dynamic_state: Option<&'a [vk::DynamicState]>,
    pub vertex_bindings: &'a [vk::VertexInputBindingDescription],
    pub vertex_attributes: &'a [vk::VertexInputAttributeDescription],
    pub viewports: &'a [vk::Viewport],
    pub scissors: &'a [vk::Rect2D],
    pub blend_attachments: &'a [vk::PipelineColorBlendAttachmentState],
    pub blend_constants: [f32; 4],
    pub logic_op_enable: bool,
    pub logic_op: vk::LogicOp,
    pub is_derivative: bool,
    pub base_pipeline: Option<vk::Pipeline>,
    pub primitive_restart_enable: bool,
    pub depth_clamp_enable: bool,
    pub rasterizer_discard_enable: bool,
    pub depth_bias_enable: bool,
    pub sample_shading_enable: bool,
    pub line_width: f32,
    pub descriptors: Option<&'a [vk::DescriptorSetLayout]>,
}

impl<'a> PipelineBuilder<'a> {
    pub unsafe fn build(self, device: &Device) -> anyhow::Result<(vk::Pipeline, vk::PipelineLayout)> {
        let vert_module = create_shader_module(device, self.vert)?;
        let mut stages = vec![vk::PipelineShaderStageCreateInfo::builder()
            .stage(vk::ShaderStageFlags::VERTEX)
            .module(vert_module)
            .name(b"main ")
            .build()];

        let frag_module = match self.frag {
            Some(code) => Some(create_shader_module(device, code)?),
            None => None,
        };

        if let Some(f) = frag_module {
            stages.push(vk::PipelineShaderStageCreateInfo::builder()
                .stage(vk::ShaderStageFlags::FRAGMENT)
                .module(f)
                .name(b"main ")
                .build());
        }

        let tesc_module = match self.tesc {
            Some(code) => Some(create_shader_module(device, code)?),
            None => None,
        };

        if let Some(t) = tesc_module {
            stages.push(vk::PipelineShaderStageCreateInfo::builder()
                .stage(vk::ShaderStageFlags::TESSELLATION_CONTROL)
                .module(t)
                .name(b"main ")
                .build());
        }

        let tese_module = match self.tese {
            Some(code) => Some(create_shader_module(device, code)?),
            None => None,
        };

        if let Some(t) = tese_module {
            stages.push(vk::PipelineShaderStageCreateInfo::builder()
                .stage(vk::ShaderStageFlags::TESSELLATION_EVALUATION)
                .module(t)
                .name(b"main ")
                .build());
        }

        let input_assembly = vk::PipelineInputAssemblyStateCreateInfo::builder()
            .topology(self.topology)
            .primitive_restart_enable(self.primitive_restart_enable);

        let tessellation_state = if self.topology == vk::PrimitiveTopology::PATCH_LIST {
            Some(vk::PipelineTessellationStateCreateInfo::builder()
                .patch_control_points(self.control_points.unwrap_or(3))
                .build())
        } else {
            None
        };

        let vertex_input = VertexInputBuilder::new();
        let vert_bind_des = &[vertex_input.binding_description()];
        let vertex_input_state = vk::PipelineVertexInputStateCreateInfo::builder()
            .vertex_binding_descriptions(vert_bind_des)
            .vertex_attribute_descriptions(vertex_input.attribute_descriptions());


        let viewport_state = vk::PipelineViewportStateCreateInfo::builder()
            .viewports(self.viewports)
            .scissors(self.scissors);

        let rasterization_state = vk::PipelineRasterizationStateCreateInfo::builder()
            .depth_clamp_enable(self.depth_clamp_enable)
            .rasterizer_discard_enable(self.rasterizer_discard_enable)
            .polygon_mode(self.polygon_mode)
            .cull_mode(self.cull_mode)
            .front_face(self.front_face)
            .depth_bias_enable(self.depth_bias_enable)
            .line_width(self.line_width);

        let multisample_state = vk::PipelineMultisampleStateCreateInfo::builder()
            .rasterization_samples(self.samples)
            .sample_shading_enable(self.sample_shading_enable);

        let blend_state = vk::PipelineColorBlendStateCreateInfo::builder()
            .logic_op_enable(self.logic_op_enable)
            .logic_op(self.logic_op)
            .attachments(self.blend_attachments)
            .blend_constants(self.blend_constants);

        let layout_info = vk::PipelineLayoutCreateInfo::builder()
            .set_layouts(self.descriptors.unwrap_or(&[]));
        let layout = device.create_pipeline_layout(&layout_info, None)?;

        let mut pipeline_info = vk::GraphicsPipelineCreateInfo::builder()
            .stages(&stages)
            .vertex_input_state(&vertex_input_state)
            .input_assembly_state(&input_assembly)
            .viewport_state(&viewport_state)
            .rasterization_state(&rasterization_state)
            .multisample_state(&multisample_state)
            .color_blend_state(&blend_state)
            .layout(layout)
            .render_pass(self.render_pass)
            .subpass(0);

        if let Some(ref tess) = tessellation_state {
            pipeline_info = pipeline_info.tessellation_state(tess);
        }
       // let dynamic_info;
        //if let Some(ref dynamic_states) = self.dynamic_state {
         //   dynamic_info = vk::PipelineDynamicStateCreateInfo::builder()
          //      .dynamic_states(dynamic_states);
           // pipeline_info = pipeline_info.dynamic_state(&dynamic_info);
       // }

        let pipeline = device.create_graphics_pipelines(
            vk::PipelineCache::null(), &[pipeline_info.build()], None
        )?.0[0];

        // Cleanup shader modules
        device.destroy_shader_module(vert_module, None);
        if let Some(f) = frag_module {
            device.destroy_shader_module(f, None);
        }
        if let Some(t) = tesc_module {
            device.destroy_shader_module(t, None);
        }
        if let Some(t) = tese_module {
            device.destroy_shader_module(t, None);
        }

        Ok((pipeline, layout ))
    }
}
pub unsafe fn create_pipeline(device: &Device, data: &mut AppData) -> Result<()> {
    // Stages

    let set_layouts = &[data.descriptor_set_layout];

    let layout_info = vk::PipelineLayoutCreateInfo::builder()
        .set_layouts(set_layouts);

    let builder = graphics_pipeline!({
        vert: include_bytes!("../shaders/vert.spv"),
        frag: include_bytes!("../shaders/frag.spv"),
        render_pass: data.render_pass,
        topology: vk::PrimitiveTopology::TRIANGLE_LIST,
        vertex_bindings: &[Vertex::binding_description()],
        vertex_attributes: &Vertex::attribute_descriptions(),
        viewports: &[vk::Viewport {
            x: 0.0,
            y: 0.0,
            width: data.swapchain_extent.width as f32,
            height: data.swapchain_extent.height as f32,
            min_depth: 0.0,
            max_depth: 1.0,
        }],
        scissors: &[vk::Rect2D {
            offset: vk::Offset2D { x: 0, y: 0 },
            extent: data.swapchain_extent,
        }],
        blend_attachments: &[vk::PipelineColorBlendAttachmentState::builder()
            .blend_enable(false)
            .color_write_mask(
            vk::ColorComponentFlags::R |
            vk::ColorComponentFlags::G |
            vk::ColorComponentFlags::B |
            vk::ColorComponentFlags::A
        ).build()],
        descriptors: set_layouts,
    });

    let (pipeline, layout) = builder.build(device)?;

    data.pipeline = pipeline;
    data.pipeline_layout = layout;

    Ok(())
}



unsafe fn create_shader_module(device: &Device, bytecode: &[u8]) -> Result<vk::ShaderModule> {
    
    let bytecode = Bytecode::new(bytecode).unwrap();
    let info = vk::ShaderModuleCreateInfo::builder()
    .code_size(bytecode.code_size())    
    .code(bytecode.code());
    Ok(device.create_shader_module(&info, None)?)
}


