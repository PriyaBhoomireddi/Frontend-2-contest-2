import adsk.core, adsk.fusion, traceback, math

from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ
from .base import package_3d_model_base

app = adsk.core.Application.get()

def create_fillet(root_comp, params, ext):
    distance = 0.08 * get_param(params, 'L')
    if(distance > 0.004):
        distance = 0.004
    fillets = root_comp.features.filletFeatures
    edgeBottom = adsk.core.ObjectCollection.create()
    bottomEdges = ext.bodies[0].faces[0].edges
    for edgeI  in bottomEdges:
         edgeBottom.add(edgeI)
    bottomEdges = ext.bodies[0].faces[1].edges
    for edgeI  in bottomEdges:
        edgeBottom.add(edgeI)
    bottomEdges = ext.bodies[0].faces[2].edges
    for edgeI  in bottomEdges:
        edgeBottom.add(edgeI)
    bottomEdges = ext.bodies[0].faces[3].edges
    for edgeI  in bottomEdges:
        edgeBottom.add(edgeI)

    radius1 = adsk.core.ValueInput.createByReal(distance)
    input2 = fillets.createInput()
    input2.addConstantRadiusEdgeSet(edgeBottom, radius1, True)
    input2.isG2 = False
    input2.isRollingBallCorner = True
    fillet2 = fillets.add(input2)

def get_param(params, name):
    if name in params:
        if name == 'color_r' and params[name] == None:
            return 220
        if name == 'color_g' and params[name] == None:
            return 0
        if name == 'color_b' and params[name] == None:
            return 0
        else:
            return params[name]
    else:
        if (name == 'E'):
            return 0.24 #Body Width
        if (name == 'D'):
            return 0.32 #Body Length
        if (name == 'A'):
            return 0.24 #Body Height
        if (name == 'A1'):
            return 0.05 #Chip Height
        if (name == 'L'):
            return 0.05 #Normal Terminal Width
        if (name == 'color_r'):
            return 220
        if (name == 'color_g'):
            return 0
        if (name == 'color_b'):
            return 0
        if (name == 'isRoundLens'):
            return 0
        if (name == 'd'):
            return 0.18

def create_chip_sketch(root_comp, params):
    # Create a new sketch.
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    sketch_body = sketches.add(xyPlane)
    #Create mid body
    body = fusion_sketch.create_center_point_rectangle(sketch_body, adsk.core.Point3D.create(0, 0, 0), '', '',
                 adsk.core.Point3D.create((get_param(params, 'D'))/2, (get_param(params, 'E'))/2, 0) , 'param_D', 'param_E')
    #Create side terminals
    lines = sketch_body.sketchCurves.sketchLines
    constraints = sketch_body.geometricConstraints
    line_odd = lines.addByTwoPoints(adsk.core.Point3D.create((get_param(params, 'D')/2 - get_param(params, 'L')), (get_param(params, 'E'))/2, 0),
                                    adsk.core.Point3D.create((get_param(params, 'D')/2 - get_param(params, 'L')), -(get_param(params, 'E'))/2, 0))
    constraints.addVertical(line_odd)
    line_even = lines.addByTwoPoints(adsk.core.Point3D.create((-(get_param(params, 'D'))/2 + get_param(params, 'L')), (get_param(params, 'E'))/2, 0),
                                    adsk.core.Point3D.create((-(get_param(params, 'D'))/2 + get_param(params, 'L')), -(get_param(params, 'E'))/2, 0))
    constraints.addVertical(line_even)
    constraints.addCoincident(line_even.startSketchPoint, body.item(0))
    constraints.addCoincident(line_odd.startSketchPoint, body.item(0))

    sketch_body.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, line_odd.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_odd.startSketchPoint)).parameter.expression = 'param_E'
    sketch_body.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, body.item(0).startSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(body.item(0).startSketchPoint)).parameter.expression = 'param_L'

    sketch_body.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, line_even.endSketchPoint,
                                                        adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_even.startSketchPoint)).parameter.expression = 'param_E'
    sketch_body.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, body.item(0).endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(body.item(0).endSketchPoint)).parameter.expression = 'param_L'

    return sketch_body

