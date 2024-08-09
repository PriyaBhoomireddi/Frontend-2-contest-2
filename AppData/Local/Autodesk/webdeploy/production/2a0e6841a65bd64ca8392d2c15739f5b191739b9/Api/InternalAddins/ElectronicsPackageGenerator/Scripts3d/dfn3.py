import adsk.core, traceback, adsk.fusion, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ
from .base import package_3d_model_base

app = adsk.core.Application.get()

#get param from the pallete
def get_param(params, name):
    if name in params:
        return params[name]
    else:
        if (name == 'e'):
            return 0.035 #Vertical Pin Pitch
        if (name == 'd'):
            return 0.065 #Horizontal Pin Pitch
        if (name == 'b'):
            return 0.02 #Normal Terminal Width
        if (name == 'L'):
            return 0.03 #Normal Terminal Length
        if (name == 'b1'):
            return 0.03 #Odd Terminal Width
        if (name == 'L1'):
            return 0.055 #Odd Terminal Length
        if (name == 'E'):
            return 0.065 #Body Width
        if (name == 'D'):
            return 0.105 #Body Length
        if (name == 'A'):
            return 0.04 #Body Height

def user_param(design, params, default_unit, root_comp):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    res_2 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_3 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_4 = addin_utility.process_user_param(design, 'param_e', get_param(params, 'e'), default_unit, _LCLZ("VerticalPinPitch", "vertical pin pitch"))
    res_5 = addin_utility.process_user_param(design, 'param_b', get_param(params, 'b'), default_unit, _LCLZ("NormalTerminalWidth", "normal terminal width"))
    res_6 = addin_utility.process_user_param(design, 'param_L', get_param(params, 'L'), default_unit, _LCLZ("NormalTerminalLength", "normal terminal length"))
    res_7 = addin_utility.process_user_param(design, 'param_d', get_param(params, 'd'), default_unit, _LCLZ("HorizontalPinPitch", "horizontal pin pitch"))
    res_8 = addin_utility.process_user_param(design, 'param_b1', get_param(params, 'b1'), default_unit, _LCLZ("OddTerminalWidth", "odd terminal width"))
    res_9 = addin_utility.process_user_param(design, 'param_L1', get_param(params, 'L1'), default_unit, _LCLZ("OddTerminalLength", "odd terminal length"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 or res_6 or res_7 or res_8 or res_9
    if isUpdate:
        #Updating terminal thickness
        thick = addin_utility.get_dfn_terminal_thickness(root_comp, get_param(params, 'A'))
            
        terminal_odd = root_comp.features.itemByName('TerminalOdd')
        terminal_odd.timelineObject.rollTo(True)
        dist_def = adsk.fusion.DistanceExtentDefinition.cast(terminal_odd.extentOne)
        dist = adsk.fusion.ModelParameter.cast(dist_def.distance)
        dist.value = thick
        design.timeline.moveToEnd()

        terminal_even = root_comp.features.itemByName('TerminalEven')
        terminal_even.timelineObject.rollTo(True)
        dist_def = adsk.fusion.DistanceExtentDefinition.cast(terminal_even.extentOne)
        dist = adsk.fusion.ModelParameter.cast(dist_def.distance)
        dist.value = thick
        design.timeline.moveToEnd()
        return isUpdate


def create_odd_terminal_sketch(root_comp, params):
    #Create Odd terminal sketch
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    pin_sketch = sketches.add(xyPlane)
    pin_sketch.isComputeDeferred = True
    fusion_sketch.create_center_point_rectangle(pin_sketch, adsk.core.Point3D.create((get_param(params, 'd'))/2, 0, 0),'param_d/2','', 
            adsk.core.Point3D.create((get_param(params, 'd'))/2 + (get_param(params, 'b1'))/2, (get_param(params, 'L1'))/2, 0), 
            'param_b1', 'param_L1')
    return pin_sketch

def create_odd_terminal_body(root_comp, params, design, pin_sketch):
    #get terminal thickness
    pin_thick_odd = addin_utility.get_dfn_terminal_thickness(root_comp, get_param(params, 'A'))
    ext_ter = pin_sketch.profiles.item(0)
    terminal_odd = fusion_model.create_extrude(root_comp,ext_ter, str(pin_thick_odd * 10), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal_odd.name = 'TerminalOdd'
    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, terminal_odd.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, terminal_odd.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)
    return terminal_odd

def create_even_terminal_sketch(root_comp, params):
    #Create even terminal sketch
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    sketch_pin = sketches.add(xyPlane)
    sketch_pin.isComputeDeferred = True
    fusion_sketch.create_center_point_rectangle(sketch_pin, adsk.core.Point3D.create(-(get_param(params, 'd'))/2, (get_param(params, 'e'))/2, 0),'param_d/2','param_e/2', 
            adsk.core.Point3D.create(-(get_param(params, 'd'))/2 - (get_param(params, 'L'))/2, (get_param(params, 'e'))/2 + (get_param(params, 'b'))/2, 0), 
            'param_L', 'param_b')
    return sketch_pin

def create_even_terminal_body(root_comp, params, design, pin_sketch):
    #get terminal thickness
    pin_thick_even = addin_utility.get_dfn_terminal_thickness(root_comp, get_param(params, 'A'))
    ext_ter = pin_sketch.profiles.item(0)
    terminal_even = fusion_model.create_extrude(root_comp, ext_ter, str(pin_thick_even * 10), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal_even.name = 'TerminalEven'
    # assign the pysical material to pin
    addin_utility.apply_material(app, design, terminal_even.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the appearance to pin
    addin_utility.apply_appearance(app, design, terminal_even.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)
    #Create pin mirror
    fusion_model.create_mirror(root_comp, terminal_even, root_comp.xZConstructionPlane)

def dfn3(params, design = None, target_comp = None):

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
    param_updated = user_param(design, params, default_unit, root_comp)
    if param_updated == True:
        return

    #Creating odd pin
    sketch_odd = create_odd_terminal_sketch(root_comp, params)
    terminal_body = create_odd_terminal_body(root_comp, params, design, sketch_odd)
    #Creating even pin
    sketch_even = create_even_terminal_sketch(root_comp, params)
    create_even_terminal_body(root_comp, params, design, sketch_even)
    #Create body
    sketch_body = fusion_sketch.create_dfn_body_sketch(root_comp, params, get_param)
    addin_utility.create_dfn_body(root_comp, app, params, design, sketch_body, terminal_body)
    #Create pin one marker
    addin_utility.create_dfn_pin_one_marker(root_comp, params, get_param, sketch_body)
    

class Dfn33DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "dfn3"

    def create_model(self, params, design, component):
        dfn3(params, design, component)

package_3d_model_base.factory.register_package(Dfn33DModel.type(), Dfn33DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    dfn3(params, design, target_comp)