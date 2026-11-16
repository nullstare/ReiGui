local Util = Util or require( "utillib" )
local Rectangle = Rectangle or require( "rectangle" )
local Vector2 = Vector2 or require( "vector2" )
local Color = Color or require( "color" )
local Gui = Gui or require( "reigui.gui" )

-- Spinner control.

local Spinner = {}
local metatable = {
	__index = setmetatable( Spinner, { __index = GuiControl } ),
}

Spinner.DEFAULT_STYLES = {}

function Spinner.DEFAULT_STYLES_UPDATE()
	Spinner.DEFAULT_STYLES = {
		spinner = {
			buttonWidth = 20,
			textInputWidth = nil, -- Set this to have fixed size and reserve rest of the bounds.width for text.
			spacing = 1,
		},
		addButton = nil, -- Set from subButton.
		subButton = Util.deepCopy( Gui.Button.DEFAULT_STYLES ),
		textInput = Util.deepCopy( Gui.TextInputBox.DEFAULT_STYLES ),
		label = Util.deepCopy( Gui.Label.DEFAULT_STYLES ),
	}

	Spinner.DEFAULT_STYLES.subButton.normal.icons = {
		{
			iconId = RL.ICON_ARROW_LEFT,
			offset = Vector2:new( 0, 0 ),
			pixelSize = 1,
			color = Color:newT( RL.GetColor( RL.GuiGetStyle( RL.BUTTON, RL.TEXT_COLOR_NORMAL ) ) ),
			alignH = RL.GuiGetStyle( RL.DEFAULT, RL.TEXT_ALIGNMENT ),
			alignV = RL.GuiGetStyle( RL.DEFAULT, RL.TEXT_ALIGNMENT_VERTICAL ),
		}
	}
	Gui:setForAllStyles( Spinner.DEFAULT_STYLES.subButton, "icons", Spinner.DEFAULT_STYLES.subButton.normal.icons )

	-- Button add.

	Spinner.DEFAULT_STYLES.addButton = Util.deepCopy( Spinner.DEFAULT_STYLES.subButton )
	Spinner.DEFAULT_STYLES.addButton.normal.icons[1].iconId = RL.ICON_ARROW_RIGHT
	Gui:setForAllStyles( Spinner.DEFAULT_STYLES.addButton, "icons", Spinner.DEFAULT_STYLES.addButton.normal.icons )

	-- Text input.

	Gui:setForAllStyles( Spinner.DEFAULT_STYLES.textInput, "text.alignH", RL.TEXT_ALIGN_CENTER )
	Gui:setForAllStyles( Spinner.DEFAULT_STYLES.textInput, "cursor.draw", false )

	-- Label.

	Gui:setForAllStyles( Spinner.DEFAULT_STYLES.label, "text.alignH", RL.TEXT_ALIGN_LEFT )
end

Spinner.DEFAULT_STYLES_UPDATE()

function Spinner:new( gui, t )
	local object = setmetatable( {}, metatable )
	object._gui = gui

	object.bounds = t.bounds and t.bounds:clone() or Rectangle:new()
	object.text = t.text
	object.value = t.value or 0
	object.minValue = t.minValue
	object.maxValue = t.maxValue
	object.valueStep = t.valueStep
	object.defaultValue = t.defaultValue

	object.visible = Util.setWithDefault( t.visible, true )
	object.locked = Util.setWithDefault( t.locked, false )
	object.disabled = Util.setWithDefault( t.disabled, false ) -- Same as locked but also uses style.
	object.callbacks = t.callbacks or {} -- set, setPosition.
	object.styles = t.styles or object.DEFAULT_STYLES
	object.stylesOverlay = t.stylesOverlay or {}
	object.tooltip = t.tooltip

	object._controls = {
		-- subButton = nil,
		-- addButton = nil,
		-- textInput = nil,
		-- label = nil,
	}
	object._controlsArray = {} -- Controls in predefined order.

	object:createControls()
	object:setPosition( object.bounds:getPosition() )

	return object
