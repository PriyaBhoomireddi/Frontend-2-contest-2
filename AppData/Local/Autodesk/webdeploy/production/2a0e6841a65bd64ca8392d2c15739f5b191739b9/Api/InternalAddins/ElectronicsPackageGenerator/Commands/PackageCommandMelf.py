import adsk.core
from . import PackageCommand
from ..Utilities import addin_utility,fusion_ui, constant
from ..Utilities.localization import _LCLZ



MELF_FAMILY_TYPES = {
    'RESISTOR': constant.COMP_FAMILY_RESISTOR,
    'DIODE': constant.COMP_FAMILY_DIODE
    }

        

class PackageCommandMelf(PackageCommand.PackageCommand):
    def __init__(self, name: str, options: dict):
        super().__init__(name, options)

        #overwrite some specific settings of this command. 
        self.cmd_id = 'cmd_id_Melf'
        self.cmd_name = _LCLZ('CmdNameMelf', 'Melf Generator')
        self.cmd_description = _LCLZ('CmdDescMelf', 'Generate Melf Packages')
        self.cmd_ctrl_id = self.cmd_id
        self.dialog_width = 300
        self.dialog_height = 580

    def get_defalt_ui_data(self):
        #default parameters
        ui_data = {}
        ui_data['type'] = constant.PKG_TYPE_MELF
        ui_data['cmd_id'] = self.cmd_id
        ui_data['horizontalPadCount'] = 2 # for metadata only
        ui_data['densityLevel'] = constant.DENSITY_LEVEL_SMD['Nominal (N)']
        ui_data['padShape'] = constant.SMD_PAD_SHAPE.get('Rectangle')
        ui_data['componentFamily'] = MELF_FAMILY_TYPES['RESISTOR']
        ui_data['roundedPadCornerSize'] = 40
        ui_data['bodyWidthMax'] = 0.37
        ui_data['bodyWidthMin'] = 0.33
        ui_data['bodyLengthMax'] = 0.16
        ui_data['bodyLengthMin'] = 0.145
        ui_data['padWidthMax'] = 0.05
        ui_data['padWidthMin'] = 0.035
        ui_data['silkscreenMappingTypeToBody'] = constant.SILKSCREEN_MAPPING_TO_BODY.get('MappingTypeToBodyMax')
        ui_data['fabricationTolerance'] = 0.005
        ui_data['placementTolerance'] = 0.003
        ui_data['hasCustomFootprint'] = False
        ui_data['customPadLength'] = 0.115
        ui_data['customPadWidth'] = 0.174
        ui_data['customPadToPadGap'] = 0.221
        return ui_data

    def update_ui_data(self, inputs):
        # update date from UI inputs
        input_data = self.get_inputs()
        for param in self.ui_data:
            if param in input_data:
                self.ui_data[param] = input_data[param]
        
        # update the density level
        self.ui_data['densityLevel'] = list(constant.DENSITY_LEVEL_SMD.values())[inputs.itemById('densityLevel').selectedItem.index]
        self.ui_data['silkscreenMappingTypeToBody'] = list(constant.SILKSCREEN_MAPPING_TO_BODY.values())[inputs.itemById('silkscreenMappingTypeToBody').selectedItem.index]
        self.ui_data['padShape'] = list(constant.SMD_PAD_SHAPE.values())[inputs.itemById('padShape').selectedItem.index]
        self.ui_data['componentFamily'] = list(MELF_FAMILY_TYPES.values())[inputs.itemById('componentFamily').selectedItem.index]
    
    def on_create(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs):
        
        super().on_create(command, inputs)

        ao = addin_utility.AppObjects()

        # Create a package tab input.
        tab1_cmd_inputs = inputs.addTabCommandInput('tab_1', _LCLZ('package', 'Package'))
        melf_inputs = tab1_cmd_inputs.children
        
        # Create image input.
        labeled_image = melf_inputs.addImageCommandInput('MelfImage', '', 'Resources/img/Melf-Labeled.png')
        labeled_image.isFullWidth = True
        labeled_image.isVisible = True

        # Create dropdown input with  list style.
        component_family = melf_inputs.addDropDownCommandInput('componentFamily', _LCLZ('componentFamily', 'Component Family'), adsk.core.DropDownStyles.TextListDropDownStyle)
        component_family_list = component_family.listItems
        for t in MELF_FAMILY_TYPES:
            component_family_list.add(_LCLZ(t, MELF_FAMILY_TYPES.get(t)), True if MELF_FAMILY_TYPES.get(t) == self.ui_data['componentFamily'] else False, '')
        component_family.maxVisibleItems = len(MELF_FAMILY_TYPES)

        # Create dropdown input with test list style.
        pad_shape = melf_inputs.addDropDownCommandInput('padShape', _LCLZ('padShape', 'Pad Shape'), adsk.core.DropDownStyles.TextListDropDownStyle)
        pad_shape_list = pad_shape.listItems
        pad_shape_list.add(_LCLZ('Rectangle', constant.SMD_PAD_SHAPE.get('Rectangle')), True if constant.SMD_PAD_SHAPE.get('Rectangle') == self.ui_data['padShape'] else False, '')        
        pad_shape_list.add(_LCLZ('RoundedRectangle', constant.SMD_PAD_SHAPE.get('RoundedRectangle')), True if constant.SMD_PAD_SHAPE.get('RoundedRectangle') == self.ui_data['padShape'] else False, '')
        pad_shape.isVisible = not self.only_3d_model_generator
        pad_shape.maxVisibleItems = 2

        # create round corner size input
        rounded_corner = melf_inputs.addValueInput('roundedPadCornerSize', _LCLZ('padRoundness', 'Pad Roundness (%)'), '', adsk.core.ValueInput.createByReal(self.ui_data['roundedPadCornerSize']))
        rounded_corner.isVisible = True if constant.SMD_PAD_SHAPE.get('RoundedRectangle') == self.ui_data['padShape'] else False

        # table
        table = melf_inputs.addTableCommandInput('bodyDimensionTable', 'Table', 3, '1:2:2')
        table.hasGrid = False
        table.tablePresentationStyle = 2
        table.maximumVisibleRows = 4
        fusion_ui.add_title_to_table(table, '', _LCLZ('min', 'Min'), _LCLZ('max', 'Max'))
        fusion_ui.add_row_to_table(table, 'padWidth', 'L', adsk.core.ValueInput.createByReal(self.ui_data['padWidthMin']), adsk.core.ValueInput.createByReal(self.ui_data['padWidthMax']), _LCLZ('terminalLength', 'Terminal Length'))
        fusion_ui.add_row_to_table(table, 'bodyWidth', 'D', adsk.core.ValueInput.createByReal(self.ui_data['bodyWidthMin']), adsk.core.ValueInput.createByReal(self.ui_data['bodyWidthMax']), _LCLZ('bodyLength', 'Body Length'))
        fusion_ui.add_row_to_table(table, 'bodyLength', 'E', adsk.core.ValueInput.createByReal(self.ui_data['bodyLengthMin']), adsk.core.ValueInput.createByReal(self.ui_data['bodyLengthMax']), _LCLZ('bodyDiameter', 'Body Diameter'))

        # Create dropdown input with test list style.
        map_silkscreen = melf_inputs.addDropDownCommandInput('silkscreenMappingTypeToBody', _LCLZ('mapSilkscreen', 'Map Silkscreen to Body'), adsk.core.DropDownStyles.TextListDropDownStyle)
        map_silkscreen_list = map_silkscreen.listItems
        for t in constant.SILKSCREEN_MAPPING_TO_BODY:
            map_silkscreen_list.add(_LCLZ(t, constant.SILKSCREEN_MAPPING_TO_BODY.get(t)), True if constant.SILKSCREEN_MAPPING_TO_BODY.get(t) == self.ui_data['silkscreenMappingTypeToBody'] else False, '')
        map_silkscreen.isVisible = not self.only_3d_model_generator
        map_silkscreen.maxVisibleItems = len(constant.SILKSCREEN_MAPPING_TO_BODY)

        # Create a custom footprint tab input.
        tab2_cmd_inputs = inputs.addTabCommandInput('tab_2', _LCLZ('footprint', 'Footprint'))
        custom_footprint_inputs = tab2_cmd_inputs.children
        tab2_cmd_inputs.isVisible = not self.only_3d_model_generator

        # Create image input.
        enable_custom_footprint = custom_footprint_inputs.addBoolValueInput('hasCustomFootprint', _LCLZ('hasCustomFootprint', 'Custom Footprint'), True, '', self.ui_data['hasCustomFootprint'])
        custom_footprint_image = custom_footprint_inputs.addImageCommandInput('customMelfImage', '', 'Resources/img/SOD-Custom-Footprint.png') #TODO:update image
        custom_footprint_image.isFullWidth = True
        custom_footprint_image.isVisible = True
        custom_pad_length = custom_footprint_inputs.addValueInput('customPadLength', 'l',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['customPadLength']))
        custom_pad_length.isEnabled = enable_custom_footprint.value
        custom_pad_length.tooltip = _LCLZ("customPadLength", 'Custom Pad Length')
        custom_pad_width = custom_footprint_inputs.addValueInput('customPadWidth', 'c',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['customPadWidth']))
        custom_pad_width.isEnabled = enable_custom_footprint.value
        custom_pad_width.tooltip = _LCLZ('customPadWidth', 'Custom Pad Width')
        custom_pad_gap = custom_footprint_inputs.addValueInput('customPadToPadGap', 'g',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['customPadToPadGap']))
        custom_pad_gap.isEnabled = enable_custom_footprint.value
        custom_pad_gap.tooltip = _LCLZ('customPadGap', 'Custom Pad To Pad Gap')

        #create the tab of Manufacturing settings.
        tab3_cmd_inputs = inputs.addTabCommandInput('tab_3', _LCLZ('Manufacturing', 'Manufacturing'))
        manufacturing_inputs = tab3_cmd_inputs.children
        tab3_cmd_inputs.isVisible = not self.only_3d_model_generator

        # Create dropdown input for density level
        density_level = manufacturing_inputs.addDropDownCommandInput('densityLevel', _LCLZ('densityLevel', 'Density Level'), adsk.core.DropDownStyles.TextListDropDownStyle)
        density_level_list = density_level.listItems
        for t in constant.DENSITY_LEVEL_SMD:
            density_level_list.add(_LCLZ(t, t), True if constant.DENSITY_LEVEL_SMD.get(t) == self.ui_data['densityLevel'] else False, '')
        density_level.maxVisibleItems = len(constant.DENSITY_LEVEL_SMD)

        # fabrication Tolerance 
        manufacturing_inputs.addValueInput('fabricationTolerance', _LCLZ('fabricationTolerance', 'Fabrication Tolerance'),  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['fabricationTolerance']))
        # placement Tolerance
        manufacturing_inputs.addValueInput('placementTolerance', _LCLZ('placementTolerance', 'PlacementTolerance'),  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(self.ui_data['placementTolerance']))
        #Update when using the custom footprint mode
        if self.ui_data['hasCustomFootprint'] : 
            tab3_cmd_inputs.isVisible = False

    def on_input_changed(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs, changed_input: adsk.core.CommandInput, input_values: dict ):

        if changed_input.id == 'hasCustomFootprint':
            inputs.itemById('customPadLength').isEnabled = changed_input.value
            inputs.itemById('customPadWidth').isEnabled = changed_input.value
            inputs.itemById('customPadToPadGap').isEnabled = changed_input.value
            inputs.itemById('tab_3').isVisible = not changed_input.value
            
        if changed_input.id == 'padShape':
            pad_shape = list(constant.SMD_PAD_SHAPE.values())[inputs.itemById('padShape').selectedItem.index]
            if pad_shape == constant.SMD_PAD_SHAPE.get("RoundedRectangle"):
                inputs.itemById('roundedPadCornerSize').isVisible = True
            else:
                inputs.itemById('roundedPadCornerSize').isVisible = False

# register the calculator into the factory. 
PackageCommand.cmd_factory.register_command(constant.PKG_TYPE_MELF, PackageCommandMelf) 
           