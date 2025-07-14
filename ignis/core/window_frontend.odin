package core

import "core:os"
import "core:log"

import "vendor:glfw"
import vk "vendor:vulkan"

Monitor_Type :: enum {
	Primary,
	Secondary,
}

Window_Property_Type :: enum {
	Resizable   = glfw.RESIZABLE,
	Visible     = glfw.VISIBLE,
	Decorated   = glfw.DECORATED,
	Transparent = glfw.TRANSPARENT_FRAMEBUFFER,
	Floating    = glfw.FLOATING,
}

Monitor_Details :: struct {
	width:        i32,
	height:       i32,
	refresh_rate: i32,
	type:         Monitor_Type,
}

Window_Property :: struct {
	property_type: Window_Property_Type,
	enabled:       bool
}

window_create :: proc{
	window_create_default,
	window_create_extended,
}

window_create_default :: proc(
	width:  i32,
	height: i32,
	title:  cstring,
	allocator := context.allocator,
) {
	context.allocator = allocator
	ensure(!glfw_context.initialised)
	ensure(bool(glfw.Init()))

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, true)

	glfw_context = {
		handle      = glfw.CreateWindow(width, height, title, nil, nil),
		width       = width,
		height      = height,
		title       = title,
		initialised = true,
	}
	ensure(glfw_context.handle != nil)

	glfw.SetWindowSizeCallback(glfw_context.handle, window_on_resize)

	input_init()

	layers: []cstring
	when !RELEASE do layers = {"VK_LAYER_KHRONOS_validation"}

	app_info: VK_Application_Info = {
		api_version = vk.API_VERSION_1_3,
		extensions  = {},
		layers      = layers,
	}

	// dynamic_rendering_feature: vk.PhysicalDeviceDynamicRenderingFeaturesKHR = {
	// 	sType            = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES,
	// 	dynamicRendering = true,
	// }

	device_attributes: VK_Device_Attributes = {
		// features      = &dynamic_rendering_feature,
		present_modes = {.FIFO},
		extensions    = {
			vk.KHR_SWAPCHAIN_EXTENSION_NAME,
		}
	}

	swapchain_attributes: VK_Swapchain_Attributes = {
		present_mode = .MAILBOX,
		extent = {
			width  = u32(width),
			height = u32(height)
		},
		format = {
			format     = .R8G8B8A8_SRGB,
			colorSpace = .SRGB_NONLINEAR
		},
		image_usage = {
			.COLOR_ATTACHMENT,
			.TRANSFER_DST
		},
	}

	vk_init(app_info, device_attributes, swapchain_attributes)
}

window_create_extended :: proc(
	width:               i32,
	height:              i32,
	title:               cstring,
	instance_layers:     []cstring         = {},
	instance_extensions: []cstring         = {},
	instance_features:   rawptr            = nil,
	device_extensions:   []cstring         = {vk.KHR_SWAPCHAIN_EXTENSION_NAME},
	device_features:     rawptr            = nil,
	window_properties:   []Window_Property = {},
	allocator := context.allocator
) {
	context.allocator = allocator
	ensure(!glfw_context.initialised)
	ensure(bool(glfw.Init()))

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	for property in window_properties {
		glfw.WindowHint(i32(property.property_type), i32(property.enabled))
	}

	glfw_context = {
		handle      = glfw.CreateWindow(width, height, title, nil, nil),
		width       = width,
		height      = height,
		title       = title,
		initialised = true
	}
	ensure(glfw_context.handle != nil)

	glfw.SetWindowSizeCallback(glfw_context.handle, window_on_resize)

	input_init()

	app_info: VK_Application_Info = {
		api_version = vk.API_VERSION_1_3,
		extensions  = instance_extensions,
		layers      = instance_layers,
		features    = instance_features,
	}

	found_swapchain: bool
	for extension in device_extensions {
		if extension == vk.KHR_SWAPCHAIN_EXTENSION_NAME do found_swapchain = true
	}
	if !found_swapchain {
		log.fatal("Window - Device extensions: Device extensions must contain", vk.KHR_SWAPCHAIN_EXTENSION_NAME)
		os.exit(-1)
	}

	device_attributes: VK_Device_Attributes = {
		features      = device_features,
		extensions    = device_extensions,
		present_modes = {.FIFO},
	}

	swapchain_attributes: VK_Swapchain_Attributes = {
		present_mode = .MAILBOX,
		extent = {
			width  = u32(width),
			height = u32(height)
		},
		format = {
			format     = .R8G8B8A8_SRGB,
			colorSpace = .SRGB_NONLINEAR
		},
		image_usage = {
			.COLOR_ATTACHMENT,
			.TRANSFER_DST
		},
	}

	vk_init(app_info, device_attributes, swapchain_attributes)
}

window_destroy :: proc() {
	ensure(glfw_context.initialised)

	input_destroy()
	vk_destroy()
	glfw.DestroyWindow(glfw_context.handle)
	glfw.Terminate()
}

window_poll :: proc() {
	ensure(glfw_context.initialised)

	glfw.PollEvents()
	input_poll()
}

window_should_close :: proc() -> (
	should_close: bool
) {
	ensure(glfw_context.initialised)

	return bool(glfw.WindowShouldClose(glfw_context.handle))
}

window_set_should_close :: proc(
	value: bool
) {
	ensure(glfw_context.initialised)

	glfw.SetWindowShouldClose(glfw_context.handle, b32(value))
}

window_get_size :: proc() -> (
	width:  i32,
	height: i32
) {
	ensure(glfw_context.initialised)

	return glfw_context.width, glfw_context.height
}

window_set_size :: proc(
	width:  i32,
	height: i32
) {
	ensure(glfw_context.initialised)

	glfw.SetWindowSize(glfw_context.handle, width, height)
	glfw_context.width, glfw_context.height = width, height
}

window_get_framebuffer_size :: proc() -> (
	width:  i32,
	height: i32
) {
	ensure(glfw_context.initialised)

	return glfw.GetFramebufferSize(glfw_context.handle)
}

window_wait_events :: proc() {
	ensure(glfw_context.initialised)

	glfw.WaitEvents()
}

window_go_fullscreen :: proc() {
	ensure(glfw_context.initialised)

	monitor := glfw.GetPrimaryMonitor()
	video_mode := glfw.GetVideoMode(monitor)
	
	glfw.SetWindowMonitor(
		glfw_context.handle,
		monitor,
		0, 0,
		video_mode.width, video_mode.height,
		video_mode.refresh_rate
	)
}

window_go_windowed :: proc(
	width:  i32,
	height: i32
) {
	ensure(glfw_context.initialised)

	video_mode := glfw.GetVideoMode(glfw.GetPrimaryMonitor())
	x: i32 = i32(f32(video_mode.width) / 2 - f32(width) / 2)
	y: i32 = i32(f32(video_mode.height) / 2 - f32(height) / 2)

	glfw.SetWindowMonitor(
		glfw_context.handle,
		nil,
		x, y,
		width, height,
		0
	)
}

window_get_primary_monitor_details :: proc() -> (
	monitor_details: Monitor_Details
) {
	ensure(glfw_context.initialised)

	primary_monitor := glfw.GetPrimaryMonitor()	
	video_mode := glfw.GetVideoMode(primary_monitor)
	
	monitor_details = {
		width        = video_mode.width,
		height       = video_mode.height,
		refresh_rate = video_mode.refresh_rate,
		type         = .Primary
	}

	return monitor_details
}
