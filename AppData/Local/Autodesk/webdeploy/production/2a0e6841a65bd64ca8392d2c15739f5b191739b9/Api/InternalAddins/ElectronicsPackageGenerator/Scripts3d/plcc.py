import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_model
from ..Utilities import fusion_sketch
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

def plcc(params, design = None, target_comp = None):

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits


    A = params.get('A') or 0.357    # body height(A)
    A1 = params['A1'] if 'A1' in params else 0.051  # body offset from seating plane (A1)
    b = params.get('b') or 0.043   # terminal width (b)
    e = params.get('e') or 0.127    # pin pitch (e)
    D = params.get('D') or 1.2445    # terminal span (D side)
    D1 = params.get('D1') or 1.15     # body length (D)
    D2 = params.get('D2') or 1.06   # weld space (D side)
    E = params.get('E') or 1.2445    # terminal span (E)
    E1 = params.get('E1') or 1.15  # body width (E1)
    E2 = params.get('E2') or 1.06   # weld space (E side)

    DPins = params.get('DPins') or 7*2 # Total pins amount on D side
    EPins = params.get('EPins') or 7*2 # Total pins amount on E side

    is_update = False
    is_update = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_A1', A1, default_unit, _LCLZ("BodyOffset", "body offset"))
    is_update = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("ESideSpan", "E side span"))
    is_update = addin_utility.process_user_param(design, 'param_E1', E1, default_unit, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_E2', E2, default_unit, _LCLZ("ESideWeldSpace", "E side weld space"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("DSideSpan", "D side span"))
    is_update = addin_utility.process_user_param(design, 'param_D1', D1, default_unit, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_D2', D2, default_unit, _LCLZ("DSideWeldSpace", "D side weld space"))
    is_update = addin_utility.process_user_param(design, 'param_e', e, default_unit, _LCLZ("Pitch", "pitch"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("TerminalLength", "terminal length"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("DSidePins", "D side pins"))
    is_update = addin_utility.process_user_param(design, 'param_EPins', EPins, '', _LCLZ("ESidePins", "E side pins"))

    # the paramters are already there, just update the models with the paramters. will skip the model creation process.
    if is_update: return

    sketches = root_comp.sketches
    terminal_thickness_name = (addin_utility.format_internal_to_default_unit(root_comp, fusion_sketch.TERMINAL_THICKNESS_J_LEAD))
    # Step1 create D side pin plane and sketches
    pin_path_plane_xz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, '((param_DPins/2 - 1)*param_e)/2')
    pin_path_plane_xz.name = 'PinPathPlaneXz'
    Dpin_path_sketch = sketches.add(pin_path_plane_xz)
    Dpin_path_sketch.name = 'DpinPathSketch'

    #create D pins profile
    fusion_sketch.create_j_lead(Dpin_path_sketch, E1, 'param_E1', E, 'param_E', E2, 'param_E2', A, 'param_A', A1, 'param_A1')
    Dpin_bottom_profile = Dpin_path_sketch.profiles.item(0)
    Dpin_side_profile = Dpin_path_sketch.profiles.item(1)

    # Step2 create the D pin body
    extrudes = root_comp.features.extrudeFeatures
    extrude_input = extrudes.createInput(Dpin_side_profile, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)

    extent_distance_1 = adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByString('param_b'))
    extent_distance_2 = adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByString('param_b/2'))
    extrude_input.setTwoSidesExtent(extent_distance_1,extent_distance_1)
    Dpin_extru_side_body = extrudes.add(extrude_input)
    Dpin_extru_side_body.name = 'DpinBodySide'

    extrude_input = extrudes.createInput(Dpin_bottom_profile, adsk.fusion.FeatureOperations.JoinFeatureOperation)
    extrude_input.setTwoSidesExtent(extent_distance_2,extent_distance_2)
    Dpin_extru_bottom_body = extrudes.add(extrude_input)
    Dpin_extru_bottom_body.name = 'DpinBodyBottom'

    #step5 move D pin to the right position.
    bodies = adsk.core.ObjectCollection.create()
    bodies.add(Dpin_extru_bottom_body.bodies.item(0))
    transform = adsk.core.Matrix3D.create()
    transform.setToRotation(math.pi/2, adsk.core.Vector3D.create(0,0,1), adsk.core.Point3D.create(0,0,0))
    # Create a move feature
    move_feats = root_comp.features.moveFeatures
    move_feature_input = move_feats.createInput(bodies, transform)
    moved_pin = move_feats.add(move_feature_input)

    #assign the material to terminal
    addin_utility.apply_material(app, design, Dpin_extru_bottom_body.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, Dpin_extru_bottom_body.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    # Step3 create E side pin plane and sketches
    pin_path_plane_yz = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, '-((param_EPins/2 - 1)*param_e)/2')
    pin_path_plane_yz.name = 'PinPathPlaneYz'
    Epin_path_sketch = sketches.add(pin_path_plane_yz)
    Epin_path_sketch.name = 'EpinPathSketch'

    #create E pins profile
    fusion_sketch.create_j_lead(Epin_path_sketch, D1, 'param_D1', D, 'param_D', D2, 'param_D2', A, 'param_A', A1, 'param_A1')
    Epin_bottom_profile = Epin_path_sketch.profiles.item(0)
    Epin_side_profile = Epin_path_sketch.profiles.item(1)

    #Step 4 create E pin body
    extrude_input = extrudes.createInput(Epin_side_profile, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    extrude_input.setTwoSidesExtent(extent_distance_1,extent_distance_1)
    Epin_extru_side_body = extrudes.add(extrude_input)
    Epin_extru_side_body.name = 'EpinBodySide'

    extrude_input = extrudes.createInput(Epin_bottom_profile, adsk.fusion.FeatureOperations.JoinFeatureOperation)
    extrude_input.setTwoSidesExtent(extent_distance_2,extent_distance_2)
    Epin_extru_bottom_body = extrudes.add(extrude_input)
    Epin_extru_bottom_body.name = 'EpinBodyBottom'

    #assign the material to terminal
    addin_utility.apply_material(app, design, Epin_extru_bottom_body.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, Epin_extru_bottom_body.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)


    #step6: create construction plane to generate the body sketch
    body_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A1')
    body_plane_xy.name = 'BodyPlaneXy'
    body_sketch = sketches.add(body_plane_xy)
    body_sketch.name = 'BodySketch'

    #step7: create the body
    fusion_sketch.create_center_point_rectangle(body_sketch, adsk.core.Point3D.create(0,0,0), '', '', adsk.core.Point3D.create(E1/2,D1/2,0), 'param_D1','param_E1')
    ext_body = fusion_model.create_extrude(root_comp,body_sketch.profiles.item(0), 'param_A-param_A1', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    ext_body.name = 'Body'
    addin_utility.apply_material(app, design, ext_body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)

    # create chamfer
    chamfer_distance = '(param_A - param_A1 -'+ terminal_thickness_name + ')/2'
    chamfer_distance1 = '0.2*(param_A - param_A1 -' + terminal_thickness_name + ')'
    fusion_model.create_start_end_face_chamfer(root_comp, ext_body, chamfer_distance, chamfer_distance1)

    # Step 8. create pin mirror and Pattern for D side pins
    pattern_pins_d = fusion_model.create_mirror_and_pattern(root_comp, Dpin_extru_bottom_body.bodies.item(0), 'param_e', 'param_DPins/2', root_comp.xConstructionAxis, root_comp.xZConstructionPlane)
    pattern_pins_d.name = 'PinPatternD'

    # Step 9. create pin mirror and Pattern for E side pins
    pattern_pins_e = fusion_model.create_mirror_and_pattern(root_comp, Epin_extru_bottom_body.bodies.item(0), 'param_e', 'param_EPins/2', root_comp.yConstructionAxis, root_comp.yZConstructionPlane)
    pattern_pins_e.name = 'PinPatternE'

    #pin one body marking
    pin_one_mark_plane_xy = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    pin_one_mark_plane_xy.name = 'PinOneMarkPlaneXy'
    pin_one_mark_sketch = root_comp.sketches.add(pin_one_mark_plane_xy)

    pin_one_mark_sketch.isComputeDeferred = True
    mark_radius = E/30
    circle_origin = adsk.core.Point3D.create(-(D/2- E/10-mark_radius) ,-0.1, 0)
    sketch_point = pin_one_mark_sketch.sketchPoints.add(circle_origin)
    pin_one_mark_sketch.sketchCurves.sketchCircles.addByCenterRadius(sketch_point, mark_radius)

    pin_one_mark_sketch.sketchDimensions.addRadialDimension(pin_one_mark_sketch.sketchCurves[0],
                                                     adsk.core.Point3D.create(0.1, 0, 0)).parameter.expression = 'param_E/30'
    pin_one_mark_sketch.sketchDimensions.addDistanceDimension(sketch_point, pin_one_mark_sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     adsk.core.Point3D.create(0.1, 0, 0)).parameter.expression = ' (1.01 + floor(param_EPins/4) - ceil(param_EPins/4))*param_e/2'
    pin_one_mark_sketch.sketchDimensions.addDistanceDimension(sketch_point, pin_one_mark_sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     adsk.core.Point3D.create(0.1, 0, 0)).parameter.expression = 'param_D1/2- param_A/10- param_E/10'

    pin_one_mark_sketch.isComputeDeferred = False
    prof = pin_one_mark_sketch.profiles[0]
    pin_one_mark = root_comp.features.extrudeFeatures.addSimple(prof, adsk.core.ValueInput.createByString('-param_A*0.1'), adsk.fusion.FeatureOperations.CutFeatureOperation)
    pin_one_mark.name = 'PinOneMark'

from .base import package_3d_model_base

class Plcc3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "plcc"

    def create_model(self, params, design, component):
        plcc(params, design, component)

package_3d_model_base.factory.register_package(Plcc3DModel.type(), Plcc3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    plcc(params, design, target_comp)