def create_chip_body(root_comp, params, design, sketch_body):
    #Extrude bodies
    ext_odd = fusion_model.create_extrude(root_comp, sketch_body.profiles.item(0), 'param_A1', adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_odd.name = 'OddPin'
    ext_even = fusion_model.create_extrude(root_comp, sketch_body.profiles.item(2), 'param_A1', adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_even.name = 'EvenPin'
    ext_body = fusion_model.create_extrude(root_comp, sketch_body.profiles.item(1), 'param_A1', adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_body.name = 'ChipBody'
    create_fillet(root_comp, params, ext_odd)
    create_fillet(root_comp, params, ext_even)
    body = ext_body.bodies.item(0)

    #Assign materials to body and terminals
    addin_utility.apply_material(app, design, ext_odd.bodies.item(0), constant.MATERIAL_ID_TIN)
    addin_utility.apply_material(app, design, ext_even.bodies.item(0), constant.MATERIAL_ID_TIN)
    addin_utility.apply_material(app, design, ext_body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)
    return body

def create_led_case_sketch(root_comp, params):
    #Create top cap sketch
    if get_param(params, 'isRoundLens'):
        led_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, "(param_A - param_d/2)")
    else:
        led_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    led_offset.name = 'LedOffset'
    sketches = root_comp.sketches
    led_sketch = sketches.add(led_offset)
    led_sketch.isLightBulbOn = False
    if (get_param(params, 'd') == get_param(params, 'E')):
        case = fusion_sketch.create_center_point_rectangle(led_sketch, adsk.core.Point3D.create(0, 0, 0), '', '',
                        adsk.core.Point3D.create((get_param(params, 'D'))/2, (get_param(params, 'E'))/2 , 0),
                        'param_D ', 'param_E ')
    else :
        case = fusion_sketch.create_center_point_rectangle(led_sketch, adsk.core.Point3D.create(0, 0, 0), '', '',
                        adsk.core.Point3D.create((get_param(params, 'D'))/2 * 0.9, (get_param(params, 'E'))/2 * 0.9, 0),
                        'param_D * 0.9', 'param_E * 0.9')
    
    #Create side terminals for cut
    lines = led_sketch.sketchCurves.sketchLines;
    constraints = led_sketch.geometricConstraints
    line_odd = lines.addByTwoPoints(adsk.core.Point3D.create((get_param(params, 'D')/2 - get_param(params, 'L')), (get_param(params, 'E'))/2 * 0.05, 0),
                                    adsk.core.Point3D.create((get_param(params, 'D')/2 - get_param(params, 'L')), -(get_param(params, 'E'))/2 * 0.05, 0))
    constraints.addVertical(line_odd)
    line_even = lines.addByTwoPoints(adsk.core.Point3D.create((-(get_param(params, 'D'))/2 + get_param(params, 'L')), (get_param(params, 'E'))/2 * 0.05, 0),
                                    adsk.core.Point3D.create((-(get_param(params, 'D'))/2 + get_param(params, 'L')), -(get_param(params, 'E'))/2 * 0.05, 0))
    constraints.addVertical(line_even)
    constraints.addCoincident(line_even.startSketchPoint, case.item(0))
    constraints.addCoincident(line_odd.startSketchPoint, case.item(0))
    #Give parameters to dimensions
    led_sketch.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, case.item(0).startSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_odd.startSketchPoint)).parameter.expression = 'param_L'
    led_sketch.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, case.item(0).endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(line_even.startSketchPoint)).parameter.expression = 'param_L'
    if (get_param(params, 'd') == get_param(params, 'E')):
            led_sketch.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, line_even.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_even.endSketchPoint)).parameter.expression = 'param_E'
            led_sketch.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, line_odd.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_odd.endSketchPoint)).parameter.expression = 'param_E'
    else :
            led_sketch.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, line_even.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_even.endSketchPoint)).parameter.expression = 'param_E * 0.9'
            led_sketch.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, line_odd.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_odd.endSketchPoint)).parameter.expression = 'param_E * 0.9'
                   

    #Draw circle sketch for round body and constrain it
    line_digonal = lines.addByTwoPoints(line_odd.startSketchPoint, line_even.endSketchPoint)
    line_digonal.isConstruction = True
    
    line_axis1 = lines.addByTwoPoints(adsk.core.Point3D.create(0 , 0, 0),
                                    adsk.core.Point3D.create(-get_param(params, 'd')/2, 0, 0))
    line_axis2 = lines.addByTwoPoints(adsk.core.Point3D.create(0 , 0, 0),
                                    adsk.core.Point3D.create(get_param(params, 'd')/2, 0, 0))

    constraints.addHorizontal(line_axis1)
    constraints.addHorizontal(line_axis2)
    constraints.addMidPoint(line_axis1.startSketchPoint, line_digonal)
    constraints.addMidPoint(line_axis2.startSketchPoint, line_digonal)

    led_sketch.sketchDimensions.addDistanceDimension(line_axis1.startSketchPoint, line_axis1.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(line_axis1.startSketchPoint)).parameter.expression = 'param_d/2'
    led_sketch.sketchDimensions.addDistanceDimension(line_axis2.startSketchPoint, line_axis2.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(line_axis2.startSketchPoint)).parameter.expression = 'param_d/2'
    arcs = led_sketch.sketchCurves.sketchArcs
    lens_sphere = arcs.addByCenterStartSweep(line_axis1.startSketchPoint, line_axis1.endSketchPoint, 180) 
    constraints.addCoincident(line_axis1.startSketchPoint, lens_sphere.centerSketchPoint)  
    constraints.addCoincident(line_axis2.endSketchPoint, lens_sphere.endSketchPoint)  
    
    led_sketch.name = 'LedSketch'
    return led_sketch

