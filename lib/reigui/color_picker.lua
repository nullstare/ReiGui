local Util = Util or require( "utillib" )
local Rectangle = Rectangle or require( "rectangle" )
local Vector2 = Vector2 or require( "vector2" )
local Vector3 = Vector3 or require( "vector3" )
local Color = Color or require( "color" )
local Gui = Gui or require( "reigui.gui" )

-- Window control.

local ColorPicker = {}
local metatable = {
	__index = setmetatable( ColorPicker, { __index = GuiControl } ),
}

ColorPicker.DEFAULT_STYLES = {}

function ColorPicker.DEFAULT_STYLES_UPDATE()
	ColorPicker.DEFAULT_STYLES = {
		colorPicker = {
			size = Vector2:new( 216, 400 ),
			padding = 8,
			spacing = 4,
			barWidth = 20,
			buttonHeight = 20,
			checkerSize = 4,
			checkerCount = 5,
		},
		window = Gui.Window.DEFAULT_STYLES,
		colorPanel = Util.deepCopy( Gui.Slider.DEFAULT_STYLES ),
		colorPreview = Util.deepCopy( Gui.Panel.DEFAULT_STYLES ),
		colorChannelSlider = Util.deepCopy( Gui.Slider.DEFAULT_STYLES ),
		colorChannelSpinner = Util.deepCopy( Gui.Spinner.DEFAULT_STYLES ),
		colorChannelLabel = Util.deepCopy( Gui.Label.DEFAULT_STYLES ),
		checkerPanel = Util.deepCopy( Gui.Panel.DEFAULT_STYLES ),
		hexValueInputBox = Util.deepCopy( Gui.TextInputBox.DEFAULT_STYLES ),
		hexValueLabel = Util.deepCopy( Gui.Label.DEFAULT_STYLES ),
		textButton = Util.deepCopy( Gui.Button.DEFAULT_STYLES ),
	}

	Gui:setForAllStyles( ColorPicker.DEFAULT_STYLES.hexValueLabel, "text.alignH", RL.TEXT_ALIGN_LEFT )
end

ColorPicker.DEFAULT_STYLES_UPDATE()

ColorPicker.CHANNEL_NAMES = { r = "Red", g = "Green", b = "Blue", a = "Alpha" }

function ColorPicker:new( gui, t )
	local object = setmetatable( {}, metatable )
	object._gui = gui

	local styles = object.DEFAULT_STYLES.colorPicker

	object.bounds = t.bounds and t.bounds:clone() or Rectangle:new( 0, 0, styles.size.x, styles.size.y )
	object.text = t.text or "Color Picker"
	object.color = t.color or Color:newT( RL.WHITE )
	object.oldColor = Color:newT( RL.WHITE )
	object.hsv = Vector3:new()

	object.visible = Util.setWithDefault( t.visible, false )
	object.locked = Util.setWithDefault( t.locked, false )
	object.disabled = Util.setWithDefault( t.disabled, false ) -- Same as locked but also uses style.
	object.draggable = Util.setWithDefault( t.draggable, true )

	object.callbacks = { -- setPosition.
		close = t.callbacks and t.callbacks.close or function() object:setColor() object:setVisible( false ) end,
		grab = t.callbacks and t.callbacks.grab or function() object:setToTop() end,
		drag = t.callbacks and t.callbacks.drag or function( this ) object:setPosition( this.bounds:getPosition() ) end,
		apply = t.callbacks and t.callbacks.apply
	}
	object.styles = t.styles or object.DEFAULT_STYLES
	object.stylesOverlay = t.stylesOverlay or {}

	object._generatedOwnTexture = false
	object.checkerTex = t.checkerTex or object:genCheckerTex()

	object._controls = {
		-- window = nil,
		-- colorPanel = nil,
		-- colorBarHue = nil,
		-- colorPreview = nil,
	}
	object._controlsArray = {} -- Controls in predefined order.

	object:createControls()
	object:setPosition( object.bounds:getPosition() )
	object:setColor( object.color )
	object:setVisible( object.visible )

	return object
end

