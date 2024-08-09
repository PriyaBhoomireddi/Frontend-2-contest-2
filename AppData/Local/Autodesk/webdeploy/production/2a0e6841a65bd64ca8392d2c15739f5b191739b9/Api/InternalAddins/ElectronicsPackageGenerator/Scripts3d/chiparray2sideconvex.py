import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ
from .base import package_3d_model_base

app = adsk.core.Application.get()


#get param from the pallete
def get_param(params, name):
    if name in params:
        if name == 'color_r' and params[name] == None: #default body color as per family
            return 10
        if name == 'color_g' and params[name] == None:
            return 10
        if name == 'color_b' and params[name] == None:
            return 10
        else:
            return params[name]
    else:
        if (name == 'e'):
            return 0.064 #Pin Pitch
        if (name == 'DPins'):
            return 10 #Total Pins
        if (name == 'A'):
            return 0.07 #Body Height
        if (name == 'b'):
            return 0.04 #Terminal Width
        if (name == 'b1'):
            return 0.055 # End Terminal Width
        if (name == 'D'):
            return 0.34 #Body Length
        if (name == 'E'):
            return 0.24 #Body Width
        if (name == 'L'):
            return 0.055 #Terminal Length
        if (name == 'color_r'):
            return 10
        if (name == 'color_g'):
            return 10
        if (name == 'color_b'):
            return 10

def user_param(root_comp, design, params, default_unit, get_param):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_e', get_param(params, 'e'), default_unit, _LCLZ("PinPitch", "pin pitch"))
    res_2 = addin_utility.process_user_param(design, 'param_pins', get_param(params, 'DPins'), '', _LCLZ("TotalPins", "total pins"))
    res_3 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    res_4 = addin_utility.process_user_param(design, 'param_b', get_param(params, 'b'), default_unit, _LCLZ("TerminalWidth", "terminal width"))
    res_5 = addin_utility.process_user_param(design, 'param_b1', get_param(params, 'b1'), default_unit, _LCLZ("EndTerminalWidth", "end terminal width"))
    res_6 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_7 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_8 = addin_utility.process_user_param(design, 'param_L', get_param(params, 'L'), default_unit, _LCLZ("TerminalLength", "terminal length"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 or res_6 or res_7 or res_8
    if isUpdate:
        rgb = adsk.core.Color.create(get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), 0)
        body_color = addin_utility.get_appearance(app, design, constant.COLOR_NAME_CHIP_BODY)
        color_prop = adsk.core.ColorProperty.cast(body_color.appearanceProperties.itemById(constant.COLOR_PROP_ID_DEFAULT))
        color_prop.value = rgb
        
        mid_terminal = root_comp.features.itemByName('MidTerminal')
        mid_terminal.timelineObject.rollTo(True)
        pins = get_param(params, 'DPins')
        if pins == 4: #suppress the mid pins if pin no. is 4
            mid_terminal.isSuppressed = True
        else:
            mid_terminal.isSuppressed = False
          
        for param in root_comp.modelParameters:
            if param.createdBy.name=="SketchPinMid":
                if param.role=="Linear Dimension-3" :
                    if 'param_pins' == 6 or 10 :
                        param.expression = '0'
                    if 'param_pins' != 6 or 10 :
                        param.expression = '(param_pins / 2 - 3 ) * param_e / 2'
        design.timeline.moveToEnd()

        return isUpdate
        
def create_body_sketch(root_comp, params):
    # Create body offset plane and sketch
    sketches = root_comp.sketches
    body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, (addin_utility.format_internal_to_default_unit(root_comp, 0.0005)))
    body_offset.name = 'BodyOffset'
    body_sketch = sketches.add(body_offset)
    fusion_sketch.create_center_point_rectangle(body_sketch,adsk.core.Point3D.create(0, 0, 0) , '', '', 
                    adsk.core.Point3D.create(get_param(params, 'E')/2 - get_param(params, 'L'), get_param(params, 'D')/2, 0),'param_E - 2 * param_L', 'param_D')
    return body_sketch

