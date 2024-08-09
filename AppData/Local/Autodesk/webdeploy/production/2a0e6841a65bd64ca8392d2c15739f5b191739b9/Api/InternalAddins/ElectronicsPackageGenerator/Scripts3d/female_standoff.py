import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

def female_standoff(params, design = None, targetComponent = None):
    A = params.get('A') or 1 # body_height
    E = params.get('E') or 0.5 #bodyWidth
    L = params.get('L') or 0.2 #partial thread length
    b = params.get('b') or 0.2 # non threaded hole
    body_shape = params.get('body') or 'hex'
    thread_type = params.get('threadType') or 'ISO Metric profile'
    thread_designation = params.get('threadDesignation') or 'M3.5x0.6'
    thread_class = params.get('threadClass') or '6H'
    thread = params['thread'] if 'thread' in params else 0 #thread
    partial = params['partial'] if 'partial' in params else 0 #partial thread

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
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("PartialThreadLength", "partial thread length"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("NonThreadedHoleDiameter", "non threaded hole diameter"))
    # the paramters are already there, just update the models with the paramters. will skip the model creation process. 
    if is_update:
        
        partial_thread = root_comp.features.itemByName('PartialThread')
        top_thread = root_comp.features.itemByName('TopThread')
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

        if not thread:
            for param in root_comp.modelParameters:
                if param.role=="HoleDepth":
                    param.expression = 'param_A'
                if param.role=="AlongDistance":    
                    if param.createdBy.name=="Body":
                        param.expression = 'param_A'
            top_thread.isSuppressed = True
 

        if thread:
            top_thread.isSuppressed = False
            
            #supress mirrored partial thread before increasing/seting fully threaded.    
            if not partial: 
                partial_thread.isSuppressed = True

            for param in root_comp.modelParameters:
                if param.role =="HoleDepth":
                    param.expression = not partial and 'param_A' or 'param_L+' + (addin_utility.format_internal_to_default_unit(root_comp, 0.001))
                elif param.role == "ThreadLength":
                    param.expression = not partial and 'param_A' or 'param_L'
                elif param.role=="AlongDistance":    
                    if param.createdBy.name=="Body":
                        param.expression = 'param_A'

            #after adjusting thread length mirror it for partial thread.
            if partial: 
                partial_thread.isSuppressed = False  

            #update thread size.
            top_thread.timelineObject.rollTo(True)
            thread_info = top_thread.threadInfo
            thread_info = threads.createThreadInfo(True, thread_type, thread_designation, thread_class)
            top_thread.threadInfo = thread_info
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
        
    sketch_points = sketch_hex_body.sketchPoints
    center_point = adsk.core.Point3D.create(0,0,0)
    sk_center = sketch_points.add(center_point)   
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
    body_height = adsk.core.ValueInput.createByString('param_A')
    ext_input.setDistanceExtent(False, body_height)
    body = extrudes.add(ext_input)
    body.name = 'Body'
    # assign the pysical material to body.
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BRASS)
    # Get the end face of the extrusion
    end_faces = body.endFaces
    end_face = end_faces.item(0)

    # Create a construction plane by offsetting the end face
    planes = root_comp.constructionPlanes
    plane_input = planes.createInput()
    offset_val = adsk.core.ValueInput.createByString('0 cm')
    plane_input.setByOffset(end_face, offset_val)
    offset_plane = planes.add(plane_input)

    # Create a sketch on the new construction plane and add center point on it
    offset_sketch = sketches.add(offset_plane)
    offset_sketch_points = offset_sketch.sketchPoints
    center_point = offset_sketch_points.add(adsk.core.Point3D.create(0, 0, 0))

    # Add the center point into a collection
    hole_center = adsk.core.ObjectCollection.create()
    hole_center.add(center_point)
    

    # Create a hole input
    holes = root_comp.features.holeFeatures
    hole_input = holes.createSimpleInput(adsk.core.ValueInput.createByString('param_b'))
    hole_input.setPositionBySketchPoints(hole_center)
    hole_input.setDistanceExtent(adsk.core.ValueInput.createByString('param_L+' + (addin_utility.format_internal_to_default_unit(root_comp, 0.001))))
    hole_input.tipAngle = adsk.core.ValueInput.createByString('180 deg')

    hole = holes.add(hole_input)
    body = hole.bodies.item(0)
    side_face = body.faces.item(0)

    #apply threads on internal cylinder face
    thread_info = threads.createThreadInfo(True, thread_type, thread_designation, thread_class)
    top_thread = fusion_model.apply_thread(root_comp, side_face, False, thread_info, 'param_L')     
    top_thread.name = 'TopThread'

    #mirror for partial thread
    mirror_thread = adsk.core.ObjectCollection.create()
    mirror_thread.add(hole)
    mirror_thread.add(top_thread)
    

    # Create a construction plane by offset
    plane_input.setByOffset(root_comp.xYConstructionPlane, adsk.core.ValueInput.createByString('param_A/2'))
    mirror_plane = planes.add(plane_input)
    mirror_plane.name = 'MirrorPlane'
    mirror_plane.isLightBulbOn = False
    mirror_features = root_comp.features.mirrorFeatures
    mirror_input = mirror_features.createInput(mirror_thread, mirror_plane)
    mirror_input.patternComputeOption = 0 #use optimized compute pattern
    partial_thread = mirror_features.add(mirror_input)
    partial_thread.name = 'PartialThread'

    if not thread:
        for param in root_comp.modelParameters:
            if param.role=="HoleDepth":
                param.expression = 'param_A'

        top_thread.isSuppressed = True
        mirror_plane.isSuppressed = True

    if thread and not partial:
        partial_thread.isSuppressed = True

        for param in root_comp.modelParameters:
            if param.role=="HoleDepth":
                param.expression = 'param_A'
            if param.role=="ThreadLength":
                param.expression = 'param_A'
                
from .base import package_3d_model_base

class FemaleStandoff3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "female_standoff"

    def create_model(self, params, design, component):
        female_standoff(params, design, component)

package_3d_model_base.factory.register_package(FemaleStandoff3DModel.type(), FemaleStandoff3DModel) 

def run(context):
    ui = app.userInterface
    
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    female_standoff(params, design, targetComponent)