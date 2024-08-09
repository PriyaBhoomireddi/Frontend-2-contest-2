import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_model
from ..Utilities import fusion_sketch
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

def sot143(params, design = None, targetComponent = None):
    A = params.get('A') or 0.114 #Body Height
    A1 = params['A1'] if 'A1' in params else 0.01
    D = params.get('D') or 0.29 #Lead Span
    E = params.get('E') or 0.24 #Body length
    E1 = params.get('E1') or 0.13 #Body width
    e = params.get('e') or 0.19 #pitch
    L = params.get('L') or 0.05 #Terminal length
    b = params.get('b') or 0.044 #Terminal width
    b1 = params.get('b1') or 0.083 #Terminal width
    e1 = params.get('e1') or 0.173 #pin pitch 1
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

    front_feet_num = math.ceil((DPins - 1) / 2)
    back_feet_num = DPins - front_feet_num

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
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("TerminalWidth", "terminal width"))
    is_update = addin_utility.process_user_param(design, 'param_e1', e1, default_unit, _LCLZ("PinPitch1", "pin pitch 1"))
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

    pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, 'param_e/2')
    pin_plane_xz.name = 'PinPlaneXz'
    sketch_pin = sketches.add(pin_plane_xz)

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
    chamfer_distance1 = '(param_A - param_A1 - param_terminalThickness)/2'
    chamfer_distance = 'param_A/10'
    fusion_model.create_start_end_face_chamfer(root_comp, body, chamfer_distance1, chamfer_distance)

    #normal pins
    body_center_z = (A+A1)/2
    lead_slope =  0
    fusion_sketch.create_gull_wing_lead(sketch_pin, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    common_pin = extrudes.add(ext_input)
    common_pin.name = 'CommonPin'
    # apply the pin material.
    addin_utility.apply_material(app, design, common_pin.bodies.item(0), constant.MATERIAL_ID_TIN)

    bodies = adsk.core.ObjectCollection.create()
    bodies.add(common_pin.bodies.item(0))
    # Create a move feature
    transform = adsk.core.Matrix3D.create()
    transform.setToRotation(math.pi, adsk.core.Vector3D.create(0,0,1), adsk.core.Point3D.create(0,0,0))
    move_feats = root_comp.features.moveFeatures
    move_feature_input = move_feats.createInput(bodies, transform)
    moved_comman_pin = move_feats.add(move_feature_input)

    fusion_model.create_one_direction_pattern(root_comp, common_pin.bodies.item(0), 'param_e', 'round((param_DPins - 1) / 2)', root_comp.yConstructionAxis)
    
    #Create odd pin side plane
    odd_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, 'param_e1/2')
    odd_pin_plane_xz.name = 'OddPinPlaneXz'
    sketch_pin_odd = sketches.add(odd_pin_plane_xz)

    #Create odd pin
    fusion_sketch.create_gull_wing_lead(sketch_pin_odd, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_pin_odd.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b1')
    ext_input.setSymmetricExtent(distance, True)
    odd_pin = extrudes.add(ext_input)
    odd_pin.name = 'OddPin'
    # apply the pin material.
    addin_utility.apply_material(app, design, odd_pin.bodies.item(0), constant.MATERIAL_ID_TIN)

    #Create adjacent pin on same axis as odd pin 
    adj_pin_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, '-param_e1/2')
    adj_pin_plane_xz.name = 'AdjPinPlaneXz'
    sketch_pin_adj = sketches.add(adj_pin_plane_xz)

    #Create odd pin
    fusion_sketch.create_gull_wing_lead(sketch_pin_adj, E, 'param_E/2', E1, 'param_E1/2', body_center_z, terminal_thickness, L, lead_slope)
    prof = sketch_pin_adj.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    adj_pin = extrudes.add(ext_input)
    adj_pin.name = 'ADJPin'
    # apply the pin material.
    addin_utility.apply_material(app, design, adj_pin.bodies.item(0), constant.MATERIAL_ID_TIN)

    
    '''
    #Create adjacent pin on same axis as odd pin 
    prof = sketch_pin_odd.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    pin = extrudes.add(ext_input)
    #Move the pin
    bodies = adsk.core.ObjectCollection.create()
    bodies.add(pin.bodies.item(0))
    # Create a transform to do move
    vector = adsk.core.Vector3D.create(0.0, -e1, 0.0)
    transform = adsk.core.Matrix3D.create()
    transform.translation = vector

    # Create a move feature
    features = root_comp.features
    moveFeats = features.moveFeatures
    moveFeatureInput = moveFeats.createInput(bodies, transform)
    moveFeats.add(moveFeatureInput)
    #transform = adsk.core.Matrix3D.create()
    #transform.setToRotation(math.pi , adsk.core.Vector3D.create(0,0,1), adsk.core.Point3D.create(0,0,0))
    # Create a move feature
    #move_feats = root_comp.features.moveFeatures
    #move_feature_input = move_feats.createInput(bodies, transform)
    #moved_pin = move_feats.add(move_feature_input)

    '''


    # apply the pin material.
    #addin_utility.apply_material(app, design, pin.bodies.item(0), constant.MATERIAL_ID_TIN)

    #pin one body marking
    addin_utility.create_pin_one_mark(root_comp, A, 'param_A', D, 'param_D', E1, 'param_E1')

from .base import package_3d_model_base

class Sot1433DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "sot143"

    def create_model(self, params, design, component):
        sot143(params, design, component)

package_3d_model_base.factory.register_package(Sot1433DModel.type(), Sot1433DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    sot143(params, design, targetComponent)