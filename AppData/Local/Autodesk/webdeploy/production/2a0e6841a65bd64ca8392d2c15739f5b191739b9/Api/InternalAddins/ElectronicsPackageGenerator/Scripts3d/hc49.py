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
            return 0.06 #Terminal Width
        if (name == 'D'):
            return 1.12 #Body Length
        if (name == 'E'):
            return 0.485 #Body Width
        if (name == 'A'):
            return 0.35 #Body Height
        if (name == 'e'):
            return 0.488 #Pitch
        if (name == 'board_thickness'):
            return 0.16 #Board Thickness

def user_param(design, params, default_unit, root_comp):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_b', get_param(params, 'b'), default_unit, _LCLZ("TerminalWidth", "terminal width"))
    res_2 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_3 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_4 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    res_5 = addin_utility.process_user_param(design, 'param_e', get_param(params, 'e'), default_unit, _LCLZ("Pitch", "pitch"))
    res_6 = addin_utility.process_user_param(design, 'board_thickness', get_param(params, 'board_thickness'), default_unit, _LCLZ("BoardThickness", "board thickness"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 or res_6
    if isUpdate:
        return isUpdate        

def create_fillet(root_comp, ext, distance):
    fillets = root_comp.features.filletFeatures
    edgeTop = adsk.core.ObjectCollection.create()
    topFace = ext.endFaces[0]
    topEdges = topFace.edges
    for edgeI  in topEdges:
            edgeTop.add(edgeI)

    radius = adsk.core.ValueInput.createByString(distance)
    input1 = fillets.createInput()
    input1.addConstantRadiusEdgeSet(edgeTop, radius, True)
    input1.isG2 = False
    input1.isRollingBallCorner = True
    fillet1 = fillets.add(input1)


def create_body_sketch(root_comp, params):
    # Create body
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    body_sketch = sketches.add(xyPlane)
    body_sketch.name = 'BodySketch'
    #Create base rectangle
    body = fusion_sketch.create_center_point_rectangle(body_sketch, adsk.core.Point3D.create(0, 0, 0),'', '',  
            adsk.core.Point3D.create(get_param(params, 'D')/2 - get_param(params, 'E')/2, get_param(params, 'E')/2, 0), 'param_D - param_E', 'param_E')

    lines = body_sketch.sketchCurves.sketchLines
    constraints = body_sketch.geometricConstraints
    line_odd = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(get_param(params, 'D')/2, 0, 0))
    line_even = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(-(get_param(params, 'D'))/2, 0, 0))
    line_odd.startSketchPoint.isFixed = True
    line_even.startSketchPoint.isFixed = True
    constraints.addHorizontal(line_odd)
    constraints.addHorizontal(line_even)
    line_odd.isConstruction = True
    line_even.isConstruction = True
    #Create rounded corners
    arcs = body_sketch.sketchCurves.sketchArcs
    arcs_odd = arcs.addByCenterStartSweep(adsk.core.Point3D.create(get_param(params, 'D')/2 - get_param(params, 'E')/2, 0 , 0), 
                adsk.core.Point3D.create(get_param(params, 'D')/2 - get_param(params, 'E')/2, get_param(params, 'E')/2, 0), -math.pi)
    arcs_even = arcs.addByCenterStartSweep(adsk.core.Point3D.create(-(get_param(params, 'D'))/2 + get_param(params, 'E')/2, 0 , 0), 
                adsk.core.Point3D.create(-(get_param(params, 'D'))/2 + get_param(params, 'E')/2, get_param(params, 'E')/2, 0), math.pi)
    constraints.addCoincident(arcs_odd.centerSketchPoint, line_odd.endSketchPoint)
    constraints.addCoincident(arcs_even.centerSketchPoint, line_even.endSketchPoint)

    body_sketch.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, line_odd.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(line_odd.startSketchPoint)).parameter.expression = 'param_D/2 - param_E/2'
    body_sketch.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, line_even.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(line_even.startSketchPoint)).parameter.expression = 'param_D/2 - param_E/2'
    body_sketch.sketchDimensions.addRadialDimension(arcs_odd, fusion_sketch.get_dimension_text_point(arcs_odd)).parameter.expression = 'param_E/2'
    body_sketch.sketchDimensions.addRadialDimension(arcs_even, fusion_sketch.get_dimension_text_point(arcs_even)).parameter.expression = 'param_E/2'

    constraints.addCoincident(arcs_odd.endSketchPoint, body.item(0).startSketchPoint)

    #Create offset
    entities = adsk.core.ObjectCollection.create()
    entities.add(arcs_odd)
    entities.add(arcs_even)
    entities.add(body.item(0))
    entities.add(body.item(2))
    dir_point = adsk.core.Point3D.create(0, 0.5, 0)
    offset_curves = body_sketch.offset(entities, dir_point, 0.02)

    return body_sketch

def create_body(root_comp, params, design, body_sketch):
    #Select profile
    profile = adsk.core.ObjectCollection.create()
    profile.add(body_sketch.profiles.item(0))
    profile.add(body_sketch.profiles.item(1))
    profile.add(body_sketch.profiles.item(3))

    #Create body extrusion
    mid_body = fusion_model.create_extrude(root_comp,profile, 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    mid_body.name = 'MidBody'

    profile.add(body_sketch.profiles.item(2))
    side_body = fusion_model.create_extrude(root_comp,profile, 'param_E * 0.1', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    side_body.name = 'SideBody'

    create_fillet(root_comp, side_body, 'param_E * 0.05')
    create_fillet(root_comp, mid_body, 'param_E * 0.05')

    # assign the pysical material to body.
    addin_utility.apply_material(app, design, mid_body.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)
    addin_utility.apply_material(app, design, side_body.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)

def create_terminal_sketch(root_comp, params):
    #Create terminals
    xyPlane = root_comp.xYConstructionPlane
    sketches = root_comp.sketches
    sketch_term = sketches.add(xyPlane)
    sketch_term.name = 'TerminalSketch'
    centerPoint = adsk.core.Point3D.create(get_param(params, 'e')/2, 0, 0)
    fusion_sketch.create_center_point_circle(sketch_term, centerPoint, 'param_e/2', '', get_param(params, 'b'), 'param_b')
    return sketch_term

def create_terminal(root_comp, params, design, terminal_sketch):
    lead_length = '-1.2 * board_thickness'
    #Selecting profile
    ext_term = terminal_sketch.profiles.item(0)
    terminal = fusion_model.create_extrude(root_comp, ext_term, lead_length, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    terminal.name = 'Terminal'

    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, terminal.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)
    #mirror the terminal
    fusion_model.create_mirror(root_comp, terminal, root_comp.yZConstructionPlane)


def hc49(params, design = None, target_comp = None):

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

    #Create body sketch
    body_sketch = create_body_sketch(root_comp, params)
    #Create body
    create_body(root_comp, params, design, body_sketch)
    #Create terminal sketch
    terminal_sketch = create_terminal_sketch(root_comp, params)
    #Create terminals
    create_terminal(root_comp, params, design, terminal_sketch)
    

class Hc493DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "crystal_hc49"

    def create_model(self, params, design, component):
        hc49(params, design, component)

package_3d_model_base.factory.register_package(Hc493DModel.type(), Hc493DModel) 

def run(context):
    ui = app.userInterface
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    hc49(params, design, target_comp)
