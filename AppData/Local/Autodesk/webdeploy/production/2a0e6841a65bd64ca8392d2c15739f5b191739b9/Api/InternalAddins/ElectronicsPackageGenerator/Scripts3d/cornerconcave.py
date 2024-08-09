import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ
from .base import package_3d_model_base

app = adsk.core.Application.get()

def get_param(params, name):
    if name in params:
        return params[name]
    else:
        if (name == 'A'):
            return 0.2 #Body Height
        if (name == 'D'):
            return 0.65 #Body Length
        if (name == 'D1'):
            return 0.3 
        if (name == 'E'):
            return 0.4 #Body Width
        if (name == 'E1'):
            return 0.15 
        if (name == 'terminal_thickness'):
            return False

def user_param(design, params, default_unit, root_comp):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    res_2 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_3 = addin_utility.process_user_param(design, 'param_D1', get_param(params, 'D1'), default_unit, _LCLZ("BodyLength", "body length"))
    res_4 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_5 = addin_utility.process_user_param(design, 'param_E1', get_param(params, 'E1'), default_unit, _LCLZ("BodyWidth", "body width"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 
    return isUpdate


def create_lower_body_sketch(root_comp, params, terminal_thickness):
    circleRadius = ((get_param(params, 'D')) - (get_param(params, 'D1')))/10
    # Create lower body
    sketches = root_comp.sketches
    body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, str(terminal_thickness))
    body_offset.name = 'BodyOffset'
    body_sketch = sketches.add(body_offset)
    body_sketch.name = 'BodySketch'
    fusion_sketch.create_center_point_rectangle(body_sketch,adsk.core.Point3D.create(0, 0, 0), '', '', adsk.core.Point3D.create((get_param(params, 'D'))/2, (get_param(params, 'E'))/2, 0), 'param_D', 'param_E')

    circle_top = fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create((get_param(params, 'D'))/2, (get_param(params, 'E'))/2, 0),'param_D/2', 'param_E/2',  circleRadius * 2, '(param_D - param_D1)/5')
    circle_top.trim(adsk.core.Point3D.create((get_param(params, 'D'))/2, (get_param(params, 'E'))/2, 0))

    circle_bottom = fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create((get_param(params, 'D'))/2, -(get_param(params, 'E'))/2, 0) ,'param_D/2', 'param_E/2',  circleRadius * 2, '(param_D - param_D1)/5')
    circle_bottom.trim(adsk.core.Point3D.create((get_param(params, 'D'))/2, -(get_param(params, 'E'))/2, 0))

    circle = fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create(-(get_param(params, 'D'))/2, -(get_param(params, 'E'))/2, 0) ,'param_D/2', 'param_E/2',  circleRadius * 2, '(param_D - param_D1)/5')
    #circle.trim(adsk.core.Point3D.create(-D/2, -E/2, 0))

    circle = fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create(-(get_param(params, 'D'))/2, (get_param(params, 'E'))/2, 0) ,'param_D/2', 'param_E/2',  circleRadius * 2, '(param_D - param_D1)/5')
    #circle.trim(adsk.core.Point3D.create(-D/2, E/2, 0))

    return body_sketch

