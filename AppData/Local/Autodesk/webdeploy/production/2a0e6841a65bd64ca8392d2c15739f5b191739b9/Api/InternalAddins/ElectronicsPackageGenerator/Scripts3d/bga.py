import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()


def bga(params, design = None, target_comp = None):

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    #get the default unit of the system.  need consider to set the right unit. consider if user use the imperial unit.
    #define default value of the input paramters of diode. unit is mm
    A = params.get('A') or 0.1 #Body height(A)
    b = params.get('b') or 0.03 #Ball Diameter(b)
    D = params.get('D') or 0.62 #Body length(D)
    E = params.get('E') or 0.62 #Body width(E)
    d = params.get('d') or 0.05 #Horizontal ball pitch(d)
    e = params.get('e') or 0.05 #Vertical ball pitch(d)
    DPins = params.get('DPins') or 11 #Horizontal pins amount(DPins)
    EPins = params.get('EPins') or 11 #Vertical pins amount(DPins)

    #Bottom body length(D1)
    D1 = D - 0.01
    #Bottom body width(E1)
    E1 = E - 0.01
    #default ball offset inside body
    b1 = 0.01
    #Ball diameter threshold
    b2 = 0.015
    #Update ball height
    if(b > b2):
        A1 = b - b1
    else:
        A1 = b1 = b/2

    #Top body height
    A2 = (A - A1) * 2/3
    #Bottom body height
    A3 = 0.5 * A2

    paddingD = (DPins - 1) * d / 2
    paddingE = (EPins - 1) * e/ 2
    offset = max(D, E)/15

    isUpdate = False
    isUpdate =addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    isUpdate =addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("BallDiameter", "ball diameter"))
    isUpdate =addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("BodyLength", "body length"))
    isUpdate =addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("BodyWidth", "body width"))
    isUpdate =addin_utility.process_user_param(design, 'param_d', d, default_unit, _LCLZ("HorizontalBallPitch", "horizontal ball pitch"))
    isUpdate =addin_utility.process_user_param(design, 'param_e', e, default_unit, _LCLZ("VerticalBallPitch", "vertical ball pitch"))
    isUpdate =addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("VerticalBalls", "vertical balls"))
    isUpdate =addin_utility.process_user_param(design, 'param_EPins', EPins, '', _LCLZ("HorizontalBalls", "horizontal balls"))
    if isUpdate: return

    #Create body
    sketches = root_comp.sketches
    top_body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    top_body_offset.name = 'TopBodyOffset'
    top_body_sketch = sketches.add(top_body_offset)
    top_body_sketch.name = 'TopBodySketch'
    E_param = 'param_E -'+ (addin_utility.format_internal_to_default_unit(root_comp, 0.01))
    D_param = 'param_D -'+ (addin_utility.format_internal_to_default_unit(root_comp, 0.01))
    fusion_sketch.create_center_point_rectangle(top_body_sketch,adsk.core.Point3D.create(0, 0, 0) , '', '', adsk.core.Point3D.create(E1/2, D1/2, 0), E_param, D_param)
    ext_body = top_body_sketch.profiles.item(0)
    top_body = fusion_model.create_extrude(root_comp,ext_body, '-(param_A - param_b/2 + ((sign(param_b - ' + (addin_utility.format_internal_to_default_unit(root_comp, 0.015)) +')) * 1 ) * (param_b/2 -' + (addin_utility.format_internal_to_default_unit(root_comp, 0.01)) + ') ) * 1/3', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    top_body.name = 'TopBody'
   
    # assign the pysical material to body.
    addin_utility.apply_material(app, design, top_body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)

    #Draw pin1 mark
    mark_radius = b/2
    extrudes = root_comp.features.extrudeFeatures
    pinOneMarkPlaneYZ = addin_utility.create_offset_plane(root_comp,root_comp.yZConstructionPlane, '-param_E/2 + param_b')
    pinOneMarkPlaneYZ.name = 'Pinonemarkplaneyz'
    pin_one_mark_sketch = sketches.add(pinOneMarkPlaneYZ)
    pin_one_mark_sketch.name = 'SketchPinOneMark'

    mark_center = adsk.core.Point3D.create(0, D/2 - b, A*0.9)
    sketch_points = pin_one_mark_sketch.sketchPoints
    sk_center = sketch_points.add(mark_center)
    sketch_mark = pin_one_mark_sketch.sketchCurves.sketchCircles.addByCenterRadius(sk_center, mark_radius)
     
    sketch_prof = adsk.core.ObjectCollection.create()
    sketch_prof.add(sketch_mark)
    # Create a move feature
    transform = adsk.core.Matrix3D.create()
    transform.setToRotation(-math.pi/2, adsk.core.Vector3D.create(0,1,0), adsk.core.Point3D.create(0,0,0))
    pin_one_mark_sketch.move(sketch_prof, transform)
    
    marking_face = top_body.startFaces[0]
    prof = pin_one_mark_sketch.profiles[0]
    extrudeInput = extrudes.createInput(prof, adsk.fusion.FeatureOperations.CutFeatureOperation)
    isChained = False
    extent_toentity = adsk.fusion.ToEntityExtentDefinition.create(marking_face, isChained)
    extrudeInput.setOneSideExtent(extent_toentity, adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrudes.add(extrudeInput)
    pin_one_mark_sketch.sketchDimensions.addRadialDimension(pin_one_mark_sketch.sketchCurves[0],
                                                     fusion_sketch.get_dimension_text_point(pin_one_mark_sketch.sketchCurves[0])).parameter.expression = 'param_b/2'
    pin_one_mark_sketch.sketchDimensions.addDistanceDimension(sk_center, pin_one_mark_sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     fusion_sketch.get_dimension_text_point(sk_center)).parameter.expression = 'param_A*0.9'
    pin_one_mark_sketch.sketchDimensions.addDistanceDimension(sk_center, pin_one_mark_sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     fusion_sketch.get_dimension_text_point(sk_center)).parameter.expression = 'param_D/2 - param_b'


    #Draw mid body
    mid_body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A -(param_A - param_b/2 + ((sign(param_b - ' + (addin_utility.format_internal_to_default_unit(root_comp, 0.015)) +')) * 1 ) * (param_b/2 -' + (addin_utility.format_internal_to_default_unit(root_comp, 0.01)) + ') ) * 1/3')
    mid_body_offset.name = 'MidBodyOffset'
    mid_body_sketch = sketches.add(mid_body_offset)
    fusion_sketch.create_center_point_rectangle(mid_body_sketch,adsk.core.Point3D.create(0, 0, 0) , '', '', adsk.core.Point3D.create(E/2, D/2, 0), 'param_E ', 'param_D ')
    ext_body = mid_body_sketch.profiles.item(0)
    mid_body = fusion_model.create_extrude(root_comp, ext_body, '-(param_A - param_b/2 + ((sign(param_b - ' + (addin_utility.format_internal_to_default_unit(root_comp, 0.015)) +')) * 1 ) * (param_b/2 -' + (addin_utility.format_internal_to_default_unit(root_comp, 0.01)) + ') ) * 2/3', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    mid_body.name = 'MidBody'

    # assign the pysical material to body.
    addin_utility.apply_material(app, design, mid_body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)
    # assign the apparance to body
    addin_utility.apply_rgb_appearance(app, design, mid_body.bodies.item(0), 0, 77, 26, constant.COLOR_NAME_BGA_MID_BODY)


    #Draw balls
    terminal_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_b/2 ')
    terminal_offset.name = 'TerminalOffset'
    terminal_sketch = sketches.add(terminal_offset)
    terminal_sketch.name ='TerminalSketch'
    fusion_sketch.create_center_point_circle(terminal_sketch,adsk.core.Point3D.create(paddingE , paddingD , 0), '((param_EPins - 1) * param_e) / 2', '((param_DPins - 1) * param_d) / 2', b, 'param_b')
    lines = terminal_sketch.sketchCurves.sketchLines
    constraints = terminal_sketch.geometricConstraints
    line1 = lines.addByTwoPoints( adsk.core.Point3D.create(0, 0, 0) ,adsk.core.Point3D.create(paddingE + b/2 , 0, 0))
    line1.isConstruction = True
    line1.startSketchPoint.isFixed = True
    constraints.addHorizontal(line1)

    terminal_sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(E/2, 0, 0)).parameter.expression = '(param_EPins - 1) * param_e  / 2 + param_b/2 '

    line2 = lines.addByTwoPoints( line1.endSketchPoint,adsk.core.Point3D.create(paddingE + b/2, paddingD , 0))
    line2.isConstruction = True
    constraints.addVertical(line2)

    terminal_sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(E/2, D/2, 0)).parameter.expression = '(param_DPins - 1) * param_d  / 2'

    axisLine = lines.addByTwoPoints(line2.endSketchPoint, adsk.core.Point3D.create(paddingE -b/2 , paddingD , 0))
    constraints.addHorizontal(axisLine)
 
    terminal_sketch.sketchDimensions.addDistanceDimension(axisLine.startSketchPoint, axisLine.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(E/2, D/2, 0)).parameter.expression = 'param_b'

    ext_term = terminal_sketch.profiles.item(0)
    # Create an revolution input
    revolves = root_comp.features.revolveFeatures
    rev_input = revolves.createInput(ext_term, axisLine, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    angle = adsk.core.ValueInput.createByReal(2 * math.pi)
    rev_input.setAngleExtent(False, angle)
    ext_rev = revolves.add(rev_input)
    # assign pysical material to terminal
    addin_utility.apply_material(app, design, ext_rev.bodies.item(0), constant.MATERIAL_ID_LEAD_SOLDER)

    pattern_pins = fusion_model.create_two_direction_pattern(root_comp, ext_rev, '-param_e', 'param_EPins', root_comp.xConstructionAxis, '-param_d', 'param_DPins', root_comp.yConstructionAxis)
    pattern_pins.name = 'PinPattern'


from .base import package_3d_model_base

class Bga3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "bga"

    def create_model(self, params, design, component):
        bga(params, design, component)

package_3d_model_base.factory.register_package(Bga3DModel.type(), Bga3DModel) 

def run(context):
    ui = app.userInterface
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    bga(params, design, target_comp)
