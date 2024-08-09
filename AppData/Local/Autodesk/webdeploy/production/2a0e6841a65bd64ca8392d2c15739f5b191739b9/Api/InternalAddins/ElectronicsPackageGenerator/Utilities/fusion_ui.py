
'''
this is the utility module which defined  functions to create ui components. 
'''
import adsk.core, adsk.fusion
import math
from . import addin_utility
from ..Utilities.localization import _LCLZ



#  add title to the table.
def add_title_to_table(table_input, title1, title2, title3):

    cmd_inputs = adsk.core.CommandInputs.cast(table_input.commandInputs)
    # add title to table
    table_input.addCommandInput(cmd_inputs.addTextBoxCommandInput('title_col0', 'title_col0', title1, 1, True), 0, 0)        
    table_input.addCommandInput(cmd_inputs.addTextBoxCommandInput('title_col1', 'title_col1', title2, 1, True), 0, 1)
    table_input.addCommandInput(cmd_inputs.addTextBoxCommandInput('title_col2', 'title_col2', title3, 1, True), 0, 2)
    return table_input

# Adds a new row to the table.
def add_row_to_table(table_input, id, label, min_value, max_value, tooltip):

    ao = addin_utility.AppObjects()
    # Get the CommandInputs object associated with the parent command.
    cmd_inputs = adsk.core.CommandInputs.cast(table_input.commandInputs)
    
    # Add the inputs to the table.
    row = table_input.rowCount    
    # Create three new command inputs.(Is this form ok?)
    row_lebal = cmd_inputs.addTextBoxCommandInput(id, label, label, 1, True)
    table_input.addCommandInput(row_lebal, row, 0)

    #create the 2nd Cell
    if min_value != None:
        row_min_value =  cmd_inputs.addValueInput(id+'Min', label, ao.units_manager.defaultLengthUnits, min_value)
    else:
        row_min_value =  cmd_inputs.addValueInput(id+'Min', label, '',  adsk.core.ValueInput.createByReal(0))
        row_min_value.isVisible = False
    row_min_value.tooltip =  tooltip + " " + _LCLZ('min', 'Min')
    table_input.addCommandInput(row_min_value, row, 1)

    #create the 3rd cell
    if max_value != None:
        row_max_value = cmd_inputs.addValueInput(id+'Max', label, ao.units_manager.defaultLengthUnits, max_value)
    else:
        row_max_value = cmd_inputs.addValueInput(id+'Max', label, '', adsk.core.ValueInput.createByReal(0))
        row_max_value.isVisible = False
    row_max_value.tooltip =  tooltip + " " +_LCLZ('max', 'Max')

    table_input.addCommandInput(row_max_value, row, 2)
    
    return table_input
    
def get_thermal_pad_settings(thermal_pad_inputs, ui_data, only_3d_model_generator = False):
    ao = addin_utility.AppObjects()

    enable_thermal_pad = thermal_pad_inputs.addBoolValueInput('hasThermalPad', _LCLZ('thermalPad', 'Thermal Pad'), True, '', ui_data['hasThermalPad'])
    thermal_pad_width = thermal_pad_inputs.addValueInput('thermalPadWidth', 'D2',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(ui_data['thermalPadWidth']))
    thermal_pad_width.tooltip = _LCLZ('thermalPadLength', 'Thermal Pad Length')
    thermal_pad_length = thermal_pad_inputs.addValueInput('thermalPadLength', 'E2',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(ui_data['thermalPadLength']))
    thermal_pad_length.tooltip = _LCLZ('thermalPadWidth', 'Thermal Pad Width')
    thermal_pad_length.isEnabled = enable_thermal_pad.value 
    thermal_pad_width.isEnabled = enable_thermal_pad.value 

    if not only_3d_model_generator:
        # Create group input for solder paste.
        solderpaste_inputs = thermal_pad_inputs.addGroupCommandInput('thermalPadSolderPasteOverride', _LCLZ('customSolderPaste', 'Custom Solder Paste'))
        solderpaste_inputs.isVisible = enable_thermal_pad.value
        solderpaste_inputs.isEnabledCheckBoxDisplayed = True
        solderpaste_inputs.isEnabledCheckBoxChecked = ui_data['thermalPadSolderPasteOverride']
        solderpaste_child_inputs = solderpaste_inputs.children
        # Create image input.
        solderpaste_pattern_image = solderpaste_child_inputs.addImageCommandInput('solderPastePattern', '', 'Resources/img/Solder-Paste-Pattern.png')
        solderpaste_pattern_image.isFullWidth = True
        solderpaste_pattern_image.isVisible = True
        solderpaste_child_inputs.addIntegerSpinnerCommandInput('thermalPadSolderPasteStencilRowCount', _LCLZ('RowsNum','# Rows'), 1 , 50 , 1, int(ui_data['thermalPadSolderPasteStencilRowCount']))
        solderpaste_child_inputs.addIntegerSpinnerCommandInput('thermalPadSolderPasteStencilColCount', _LCLZ('ColsNum','# Cols'), 1 , 50 , 1, int(ui_data['thermalPadSolderPasteStencilColCount']))
        aperture_length = solderpaste_child_inputs.addValueInput('thermalPadSolderPasteStencilApertureWidth', 'd3',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(ui_data['thermalPadSolderPasteStencilApertureWidth']))
        aperture_length.tooltip = _LCLZ('apertureLength', 'Aperture Length')
        aperture_width = solderpaste_child_inputs.addValueInput('thermalPadSolderPasteStencilApertureLength', 'e3',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(ui_data['thermalPadSolderPasteStencilApertureLength']))
        aperture_width.tooltip = _LCLZ('apertureWidth', 'Aperture Width')
        aperture_gap1 =solderpaste_child_inputs.addValueInput('thermalPadSolderPasteStencilApertureGapY', 'g1',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(ui_data['thermalPadSolderPasteStencilApertureGapY']))
        aperture_gap1.tooltip = _LCLZ('apertureGap1', 'Aperture Gap 1')
        aperture_gap2 = solderpaste_child_inputs.addValueInput('thermalPadSolderPasteStencilApertureGapX', 'g2',  ao.units_manager.defaultLengthUnits, adsk.core.ValueInput.createByReal(ui_data['thermalPadSolderPasteStencilApertureGapX']))
        aperture_gap2.tooltip = _LCLZ('apertureGap2', 'Aperture Gap 2')
        solderpaste_child_inputs.addValueInput('thermalPadSolderPasteAreaCoverage', _LCLZ('PasteCoveragePercent','Paste Coverage %'),  '', adsk.core.ValueInput.createByReal(ui_data['thermalPadSolderPasteAreaCoverage']))