end

function Spinner:createControls()
	local styles = self.styles
	local spacing = styles.spinner.spacing
	local buttonWidth = styles.spinner.buttonWidth
	local textFieldWidthStyle = self._gui:getStyle( "spinner.textInputWidth", self.styles, self.stylesOverlay )
	local textFieldWidth = textFieldWidthStyle or ( self.bounds.width - buttonWidth * 2 - spacing * 2 )

	-- Label.

	if self.text then
		self._controls.label = self._gui:newLabel( {
			bounds = Rectangle:new( 0, 0, self.bounds.width - buttonWidth * 2 - textFieldWidth - spacing * 3, self.bounds.height ),
			text = self.text,
			styles = styles.label,
		} )
		self._controls.label.position = Vector2:new()

		table.insert( self._controlsArray, self._controls.label )
	end

	-- Sub button.

	self._controls.subButton = self._gui:newButton( {
		bounds = Rectangle:new( 0, 0, buttonWidth, self.bounds.height ),
		callbacks = {
			released = function()
				self:setValue( self.value - ( self.valueStep or 1 ) )

				if self.callbacks.set then
					self.callbacks.set( self )
				end
			end,
		},
		tooltip = self.tooltip,
		styles = styles.subButton,
	} )
	self._controls.subButton.position = Vector2:new( self.bounds.width - buttonWidth * 2 - spacing * 2 - textFieldWidth, 0)

	table.insert( self._controlsArray, self._controls.subButton )

	-- Text Field.

	self._controls.textInput = self._gui:newTextInputBox( {
		bounds = Rectangle:new( 0, 0, textFieldWidth, self.bounds.height ),
		text = tostring( self.value ),
		callbacks = {
			set = function( this )
				self:setValue( tonumber( this.text ) )

				if self.callbacks.set then
					self.callbacks.set( self )
				end
			end,
		},
		tooltip = self.tooltip,
		styles = styles.textInput,
	} )
	self._controls.textInput.position = Vector2:new( self.bounds.width - buttonWidth - textFieldWidth - spacing, 0 )

	table.insert( self._controlsArray, self._controls.textInput )

	-- Add button.

	self._controls.addButton = self._gui:newButton( {
		bounds = Rectangle:new( 0, 0, buttonWidth, self.bounds.height ),
		callbacks = {
			released = function()
				self:setValue( self.value + ( self.valueStep or 1 ) )

				if self.callbacks.set then
					self.callbacks.set( self )
				end
			end,
		},
		tooltip = self.tooltip,
		styles = styles.addButton,
	} )
	self._controls.addButton.position = Vector2:new( self.bounds.width - buttonWidth, 0 )

	table.insert( self._controlsArray, self._controls.addButton )
end

function Spinner:setValue( value )
	value = value or self.defaultValue or self.minValue or 0

	if self.valueStep then
		value = RL.Round( value / self.valueStep ) * self.valueStep
	end

	if self.minValue and self.maxValue then
		self.value = Util.clamp( value, self.minValue, self.maxValue )
	elseif self.minValue then
		self.value = math.max( value, self.minValue )
	elseif self.maxValue then
		self.value = math.min( value, self.maxValue )
	else
		self.value = value
	end

	self._controls.textInput.text = tostring( self.value )
end

function Spinner:setSize( size )
	self.bounds:setSizeV( size )

	if self._controlsArray then
		for _, control in ipairs( self._controlsArray ) do
			-- control:setSize( size )
			control.bounds.height = size.y
		end
	end

	self._controls.label.bounds.width = self.bounds.width - self._controls.addButton.position.x - self.styles.spinner.spacing

	if self.callbacks.setSize then
		self.callbacks.setSize( self )
	end

	self:setPosition( self.bounds:getPosition() )
end

return { Spinner = Spinner }
