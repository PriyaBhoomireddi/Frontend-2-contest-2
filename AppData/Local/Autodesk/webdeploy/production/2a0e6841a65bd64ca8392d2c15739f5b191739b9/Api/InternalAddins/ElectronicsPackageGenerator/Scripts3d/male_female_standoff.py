import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()


def male_female_standoff(params, design = None, targetComponent = None):
    A = params.get('A') or 1 # body Height
    E = params.get('E') or 0.5 #body Width
    L = params.get('L') or 0.2 #inner thread length
    L1 = params.get('L1') or 0.8 #post thread length
    body_shape = params.get('body') or 'hex'
    inner_thread_type = params.get('innerThreadType') or 'ISO Metric profile'
    inner_thread_designation = params.get('innerThreadDesignation') or 'M2.5x0.45'
    inner_thread_class = params.get('innerThreadClass') or '6H'
    post_thread_type = params.get('postThreadType') or 'ISO Metric profile'
    post_thread_designation = params.get('postThreadDesignation') or 'M2.6x0.45'
    post_thread_class = params.get('postThreadClass') or '6g'

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design.
    root_comp = design.rootComponent
    
    if targetComponent:
        root_comp = targetComponent

    threads = root_comp.features.threadFeatures

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits
    is_update = False
    is_update = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("InnerThreadLength", "inner thread length"))
    is_update = addin_utility.process_user_param(design, 'param_L1', L1, default_unit, _LCLZ("PostThreadLength", "post thread length"))
    # the paramters are already there, just update the models with the paramters. will skip the model creation process. 
    if is_update:
        inner_thread = root_comp.features.itemByName('InnerThread')
        post_thread = root_comp.features.itemByName('PostThread')
        body = root_comp.features.itemByName('Body')

        body.timelineObject.rollTo(True)
        if body_shape == 'hex':
            sketch = root_comp.sketches.itemByName('SketchHexBody')
        elif body_shape == 'round':
            sketch = root_comp.sketches.itemByName('SketchRoundBody')
        elif body_shape == 'square':
            sketch = root_comp.sketches.itemByName('SketchSquareBody')

        prof = sketch.profiles[0]
        body.profile = prof
        design.timeline.moveToEnd()
        #get and set threadInfo
        inner_thread.timelineObject.rollTo(True)
        thread_info = inner_thread.threadInfo
        thread_info = threads.createThreadInfo(True, inner_thread_type, inner_thread_designation, inner_thread_class)
        inner_thread.threadInfo = thread_info
        for param in root_comp.modelParameters:
            if param.role=="ThreadLength":
                if param.createdBy.name=="InnerThread":
                    param.expression = 'param_L'
        design.timeline.moveToEnd()

        post_thread.timelineObject.rollTo(True)
        post_thread_info = post_thread.threadInfo
        post_thread_info = threads.createThreadInfo(False, post_thread_type, post_thread_designation, post_thread_class)
        post_thread.threadInfo = post_thread_info
        for param in root_comp.modelParameters:
            if param.role=="ThreadLength":
                if param.createdBy.name=="PostThread":
                    param.expression = 'param_L1'
        design.timeline.moveToEnd()
            
        return

    # Create a new sketch.
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    sketch_hex_body = sketches.add(xyPlane)
    sketch_hex_body.name = 'SketchHexBody'
    sketch_hex_body.isLightBulbOn = False
    sketch_round_body = sketches.add(xyPlane)
    sketch_round_body.name = 'SketchRoundBody'
    sketch_round_body.isLightBulbOn = False
    sketch_square_body = sketches.add(xyPlane)
    sketch_square_body.name = 'SketchSquareBody'
    sketch_square_body.isLightBulbOn = False
    sketch_post_body = sketches.add(xyPlane)
    sketch_post_body.name = 'SketchPostBody'
    # hex body
    center = adsk.core.Point3D.create(0, 0, 0)
    hex_radius = E/math.sqrt(3)
    vertices = []
    constraints = sketch_hex_body.geometricConstraints
    for i in range(0, 6):
        vertex = adsk.core.Point3D.create(center.x + (hex_radius) * math.cos(math.pi * i / 3), center.y + (hex_radius) * math.sin(math.pi * i / 3),0)
        vertices.append(vertex)
    for i in range(0, 6):
        if i ==0:
            line0 = sketch_hex_body.sketchCurves.sketchLines.addByTwoPoints( vertices[i], vertices[(i+1) %5])
        elif i!= 5:
            sketch_hex_body.sketchCurves.sketchLines.addByTwoPoints(sketch_hex_body.sketchCurves.sketchLines[i-1].endSketchPoint, vertices[i+1 %5])
            constraints.addEqual(sketch_hex_body.sketchCurves.sketchLines[i-1], sketch_hex_body.sketchCurves.sketchLines[i])
        elif i == 5:
            sketch_hex_body.sketchCurves.sketchLines.addByTwoPoints(sketch_hex_body.sketchCurves.sketchLines[4].endSketchPoint, sketch_hex_body.sketchCurves.sketchLines[0].startSketchPoint)
            constraints.addEqual(sketch_hex_body.sketchCurves.sketchLines[i-1], sketch_hex_body.sketchCurves.sketchLines[i])
        
    sketchpoints = sketch_hex_body.sketchPoints
    center_point = adsk.core.Point3D.create(0,0,0)
    sk_center = sketchpoints.add(center_point)   
    sk_center.isFixed = True
    end_point = sketch_hex_body.sketchCurves.sketchLines[0].endSketchPoint  

    mid_point = adsk.core.Point3D.create(0,end_point.geometry.y,0)
    mid_point1 = adsk.core.Point3D.create(0,-(end_point.geometry.y),0)

    hexagon_r = sketch_hex_body.sketchCurves.sketchLines.addByTwoPoints(sk_center, mid_point)
    hexagon_r.isConstruction = True
    hexagon_r.isFixed = True
    hexagon_r1 = sketch_hex_body.sketchCurves.sketchLines.addByTwoPoints(sk_center, mid_point1)
    hexagon_r1.isConstruction = True
    hexagon_r1.isFixed = True
    constraints.addEqual(hexagon_r, hexagon_r1)
    constraints.addMidPoint(hexagon_r.endSketchPoint, sketch_hex_body.sketchCurves.sketchLines[1])
    constraints.addMidPoint(hexagon_r1.endSketchPoint, sketch_hex_body.sketchCurves.sketchLines[4])
    sketch_hex_body.sketchDimensions.addDistanceDimension(hexagon_r.endSketchPoint, sk_center,
                                            adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                            adsk.core.Point3D.create(1, 0, 0)).parameter.expression = 'param_E/2'

    # round body
    sketch_round_body.sketchCurves.sketchCircles.addByCenterRadius(center, E/2)

    sketch_round_body.sketchDimensions.addRadialDimension(sketch_round_body.sketchCurves[0],
                                                adsk.core.Point3D.create(0.1, 0, 0)).parameter.expression = 'param_E/2'

    # square body    
    center_point = adsk.core.Point3D.create(0,0,0)
    end_point = adsk.core.Point3D.create(E/2,E/2,0)
    fusion_sketch.create_center_point_rectangle(sketch_square_body, center_point, '', '', end_point, 'param_E', 'param_E')

    if body_shape == 'hex':
        sketch = root_comp.sketches.itemByName('SketchHexBody')
    elif body_shape == 'round':
        sketch = root_comp.sketches.itemByName('SketchRoundBody')
    elif body_shape == 'square':
        sketch = root_comp.sketches.itemByName('SketchSquareBody')

    body_profile = sketch.profiles[0]
    
    extrudes = root_comp.features.extrudeFeatures
    ext_input = extrudes.createInput(body_profile, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_input.setDistanceExtent(False, adsk.core.ValueInput.createByString('param_A'))
    body = extrudes.add(ext_input)
    body.name = 'Body'
    # assign the pysical material to body.
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BRASS)
    # Get the end face of the extrusion
    end_faces = body.endFaces
    end_face = end_faces.item(0)

    # Create a construction plane by offsetting the end face to add hole on top side of body.
    planes = root_comp.constructionPlanes
    plane_input = planes.createInput()
    plane_input.setByOffset(end_face, adsk.core.ValueInput.createByString('0 cm'))
    offset_plane = planes.add(plane_input)
    offset_sketch = sketches.add(offset_plane)
    offset_sketch_points = offset_sketch.sketchPoints
    center_point = offset_sketch_points.add(adsk.core.Point3D.create(0, 0, 0))
    hole_center = adsk.core.ObjectCollection.create()
    hole_center.add(center_point)

    #get hole size from thread input
    thread_info = threads.createThreadInfo(True, inner_thread_type, inner_thread_designation, inner_thread_class)
    post_thread_info = threads.createThreadInfo(False, post_thread_type, post_thread_designation, post_thread_class)
    # Create a hole input
    holes = root_comp.features.holeFeatures
    hole_diameter = thread_info.threadSize
    post_diameter = post_thread_info.threadSize

    hole_input = holes.createSimpleInput(adsk.core.ValueInput.createByReal(float(hole_diameter)/10))
    hole_input.setPositionBySketchPoints(hole_center)
    hole_input.setDistanceExtent(adsk.core.ValueInput.createByString('param_L+' + (addin_utility.format_internal_to_default_unit(root_comp, 0.001))))
    hole_input.tipAngle = adsk.core.ValueInput.createByString('180 deg')
    hole = holes.add(hole_input)
    body = hole.bodies.item(0)
    side_face = body.faces.item(0)
    
    inner_thread = fusion_model.apply_thread(root_comp, side_face, False, thread_info, 'param_L')
    inner_thread.name = 'InnerThread'
    #create sketch for post and apply threads
    sketch_post_body.sketchCurves.sketchCircles.addByCenterRadius(center, float(post_diameter)/20)

    sketch_post_body.sketchDimensions.addRadialDimension(sketch_post_body.sketchCurves[0],
                                                adsk.core.Point3D.create(0.1, 0, 0)).parameter.value = float(post_diameter)/20
    post_profile = sketch_post_body.profiles[0]
    ext_input = extrudes.createInput(post_profile, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_input.setDistanceExtent(False, adsk.core.ValueInput.createByString('-param_L1' ))
    post = extrudes.add(ext_input)
    post.name = 'Post'
    # assign the pysical material to body.
    addin_utility.apply_material(app, design, post.bodies.item(0), constant.MATERIAL_ID_BRASS)
    side_face = post.sideFaces[0]
    post_thread = fusion_model.apply_thread(root_comp, side_face, False, post_thread_info, 'param_L1')   
    post_thread.name = 'PostThread'


from .base import package_3d_model_base

class MaleFemaleStandoff3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "male_female_standoff"

    def create_model(self, params, design, component):
        male_female_standoff(params, design, component)

package_3d_model_base.factory.register_package(MaleFemaleStandoff3DModel.type(), MaleFemaleStandoff3DModel) 

def run(context):
    ui = app.userInterface
    
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    male_female_standoff(params, design, targetComponent)