import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ
from .base import package_3d_model_base

app = adsk.core.Application.get()

#get param from the pallete
def get_param(params, name):
    if name in params:
        return params[name]
    else:
        if (name == 'b'):
            return 0.079 #Terminal Width
        if (name == 'L'):
            return 0.416 #Terminal Length
        if (name == 'D2'):
            return 0.488 #Terminal Gap
        if (name == 'E'):
            return 0.5 #Body Width
        if (name == 'D1'):
            return 1.17 #Body Length
        if (name == 'A'):
            return 0.45 #Body Height

def user_param(design, params, default_unit, root_comp):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_b', get_param(params, 'b'), default_unit, _LCLZ("TerminalWidth", "terminal width"))
    res_2 = addin_utility.process_user_param(design, 'param_L', get_param(params, 'L'), default_unit, _LCLZ("TerminalLength", "terminal length"))
    res_3 = addin_utility.process_user_param(design, 'param_D2', get_param(params, 'D2'), default_unit, _LCLZ("TerminalGap", "terminal gap"))
    res_4 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_5 = addin_utility.process_user_param(design, 'param_D1', get_param(params, 'D1'), default_unit, _LCLZ("BodyLength", "body length"))
    res_6 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 or res_6
    if isUpdate:
        return isUpdate

def create_fillet(root_comp, ext, distance):
    fillets = root_comp.features.filletFeatures
    edgeTop = adsk.core.ObjectCollection.create()
    topFace = ext.endFaces[0];
    topEdges = topFace.edges
    for edgeI  in topEdges:
            edgeTop.add(edgeI)

    radius = adsk.core.ValueInput.createByReal(distance)
    input1 = fillets.createInput()
    input1.addConstantRadiusEdgeSet(edgeTop, radius, True)
    input1.isG2 = False
    input1.isRollingBallCorner = True
    fillet1 = fillets.add(input1)

def create_lower_body_sketch(root_comp, params):
    #create lower body sketch
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    low_body_offset =  addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, (addin_utility.format_internal_to_default_unit(root_comp, 0.0001)))
    low_body_offset.name = 'LowBodyOffset'
    low_body_sketch = sketches.add(low_body_offset)
    low_body_sketch.name = 'LowBodySketch'
    fusion_sketch.create_center_point_rectangle(low_body_sketch, adsk.core.Point3D.create(0, 0, 0), '', '', 
                    adsk.core.Point3D.create(get_param(params, 'D1')/2, get_param(params, 'E')/2, 0), 'param_D1', 'param_E')
    

    return low_body_sketch

def create_lower_body(root_comp, params, design, low_body_sketch):
    #extrude the lower body
    prof_low_body = low_body_sketch.profiles.item(0)
    low_body = fusion_model.create_extrude(root_comp, prof_low_body, "param_A/4",
                                     adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    low_body.name = 'LowBody'
    # assign the pysical material and appearance to body
    addin_utility.apply_material(app, design, low_body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)
    addin_utility.apply_appearance(app, design, low_body.bodies.item(0), constant.APPEARANCE_ID_BODY_DEFAULT)

def create_upper_body_plane(root_comp, params):
    #Create top body offset plane
    sketches = root_comp.sketches
    top_body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, "param_A/4")
    top_body_offset.name = 'TopBodyOffset'
    top_body_sketch = sketches.add(top_body_offset)
    top_body_sketch.name = 'TopBodySketch'
    return top_body_sketch