function ColorPicker:genCheckerTex()
	local checkerSize = self.styles.colorPicker.checkerSize
	local img = RL.GenImageChecked( Vector2:temp( checkerSize * 2 ), Vector2:temp( checkerSize ), RL.WHITE, RL.BLACK )
	local tex = RL.LoadTextureFromImage( img )

	RL.SetTextureWrap( tex, RL.TEXTURE_WRAP_REPEAT )

	if not RL.IsGCUnloadEnabled() then
		RL.UnloadImage( img )
	end

	self._generatedOwnTexture = true

	return tex
end

function ColorPicker:createControls()
	local styles = self.styles

	-- Window.

	self._controls.window = self._gui:newWindow( {
		bounds = Rectangle:new( 0, 0, self.bounds.width, self.bounds.height ),
		text = self.text,
		draggable = self.draggable,
		callbacks = {
			close = self.callbacks.close,
			grab = self.callbacks.grab,
			drag = self.callbacks.drag,
		},
		styles = styles.window,
	} )
	self._controls.window.position = Vector2:new()

	table.insert( self._controlsArray, self._controls.window )

	-- Color panel.

	local padding = styles.colorPicker.padding
	local spacing = styles.colorPicker.spacing
	local barWidth = styles.colorPicker.barWidth
	local width = self.bounds.width - barWidth - spacing - padding * 2
	local bounds = Rectangle:new( 0, 0, width, width )

	-- Color panel.

	local colorPanelStyles = Util.deepCopy( styles.colorPanel )
	local drawRectangleCallback = function( rect, s, so )
		self:drawColorPanel( rect, s, so )
	end
	local drawColorPanelSliderCallback = function( rect, s, so )
		self:drawColorPanelSlider( rect, s, so )
	end

	Gui:setForAllStyles( colorPanelStyles, "slider.width", 1 )
	Gui:setForAllStyles( colorPanelStyles, "drawRectangleCallback", drawRectangleCallback )
	Gui:setForAllStyles( colorPanelStyles, "slider.drawRectangleCallback", drawColorPanelSliderCallback )

	self._controls.colorPanel = self._gui:newSlider( {
		bounds = bounds,
		value = Vector2:new( self.hsv.y, self.hsv.z ),
		maxValue = Vector2:new( 1 ),
		valueStep = Vector2:new( 0.01 ),
		styles = colorPanelStyles,
		callbacks = {
			edit = function( this )
				local color = Color:newT( RL.ColorFromHSV( self.hsv.x, this.value.x, this.maxValue.y - this.value.y ) )
				color.a = self.color.a
				self:setColor( color )
			end
		},
	} )
	self._controls.colorPanel.position = Vector2:new( padding, self.DEFAULT_STYLES.window.window.handleHeight + padding )
	self._controls.colorPanel.colors = { Color:newT( RL.RED ), Color:newT( RL.BLUE ), Color:newT( RL.GREEN ), Color:newT( RL.WHITE ) }

	table.insert( self._controlsArray, self._controls.colorPanel )

	-- Color bar hue.

	local panelBounds = self._controls.colorPanel.bounds:addPosition( self._controls.colorPanel.position )
	local colorBarHueStyles = Util.deepCopy( styles.colorPanel )

	Gui:setForAllStyles( colorBarHueStyles, "slider.width", 1 )
	Gui:setForAllStyles( colorBarHueStyles, "drawRectangleCallback", function( rect, s, so )
		self:drawColorBarHue( rect, s, so )
	end )

	self._controls.colorBarHue = self._gui:newSlider( {
		bounds = Rectangle:new( 0, 0, barWidth, panelBounds.height ),
		value = Vector2:new( 0, self.hsv.x ),
		maxValue = Vector2:new( 0, 360 ),
		styles = colorBarHueStyles,
		callbacks = {
			edit = function( this )
				local color = Color:newT( RL.ColorFromHSV( this.value.y, self.hsv.y, self.hsv.z ) )
				color.a = self.color.a
				self:setColor( color )
			end
		},
	} )
	self._controls.colorBarHue.position = Vector2:new( padding + panelBounds.width + spacing, panelBounds.y )

	table.insert( self._controlsArray, self._controls.colorBarHue )

	-- RGB Color sliders and spinners.

	width = self.bounds.width - padding * 2
	local height = styles.colorPicker.checkerSize * styles.colorPicker.checkerCount -- Size of one checher in the texture.

	-- local pos = self._controls.colorPreview.position + Vector2:temp( 0, self._controls.colorPreview.bounds.height + spacing )
	local pos = self._controls.colorPanel.position + Vector2:temp( 0, self._controls.colorPanel.bounds.height + spacing )
	local spinnerSize = Vector2:new( 72, height )
	local charWidth = 12
	barWidth = width - spinnerSize.x - spacing - charWidth

	local colorChannelLabel = Util.deepCopy( styles.colorChannelLabel )
	Gui:setForAllStyles( colorChannelLabel, "text.alignH", RL.TEXT_ALIGN_LEFT )

	local sliderStyles = Util.deepCopy( styles.colorChannelSlider )
	Gui:setForAllStyles( sliderStyles, "slider.width", 1 )
	Gui:setForAllStyles( sliderStyles, "base.gradient", "horizontal" )

	local spinnerStyles = Util.deepCopy( styles.colorChannelSpinner )

	for _, c in ipairs( { "r", "g", "b", "a" } ) do
		-- Label.
		local labelName = "colorLabel"..self.CHANNEL_NAMES[c]

		self._controls[ labelName ] = self._gui:newLabel( {
			bounds = Rectangle:new( 0, 0, charWidth, spinnerSize.y ),
			text = string.upper( c ),
			styles = colorChannelLabel,
		} )
		self._controls[ labelName ].position = Vector2:newV( pos )

		table.insert( self._controlsArray, self._controls[ labelName ] )

		-- Slider.
		local sliderName = "colorSlider"..self.CHANNEL_NAMES[c]

		Gui:setForAllStyles( sliderStyles, "base.color", { self.color, self.color } )
		Gui:setForAllStyles( sliderStyles, "drawRectangleCallback", function( rect, s, so )
			self:drawColorChannelSlider( rect, s, so, c )
		end )

		self._controls[ sliderName ] = self._gui:newSlider( {
			bounds = Rectangle:new( 0, 0, barWidth, spinnerSize.y ),
			value = Vector2:new( self.color[c], 0 ),
			maxValue = Vector2:new( 255, 0 ),
			valueStep = Vector2:new( 1, 0 ),
			callbacks = {
				edit = function( this )
					local color = self.color:clone()
					color[c] = this.value.x
					self:setColor( color )
				end
			},
			styles = Util.deepCopy( sliderStyles ), -- Each one need to set their own colors.
		} )
		self._controls[ sliderName ].position = Vector2:newV( Vector2:temp( charWidth, 0 ) + pos )

		table.insert( self._controlsArray, self._controls[ sliderName ] )

		-- Spinner.
		local spinnerName = "colorSpinner"..self.CHANNEL_NAMES[c]

		self._controls[ spinnerName ] = self._gui:newSpinner( {
			bounds = Rectangle:new( 0, 0, spinnerSize.x, spinnerSize.y ),
			minValue = 0,
			maxValue = 255,
			valueStep = 1,
			defaultValue = 255,
			callbacks = {
				set = function( this )
					local color = self.color:clone()
					color[c] = this.value
					self:setColor( color )
				end
			},
			styles = spinnerStyles,
		} )
		self._controls[ spinnerName ].position = Vector2:newV( Vector2:temp( charWidth + barWidth + spacing, 0 ) + pos )

		pos:addEq( Vector2:temp( 0, spinnerSize.y + spacing ) )

		table.insert( self._controlsArray, self._controls[ spinnerName ] )
	end

	-- Hex Value InputBox.

	self._controls.hexValueInputBox = self._gui:newTextInputBox( {
		bounds = Rectangle:new( 0, 0, 64, height ),
		text = string.format( "%x", self.color:toHex() ):upper(),
		charLimit = 8,
		callbacks = {
			set = function( this )
				local hex = tonumber( "0x"..this.text ) or 0
				local color = Color:new():fromHex( hex )

				self:setColor( color )
			end,
		},
		styles = styles.hexValueInputBox,
	} )
	self._controls.hexValueInputBox.position = pos:clone()

	table.insert( self._controlsArray, self._controls.hexValueInputBox )

	pos:addEq( Vector2:temp( self._controls.hexValueInputBox.bounds.width + spacing, 0 ) )

	-- Hex label.

	local buttonHeight = styles.colorPicker.buttonHeight

	self._controls.hexValueLabel = self._gui:newLabel( {
		bounds = Rectangle:new( 0, 0, width - self._controls.hexValueInputBox.bounds.width - spacing, buttonHeight ),
		text = "Hex",
		styles = styles.hexValueLabel,
	} )
	self._controls.hexValueLabel.position = Vector2:newV( pos )

	table.insert( self._controlsArray, self._controls.hexValueLabel )

	pos:set( padding, pos.y + self._controls.hexValueInputBox.bounds.height + spacing )

	-- Color preview.

	local previewStyles = Util.deepCopy( styles.colorPreview )
	Gui:setForAllStyles( previewStyles, "base.color", self.color )

	bounds = Rectangle:new( 0, 0, width, height )

	self._controls.colorPreview = self._gui:newPanel( {
		bounds = bounds,
		styles = previewStyles,
		stylesOverlay = self._gui:getDummyStyles(),
	} )
	self._controls.colorPreview.position = pos:clone()

	table.insert( self._controlsArray, self._controls.colorPreview )

	self._gui:setForAllStyles( self._controls.colorPreview.stylesOverlay, "drawRectangleCallback", function( rect, s, so )
		self:drawColorPreview( rect, s, so )
	end )

	pos.y = pos.y + buttonHeight + spacing

	-- Apply Button.

	self._controls.applyButton = self._gui:newButton( {
		bounds = Rectangle:new( 0, 0, width, buttonHeight ),
		text = "OK",
		callbacks = {
			released = function()
				if self.callbacks.apply then
					self.callbacks.apply( self.color:clone() )
				end
				self:setVisible( false )
			end,
		},
		styles = self.styles.textButton,
	} )
	self._controls.applyButton.position = pos:clone()

	table.insert( self._controlsArray, self._controls.applyButton )

	-- Set window bounds.

	self.bounds.height = self._controls.applyButton.position.y + self._controls.applyButton.bounds.height + padding
	self._controls.window:setSize( self.bounds:getSize() )