def create_led_case_body(root_comp, params, design, sketch, body):
    #Select the profile for loft by creating profile collection
    led_prof = adsk.core.ObjectCollection.create()
    #led_prof.add(sketch.profiles.item(1))
    if (get_param(params, 'd') == get_param(params, 'E')):
        led_prof.add(sketch.profiles.item(2))
        led_prof.add(sketch.profiles.item(3))
    else :
        led_prof.add(sketch.profiles.item(1))
        led_prof.add(sketch.profiles.item(3))
    # Create loft feature
    loftFeats = root_comp.features.loftFeatures
    loftInput = loftFeats.createInput(adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    loftSectionsObj = loftInput.loftSections
    loftSectionsObj.add(body.faces.item(4))
    loftSectionsObj.add(led_prof)
    loftInput.isSolid = True
    led = loftFeats.add(loftInput)
    led.name = 'LedGlassCase'
    led_case = led.bodies.item(0)

    #Apply material and appearance to led case
    addin_utility.apply_material(app, design, led_case,constant.MATERIAL_ID_PLASTIC_TRANSP)
    addin_utility.apply_rgb_appearance(app, design, led_case,get_param(params, 'color_r'),
                    get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_LED_CASE)
    
    #Create top sphere
    revolves = root_comp.features.revolveFeatures
    if (get_param(params, 'd') == get_param(params, 'E')):
        rev_input = revolves.createInput(sketch.profiles.item(2), sketch.sketchCurves.sketchLines.item(10), adsk.fusion.FeatureOperations.JoinFeatureOperation)
    else :
        rev_input = revolves.createInput(sketch.profiles.item(3), sketch.sketchCurves.sketchLines.item(10), adsk.fusion.FeatureOperations.JoinFeatureOperation)
    angle = adsk.core.ValueInput.createByReal(math.pi)
    rev_input.setAngleExtent(False, angle)
    ext_rev = revolves.add(rev_input)
    ext_rev.name = 'SphereRevolve'

    if not get_param(params, 'isRoundLens'):
        ext_rev.isSuppressed = True

    return led_case

def create_led_light_sketch(root_comp, params):
    #Create light sketch
    light_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A1')
    light_offset.name = 'LightOffset'
    sketches = root_comp.sketches
    light_sketch = sketches.add(light_offset)
    fusion_sketch.create_center_point_rectangle(light_sketch, adsk.core.Point3D.create(0, 0, 0), '', '',
                    adsk.core.Point3D.create((get_param(params, 'D'))/10, (get_param(params, 'E'))/10, 0), 'param_D/10', 'param_E/10')
    
    return light_sketch
    
def create_led_light_body(root_comp, params, design, sketch):
    #Select the profile and extrude it
    light_prof = sketch.profiles.item(0)
    ext_light = fusion_model.create_extrude(root_comp, light_prof, 'param_A1/10', adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_light.name = 'LedLight'
    led_light = ext_light.bodies.item(0)
    #Apply material and appearance to led light source
    addin_utility.apply_material(app, design, led_light,constant.MATERIAL_ID_CERAMIC)
    addin_utility.apply_emissive_appearance(app, design, led_light, 50000.0,
                    get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_LED_LIGHT)

def change_sketch_dimension(root_comp, flag):
    for param in root_comp.modelParameters:
            if param.createdBy.name == "LedSketch":
                if flag == True:
                    if param.role=="Linear Dimension-4" :
                        param.expression = 'param_D'
                    if param.role=="Linear Dimension-5" :
                        param.expression = 'param_E'
                    if param.role=="Linear Dimension-8" :
                        param.expression = 'param_E'
                    if param.role=="Linear Dimension-9" :
                        param.expression = 'param_E'
                else:
                    if param.role=="Linear Dimension-4" :
                        param.expression = 'param_D * 0.9'
                    if param.role=="Linear Dimension-5" :
                        param.expression = 'param_E * 0.9'
                    if param.role=="Linear Dimension-8" :
                        param.expression = 'param_E * 0.9'
                    if param.role=="Linear Dimension-9" :
                        param.expression = 'param_E * 0.9'


def user_param(root_comp, design, params, default_unit):
    #User param creation and updation
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    res_2 = addin_utility.process_user_param(design, 'param_A1', get_param(params, 'A1'), default_unit, _LCLZ("ChipHeight", "chip height"))
    res_3 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_4 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_5 = addin_utility.process_user_param(design, 'param_L', get_param(params, 'L'), default_unit, _LCLZ("NormalTerminalWidth", "normal terminal width"))
    res_6 = addin_utility.process_user_param(design, 'param_d', get_param(params, 'd'), default_unit,_LCLZ("DomeDiameter", "dome diameter"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 or res_6 
    if isUpdate:
        offset_plane = root_comp.constructionPlanes.itemByName('LedOffset')
        led_sphere = root_comp.features.itemByName('SphereRevolve')
        led_sketch = root_comp.sketches.itemByName('LedSketch')

        offset_plane.timelineObject.rollTo(True)
        for param in root_comp.modelParameters:
            if param.role=="AlongDistance" :
                if param.createdBy.name=="LedOffset":
                    if get_param(params, 'isRoundLens'):
                        param.expression = 'param_A - param_d/2'
                        led_sphere.isSuppressed = False
                    else:
                        param.expression = 'param_A'
                        led_sphere.isSuppressed = True

        design.timeline.moveToEnd()

        led_sketch.timelineObject.rollTo(True)
        if (get_param(params, 'd') == get_param(params, 'E')):
            change = True
        else:
            change = False
        change_sketch_dimension(root_comp, change)

        if not get_param(params, 'isRoundLens'):
            change_sketch_dimension(root_comp, False)   

        design.timeline.moveToEnd()

        #update the color and luminance value
        addin_utility.update_emissive_appearance(app, design, 50000.0, get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_LED_LIGHT)
        addin_utility.update_rgb_appearance(app, design, get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_LED_CASE, constant.COLOR_PROP_ID_METAL)
        addin_utility.update_rgb_appearance(app, design, get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_LED_CASE, constant.COLOR_PROP_ID_TRANSPARENT)
        return isUpdate

def chip_led(params, design = None, target_comp = None):

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
    param_updated = user_param(root_comp, design, params, default_unit)
    if param_updated == True:
        return

    #Create chip sketch
    chip_sketch = create_chip_sketch(root_comp,params)
    #Create chip body
    body_face = create_chip_body(root_comp, params, design, chip_sketch)
    #Create top case sketch
    case_sketch = create_led_case_sketch(root_comp, params)
    #Create top case body
    create_led_case_body(root_comp, params, design, case_sketch, body_face)
    #Create LED light sketch
    light_sketch = create_led_light_sketch(root_comp, params)
    #Create LED light body
    create_led_light_body(root_comp, params, design, light_sketch)

    #activate the root component. make sure it is not activate the sub component which is top dome by the creation of revolve feature. 
    design.activateRootComponent()
        

class ChipLed3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "chip_led"

    def create_model(self, params, design, component):
        chip_led(params, design, component)

package_3d_model_base.factory.register_package(ChipLed3DModel.type(), ChipLed3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    chip_led(params, design, target_comp)