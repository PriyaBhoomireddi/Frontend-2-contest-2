import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_model
from ..Utilities import fusion_sketch
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

def sot223(params, design = None, targetComponent = None):
    A = params.get('A') or 0.1 #Body Height
    A1 = params['A1'] if 'A1' in params else 0.01
    D = params.get('D') or 0.65 #Lead Span
    E = params.get('E') or 0.7 #Body length
    E1 = params.get('E1') or 0.35 #Body width
    e = params.get('e') or 0.2 #Terminal width
    L = params.get('L') or 0.09 #Terminal length
    b = params.get('b') or 0.07 #Terminal thickness
    b1 = params.get('b1') or 0.3 #Terminal thickness
    DPins = params.get('DPins') or 4

    #normal value of terminal thickness from JEDEC doc, or calculate avg(min,max)
    c = 0.013

    if('terminal_thickness' not in params):
        terminal_thickness = c
    else:
        if(params['terminal_thickness']<0):
            terminal_thickness = c
        else:
            terminal_thickness = min(params['terminal_thickness'],c)

    front_feet_num = DPins - 1

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
    is_update = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("Span", "span"))
    is_update = addin_utility.process_user_param(design, 'param_E1', E1, default_unit, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_e', e, default_unit, _LCLZ("Pitch", "pitch"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("TerminalLength", "terminal length"))
    is_update = addin_utility.process_user_param(design, 'param_b1', b1, default_unit, _LCLZ("TerminalLength", "terminal length"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("TabWidth", "tab width"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("Pins", "pins"))
    is_update = addin_utility.process_user_param(design, 'param_terminalThickness', terminal_thickness, default_unit, _LCLZ("TerminalThickness", "terminal thickness"))
    # the paramters are already there, just update the models with the paramters. will skip the model creation process.
    if is_update: return

    # Create a construction plane by offset
    sketches = root_comp.sketches
    body_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A1')
    body_plane_xy.name = 'BodyPlaneXy'
    sketch_body = sketches.add(body_plane_xy)

    common_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, 'param_e/2*(param_DPins-2)')
    common_pin_plane_xz.name = 'CommonPinPlaneXz'
    sketch_common_pin = sketches.add(common_pin_plane_xz)

    odd_pin_plane_xz = root_comp.xZConstructionPlane
    odd_pin_plane_xz.name = 'OddPinPlaneXz'
    sketch_odd_pin = sketches.add(odd_pin_plane_xz)

    #pin_one_mark_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, A)
    #pin_one_mark_plane_xy.name = 'PinOneMarkPlaneXy'
    #sketch_pin_one_mark = sketches.add(pin_one_mark_plane_xy)

    extrudes = root_comp.features.extrudeFeatures

    #create body
    center_point = adsk.core.Point3D.create(0,0,0)
    end_point = adsk.core.Point3D.create(E1/2,D/2,0)
    fusion_sketch.create_center_point_rectangle(sketch_body, center_point, '', '', end_point, 'param_E1', 'param_D')
    prof = sketch_body.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body = extrudes.addSimple(prof, adsk.core.ValueInput.createByString('param_A - param_A1'), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body.name = 'Body'
    # apply the body material.
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)

    #create chamfer
    chamfer_distance1 = '(param_A - param_A1 - param_terminalThickness)/2'
    chamfer_distance = 'param_A/10'
    fusion_model.create_start_end_face_chamfer(root_comp, body, chamfer_distance1, chamfer_distance)

    #common pin
    lead_slope =  math.tan(math.pi/15) * (A/2-terminal_thickness/2)
    body_center_z = (A+A1)/2
    fusion_sketch.create_gull_wing_lead(sketch_common_pin, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_common_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    common_pin = extrudes.add(ext_input)
    common_pin.name = 'CommonPin'
    # apply the pin material.
    addin_utility.apply_material(app, design, common_pin.bodies.item(0), constant.MATERIAL_ID_TIN)
    fusion_model.create_one_direction_pattern(root_comp, common_pin, '-param_e', 'param_DPins-1', root_comp.yConstructionAxis)

    #odd pin
    fusion_sketch.create_gull_wing_lead(sketch_odd_pin, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_odd_pin.profiles[0]
    extent_distance = adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByString('param_b1/2'))
    extrude_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    extrude_input.setTwoSidesExtent(extent_distance, extent_distance)
    odd_pin = extrudes.add(extrude_input)
    odd_pin.name = 'OddPin'
    # apply the pin material.
    addin_utility.apply_material(app, design, odd_pin.bodies.item(0), constant.MATERIAL_ID_TIN)
 
    bodies = adsk.core.ObjectCollection.create()
    bodies.add(odd_pin.bodies.item(0))
    #Create a move feature
    transform_pin = adsk.core.Matrix3D.create()
    transform_pin.setToRotation(math.pi, adsk.core.Vector3D.create(0,0,1), adsk.core.Point3D.create(0,0,0))
    move_feats = root_comp.features.moveFeatures
    move_feature_input = move_feats.createInput(bodies, transform_pin)
    moved_odd_pin = move_feats.add(move_feature_input)

    #pin one body marking
    #addin_utility.create_pin_one_mark(sketch_pin_one_mark, extrudes, A, D, E1, chamfer_distance1, 'param_D/2')
    addin_utility.create_pin_one_mark(root_comp, A, 'param_A', D, 'param_D', E1, 'param_E1')

from .base import package_3d_model_base

class Sot2233DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "sot223"

    def create_model(self, params, design, component):
        sot223(params, design, component)

package_3d_model_base.factory.register_package(Sot2233DModel.type(), Sot2233DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    sot223(params, design, targetComponent)