end

function ColorPicker:popup( position, color, callback )
	color = color or self.color

	self.oldColor:setC( color )
	self.callbacks.apply = callback

	self:setColor( color )
	self:setPosition( position )
	self:setVisible( true )
	self:setToTop()
end

function ColorPicker:drawColorPanel( rect, styles, stylesOverlay )
	local c = self._controls.colorPanel.colors

	RL.DrawRectangleGradientEx(
		rect,
		c[1], c[2], c[3], c[4]
	)
	RL.DrawRectangleGradientEx(
		rect,
		RL.BLANK, RL.BLACK, RL.BLACK, RL.BLANK
	)
end

function ColorPicker:drawColorPanelSlider( rect, styles, stylesOverlay )
	-- Only draw once since this function is called for both axis.
	if rect.height < rect.width then
		local cp = self._controls.colorPanel
		local point = Vector2:new( rect.x + rect.width / cp.maxValue.x * cp.value.x, rect.y )

		RL.DrawCircleLines( point, 4, styles.base.color )
	end
end

function ColorPicker:drawColorBarHue( rect, styles, stylesOverlay )
	local hueCols = { { 255, 0, 0, 255 }, { 255, 255, 0, 255 },	{ 0, 255, 0, 255 },
		{ 0, 255, 255, 255 }, { 0, 0, 255, 255 }, { 255, 0, 255, 255 },	{ 255, 0, 0, 255 } }
	local segN = #hueCols - 1
	local segH = rect.height / segN

	for i = 1, segN do
		local r = Rectangle:temp(
			rect.x, math.floor( rect.y + (i-1) * segH ),
			rect.width, math.ceil( segH )
		)
		RL.DrawRectangleGradientV( r, hueCols[i], hueCols[ i+1 ] )
	end