def create_lower_body(root_comp, params, design, body_sketch, terminal_thickness):
    ext_body = body_sketch.profiles.item(5)
    body = fusion_model.create_extrude(root_comp,ext_body, '0.8 * param_A-' + (addin_utility.format_internal_to_default_unit(root_comp, terminal_thickness)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    body.name = 'Body'
    # assign the pysical material to body.
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)
    # assign the apparance to body
    addin_utility.apply_appearance(app, design, body.bodies.item(0), constant.APPEARANCE_ID_BODY_DEFAULT)
    
    #rendering lower body
    body_side = body.bodies.item(0)
    for face in body_side.faces:
        if face.geometry.objectType == adsk.core.Cylinder.classType():
            addin_utility.apply_appearance(app, design, face, constant.APPEARANCE_ID_GOLD_POLISHED)

def create_upper_body_sketch(root_comp, params):
    #Creating top body
    sketches = root_comp.sketches
    top_body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    top_body_offset.name = 'TopBodyOffset'
    top_body_sketch = sketches.add(top_body_offset)
    top_body_sketch.isComputeDeferred = True
    fusion_sketch.create_center_point_rectangle(top_body_sketch,adsk.core.Point3D.create(0, 0, 0) , '', '',  adsk.core.Point3D.create(0.9 * (get_param(params, 'D'))/2, 0.9 * (get_param(params, 'E'))/2, 0), 'param_D * 0.9', 'param_E *0.9')
    lines = top_body_sketch.sketchCurves.sketchLines
    top_body_sketch.sketchCurves.sketchArcs.addFillet(lines.item(0), lines.item(0).endSketchPoint.geometry, lines.item(1), lines.item(1).startSketchPoint.geometry, 0.02 )
    top_body_sketch.sketchCurves.sketchArcs.addFillet(lines.item(1), lines.item(1).endSketchPoint.geometry, lines.item(2), lines.item(2).startSketchPoint.geometry, 0.02 )
    top_body_sketch.sketchCurves.sketchArcs.addFillet(lines.item(2), lines.item(2).endSketchPoint.geometry, lines.item(3), lines.item(3).startSketchPoint.geometry, 0.02 )
    top_body_sketch.sketchCurves.sketchArcs.addFillet(lines.item(3), lines.item(3).endSketchPoint.geometry, lines.item(0), lines.item(0).startSketchPoint.geometry, 0.02 )
    top_body_sketch.isComputeDeferred = False
    return top_body_sketch

def create_upper_body(root_comp, params, design, body_sketch):
    top_body = body_sketch.profiles.item(0)
    ext_top_body = fusion_model.create_extrude(root_comp,top_body, "-0.2 * param_A", adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    ext_top_body.name = 'TopBody'
    #assign material to top body
    addin_utility.apply_material(app, design, ext_top_body.bodies.item(0),constant.MATERIAL_ID_ALUMINUM)

def create_terminal_sketch(root_comp, params):
    D = get_param(params, 'D')
    D1 = get_param(params, 'D1')
    E = get_param(params, 'E')
    E1 = get_param(params, 'E1')
    circleRadius = (D - D1)/10
    #Creating terminals
    xyPlane = root_comp.xYConstructionPlane
    sketches = root_comp.sketches
    sketch_terminal = sketches.add(xyPlane)
    sketch_terminal.name = 'TerminalSketch'
    fusion_sketch.create_center_point_rectangle(sketch_terminal,adsk.core.Point3D.create(D1/2 + (D - D1)/4, E1/2 + (E - E1)/4, 0), 'param_D1/2 + (param_D - param_D1)/4', 'param_E1/2 + (param_E - param_E1)/4',
                                    adsk.core.Point3D.create(D/2, E/2, 0), '(param_D - param_D1)/2', '(param_E - param_E1)/2')    
    circle = fusion_sketch.create_center_point_circle(sketch_terminal, adsk.core.Point3D.create(D/2, E/2, 0), 'param_D/2', 'param_E/2', circleRadius * 2, '(param_D - param_D1)/5')
    circle.trim(adsk.core.Point3D.create(get_param(params, 'D')/2, get_param(params, 'E')/2, 0))
    return sketch_terminal

def create_terminal(root_comp, params, design, sketch_terminal, terminal_thickness):
    terminal = sketch_terminal.profiles.item(0)
    terminal = fusion_model.create_extrude(root_comp,terminal, (addin_utility.format_internal_to_default_unit(root_comp, terminal_thickness)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal.name = 'Terminal'
    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, terminal.bodies.item(0), constant.APPEARANCE_ID_GOLD_POLISHED)
    #other terminal creation
    pin = fusion_model.create_mirror(root_comp, terminal, root_comp.yZConstructionPlane)
    fusion_model.create_mirror(root_comp, terminal, root_comp.xZConstructionPlane)
    fusion_model.create_mirror(root_comp, pin, root_comp.xZConstructionPlane)

def create_pin_one_marker(root_comp, params, top_body_sketch):
    #Draw pin 1 marker
    if(get_param(params, 'D') > get_param(params, 'E')):
        max = get_param(params, 'D')
    else:
        max = get_param(params, 'E')
    circleRadius = max/50
    top_body_sketch.isComputeDeferred = True
    lines = top_body_sketch.sketchCurves.sketchLines
    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(-(get_param(params, 'D'))/2 + 0.1 * (get_param(params, 'D')) + 2 * circleRadius , 0, 0))
    constraints = top_body_sketch.geometricConstraints
    line1.startSketchPoint.isfixed = True
    line1.isConstruction = True
    constraints.addCoincident(line1.startSketchPoint, top_body_sketch.originPoint)
    top_body_sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(line1.startSketchPoint)).parameter.expression = 'param_D/2 - 0.1 * param_D - 2 * param_D/50'

    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(-(get_param(params, 'D'))/2 + 0.1 * (get_param(params, 'D')) + 2 * circleRadius , -(get_param(params, 'E'))/2 + 0.1 * (get_param(params, 'E')) + 2 * circleRadius, 0))
    top_body_sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line2.startSketchPoint)).parameter.expression = 'param_E/2 - 0.1 * param_E - 2 * param_E/50'
    line2.isConstruction = True

    constraints.addHorizontal(line1)
    constraints.addVertical(line2)

    circles = top_body_sketch.sketchCurves.sketchCircles
    circle = circles.addByCenterRadius(line2.endSketchPoint,circleRadius)
    top_body_sketch.sketchDimensions.addDiameterDimension(circle, fusion_sketch.get_dimension_text_point(circle), True).parameter.expression = 'param_D/25'
    top_body_sketch.isComputeDeferred = False
    ext_pin_one = top_body_sketch.profiles.item(1)
    pin_one = fusion_model.create_extrude(root_comp, ext_pin_one, (addin_utility.format_internal_to_default_unit(root_comp, -0.01)), adsk.fusion.FeatureOperations.CutFeatureOperation)
    pin_one.name = 'PinOne'

def cornerconcave(params, design = None, target_comp= None):

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    #param creation and updation
    param_updated = user_param(design, params, default_unit, root_comp)
    if param_updated == True:
        return

    terminal_thickness = addin_utility.get_terminal_thickness(get_param, params, 0.001)
    
    #Create lower body sketch
    lower_sketch = create_lower_body_sketch(root_comp, params, terminal_thickness)
    #Create body
    create_lower_body(root_comp, params, design, lower_sketch, terminal_thickness)
    #Create upper body sketch
    upper_sketch = create_upper_body_sketch(root_comp, params)
    #Create upper body
    create_upper_body(root_comp, params, design, upper_sketch)
    #Create terminal sketch
    terminal_sketch = create_terminal_sketch(root_comp, params)
    #Create terminal
    create_terminal(root_comp, params, design, terminal_sketch, terminal_thickness)
    #Create pin one
    create_pin_one_marker(root_comp, params, upper_sketch)


class CornerConcave3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "cornerconcave"

    def create_model(self, params, design, component):
        cornerconcave(params, design, component)

package_3d_model_base.factory.register_package(CornerConcave3DModel.type(), CornerConcave3DModel) 

def run(context):
    ui = app.userInterface
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    cornerconcave(params, design, target_comp)