def create_upper_body_sketch(root_comp, params, top_body_sketch):
    #create top body sketch
    top_body = fusion_sketch.create_center_point_rectangle(top_body_sketch, adsk.core.Point3D.create(0, 0, 0),'', '',
                                adsk.core.Point3D.create((0.45 * get_param(params, 'D1')) - (0.4 * get_param(params, 'E')), 0.45 * get_param(params, 'E'), 0), 
                                'param_D1 * 0.9 - param_E * 0.8', 'param_E * 0.9')

    lines = top_body_sketch.sketchCurves.sketchLines;
    constraints = top_body_sketch.geometricConstraints
    line_odd = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create((0.45 * get_param(params, 'D1')) - (0.4 * get_param(params, 'E')), 0, 0))
    line_even = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create((-0.45 * get_param(params, 'D1')) + (0.4 * get_param(params, 'E')), 0, 0))
    line_odd.startSketchPoint.isFixed = True
    line_even.startSketchPoint.isFixed = True
    constraints.addHorizontal(line_odd)
    constraints.addHorizontal(line_even)
    line_odd.isConstruction = True
    line_even.isConstruction = True

    #draw arcs for the rounded corner
    arcs = top_body_sketch.sketchCurves.sketchArcs;
    arcs_odd = arcs.addByCenterStartSweep(adsk.core.Point3D.create((0.45 * get_param(params, 'D1')) - (0.4 * get_param(params, 'E')), 0 , 0), 
                adsk.core.Point3D.create((0.45 * get_param(params, 'D1')) - (0.4 * get_param(params, 'E')), 0.45 * get_param(params, 'E'), 0), -math.pi)
    arcs_even = arcs.addByCenterStartSweep(adsk.core.Point3D.create((-0.45 * get_param(params, 'D1')) + (0.4 * get_param(params, 'E')), 0 , 0), 
                adsk.core.Point3D.create((-0.45 * get_param(params, 'D1')) + (0.4 * get_param(params, 'E')), 0.45 * get_param(params, 'E'), 0), math.pi)
    constraints.addCoincident(arcs_odd.centerSketchPoint, line_odd.endSketchPoint)
    constraints.addCoincident(arcs_even.centerSketchPoint, line_even.endSketchPoint)

    top_body_sketch.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, line_odd.endSketchPoint,
                                                    adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                    fusion_sketch.get_dimension_text_point(line_odd.endSketchPoint)).parameter.expression = '0.45 * param_D1 - 0.4 * param_E'
    top_body_sketch.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, line_even.endSketchPoint,
                                                    adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                        fusion_sketch.get_dimension_text_point(line_even.startSketchPoint)).parameter.expression = '0.45 * param_D1 - 0.4 * param_E'
    top_body_sketch.sketchDimensions.addRadialDimension(arcs_odd, adsk.core.Point3D.create((get_param(params, 'D2') + get_param(params, 'L') * 2)/2, 0, 0)).parameter.expression = 'param_E * 0.45'
    top_body_sketch.sketchDimensions.addRadialDimension(arcs_even, adsk.core.Point3D.create(-(get_param(params, 'D2') + get_param(params, 'L') * 2)/2, 0, 0)).parameter.expression = 'param_E * 0.45'

    constraints.addCoincident(arcs_odd.endSketchPoint, top_body.item(0).startSketchPoint)

    #Create offset
    entities = adsk.core.ObjectCollection.create()
    entities.add(arcs_odd)
    entities.add(arcs_even)
    entities.add(top_body.item(0))
    entities.add(top_body.item(2))
    dir_point = adsk.core.Point3D.create(0, 0, 0)
    offset_curves = top_body_sketch.offset(entities, dir_point, -0.005)

    return top_body_sketch

def create_upper_body(root_comp, params, design, top_body_sketch):
    A1 = 1/4 * get_param(params, 'A')
    #Create extrusion
    profile = adsk.core.ObjectCollection.create()
    profile.add(top_body_sketch.profiles.item(0))
    profile.add(top_body_sketch.profiles.item(1))
    profile.add(top_body_sketch.profiles.item(3))

    mid_body = fusion_model.create_extrude(root_comp, profile, "param_A * 3/4", adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    mid_body.name = 'MidBody'

    prof = top_body_sketch.profiles.item(2)    
    side_body = fusion_model.create_extrude(root_comp,prof, "param_A * 3/4 * 0.1", adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    side_body.name = 'SideBody'

    #Create fillet o the top face edges
    create_fillet(root_comp, mid_body, 0.03)

    # assign the pysical material to body.
    addin_utility.apply_material(app, design, mid_body.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)
    addin_utility.apply_material(app, design, side_body.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)

def create_terminal_sketch(root_comp, params):
    #Draw terminals
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    terminal_sketch = sketches.add(xyPlane)
    terminal_sketch.name = 'TerminalSketch'
    fusion_sketch.create_center_point_rectangle(terminal_sketch, adsk.core.Point3D.create(get_param(params, 'D2')/2  + get_param(params, 'L')/2 , 0, 0), 
                        'param_D2/2 + param_L/2' , '', adsk.core.Point3D.create(get_param(params, 'D2')/2+ get_param(params, 'L'), get_param(params, 'b')/2, 0), 'param_L', 'param_b')
    
    return terminal_sketch

def create_terminal(root_comp, params, design, terminal_sketch):
    #select the right profile
    ext_terminal = terminal_sketch.profiles.item(0)
    terminal = fusion_model.create_extrude(root_comp,ext_terminal, (addin_utility.format_internal_to_default_unit(root_comp, 0.03)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal.name = 'Terminal'

    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the appearance to pin
    addin_utility.apply_appearance(app, design, terminal.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)
    #mirror the terminal
    fusion_model.create_mirror(root_comp, terminal, root_comp.yZConstructionPlane)


def crystal(params, design = None, target_comp = None):

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

    #create lower body sketch
    lower_body_sketch = create_lower_body_sketch(root_comp, params)
    #create lower body
    create_lower_body(root_comp, params, design, lower_body_sketch)
    #create upper body plane
    upper_body_plane = create_upper_body_plane(root_comp, params)
    #create upper body sketch
    upper_body_sketch = create_upper_body_sketch(root_comp, params, upper_body_plane)
    #create upper body
    create_upper_body(root_comp, params, design, upper_body_sketch)
    #create terminal sketch
    terminal_sketch  = create_terminal_sketch(root_comp, params)
    #create terminals
    create_terminal(root_comp, params, design, terminal_sketch)

    

class Crystal3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "crystal"

    def create_model(self, params, design, component):
        crystal(params, design, component)

package_3d_model_base.factory.register_package(Crystal3DModel.type(), Crystal3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    crystal(params, design, target_comp)