def create_body(root_comp, params, design, body_sketch):
    #Select the body profile
    body_prof = body_sketch.profiles.item(0)
    ext_body = fusion_model.create_extrude(root_comp,body_prof, 'param_A -' + str(addin_utility.format_internal_to_default_unit(root_comp, 0.0005)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    ext_body.name = 'Body'
    chip_body = ext_body.bodies.item(0)
    chip_body.name = 'ChipBody'

    # assign the pysical material to body.
    addin_utility.apply_material(app, design, chip_body, constant.MATERIAL_ID_CERAMIC)
    # assign the apparance to body
    addin_utility.apply_rgb_appearance(app, design, chip_body, get_param(params, 'color_r'), get_param(params, 'color_g'), 
                                            get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_BODY)

def create_end_terminal_sketch(root_comp, params):
    #Create end terminal sketch
    xyPlane = root_comp.xYConstructionPlane
    sketches = root_comp.sketches
    pin_sketch = sketches.add(xyPlane)
    pin_sketch.name = 'SketchPin'
    centerPoint = adsk.core.Point3D.create(get_param(params, 'E')/2 - get_param(params, 'L')/2, 
                    (get_param(params, 'DPins')/2 - 1) * get_param(params, 'e')/2, 0)
    endPoint = adsk.core.Point3D.create(get_param(params, 'E')/2 , 
                    (get_param(params, 'DPins')/2 - 1) * get_param(params, 'e')/2 + get_param(params, 'b1')/2, 0)
    fusion_sketch.create_center_point_rectangle(pin_sketch, centerPoint, 'param_E/2 -param_L/2' , '(param_pins/2 - 1) * param_e/2'  ,endPoint, 'param_L', 'param_b1')

    return pin_sketch

def create_end_terminals(root_comp, params, design, pin_sketch):
    #Select the pin profile
    ext_term = pin_sketch.profiles.item(0)
    term = fusion_model.create_extrude(root_comp,ext_term, 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    term.name = 'EndTerminal'

    # assign pysical material to terminal
    addin_utility.apply_material(app, design, term.bodies.item(0), constant.MATERIAL_ID_TIN)

    #Create pattern and mirror
    pattern_pin_end = fusion_model.create_mirror_and_pattern(root_comp, term, '-param_E + param_L', 
                        '2', root_comp.xConstructionAxis, root_comp.xZConstructionPlane)
    pattern_pin_end.name = 'PinPatternEnd'

def create_mid_terminal_sketch(root_comp, params):
    #Create middle terminals
    xyPlane = root_comp.xYConstructionPlane
    sketches = root_comp.sketches
    pin_sketch_mid = sketches.add(xyPlane)
    pin_sketch_mid.name = 'SketchPinMid'
    centerPoint = adsk.core.Point3D.create(get_param(params, 'L')/2 - get_param(params, 'E')/2, 
                                        (get_param(params, 'DPins')/2 - 3) * -(get_param(params, 'e'))/2, 0)
    endPoint = adsk.core.Point3D.create(-(get_param(params, 'E'))/2 , 
                            (get_param(params, 'DPins')/2 - 3) * -(get_param(params, 'e'))/2 - get_param(params, 'b')/2, 0)
    fusion_sketch.create_center_point_rectangle(pin_sketch_mid, centerPoint, 'param_E/2 -param_L/2'  , '(param_pins/2 - 3) * param_e/2',
                                                    endPoint, 'param_L', 'param_b')
    
    return pin_sketch_mid

def create_mid_terminals(root_comp, params, design, pin_sketch_mid):
    #Selecting the profile
    ext_term_mid = pin_sketch_mid.profiles.item(0)
    term = fusion_model.create_extrude(root_comp,ext_term_mid, 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    term.name = 'MidTerminal'

    # assign pysical material to terminal
    addin_utility.apply_material(app, design, term.bodies.item(0), constant.MATERIAL_ID_TIN)

    #Create pattern and mirror
    pattern_pin_mid = fusion_model.create_mirror_and_pattern(root_comp, term, 'param_e', 
                        'param_pins/2 - 2', root_comp.yConstructionAxis, root_comp.yZConstructionPlane)
    pattern_pin_mid.name = 'PinPatternMid'

    if get_param(params, 'DPins') == 4: #Suppress the mid pin if pin no. is 4
        term.isSuppressed = True
        pattern_pin_mid = True

def chiparray2sideconvex(params, design = None, target_comp = None):

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    #param creation and updation
    param_updated = user_param(root_comp, design, params, default_unit, get_param)
    if param_updated == True:
        return

    #Create body sketch
    body_sketch = create_body_sketch(root_comp, params)
    #Create body
    create_body(root_comp, params, design, body_sketch)
    #Create end terminal sketch
    end_terminal_sketch = create_end_terminal_sketch(root_comp, params)
    #Create end terminal
    create_end_terminals(root_comp, params, design, end_terminal_sketch)
    #Create mid terminal sketch
    mid_terminal_sketch = create_mid_terminal_sketch(root_comp, params)
    #Create middle terminals
    create_mid_terminals(root_comp, params, design, mid_terminal_sketch)


class ChipArray2SideConvex3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "chiparray2sideconvex"

    def create_model(self, params, design, component):
        chiparray2sideconvex(params, design, component)

package_3d_model_base.factory.register_package(ChipArray2SideConvex3DModel.type(), ChipArray2SideConvex3DModel) 

def run(context):
    ui = app.userInterface
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    chiparray2sideconvex(params, design, target_comp)
