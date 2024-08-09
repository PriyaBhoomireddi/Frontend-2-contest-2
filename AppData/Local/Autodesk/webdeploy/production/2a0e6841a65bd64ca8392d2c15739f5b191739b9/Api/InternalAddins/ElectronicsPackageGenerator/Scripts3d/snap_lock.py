import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

        
def snap_lock(params, design = None, target_comp = None):

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp
    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    A = params.get('A') or 0.8128 #body height
    A1 = params.get('A1') or 0.16 #board thickness
    E = params.get('E') or 0.46 #Body diameter
    E1 = params.get('E1') or 0.38 #lock diameter
    L1 = params.get('L1') or 0.2 #lock height
    b = params.get('H') or 0.318 #mouting hole diameter

    isUpdate = False
    isUpdate = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    isUpdate = addin_utility.process_user_param(design, 'param_A1', A1, default_unit, _LCLZ("BoardThickness", "board thickness"))
    isUpdate = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("BodyDiameter", "body diameter"))
    isUpdate = addin_utility.process_user_param(design, 'param_E1', E1, default_unit, _LCLZ("LockDiameter", "lock diameter"))
    isUpdate = addin_utility.process_user_param(design, 'param_L1', L1, default_unit, _LCLZ("LockHeight", "lock height"))
    isUpdate = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("MountingHoleDiameter", "mounting hole diameter"))
    if isUpdate: return

    # Create a new sketch on the xy plane.
    sketches = root_comp.sketches
    body_sketch = sketches.add(root_comp.yZConstructionPlane)

    body_sketch.isComputeDeferred = True
    lines = body_sketch.sketchCurves.sketchLines
    constraints = body_sketch.geometricConstraints

    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(0,  b/2, 0), adsk.core.Point3D.create(0, E/2, 0))
    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(-A, E/2, 0))
    line3 = lines.addByTwoPoints(line2.endSketchPoint, adsk.core.Point3D.create(-A, b/2, 0))
    line4 = lines.addByTwoPoints(line3.endSketchPoint, adsk.core.Point3D.create(-A - A1, b/2, 0))
    line5 = lines.addByTwoPoints(line4.endSketchPoint, adsk.core.Point3D.create(-A - A1, E1/2, 0))
    line6 = lines.addByTwoPoints(line5.endSketchPoint, adsk.core.Point3D.create(-A - A1 -L1/5, E1/2, 0))
    
    axis_line = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(-A - A1 -L1, 0, 0)) 
    line7 = lines.addByTwoPoints(axis_line.endSketchPoint, adsk.core.Point3D.create(-A - A1 -L1, b/2, 0))

    line8 = lines.addByTwoPoints(line7.endSketchPoint, line6.endSketchPoint)

    line9 = lines.addByTwoPoints(line1.startSketchPoint, adsk.core.Point3D.create(A1, b/2, 0))
    line10 = lines.addByTwoPoints(line9.endSketchPoint, adsk.core.Point3D.create(A1, E1/2, 0))
    line11 = lines.addByTwoPoints(line10.endSketchPoint, adsk.core.Point3D.create(A1 + L1/5, E1/2, 0))
    line12 = lines.addByTwoPoints(axis_line.startSketchPoint, adsk.core.Point3D.create(A1 + L1, 0, 0))
    line13 = lines.addByTwoPoints(line12.endSketchPoint, adsk.core.Point3D.create(A1 + L1, b/2, 0))
    line14 = lines.addByTwoPoints(line11.endSketchPoint, line13.endSketchPoint)

    #To make sketch fully constrained 
    const_line = lines.addByTwoPoints(axis_line.startSketchPoint, line1.endSketchPoint)
    const_line.isConstruction = True

    #Applying constraints
    axis_line.startSketchPoint.isFixed = True
    
    constraints.addHorizontal(line2)
    constraints.addHorizontal(line4)
    constraints.addHorizontal(line6)
    constraints.addHorizontal(axis_line)
    constraints.addHorizontal(line12)
    constraints.addHorizontal(line9)
    constraints.addHorizontal(line11)

    constraints.addVertical(line1)
    constraints.addVertical(line3)
    constraints.addVertical(line5)
    constraints.addVertical(line7)
    constraints.addVertical(line10)
    constraints.addVertical(line13)
    constraints.addVertical(const_line)

    body_sketch.sketchDimensions.addDistanceDimension(axis_line.startSketchPoint, axis_line.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(-A/2, 0, 0)).parameter.expression = 'param_A + param_A1 + param_L1'
    body_sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(0, E/2, 0)).parameter.expression = 'abs(param_E - param_b)/2'                                                 
    body_sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(-A/2, E/2, 0)).parameter.expression = 'param_A'
    body_sketch.sketchDimensions.addDistanceDimension(line3.startSketchPoint, line3.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(-A, E/2, 0)).parameter.expression = 'abs(param_E - param_b)/2'     
    body_sketch.sketchDimensions.addDistanceDimension(line4.startSketchPoint, line4.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(-A - A1/2, b/2, 0)).parameter.expression = 'param_A1'
    body_sketch.sketchDimensions.addDistanceDimension(line5.startSketchPoint, line5.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(-A - A1, b/2, 0)).parameter.expression = 'abs(param_E1 - param_b)/2'   
    body_sketch.sketchDimensions.addDistanceDimension(line6.startSketchPoint, line6.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(-A - A1 -L1/5, b/2, 0)).parameter.expression = 'param_L1/5'
    body_sketch.sketchDimensions.addDistanceDimension(line7.startSketchPoint, line7.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(-A - A1 - L1, E/4, 0)).parameter.expression = 'param_b/2' 
    body_sketch.sketchDimensions.addDistanceDimension(line9.startSketchPoint, line9.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(A1/2, b/2, 0)).parameter.expression = 'param_A1'
    body_sketch.sketchDimensions.addDistanceDimension(line10.startSketchPoint, line10.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(A1, b/2, 0)).parameter.expression = 'abs(param_E1 - param_b)/2'   
    body_sketch.sketchDimensions.addDistanceDimension(line11.startSketchPoint, line11.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(A1 + L1/5, b/2, 0)).parameter.expression = 'param_L1/5'
    body_sketch.sketchDimensions.addDistanceDimension(line12.startSketchPoint, line12.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create((A1 + L1)/2, 0, 0)).parameter.expression = 'param_A1 + param_L1'
    body_sketch.sketchDimensions.addDistanceDimension(line13.startSketchPoint, line13.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(A1 + L1, E/4, 0)).parameter.expression = 'param_b/2' 
    body_sketch.sketchDimensions.addDistanceDimension(const_line.startSketchPoint, const_line.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         adsk.core.Point3D.create(0, E/2, 0)).parameter.expression = 'param_E/2' 
    
    #Revolving the body
    body_prof = body_sketch.profiles.item(0)
    revolves = root_comp.features.revolveFeatures
    rev_input = revolves.createInput(body_prof, axis_line, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    angle = adsk.core.ValueInput.createByReal(math.pi * 2)
    rev_input.setAngleExtent(False, angle)
    ext_body = revolves.add(rev_input)

    addin_utility.apply_material(app, design, ext_body.bodies.item(0), constant.MATERIAL_ID_NYLON)

    #Create gap space
    gap_sketch = sketches.add(root_comp.xZConstructionPlane)
    gap = fusion_sketch.create_center_point_rectangle(gap_sketch, adsk.core.Point3D.create(0, -A - (A1 + L1)/2, 0), '', 'param_A + (param_A1 + param_L1)/2',  
                                                        adsk.core.Point3D.create(b/6, -A - A1 - L1, 0) , 'param_b/3', 'param_A1 + param_L1',)
    fusion_sketch.create_center_point_circle(gap_sketch, adsk.core.Point3D.create(0, -A -b/6, 0),'', 'param_A + param_b/6',  b/3, 'param_b/3')

    fusion_sketch.create_center_point_rectangle(gap_sketch, adsk.core.Point3D.create(0, (A1 + L1)/2, 0), '', '(param_A1 + param_L1)/2',  
                                                        adsk.core.Point3D.create(b/6, A1 + L1, 0) , 'param_b/3', 'param_A1 + param_L1')
    fusion_sketch.create_center_point_circle(gap_sketch, adsk.core.Point3D.create(0, b/6, 0),'', 'param_b/6',  b/3, 'param_b/3')


    ext_gap = adsk.core.ObjectCollection.create()
    ext_gap.add(gap_sketch.profiles.item(0))
    ext_gap.add(gap_sketch.profiles.item(2))
    ext_gap.add(gap_sketch.profiles.item(5))
    ext_gap.add(gap_sketch.profiles.item(6))

    #cut gap space
    extrudes = root_comp.features.extrudeFeatures
    ext_input = extrudes.createInput(ext_gap, adsk.fusion.FeatureOperations.CutFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_E1 + param_b')
    deg0 = adsk.core.ValueInput.createByString("0 deg")
    ext_input.setSymmetricExtent(distance, True, deg0)
    cut = extrudes.add(ext_input)
    cut.name = 'GapExtrude'


from .base import package_3d_model_base

class SnapLock3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "snap_lock"

    def create_model(self, params, design, component):
        snap_lock(params, design, component)

package_3d_model_base.factory.register_package(SnapLock3DModel.type(), SnapLock3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    snap_lock(params, design, target_comp)