def update_solder_paste_ui(changed_input_id, current_inputs):
    ao = addin_utility.AppObjects()
    total_area = current_inputs['thermalPadLength'] * current_inputs['thermalPadWidth']
    if changed_input_id == 'thermalPadSolderPasteAreaCoverage' and current_inputs['thermalPadSolderPasteAreaCoverage'] > 0 :
        #create aperture size and gap automatically without changing grid size when area coverage is updated 
        x = current_inputs['thermalPadSolderPasteAreaCoverage'] * total_area / 100
        y = current_inputs['thermalPadLength'] / current_inputs['thermalPadWidth']

        a = math.sqrt(x * y)
        b = math.sqrt(x / y)

        aperture_X = round(ao.units_manager.convert(a / current_inputs['thermalPadSolderPasteStencilColCount'], 'cm', ao.units_manager.defaultLengthUnits),2)
        aperture_Y = round(ao.units_manager.convert(b / current_inputs['thermalPadSolderPasteStencilRowCount'], 'cm', ao.units_manager.defaultLengthUnits),2)

        #distrubute gap around apertures uniformly along each direction
        gap_X = round(ao.units_manager.convert(abs(current_inputs['thermalPadLength'] - a) / (current_inputs['thermalPadSolderPasteStencilColCount'] + 1), 'cm', ao.units_manager.defaultLengthUnits),2)
        gap_Y = round(ao.units_manager.convert(abs(current_inputs['thermalPadWidth'] - b) / (current_inputs['thermalPadSolderPasteStencilRowCount'] + 1), 'cm', ao.units_manager.defaultLengthUnits),2)

        current_inputs['thermalPadSolderPasteStencilApertureLength_input'].expression = str(aperture_X)
        current_inputs['thermalPadSolderPasteStencilApertureWidth_input'].expression = str(aperture_Y)
        current_inputs['thermalPadSolderPasteStencilApertureGapX_input'].expression = str(gap_X)
        current_inputs['thermalPadSolderPasteStencilApertureGapY_input'].expression = str(gap_Y)
        current_inputs['thermalPadSolderPasteStencilApertureLength'] = aperture_X
        current_inputs['thermalPadSolderPasteStencilApertureWidth'] = aperture_Y
        current_inputs['thermalPadSolderPasteStencilApertureGapX'] = gap_X
        current_inputs['thermalPadSolderPasteStencilApertureGapY'] = gap_Y
    else:
        total_aperture_area = current_inputs['thermalPadSolderPasteStencilRowCount'] * current_inputs['thermalPadSolderPasteStencilColCount'] * current_inputs['thermalPadSolderPasteStencilApertureLength'] * current_inputs['thermalPadSolderPasteStencilApertureWidth']
        current_inputs['thermalPadSolderPasteAreaCoverage_input'].expression = str(round(100 * (total_aperture_area / total_area), 2))
        current_inputs['thermalPadSolderPasteAreaCoverage'] = round(100 * (total_aperture_area / total_area), 2)