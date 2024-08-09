import adsk.core
from ..Commands import PackageCommand
from ..Utilities import addin_utility, fusion_ui, constant
from ..Utilities.localization import _LCLZ

class PackageCommandDip(PackageCommand.PackageCommand):
    def __init__(self, name: str, options: dict):
        super().__init__(name, options)
        #overwrite some specific settings of this command. 
        self.cmd_id = 'cmd_id_dip'
        self.cmd_name = _LCLZ('CmdNameDip', 'DIP Generator')
        self.cmd_description = _LCLZ('CmdDescDip', 'Generate DIP Packages')
        self.cmd_ctrl_id = self.cmd_id
        self.dialog_width = 330
        self.dialog_height = 700

    def get_defalt_ui_data(self):
        ui_data = {}
        ui_data['cmd_id'] = self.cmd_id
        ui_data['type'] = constant.PKG_TYPE_DIP
        ui_data['horizontalPadCount'] = 16
        ui_data['padShape'] = constant.PTH_PAD_SHAPE.get('Round')
        ui_data['densityLevel'] = constant.DENSITY_LEVEL_TH['Nominal (B)']
        ui_data['verticalPinPitch'] = 0.254
        ui_data['leadSpan'] = 0.762
        ui_data['terminalWidth'] = 0.053
        ui_data['terminalLength'] = 0.24
        ui_data['terminalThickness'] = 0.012
        ui_data['bodyLengthMax'] = 1.969
        ui_data['bodyLengthMin'] = 1.969
        ui_data['bodyWidthMax'] = 0.66
        ui_data['bodyWidthMin'] = 0.66
        ui_data['bodyHeightMax'] = 0.508
        ui_data['bodyOffset'] = 0.038
        ui_data['silkscreenMappingTypeToBody'] = constant.SILKSCREEN_MAPPING_TO_BODY.get('MappingTypeToBodyMax')
        ui_data['padToHoleRatio'] = 1.5
        ui_data['hasCustomFootprint'] = False
        ui_data['customPadDiameter'] = 0.134
        ui_data['customHoleDiameter'] = 0.074
        return ui_data

    def validate_ui_input(self, inputs: adsk.core.CommandInputs):

        status = super().validate_ui_input(inputs)
        #input field related check
        command = inputs.itemById('leadSpan')
        tooltip = command.tooltip
        name = command.name
        if command.value <= 0 :
            status.add_error(tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

        command = inputs.itemById('terminalWidth')
        tooltip = command.tooltip
        name = command.name
        if command.value <= 0 :
            status.add_error(tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

        command = inputs.itemById('terminalLength')
        tooltip = command.tooltip
        name = command.name
        if command.value <= 0 :
            status.add_error(tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

        command = inputs.itemById('terminalThickness')
        tooltip = command.tooltip
        name = command.name
        if command.value <= 0 :
            status.add_error(tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

        #Check if the no. of pins are odd
        command = inputs.itemById('horizontalPadCount')
        if (command.value % 2 != 0):
            status.add_error(_LCLZ("errMessageForPinCount", "Number of pins must be even."))

        #calculation related check
        if float('{:.6f}'.format(self.ui_data['bodyWidthMax'])) >= float('{:.6f}'.format(self.ui_data['leadSpan'])) :
            status.add_error(_LCLZ("LJLeadError2", "E should be greater than E1."))
        
        return status

    def update_ui_data(self, inputs):
        
        input_data = self.get_inputs()
        for param in self.ui_data:
            if param in input_data:
                self.ui_data[param] = input_data[param]

        self.ui_data['densityLevel'] = list(constant.DENSITY_LEVEL_TH.values())[inputs.itemById('densityLevel').selectedItem.index]
        self.ui_data['silkscreenMappingTypeToBody'] = list(constant.SILKSCREEN_MAPPING_TO_BODY.values())[inputs.itemById('silkscreenMappingTypeToBody').selectedItem.index]
        self.ui_data['padShape'] = list(constant.PTH_PAD_SHAPE.values())[inputs.itemById('padShape').selectedItem.index]

    def on_create(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs):
        super().on_create(command, inputs)

        ao = addin_utility.AppObjects() 

        # Create a package tab input.
        tab1_cmd_inputs = inputs.addTabCommandInput('tab_1', _LCLZ('package', 'Package'))
        tab1_inputs = tab1_cmd_inputs.children

        # Create image input.
        labeled_image = tab1_inputs.addImageCommandInput('DipImage', '', "Resources/img/DIP-Labeled.png")
        labeled_image.isFullWidth = True
        labeled_image.isVisible = True

        tab1_inputs.addIntegerSpinnerCommandInput('horizontalPadCount', _LCLZ('#Pins', '# Pins'), 2 , 100 , 2, int(self.ui_data['horizontalPadCount']))

        # Create dropdown input with test list style.
        pad_shape = tab1_inputs.addDropDownCommandInput('padShape', _LCLZ('padShape', 'Pad Shape'), adsk.core.DropDownStyles.TextListDropDownStyle)
        pad_shape_list = pad_shape.listItems
        pad_shape_list.add(_LCLZ('Round', constant.PTH_PAD_SHAPE.get('Round')), True if constant.PTH_PAD_SHAPE.get("Round") == self.ui_data['padShape'] else False, "")
        pad_shape_list.add(_LCLZ('Square', constant.PTH_PAD_SHAPE.get('Square')), True if constant.PTH_PAD_SHAPE.get("Square") == self.ui_data['padShape'] else False, "")
        pad_shape.isVisible = not self.only_3d_model_generator
        pad_shape.maxVisibleItems = 2

        pin_pitch = tab1_inputs.addValueInput('verticalPinPitch', 'e', ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['verticalPinPitch']))
        pin_pitch.tooltip = _LCLZ('pinPitch', 'Pin Pitch')
        lead_span = tab1_inputs.addValueInput('leadSpan', 'E', ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['leadSpan']))
        lead_span.tooltip = _LCLZ('leadSpan', 'Lead Span')
        terminal_width = tab1_inputs.addValueInput('terminalWidth', 'b', ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['terminalWidth']))
        terminal_width.tooltip = _LCLZ('terminalWidth', 'Terminal Width')
        terminal_length = tab1_inputs.addValueInput('terminalLength', 'L', ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['terminalLength']))
        terminal_length.tooltip = _LCLZ('terminalLength', 'Terminal Length')
        terminal_thickness = tab1_inputs.addValueInput('terminalThickness', 'c', ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['terminalThickness']))
        terminal_thickness.tooltip = _LCLZ('terminalThickness', 'Terminal Thickness')

        # table
        table = tab1_inputs.addTableCommandInput('bodyDimensionTable', 'Table', 3, '1:2:2')
        table.hasGrid = False
        table.tablePresentationStyle = 2
        table.maximumVisibleRows = 4
        fusion_ui.add_title_to_table(table, '', _LCLZ('min', 'Min'), _LCLZ('max', 'Max'))
        fusion_ui.add_row_to_table(table, 'bodyLength', 'D', adsk.core.ValueInput.createByReal(self.ui_data['bodyLengthMin']), adsk.core.ValueInput.createByReal(self.ui_data['bodyLengthMax']), _LCLZ('bodyLength', 'Body Length'))
        fusion_ui.add_row_to_table(table, 'bodyWidth', 'E1', adsk.core.ValueInput.createByReal(self.ui_data['bodyWidthMin']), adsk.core.ValueInput.createByReal(self.ui_data['bodyWidthMax']), _LCLZ('bodyWidth', 'Body Width'))
        fusion_ui.add_row_to_table(table, 'bodyHeight', 'A', None, adsk.core.ValueInput.createByReal(self.ui_data['bodyHeightMax']), _LCLZ('bodyHeight', 'Body Height'))

        body_offset = tab1_inputs.addValueInput('bodyOffset', 'A1', ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['bodyOffset']))
        body_offset.tooltip = _LCLZ('bodyOffset', 'Body Offset')

        # Create dropdown input with test list style.
        map_silkscreen = tab1_inputs.addDropDownCommandInput('silkscreenMappingTypeToBody', _LCLZ('mapSilkscreen', 'Map Silkscreen to Body'), adsk.core.DropDownStyles.TextListDropDownStyle)
        map_silkscreen_list = map_silkscreen.listItems
        for t in constant.SILKSCREEN_MAPPING_TO_BODY:
            map_silkscreen_list.add(_LCLZ(t, constant.SILKSCREEN_MAPPING_TO_BODY.get(t)), True if constant.SILKSCREEN_MAPPING_TO_BODY.get(t) == self.ui_data['silkscreenMappingTypeToBody'] else False, '')
        map_silkscreen.isVisible = not self.only_3d_model_generator
        map_silkscreen.maxVisibleItems = len(constant.SILKSCREEN_MAPPING_TO_BODY)

        err_message = tab1_inputs.addTextBoxCommandInput('errMessage', '', '', 2, True)
        err_message.isFullWidth = True

        # Create a custom footprint tab input.
        tab2_cmd_inputs = inputs.addTabCommandInput('tab_2', _LCLZ('footprint', 'Footprint'))
        custom_footprint_inputs = tab2_cmd_inputs.children
        tab2_cmd_inputs.isVisible = not self.only_3d_model_generator

        # Create image input.
        enable_custom_footprint = custom_footprint_inputs.addBoolValueInput('hasCustomFootprint', _LCLZ('hasCustomFootprint', 'Custom Footprint'), True, '', self.ui_data['hasCustomFootprint'])
        custom_footprint_image = custom_footprint_inputs.addImageCommandInput('customPthImage', '', 'Resources/img/PTH-Custom-Footprint.png')
        custom_footprint_image.isFullWidth = True
        custom_footprint_image.isVisible = True
        custom_pad_diameter = custom_footprint_inputs.addValueInput('customPadDiameter', 'p',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['customPadDiameter']))
        custom_pad_diameter.isEnabled = True if enable_custom_footprint.value else False
        custom_pad_diameter.tooltip = _LCLZ('customPadDiameter', 'Custom Pad Diameter')
        custom_hole_diameter = custom_footprint_inputs.addValueInput('customHoleDiameter', 'b1',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['customHoleDiameter']))
        custom_hole_diameter.isEnabled = True if enable_custom_footprint.value else False
        custom_hole_diameter.tooltip = _LCLZ('customHoleDiameter', 'Custom Hole Diameter')

        #create the tab of Manufacturing settings.
        tab3_cmd_inputs = inputs.addTabCommandInput('tab_3', _LCLZ('Manufacturing', 'Manufacturing'))
        manufacturing_inputs = tab3_cmd_inputs.children
        tab3_cmd_inputs.isVisible = not self.only_3d_model_generator

        # Create dropdown input with test list style.
        density_level = manufacturing_inputs.addDropDownCommandInput('densityLevel', _LCLZ('producibilityLevel', 'Producibility Level'), adsk.core.DropDownStyles.TextListDropDownStyle)
        density_level_list = density_level.listItems
        for t in constant.DENSITY_LEVEL_TH:
            density_level_list.add(_LCLZ(t, t), True if constant.DENSITY_LEVEL_TH.get(t) == self.ui_data['densityLevel'] else False, '')
        density_level.maxVisibleItems = len(constant.DENSITY_LEVEL_TH)

        # Pad to Hole Ratio
        manufacturing_inputs.addValueInput('padToHoleRatio', _LCLZ('padToHoleRatio', 'Pad to Hole Ratio'), '', adsk.core.ValueInput.createByReal(self.ui_data['padToHoleRatio']))

        #Update when using the custom footprint mode
        if self.ui_data['hasCustomFootprint'] : 
            tab3_cmd_inputs.isVisible = False


    def on_input_changed(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs, changed_input: adsk.core.CommandInput, input_values: dict ):

        if changed_input.id == 'hasCustomFootprint':
            inputs.itemById('customPadDiameter').isEnabled = changed_input.value
            inputs.itemById('customHoleDiameter').isEnabled = changed_input.value
            inputs.itemById('tab_3').isVisible = not changed_input.value
                
# register the command into the factory. 
PackageCommand.cmd_factory.register_command(constant.PKG_TYPE_DIP, PackageCommandDip)