end

function ColorPicker:drawColorChannelSlider( rect, styles, stylesOverlay, channel )
	local col1 = self.color:clone()
	local col2 = self.color:clone()

	col1[ channel ] = 0
	col2[ channel ] = 255

	if channel ~= "a" then
		col1.a = 255
		col2.a = 255
	end

	RL.DrawTextureRec( self.checkerTex, { 0, 0, rect.width, rect.height }, rect:getPosition(), RL.WHITE )
	RL.DrawRectangleGradientH(
		rect, col1, col2
	)
end

function ColorPicker:drawColorPreview( rect, styles, stylesOverlay )
	RL.DrawTextureRec( self.checkerTex, { 0, 0, rect.width, rect.height }, rect:getPosition(), RL.WHITE )
	RL.DrawTextureRec(
		RL.GetTextureDefault(),
		{ 0, 0, rect.width / 2, rect.height },
		rect:getPosition(),
		self.oldColor
	)
	RL.DrawTextureRec(
		RL.GetTextureDefault(),
		{ 0, 0, rect.width / 4, rect.height / 2 },
		rect:getPosition() + Vector2:temp( rect.width / 4, 0 ),
		self.oldColor:getWithFullAlpha()
	)
	RL.DrawTextureRec(
		RL.GetTextureDefault(),
		{ 0, 0, rect.width / 2, rect.height },
		rect:getPosition() + Vector2:temp( rect.width / 2, 0 ),
		self.color
	)
	RL.DrawTextureRec(
		RL.GetTextureDefault(),
		{ 0, 0, rect.width / 4, rect.height / 2 },
		rect:getPosition() + Vector2:temp( rect.width / 2, 0 ),
		self.color:getWithFullAlpha()
	)
