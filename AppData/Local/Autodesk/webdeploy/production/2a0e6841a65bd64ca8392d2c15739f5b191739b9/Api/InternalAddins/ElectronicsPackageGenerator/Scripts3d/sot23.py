import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

def sot23(params, design = None, targetComponent = None):
    A = params.get('A') or 0.117 #Body Height
    A1 = params['A1'] if 'A1' in params else 0.01 #Body offset
    D = params.get('D') or 0.29 #Lead Span
    E = params.get('E') or 0.24 #Body length
    E1 = params.get('E1') or 0.13 #Body width
    e = params.get('e') or 0.095 #Terminal width
    e1 = params.get('e1') or 0.095 #Terminal width
    L = params.get('L') or 0.05 #Terminal length
    b = params.get('b') or 0.044 #Terminal thickness
    DPins = params.get('DPins') or 6 #pins

    #normal value of terminal thickness from JEDEC doc, or calculate avg(min,max)
    c = 0.013

    if('terminalThickness' not in params):
        terminal_thickness = c
    else:
        if(params['terminalThickness']<0):
            terminal_thickness = c
        else:
            terminal_thickness = min(params['terminalThickness'],c)

    front_feet_num = math.ceil((DPins - 1) / 2)
    back_feet_num = DPins - front_feet_num

    if ('e1' not in params):
    	#e1 is used for placing front pins and e is used for back pins
        e1 = 2 * e if(front_feet_num == 2) else e

    #update back pin pitch if backpin number is 2
    if(back_feet_num == 2):
        e = 2 * e

    chamfer_distance = (A-A1-terminal_thickness)/2
    chamfer_distance1 = A/10

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
    is_update = addin_utility.process_user_param(design, 'param_e1', e1, default_unit, _LCLZ("Pitch", "pitch")) #:todo need to verify requrement
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("TerminalLength", "terminal length"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("TerminalWidth", "terminal width"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("Pins", "pins")) #:todo need to verify requrement
    is_update = addin_utility.process_user_param(design, 'param_terminalThickness', terminal_thickness, default_unit, _LCLZ("TerminalThickness", "terminal thickness"))
    # the paramters are already there, just update the models with the paramters. will skip the model creation process.
    if is_update: return

    # Create a new sketch.
    sketches = root_comp.sketches
    # Create a construction plane by offset
    body_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A1')
    body_plane_xy.name = 'BodyPlaneXy'
    sketch_body = sketches.add(body_plane_xy)

    front_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, '-(round((param_DPins - 1) / 2)-1)/2*param_e1')
    front_pin_plane_xz.name = 'FrontPinPlaneXz'
    sketch_front_pin = sketches.add(front_pin_plane_xz)

    back_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, '(param_DPins-round((param_DPins - 1) / 2)-1)/2*param_e')
    back_pin_plane_xz.name = 'BackPinPlaneXz'
    sketch_back_pin = sketches.add(back_pin_plane_xz)

    #pin_one_mark_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, A)
    #pin_one_mark_plane_xy.name = 'PinOneMarkPlaneXy'
    #sketch_pin_one_mark = sketches.add(pin_one_mark_plane_xy)

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
    chamfer_distance = '(param_A - param_A1 - param_terminalThickness)/2'
    chamfer_distance1 = 'param_A/10'
    fusion_model.create_start_end_face_chamfer(root_comp, body, chamfer_distance, chamfer_distance1)

    #normal pins
    body_center_z = (A+A1)/2
    lead_slope =  0
    fusion_sketch.create_gull_wing_lead(sketch_front_pin, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_front_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('-param_b')
    ext_input.setSymmetricExtent(distance, True)
    front_pin = extrudes.add(ext_input)
    front_pin.name = 'FrontPin'
    addin_utility.apply_material(app, design, front_pin.bodies.item(0), constant.MATERIAL_ID_TIN)

    bodies = adsk.core.ObjectCollection.create()
    bodies.add(front_pin.bodies.item(0))
    # Create a move feature
    transform = adsk.core.Matrix3D.create()
    transform.setToRotation(math.pi, adsk.core.Vector3D.create(0,0,1), adsk.core.Point3D.create(0,0,0))
    moveFeats = root_comp.features.moveFeatures
    moveFeatureInput = moveFeats.createInput(bodies, transform)
    movedFrontPin = moveFeats.add(moveFeatureInput)
    pattern_pins1 = fusion_model.create_one_direction_pattern(root_comp, front_pin.bodies.item(0), '-param_e1', 'round((param_DPins - 1) / 2)', root_comp.yConstructionAxis)
    pattern_pins1.name = 'PinPattern1'

    fusion_sketch.create_gull_wing_lead(sketch_back_pin, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_back_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('-param_b')
    ext_input.setSymmetricExtent(distance, True)
    back_pin = extrudes.add(ext_input)
    back_pin.name = 'BackPin'
    addin_utility.apply_material(app, design, back_pin.bodies.item(0), constant.MATERIAL_ID_TIN)

    pattern_pins2 = fusion_model.create_one_direction_pattern(root_comp, back_pin.bodies.item(0), '-param_e', 'param_DPins-round((param_DPins - 1) / 2)', root_comp.yConstructionAxis)
    pattern_pins2.name = 'PinPattern2'

    #pin one body marking
    #addin_utility.create_pin_one_mark(sketch_pin_one_mark, extrudes, A, D, E1, chamfer_distance1, 'param_D/2')
    addin_utility.create_pin_one_mark(root_comp, A, 'param_A', D, 'param_D', E1, 'param_E1')


from .base import package_3d_model_base

class Sot233DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "sot23"

    def create_model(self, params, design, component):
        sot23(params, design, component)

package_3d_model_base.factory.register_package(Sot233DModel.type(), Sot233DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    sot23(params, design, targetComponent)
