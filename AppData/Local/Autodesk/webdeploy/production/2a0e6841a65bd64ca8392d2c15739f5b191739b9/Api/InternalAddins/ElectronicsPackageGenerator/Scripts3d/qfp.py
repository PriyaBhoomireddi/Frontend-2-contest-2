import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_model
from ..Utilities import fusion_sketch
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()
 

def qfp(params, design = None, targetComponent = None):
    A = params.get('A') or 0.12 #body height
    A1 = params['A1'] if 'A1' in params else 0.005 #body offset
    b = params.get('b') or 0.027 #terminal width
    D = params.get('D') or 1.31 #span2
    D1 = params.get('D1') or 1.02 #body length
    E = params.get('E') or 1.31 #span1
    E1 = params.get('E1') or 1.02 #ody width
    ee1 = params.get('e') or 0.05 #lower case e in front
    #ee2 = params.get('ee2') or 0.05 #lower case e in back
    ee3 = params.get('e') or 0.05 #ower case e in left
    #ee4 = params.get('ee4') or 0.05 #lower case e in right
    L = params.get('L') or 0.103
    DPins= params.get('DPins') or 32
    EPins = params.get('EPins') or 32
    thermal = params['thermal'] if 'thermal' in params else 0 #flag
    E2 = params.get('E2') or 0.7
    D2 = params.get('D2') or 0.7

    terminal_thickness = 0.02
    front_feet_num = DPins/2
    leftFeetNum = EPins/2

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design.
    root_comp = design.rootComponent

    if targetComponent:
        root_comp = targetComponent

    unitsMgr = design.unitsManager
    default_unit = unitsMgr.defaultLengthUnits
    is_update = False
    is_update = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_A1', A1, default_unit, _LCLZ("BodyOffset", "body offset"))
    is_update = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("Span", "span")+'1')
    is_update = addin_utility.process_user_param(design, 'param_E1', E1, default_unit, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_D1', D1, default_unit, _LCLZ("Span", "span")+'2')
    is_update = addin_utility.process_user_param(design, 'param_ee1', ee1, default_unit, _LCLZ("Pitch", "pitch"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("TerminalWidth", "terminal width"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("TerminalLand", "terminal land"))
    is_update = addin_utility.process_user_param(design, 'param_D2', D2, default_unit, _LCLZ("ThermalPadLength", "thermal pad length"))
    is_update = addin_utility.process_user_param(design, 'param_E2', E2, default_unit, _LCLZ("ThermalPadWidth", "thermal pad width"))
    is_update = addin_utility.process_user_param(design, 'param_terminalThickness', terminal_thickness, default_unit, _LCLZ("TerminalThickness", "terminal thickness"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("DSidePins", "D side pins"))
    is_update = addin_utility.process_user_param(design, 'param_EPins', EPins, '', _LCLZ("ESidePins", "E side pins"))
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

    body_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A1')
    body_plane_xy.name = 'BodyPlaneXy'
    sketch_body = sketches.add(body_plane_xy)

    front_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, 'param_ee1/2 * (param_DPins/2-1)')
    front_pin_plane_xz.name = 'FrontPinPlaneXz'
    sketch_front_pin = sketches.add(front_pin_plane_xz)

    left_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, '-param_ee1/2 * (param_EPins/2-1)')
    left_pin_plane_xz.name = 'LeftPinPlaneXz'
    sketch_left_pin = sketches.add(left_pin_plane_xz)

    extrudes = root_comp.features.extrudeFeatures

    #create body and apply material
    center_point = adsk.core.Point3D.create(0,0,0)
    end_point = adsk.core.Point3D.create(E1/2,D1/2,0)
    fusion_sketch.create_center_point_rectangle(sketch_body, center_point, '', '', end_point, 'param_E1', 'param_D1')
    prof = sketch_body.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_A - param_A1')
    body = extrudes.addSimple(prof, distance, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body.name = 'Body'
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)

    # create chamfer
    # chamfer_distance1 = (A - A1-terminal_thickness)/2
    # chamfer_distance = 0.2*(A - A1-terminal_thickness)
    fusion_model.create_start_end_face_chamfer(root_comp, body, '(param_A - param_A1 - param_terminalThickness)/2', 'param_A /10')

    #build pin front and back
    lead_slope =  math.tan(math.pi/15) * (A/2-terminal_thickness/2)
    body_center_z = (A+A1)/2

    fusion_sketch.create_gull_wing_lead(sketch_front_pin, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_front_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    front_pin = extrudes.add(ext_input)
    front_pin.name = 'FrontPin'
    addin_utility.apply_material(app, design, front_pin.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, front_pin.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    pattern_pins = fusion_model.create_mirror_and_pattern(root_comp, front_pin, '-param_ee1', 'param_DPins/2', root_comp.yConstructionAxis, root_comp.yZConstructionPlane)
    pattern_pins.name = 'PinPattern'

    #build pin left and right
    fusion_sketch.create_gull_wing_lead(sketch_left_pin, D, 'param_D/2', D1, 'param_D1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_left_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    left_pin = extrudes.add(ext_input)
    left_pin.name = 'LeftPin'
    addin_utility.apply_material(app, design, left_pin.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, left_pin.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    bodies = adsk.core.ObjectCollection.create()
    bodies.add(left_pin.bodies.item(0))
    transform = adsk.core.Matrix3D.create()
    transform.setToRotation(math.pi/2, adsk.core.Vector3D.create(0,0,1), adsk.core.Point3D.create(0,0,0))
    # Create a move feature
    move_feats = root_comp.features.moveFeatures
    move_feature_input = move_feats.createInput(bodies, transform)
    moved_pin = move_feats.add(move_feature_input)
    # Create mirror and pattern for moved pin
    mirrored_left_pin = fusion_model.create_mirror(root_comp, left_pin.bodies.item(0), root_comp.xZConstructionPlane)
    fusion_model.create_one_direction_pattern(root_comp, left_pin.bodies.item(0), '-param_ee1', 'param_EPins/2', root_comp.xConstructionAxis)
    fusion_model.create_one_direction_pattern(root_comp, mirrored_left_pin.bodies.item(0), '-param_ee1', 'param_EPins/2', root_comp.xConstructionAxis)

    #draw thermal pad
    if A1 == 0:
        A1 = terminal_thickness
    addin_utility.create_thermal_pad(app, root_comp, '0', adsk.core.Point3D.create(0, 0, 0), '', '', adsk.core.Point3D.create(E2/2, D2/2, 0), 'param_E2', 'param_D2', 'param_A1', thermal)

    #pin one body marking
    addin_utility.create_pin_one_mark(root_comp, A, 'param_A', D1, 'param_D1', E1, 'param_E1')

from .base import package_3d_model_base

class Qfp3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "qfp"

    def create_model(self, params, design, component):
        qfp(params, design, component)

package_3d_model_base.factory.register_package(Qfp3DModel.type(), Qfp3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    qfp(params, design, targetComponent)
