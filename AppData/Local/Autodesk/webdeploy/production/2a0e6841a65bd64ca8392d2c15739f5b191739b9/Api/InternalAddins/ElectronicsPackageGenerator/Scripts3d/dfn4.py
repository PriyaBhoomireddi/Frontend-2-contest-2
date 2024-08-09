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
        return params[name]
    else:
        if (name == 'e'):
            return 0.045 #Vertical Pin Pitch
        if (name == 'd'):
            return 0.075 #Horizontal Pin Pitch
        if (name == 'b'):
            return 0.028 #Normal Terminal Width
        if (name == 'L'):
            return 0.04 #Normal Terminal Length
        if (name == 'E'):
            return 0.08 #Body Width
        if (name == 'D'):
            return 0.125 #Body Length
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
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 or res_6 or res_7
    if isUpdate:
        #Updating terminal thickness
        thick = addin_utility.get_dfn_terminal_thickness(root_comp, get_param(params, 'A'))
        terminal = root_comp.features.itemByName('Terminal')
        terminal.timelineObject.rollTo(True)
        dist_def = adsk.fusion.DistanceExtentDefinition.cast(terminal.extentOne)
        dist = adsk.fusion.ModelParameter.cast(dist_def.distance)
        dist.value = thick
        design.timeline.moveToEnd()
        return isUpdate


def create_terminal_sketch(root_comp, params):
    #Create terminal sketch
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    pin_sketch = sketches.add(xyPlane)
    fusion_sketch.create_center_point_rectangle(pin_sketch, adsk.core.Point3D.create((get_param(params, 'd'))/2, (get_param(params, 'e'))/2, 0),
            'param_d/2', 'param_e/2', adsk.core.Point3D.create((get_param(params, 'd'))/2 + (get_param(params, 'L'))/2, (get_param(params, 'e'))/2 + (get_param(params, 'b'))/2, 0), 
            'param_L', 'param_b')
    return pin_sketch

def create_terminal_body(root_comp, params, design, pin_sketch):
    #get terminal thickness
    pin_thick = addin_utility.get_dfn_terminal_thickness(root_comp, get_param(params, 'A'))
    ext_ter = pin_sketch.profiles.item(0)
    terminal = fusion_model.create_extrude(root_comp,ext_ter, str(pin_thick * 10) , adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal.name = 'Terminal'
    #Assign the pysical material to terminal
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    #Assign the appearance to terminal
    addin_utility.apply_appearance(app, design, terminal.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)
    #Create the rest of the terminals
    fusion_model.create_mirror_and_pattern(root_comp, terminal, '-param_d', '2', root_comp.xConstructionAxis, root_comp.xZConstructionPlane)
    return terminal

def dfn4(params, design = None, target_comp = None):

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

    #create terminal sketch
    terminal_sketch = create_terminal_sketch(root_comp, params)
    #Create terminal
    terminal = create_terminal_body(root_comp, params, design, terminal_sketch)
    #terminal.name = 'Terminal'
    #Create body sketch
    #body_sketch = create_dfn4_sketch(root_comp, params)
    body_sketch = fusion_sketch.create_dfn_body_sketch(root_comp, params, get_param)
    #Create body
    #create_dfn4_body(root_comp, params, design, body_sketch, terminal)
    addin_utility.create_dfn_body(root_comp, app, params, design, body_sketch, terminal)
    #Create pin one marker
    addin_utility.create_dfn_pin_one_marker(root_comp, params, get_param, body_sketch)

#registering the package with the factory
class Dfn43DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "dfn4"

    def create_model(self, params, design, component):
        dfn4(params, design, component)

package_3d_model_base.factory.register_package(Dfn43DModel.type(), Dfn43DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    dfn4(params, design, target_comp)