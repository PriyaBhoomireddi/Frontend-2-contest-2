import adsk.core,traceback, adsk.fusion, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

def create_fillet(root_comp, ext, distance):
    fillets = root_comp.features.filletFeatures
    edgeBottom = adsk.core.ObjectCollection.create()
    bottomEdges = ext.bodies.item(0).faces.item(2).edges
    for edgeI  in bottomEdges:
         edgeBottom.add(edgeI)

    radius1 = adsk.core.ValueInput.createByReal(distance)
    input2 = fillets.createInput()
    input2.addConstantRadiusEdgeSet(edgeBottom, radius1, True)
    input2.isG2 = False
    input2.isRollingBallCorner = True
    fillet2 = fillets.add(input2)

def ecap(params, design = None, target_comp = None):

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    A = params.get('A') or 1.05  #Body height(A)
    D1 = params.get('D1') or 1.05 #Body length(D1)
    b = params.get('b') or 0.11 #Terminal width(b)
    #D = params.get('D') or 1.22 #Terminal Span(D)
    D2 = params.get('D2') or 0.48 #Terminal gap(D2)
    L = params.get('L') or 0.37 #Termoinal length(L)

    A1 = A/8
    c = b/4

    is_update = False
    is_update = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_D1', D1, default_unit, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("BodyWidth", "body width"))
    #is_update = addin_utility.process_user_param(design, 'param_D', D, default_unit, 'terminal width')
    is_update = addin_utility.process_user_param(design, 'param_D2', D2, default_unit, _LCLZ("TerminalGap", "terminal gap"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, '')
    # the paramters are already there, just update the models with the paramters. will skip the model creation process.
    if is_update: return

    #Create body
    sketches = root_comp.sketches
    bottom_body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_b/8')
    bottom_body_offset.name = 'BottomBodyOffset'
    bottom_body_sketch = sketches.add(bottom_body_offset)
    fusion_sketch.create_center_point_rectangle(bottom_body_sketch,adsk.core.Point3D.create(0, 0, 0) , '', '',  adsk.core.Point3D.create(D1/2, D1/2, 0), 'param_D1', 'param_D1')

    lines = bottom_body_sketch.sketchCurves.sketchLines
    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(-D1/2, 0, 0))
    constraints = bottom_body_sketch.geometricConstraints
    line1.startSketchPoint.isfixed = True
    line1.isConstruction = True
    constraints.addCoincident(line1.startSketchPoint, bottom_body_sketch.originPoint)

    bottom_body_sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(-D1/4, 0, 0)).parameter.expression = 'param_D1/2 '

    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(-D1/2, D1/4, 0))

    bottom_body_sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(-D1/2, D1/4, 0)).parameter.expression = 'param_D1/4'
    line2.isConstruction = True

    line3 = lines.addByTwoPoints(line1.startSketchPoint, adsk.core.Point3D.create(0, D1/2, 0))

    bottom_body_sketch.sketchDimensions.addDistanceDimension(line3.startSketchPoint, line3.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(0, D1/4, 0)).parameter.expression = 'param_D1/2'
    line3.isConstruction = True

    line4 = lines.addByTwoPoints(line3.endSketchPoint, adsk.core.Point3D.create(-D1/4, D1/2, 0))

    bottom_body_sketch.sketchDimensions.addDistanceDimension(line4.startSketchPoint, line4.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                        adsk.core.Point3D.create(-D1/4, D1/2, 0)).parameter.expression = 'param_D1/4'

    constraints.addHorizontal(line1)
    constraints.addVertical(line2)
    constraints.addVertical(line3)
    constraints.addHorizontal(line4)

    Line1 = lines.addByTwoPoints(line2.endSketchPoint, line4.endSketchPoint)

    line5 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(-D1/2, -D1/4, 0))

    bottom_body_sketch.sketchDimensions.addDistanceDimension(line5.startSketchPoint, line5.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(-D1/2, -D1/4, 0)).parameter.expression = 'param_D1/4'
    line5.isConstruction = True

    line6 = lines.addByTwoPoints(line1.startSketchPoint, adsk.core.Point3D.create(0, -D1/2, 0))

    bottom_body_sketch.sketchDimensions.addDistanceDimension(line6.startSketchPoint, line6.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(0, -D1/4, 0)).parameter.expression = 'param_D1/2'
    line6.isConstruction = True

    line7 = lines.addByTwoPoints(line6.endSketchPoint, adsk.core.Point3D.create(-D1/4, -D1/2, 0))

    bottom_body_sketch.sketchDimensions.addDistanceDimension(line7.startSketchPoint, line7.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                        adsk.core.Point3D.create(-D1/4, -D1/2, 0)).parameter.expression = 'param_D1/4'

    constraints.addVertical(line5)
    constraints.addVertical(line6)
    constraints.addHorizontal(line7)

    Line2 = lines.addByTwoPoints(line5.endSketchPoint, line7.endSketchPoint)

    ext_low_body = bottom_body_sketch.profiles.item(1)
    lower_body = fusion_model.create_extrude(root_comp,ext_low_body, 'param_A/8', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    lower_body.name = 'LowerBody'
     # assign the pysical material and appearance to body
    addin_utility.apply_material(app, design, lower_body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)
    addin_utility.apply_appearance(app, design, lower_body.bodies.item(0), constant.APPEARANCE_ID_BODY_DEFAULT)


    #Create Terminals
    xyPlane = root_comp.xYConstructionPlane
    pin_sketch = sketches.add(xyPlane)
    fusion_sketch.create_center_point_rectangle(pin_sketch, adsk.core.Point3D.create(D2/2 + L/2, 0, 0),'param_D2/2 + param_L/2','', adsk.core.Point3D.create(D2/2 + L, b/2, 0), 'param_L', 'param_b')
    ext_ter = pin_sketch.profiles.item(0)
    terminal = fusion_model.create_extrude(root_comp,ext_ter, 'param_b/4', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal.name = 'Terminal'
    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, terminal.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    fusion_model.create_mirror(root_comp, terminal, root_comp.yZConstructionPlane)

    #Create upper body
    sketches = root_comp.sketches
    xzPlane = root_comp.xZConstructionPlane
    body_sketch = sketches.add(xzPlane)

    rect = fusion_sketch.create_center_point_rectangle(body_sketch, adsk.core.Point3D.create(D1/4, -A/2, 0), 'param_D1/4', '( param_A - ( param_b / 8 + param_A / 8 ) ) / 2 + param_b / 8 + param_A / 8',
                                                 adsk.core.Point3D.create(D1/2, -A , 0), 'param_D1/2', 'param_A - (param_b/8 + param_A/8)')

    circle = fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create(D1/2, -A/4 - b/8, 0),'param_D1/2', 'param_A/4 + param_b/8',  D1/10, 'param_D1/10')
    circle.trim(adsk.core.Point3D.create(D1, 0, 0))
    #Revolving the body
    body_prof = body_sketch.profiles.item(1)
    revolves = root_comp.features.revolveFeatures
    rev_input = revolves.createInput(body_prof, rect.item(1), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    angle = adsk.core.ValueInput.createByReal(math.pi * 2)
    rev_input.setAngleExtent(False, angle)
    ext_body = revolves.add(rev_input)

    # assign the pysical material to body.
    addin_utility.apply_material(app, design, ext_body.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)

    create_fillet(root_comp, ext_body, 0.03)

    #Draw top marker
    marker_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    marker_offset.name = 'MarkerOffset'
    sketch_marker = sketches.add(marker_offset)
    constraints = sketch_marker.geometricConstraints
    fusion_sketch.create_center_point_circle(sketch_marker,adsk.core.Point3D.create(0, 0, 0), '', '', D1 - 0.06, '( param_D1 - ' + (addin_utility.format_internal_to_default_unit(root_comp, 0.06)) + ')')
    lines = sketch_marker.sketchCurves.sketchLines
    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create((D1/2 - 0.03) * 0.055, 0, 0))
    constraints = sketch_marker.geometricConstraints
    line1.startSketchPoint.isfixed = True
    line1.isConstruction = True
    constraints.addCoincident(line1.startSketchPoint, sketch_marker.originPoint)

    sketch_marker.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(D1/4, 0, 0)).parameter.expression = '( (0.55 * param_D1/2) - ' +  (addin_utility.format_internal_to_default_unit(root_comp, 0.03)) + ') '

    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create((D1/2 - 0.03) * 0.055, D1/2, 0))

    sketch_marker.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(D1/4, D1/4, 0)).parameter.expression = 'param_D1/2'

    line3 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create((D1/2 - 0.03) * 0.055, -D1/2, 0))
 
    sketch_marker.sketchDimensions.addDistanceDimension(line3.startSketchPoint, line3.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(D1/4, -D1/4, 0)).parameter.expression = 'param_D1/2'

    constraints.addHorizontal(line1)
    constraints.addVertical(line2)
    constraints.addVertical(line3)

    ext_marker = sketch_marker.profiles.item(1)
    marker = fusion_model.create_extrude(root_comp,ext_marker, (addin_utility.format_internal_to_default_unit(root_comp, 0.001)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    marker.name = 'Marker'
    addin_utility.apply_appearance(app, design, marker.bodies.item(0), constant.APPEARANCE_ID_BODY_DEFAULT)

from .base import package_3d_model_base

class Ecap3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "ecap"

    def create_model(self, params, design, component):
        ecap(params, design, component)

package_3d_model_base.factory.register_package(Ecap3DModel.type(), Ecap3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    ecap(params, design, target_comp)
