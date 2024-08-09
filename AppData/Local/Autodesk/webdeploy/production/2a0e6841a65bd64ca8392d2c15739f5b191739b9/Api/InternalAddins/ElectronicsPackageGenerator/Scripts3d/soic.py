import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_model
from ..Utilities import fusion_sketch
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()


def soic(params, design = None, targetComponent = None):

    A = params.get('A') or 0.265 #body height
    A1 = params['A1'] if 'A1' in params else 0.025 #body offset
    b = params.get('b') or 0.051 #terminal width
    D = params.get('D') or 1.3 #body length
    E = params.get('E') or 1.065 #lead span
    E1 = params.get('E1') or 0.76 #body width
    e = params.get('e') or 0.127 #pin pitch
    L= params.get('L') or 0.0835 #terminal length
    DPins= params.get('DPins') or 20 #pins
    E2 = params.get('E2') or 0.48 #thermal pad width
    D2 = params.get('D2') or 0.861 #thermal pad length
    thermal = params['thermal'] if 'thermal' in params else 0 #flag

    terminal_thickness = 0.02
    lead_slope =  math.tan(math.pi/15) * (A/2-terminal_thickness/2)

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design.
    root_comp = design.rootComponent

    if targetComponent:
        root_comp = targetComponent

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    is_update = False

    is_update = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_A1', A1, default_unit, _LCLZ("BodyOffset", "body offset"))
    is_update = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("Span", "span"))
    is_update = addin_utility.process_user_param(design, 'param_E1', E1, default_unit, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_e', e, default_unit, _LCLZ("Pitch", "pitch"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("TerminalLength", "terminal length"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("TerminalWidth", "terminal width"))
    is_update = addin_utility.process_user_param(design, 'param_D2', D2, default_unit, _LCLZ("ThermalPadLength", "thermal pad length"))
    is_update = addin_utility.process_user_param(design, 'param_E2', E2, default_unit, _LCLZ("ThermalPadWidth", "thermal pad width"))
    is_update = addin_utility.process_user_param(design, 'param_terminalThickness', terminal_thickness, default_unit, _LCLZ("TerminalThickness", "terminal thickness"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("Pins", "pins"))
    # the paramters are already there, just update the models with the paramters. will skip the model creation process.
    if is_update:
        thermal_pad = root_comp.features.itemByName('ThermalPad')
        if thermal:
            thermal_pad.isSuppressed = False
        else:
            thermal_pad.isSuppressed = True
        return

    # Create a construction plane by offset
    sketches = root_comp.sketches
    planes = root_comp.constructionPlanes

    body_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A1')
    body_plane_xy.name = 'BodyPlaneXy'
    sketch_body = sketches.add(body_plane_xy)

    front_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, 'param_e / 2 * ( param_DPins / 2 - 1 )')
    front_pin_plane_xz.name = 'FrontPinPlaneXz'
    sketch_front_pin = sketches.add(front_pin_plane_xz)

    extrudes = root_comp.features.extrudeFeatures

    #body
    center_point = adsk.core.Point3D.create(0,0,0)
    end_point = adsk.core.Point3D.create(E1/2,D/2,0)
    fusion_sketch.create_center_point_rectangle(sketch_body, center_point, '', '', end_point, 'param_E1', 'param_D')
    prof = sketch_body.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body = extrudes.addSimple(prof, adsk.core.ValueInput.createByString('param_A - param_A1'), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body.name = 'Body'
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)

    # create chamfer
    chamfer_distance = 'abs((param_A - param_A1 - param_terminalThickness)/2)'
    chamfer_distance1 = 'abs((param_A - param_A1 - param_terminalThickness) * 0.2)'
    fusion_model.create_start_end_face_chamfer(root_comp, body, chamfer_distance, chamfer_distance1)

    fusion_sketch.create_gull_wing_lead(sketch_front_pin, E, 'param_E/2', E1, 'param_E1/2', (A+A1)/2, terminal_thickness, L, lead_slope)
    prof = sketch_front_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    front_pin = extrudes.add(ext_input)
    front_pin.name = 'FrontPin'
    # apply the pin material.
    addin_utility.apply_material(app, design, front_pin.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, front_pin.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    fusion_model.create_mirror_and_pattern(root_comp, front_pin, '-param_e', 'param_DPins/2', root_comp.yConstructionAxis, root_comp.yZConstructionPlane)

    #pin one body marking
    addin_utility.create_pin_one_mark(root_comp, A, 'param_A', D, 'param_D', E1, 'param_E1')

    #Creating thermal pad
    if A1 == 0:
        A1 = terminal_thickness
    addin_utility.create_thermal_pad(app, root_comp, '0', adsk.core.Point3D.create(0, 0, 0), '', '', adsk.core.Point3D.create(E2/2, D2/2, 0), 'param_E2', 'param_D2', 'param_A1', thermal)

from .base import package_3d_model_base

class Soic3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "soic"

    def create_model(self, params, design, component):
        soic(params, design, component)

package_3d_model_base.factory.register_package(Soic3DModel.type(), Soic3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    soic(params, design, targetComponent)
