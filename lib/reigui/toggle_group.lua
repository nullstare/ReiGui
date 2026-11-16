local Util = Util or require( "utillib" )
local Rectangle = Rectangle or require( "rectangle" )
local Vector2 = Vector2 or require( "vector2" )
local Gui = Gui or require( "reigui.gui" )

-- NodeButton control.

local ToggleGroup = {}
local metatable = {
	__index = setmetatable( ToggleGroup, { __index = GuiControl } ),
}

ToggleGroup.DEFAULT_STYLES = {}

function ToggleGroup.DEFAULT_STYLES_UPDATE()
	ToggleGroup.DEFAULT_STYLES = {
		toggleGroup = {
			buttonSize = Vector2:new( 20 ),
			spacing = 2,
		},
		label = Util.deepCopy( Gui.Label.DEFAULT_STYLES ),
		button = Util.deepCopy( Gui.Button.DEFAULT_STYLES ),
	}

	Gui:setForAllStyles( ToggleGroup.DEFAULT_STYLES.button, "icons", {
		{
			iconId = RL.ICON_EYE_ON,
			offset = Vector2:new( 0, 0 ),
			pixelSize = 1,
			color = Color:newT( RL.GetColor( RL.GuiGetStyle( RL.BUTTON, RL.TEXT_COLOR_PRESSED ) ) ),
			alignH = RL.TEXT_ALIGN_CENTER,
			alignV = RL.TEXT_ALIGN_MIDDLE,
		}
	} )
	ToggleGroup.DEFAULT_STYLES.button.normal.icons = {
		{
			iconId = RL.ICON_EYE_ON,
			offset = Vector2:new( 0, 0 ),
			pixelSize = 1,
			color = Color:newT( RL.GetColor( RL.GuiGetStyle( RL.BUTTON, RL.TEXT_COLOR_NORMAL ) ) ),
			alignH = RL.TEXT_ALIGN_CENTER,
			alignV = RL.TEXT_ALIGN_MIDDLE,
		},
	}

	Gui:setForAllStyles( ToggleGroup.DEFAULT_STYLES.label, "text.alignH", RL.TEXT_ALIGN_LEFT )
end

ToggleGroup.DEFAULT_STYLES_UPDATE()

function ToggleGroup:new( gui, t )
	local object = setmetatable( {}, metatable )
	object._gui = gui

	object.bounds = t.bounds and t.bounds:clone() or Rectangle:new()
	object.text = t.text or ""
	object.active = t.active or 1
	object.buttonData = t.buttonData or {}

	object.visible = Util.setWithDefault( t.visible, true )
	object.locked = Util.setWithDefault( t.locked, false )
	object.disabled = Util.setWithDefault( t.disabled, false ) -- Same as locked but also uses style.
	object.callbacks = t.callbacks or {} -- set, setPosition.
	object.styles = t.styles or object.DEFAULT_STYLES
	object.stylesOverlay = t.stylesOverlay or {}

	object._controls = {
		-- label = {},
		-- buttons = {},
	}
	object._controlsArray = {} -- Controls in predefined order.

	object:createControls()
	object:setPosition( object.bounds:getPosition() )

	return object
end

function ToggleGroup:createControls()
	local styles = self.styles
	local spacing = styles.toggleGroup.spacing
	local buttonSize = styles.toggleGroup.buttonSize:min( self.bounds:getSize() )
	local buttonsWidth = #self.buttonData * buttonSize.x + ( #self.buttonData - 1 ) * spacing

	self.bounds.width = math.max( self.bounds.width, buttonsWidth )

	-- Label.

	if self.text then
		self._controls.label = self._gui:newLabel( {
			bounds = Rectangle:new( 0, 0, self.bounds.width - buttonsWidth - styles.toggleGroup.spacing, self.bounds.height ),
			text = self.text,
			styles = styles.label,
		} )
		self._controls.label.position = Vector2:new()

		table.insert( self._controlsArray, self._controls.label )
	end

	-- Buttons.

	local pos = Vector2:new( self.bounds.width - buttonsWidth, 0 )
	-- local pos = Vector2:new( self._controls.label and ( self.bounds.width - buttonsWidth ) or 0, 0 )

	self._controls.buttons = {}

	for i, data in ipairs( self.buttonData ) do
		self._controls.buttons[i] = self._gui:newButton( {
			bounds = Rectangle:new( 0, 0, buttonSize.x, buttonSize.y ),
			toggle = i == self.active,
			callbacks = {
				released = function( _ )
					self:setActive( i )

					if self.callbacks.released then
						self.callbacks.released( self )
					end
					if data.callback then
						data.callback( self )
					end
				end,
			},
			tooltip = data.tooltip,
			styles = styles.button,
			stylesOverlay = self._gui:getDummyStyles(),
		} )
		self._gui:setForAllStyles( self._controls.buttons[i].stylesOverlay, "icons", { { iconId = data.icon } } )
		self._controls.buttons[i].position = pos:clone()

		table.insert( self._controlsArray, self._controls.buttons[i] )

		pos.x = pos.x + buttonSize.x + spacing
	end
end

function ToggleGroup:setActive( active )
	self.active = active

	for i, button in ipairs( self._controls.buttons ) do
		button.toggle = i == self.active
	end
end

function ToggleGroup:setText( text )
	self.text = text

	local label = self._controls.label

	if label then
		label.text = text
	end
end

function ToggleGroup:setSize( size )
	self.bounds:setSizeV( size )

	-- local styles = self.styles
	-- local spacing = styles.nodeButton.spacing
	-- local buttonSize = styles.nodeButton.buttonSize:min( self.bounds:getSize() )

	-- self._controls.nameButton:setSize( Vector2:new( self.bounds.width - buttonSize.x - spacing, buttonSize.y ) )
	-- self._controls.visibleButton:setSize( Vector2:new( buttonSize.x, buttonSize.y ) )
	-- self._controls.visibleButton.position = Vector2:new( self._controls.nameButton.bounds.width + spacing, 0 ):round()

	if self.callbacks.setSize then
		self.callbacks.setSize( self )
	end

	self:setPosition( self.bounds:getPosition() )
end

return { ToggleGroup = ToggleGroup }