end

function ColorPicker:setVisible( visible )
	self.visible = visible

	for _, control in ipairs( self._controlsArray ) do
		control:setVisible( visible )
	end

	if not self.visible then
		self.callbacks.apply = nil
	end

	if self.callbacks.setVisible then
		self.callbacks.setVisible( self, visible )
	end
end

function ColorPicker:setColor( color )
	self.color:setC( color or self.oldColor )
	self.hsv:setT( RL.ColorToHSV( self.color ) )
	local maxHue = Vector3:new( self.hsv.x, 1, 1 )
	local rgbHue = Color:newT( RL.ColorFromHSV( maxHue.x, maxHue.y, maxHue.z ) )

	self._controls.colorPanel.colors[1]:setT( RL.WHITE )
	self._controls.colorPanel.colors[2]:setT( RL.WHITE )
	self._controls.colorPanel.colors[3]:setC( rgbHue )
	self._controls.colorPanel.colors[4]:setC( rgbHue )

	self._controls.colorPanel.value:set( self.hsv.y, 1 - self.hsv.z )
	self._controls.colorBarHue.value.y = self.hsv.x

	for c, v in pairs( self.color ) do
		local sliderName = "colorSlider"..self.CHANNEL_NAMES[c]
		local spinnerName = "colorSpinner"..self.CHANNEL_NAMES[c]

		self._controls[ sliderName ].value.x = v
		self._controls[ spinnerName ]:setValue( v )
	end

	self._controls.hexValueInputBox.text = string.format( "%x", self.color:toHex() ):upper()

	if self.callbacks.apply then
		self.callbacks.apply( self.color:clone() )
	end
end

function ColorPicker:setSize( size )
	self.bounds:setSizeV( size )

	if self.callbacks.setSize then
		self.callbacks.setSize( self )
	end

	self:setPosition( self.bounds:getPosition() )
end

function ColorPicker:unload()
	if self._generatedOwnTexture then
		RL.UnloadTexture( self.checkerTex )
	end
end

return { ColorPicker = ColorPicker }
