class_name RetroTheme
extends RefCounted

## MainMenu, Pause, Options, HealthBar가 같이 쓰는 레트로 창 스타일.
## 색과 두께는 시험값이며 최종 테마가 아니다.

const FONT := preload("res://assets/fonts/Galmuri9.ttf")
const PANEL := Color(0.75, 0.75, 0.73, 1)
const HIGHLIGHT := Color(0.95, 0.95, 0.93, 1)
const SHADOW := Color(0.28, 0.28, 0.30, 1)
const TITLE_BAR := Color(0.10, 0.16, 0.38, 1)
const TEXT := Color(0.08, 0.08, 0.10, 1)
const TITLE_TEXT := Color(0.95, 0.95, 0.96, 1)
const DISABLED_TEXT := Color(0.42, 0.42, 0.44, 1)


static func bevel_style(fill: Color, top_left: Color, bottom_right: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(0)
	style.set_content_margin_all(0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.border_color = top_left
	style.shadow_color = bottom_right
	style.shadow_size = 2
	style.shadow_offset = Vector2(1, 1)
	return style


static func window_style() -> StyleBoxFlat:
	var style := bevel_style(PANEL, HIGHLIGHT, SHADOW)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2, 2)
	return style


static func button_style(pressed: bool, disabled: bool = false, hovered: bool = false) -> StyleBoxFlat:
	var fill := PANEL
	var top_left := HIGHLIGHT
	var bottom_right := SHADOW
	if disabled:
		fill = Color(0.55, 0.55, 0.53, 1)
		top_left = Color(0.70, 0.70, 0.68, 1)
		bottom_right = Color(0.40, 0.40, 0.42, 1)
	elif pressed:
		fill = Color(0.62, 0.62, 0.60, 1)
		top_left = SHADOW
		bottom_right = HIGHLIGHT
	elif hovered:
		fill = Color(0.88, 0.88, 0.86, 1)
		top_left = Color(1.0, 1.0, 1.0, 1)
		bottom_right = Color(0.18, 0.18, 0.20, 1)
	var style := bevel_style(fill, top_left, bottom_right)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	if disabled:
		style.shadow_size = 0
	elif hovered and not pressed:
		style.border_width_left = 3
		style.border_width_top = 3
		style.shadow_size = 3
	return style


static func apply_button(button: Button, font_size: int = 14) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override(&"font", FONT)
	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color", TEXT)
	button.add_theme_color_override(&"font_hover_color", TEXT)
	button.add_theme_color_override(&"font_pressed_color", TEXT)
	button.add_theme_color_override(&"font_disabled_color", DISABLED_TEXT)
	button.add_theme_stylebox_override(&"normal", button_style(false))
	button.add_theme_stylebox_override(&"hover", button_style(false, false, true))
	button.add_theme_stylebox_override(&"pressed", button_style(true))
	button.add_theme_stylebox_override(&"disabled", button_style(false, true))
	button.add_theme_stylebox_override(&"focus", button_style(false))
	GameAudio.bind_button(button)


static func apply_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
