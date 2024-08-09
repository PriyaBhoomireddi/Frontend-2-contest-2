import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_model
from ..Utilities import fusion_sketch
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()
      

def header_straight_socket(params, design = None, targetComponent = None):
    b = params.get('b') or 0.1 #Terminal thickness
    D = params.get('D') or 1.016 #Lead Span
    d = params.get('d') or 0.254 #pitch along D
    E = params.get('E') or 0.556 #Body length
    e = params.get('e') or 0.254 #pitch along E
    L = params.get('L') or 0.254 #body height
    L1 = params.get('L1') or 0.3 #terminal tail length
    DPins = params.get('DPins') or 4 #Total pins along D
    EPins = params.get('EPins') or 2 #Total pins along E

    origin_location_id = params['originLocationId'] if 'originLocationId' in params else 0

    origin_y = -e*(EPins-1)/2
    pattern_distance_E = -e
    pattern_distance_D = d

    padding_E = (E-e*(EPins-1))     
    padding_D = (D-d*(DPins-1))/2
    chamfer_size = min(e, d, E, L)/5

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design.
    root_comp = design.rootComponent

    if targetComponent:
        root_comp = targetComponent

        #Get the current transform of the occurrence
        if design.snapshots.count !=0:
            snapshot = design.snapshots.item(0)
            snapshot.deleteMe()
        component_acc = design.rootComponent.allOccurrencesByComponent(root_comp).item(0)
        transform = component_acc.transform
        # Change the transform data by moving x and y
        if origin_location_id == 1:
            transform.translation = adsk.core.Vector3D.create(-d*(DPins-1), -e*(EPins-1)/2, 0)
        elif origin_location_id == 2:
            transform.translation = adsk.core.Vector3D.create(-d*(DPins-1), e*(EPins-1)/2, 0)
        elif origin_location_id == 3:
            transform.translation = adsk.core.Vector3D.create(0, e*(EPins-1), 0)
        elif origin_location_id == 4:
            transform.translation = adsk.core.Vector3D.create(-d*(DPins-1)/2, e*(EPins-1)/2, 0)   
        else:
            transform.translation = adsk.core.Vector3D.create(0, 0, 0)         
        # Set the transform data back to the occurrence
        design.rootComponent.allOccurrencesByComponent(root_comp).item(0).transform = transform
        if design.snapshots.hasPendingSnapshot:
            design.snapshots.add()
 
    units = design.unitsManager
    mm = units.defaultLengthUnits
    is_update = False
    is_update = addin_utility.process_user_param(design, 'param_E', E, mm, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_d', d, mm, _LCLZ("PitchAlongD", "pitch along D"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, mm, _LCLZ("LeadSpan", "lead span"))
    is_update = addin_utility.process_user_param(design, 'param_e', e, mm, _LCLZ("PitchAlongE", "pitch along E"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, mm, _LCLZ("TerminalThickness", "terminal thickness"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, mm, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_L1', L1, mm, _LCLZ("TerminalTailLength", "terminal tail length"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("PinsAlongD", "pins along D"))
    is_update = addin_utility.process_user_param(design, 'param_EPins', EPins, '', _LCLZ("PinsAlongE", "pins along E"))
    # the paramters are already there, just update the models with the paramters. will skip the model creation process. 
    if is_update: return

    # Create a new sketch on the xy plane.
    sketches = root_comp.sketches

    body_plane_yz = addin_utility.create_offset_plane(root_comp,root_comp.yZConstructionPlane, '(-param_D+param_d*(param_DPins-1))/2')
    body_plane_yz.name = 'BodyPlaneYz'
    sketch_body = sketches.add(body_plane_yz)
    sketch_body.name = 'SketchBody'

    pin_plane_xy = addin_utility.create_offset_plane(root_comp,root_comp.xYConstructionPlane, '-param_L1')
    pin_plane_xy.name = 'PinPlaneXy'
    sketch_pin = sketches.add(pin_plane_xy)
    sketch_pin.name = 'SketchPin'

    body_slot_plane_xy = addin_utility.create_offset_plane(root_comp,root_comp.xYConstructionPlane, 'param_L-param_b*0.7')
    body_slot_plane_xy.name = 'BodySlotPlaneXy'
    sketch_body_slot = sketches.add(body_slot_plane_xy)
    sketch_body_slot.name = 'SketchBodySlot'

    extrudes = root_comp.features.extrudeFeatures

    #create pin and apply material

    sketch_pin.isComputeDeferred = True
    lines = sketch_pin.sketchCurves.sketchLines

    center_point = adsk.core.Point3D.create(0,0,0)
    end_point = adsk.core.Point3D.create(b/2,-b/2,0)
    fusion_sketch.create_center_point_rectangle(sketch_pin, center_point, '', '', end_point, 'param_b', 'param_b')
    sketch_pin.isComputeDeferred = False
    prof = sketch_pin.profiles[0]
    pin = extrudes.addSimple(prof, adsk.core.ValueInput.createByString('param_L1+param_b/4'), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    pin.name = 'Pin'
    addin_utility.apply_material(app, design, pin.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    addin_utility.apply_appearance(app, design, pin.bodies.item(0), constant.APPEARANCE_ID_GOLD_POLISHED)
    
    #chamfer pin and get pattern
    start_face = pin.startFaces[0]
    fusion_model.create_face_chamfer(root_comp, start_face, 'param_b/4', 'param_b/1.5') 
    pattern_pins1 = fusion_model.create_two_direction_pattern(root_comp, pin.bodies.item(0), 'param_d', 'param_DPins', root_comp.xConstructionAxis, '-param_e', 'param_EPins', root_comp.yConstructionAxis)
    pattern_pins1.name = 'PinPattern1'

    #create body and apply material
    end_point = adsk.core.Point3D.create(-L, padding_E/2, 0)
    center_point = adsk.core.Point3D.create(-L/2, origin_y, 0)
    fusion_sketch.create_center_point_rectangle(sketch_body, center_point, 'param_L/2', 'param_E/2-(param_E-param_e*(param_EPins-1))/2', end_point, 'param_L', 'param_E')
    
    prof = sketch_body.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body = extrudes.addSimple(prof, adsk.core.ValueInput.createByString('param_D'), adsk.fusion.FeatureOperations.NewBodyFeatureOperation) 
    body.name = 'Body'
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_PBT_PLASTIC)
    addin_utility.apply_appearance(app, design, body.bodies.item(0), constant.APPEARANCE_ID_BODY_DEFAULT)

    #extrudeCutBody
    sketch_body_slot.isComputeDeferred = True
    center_point = adsk.core.Point3D.create(0,0, 0)
    end_point = adsk.core.Point3D.create(b/2,-b/2, 0)
    fusion_sketch.create_center_point_rectangle(sketch_body_slot, center_point, '', '', end_point, 'param_b', 'param_b')
    sketch_body_slot.isComputeDeferred = False
    prof = sketch_body_slot.profiles[0]
    
    extrude_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.CutFeatureOperation)
    deg0 = adsk.core.ValueInput.createByString("0 deg")
    deg45 = adsk.core.ValueInput.createByString("45 deg")
    extent_distance = adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByString('param_L - param_b*0.7'))
    extent_distance_2 = adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByString('param_b*0.7'))
    extrude_input.setTwoSidesExtent(extent_distance_2, extent_distance, deg45, deg0)
    pin_socket = extrudes.add(extrude_input)
    pin_socket.name = 'PinSocket'
    pattern_pins2 = fusion_model.create_two_direction_pattern(root_comp, pin_socket, 'param_d', 'param_DPins', root_comp.xConstructionAxis, '-param_e', 'param_EPins', root_comp.yConstructionAxis)
    pattern_pins2.name = 'PinPattern2'


from .base import package_3d_model_base

class HeaderStraightSocket3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "header_straight_socket"

    def create_model(self, params, design, component):
        header_straight_socket(params, design, component)

package_3d_model_base.factory.register_package(HeaderStraightSocket3DModel.type(), HeaderStraightSocket3DModel) 

def run(context):
    ui = app.userInterface
     
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    header_straight_socket(params, design, targetComponent)
