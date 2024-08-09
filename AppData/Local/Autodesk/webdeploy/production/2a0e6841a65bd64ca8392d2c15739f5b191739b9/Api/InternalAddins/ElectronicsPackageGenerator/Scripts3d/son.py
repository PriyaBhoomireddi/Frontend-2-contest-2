import adsk.core, adsk.fusion, traceback
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()

def create_chamfer(root_comp, ext, dist1, dist2):
    edge_top = adsk.core.ObjectCollection.create()
    top_face = ext.startFaces[0]
    top_edges = top_face.edges
    for edgeI  in top_edges:
        edge_top.add(edgeI)

    chamfer_feats = root_comp.features.chamferFeatures
    chamfer_top = chamfer_feats.createInput(edge_top, True)
    chamfer_top.setToTwoDistances(adsk.core.ValueInput.createByString(dist1), adsk.core.ValueInput.createByString(dist2))
    chamfer_feats.add(chamfer_top)

def son(params, design = None, target_comp = None):

    A = params.get('A') or 0.08 #Body height(A)
    b = params.get('b') or 0.03 #Termianl width(b)
    D = params.get('D') or 0.41 #Body length(D)
    E = params.get('E') or 0.31 #Body width(E)
    e = params.get('e') or 0.05 #Pin pitch(e)
    L = params.get('L') or 0.05 #Terminal length(L)
    D2 = params.get('D2') or 0.34 #Thermal pad length(D2)
    E2 = params.get('E2') or 0.15 #Thermal pad width(E2)
    DPins = params.get('DPins') or 14 #Total pins
    thermal = params['thermal'] if 'thermal' in params else 0 #Thermal pad flag

    offset = (DPins/2 - 1) * e/2
    boxChamfer = 0.1 * A

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent

    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane

    if target_comp:
        root_comp = target_comp

    terminal_thickness =  (addin_utility.format_internal_to_default_unit(root_comp, 0.005)) #Terminal thickness

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    is_update = False
    is_update = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("TerminalWidth", "terminal width"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_e', e, default_unit, _LCLZ("PinPitch", "pin pitch"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("TerminalLength", "terminal length"))
    is_update = addin_utility.process_user_param(design, 'param_D2', D2, default_unit, _LCLZ("ThermalPadLength", "thermal pad length"))
    is_update = addin_utility.process_user_param(design, 'param_E2', E2, default_unit, _LCLZ("ThermalPadWidth", "thermal pad width"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("Pins", "pins"))

    # the paramters are already there, just update the models with the paramters. will skip the model creation process.
    if is_update:
        thermal_pad = root_comp.features.itemByName('ThermalPad')
        if thermal:
            thermal_pad.isSuppressed = False
        else:
            thermal_pad.isSuppressed = True
        return

    #Create body
    sketches = root_comp.sketches
    body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    body_offset.name = 'BodyOffset'
    body_sketch = sketches.add(body_offset)
    fusion_sketch.create_center_point_rectangle(body_sketch, adsk.core.Point3D.create(0, 0, 0), '', '', adsk.core.Point3D.create(E/2, D/2, 0), 'param_E', 'param_D')
    ext_body = body_sketch.profiles.item(0)
    body = fusion_model.create_extrude(root_comp,ext_body, '-param_A +' + (addin_utility.format_internal_to_default_unit(root_comp, 0.005)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    body.name = 'Body'
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)
    create_chamfer(root_comp, body, 'param_A/10', 'param_A/10')

    #Draw pin1 mark
    lines = body_sketch.sketchCurves.sketchLines
    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(-E/2 + 2 * boxChamfer + 0.015 , 0, 0))
    constraints = body_sketch.geometricConstraints
    line1.startSketchPoint.isfixed = True
    line1.isConstruction = True
    constraints.addCoincident(line1.startSketchPoint, body_sketch.originPoint)
    offset_name = (addin_utility.format_internal_to_default_unit(root_comp, 0.015))

    body_sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(-E/2, 0, 0)).parameter.expression = 'param_E/2  - 0.2 * param_A -' + offset_name 

    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(-E/2 + 2 * boxChamfer + 0.15 , D/2 - 2 * boxChamfer - 0.015, 0))

    body_sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(-E/4  , D/2 , 0)).parameter.expression = 'param_D/2 - 0.2 * param_A -' + offset_name
    line2.isConstruction = True

    constraints.addHorizontal(line1)
    constraints.addVertical(line2)

    circles = body_sketch.sketchCurves.sketchCircles
    circle = circles.addByCenterRadius(line2.endSketchPoint,0.15)
    body_sketch.sketchDimensions.addDiameterDimension(circle, adsk.core.Point3D.create(E/2,D/2,0), True).parameter.value = 0.015
    ext_pin_one = body_sketch.profiles.item(1)
    pin_one = fusion_model.create_extrude(root_comp, ext_pin_one, '-0.1 * param_A', adsk.fusion.FeatureOperations.CutFeatureOperation)
    pin_one.name = 'Pin1'

    #Create terminals
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    pin_sketch = sketches.add(xyPlane)
    fusion_sketch.create_center_point_rectangle(pin_sketch, adsk.core.Point3D.create(E/2 + 0.001 - L/2, offset, 0),
                                                'param_E/2 - param_L/2 +' + (addin_utility.format_internal_to_default_unit(root_comp, 0.0001)),
                                                '(param_DPins/2 - 1) * param_e/2', adsk.core.Point3D.create(E/2 + 0.001, offset + b/2, 0), 'param_L', 'param_b')

    lines = pin_sketch.sketchCurves.sketchLines
    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(0, offset + b/2, 0))
    constraints = pin_sketch.geometricConstraints
    line1.startSketchPoint.isfixed = True
    line1.isConstruction = True
    constraints.addCoincident(line1.startSketchPoint, pin_sketch.originPoint)

    pin_sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                        adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(0, D/4, 0)).parameter.expression = '(param_DPins/2 - 1) * param_e/2 + param_b/2'

    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(E/2, offset + b/2, 0))
    line2.isConstruction = True

    pin_sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                        adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                        adsk.core.Point3D.create(E/2, D/4, 0)).parameter.expression = 'param_E/2'

    line3 = lines.addByTwoPoints(line2.endSketchPoint, adsk.core.Point3D.create(E/2, offset - b/2, 0))

    pin_sketch.sketchDimensions.addDistanceDimension(line3.startSketchPoint, line3.endSketchPoint,
                                                        adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        adsk.core.Point3D.create(E/2, D/2, 0)).parameter.expression = 'param_b'
    constraints.addVertical(line1)
    constraints.addHorizontal(line2)
    constraints.addVertical(line3)


    circle = fusion_sketch.create_center_point_circle(pin_sketch, adsk.core.Point3D.create(E/2 - L + b/2, offset , 0),'param_E/2 - param_L + param_b/2', '(param_DPins/2 - 1) * param_e/2',
                                                                                                                             b, 'param_b')
    circle.trim(adsk.core.Point3D.create(E/2, D/2, 0))


    ter_ext_side = pin_sketch.profiles.item(4)
    terminal_side = fusion_model.create_extrude(root_comp,ter_ext_side,'(param_A -'+ (addin_utility.format_internal_to_default_unit(root_comp, 0.005)) +')/5', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal_side.name = 'TerminalSide'
    # apply the pin material.
    addin_utility.apply_material(app, design, terminal_side.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, terminal_side.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    ter_ext = pin_sketch.profiles.item(3)
    terminal = fusion_model.create_extrude(root_comp,ter_ext, terminal_thickness , adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal.name = 'Terminal'
    # apply the pin material.
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, terminal.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    pattern_pins1 = fusion_model.create_mirror_and_pattern(root_comp, terminal, '-param_e', 'param_DPins/2', root_comp.yConstructionAxis, root_comp.yZConstructionPlane)
    pattern_pins1.name = 'PinPattern1'
    pattern_pins2 = fusion_model.create_mirror_and_pattern(root_comp, terminal_side, '-param_e', 'param_DPins/2', root_comp.yConstructionAxis, root_comp.yZConstructionPlane)
    pattern_pins2.name = 'PinPattern2'
    #Draw thermal pad
    addin_utility.create_thermal_pad(app, root_comp, '0', adsk.core.Point3D.create(0, 0, 0), '', '',  adsk.core.Point3D.create(E2/2, D2/2, 0), 'param_E2', 'param_D2', (addin_utility.format_internal_to_default_unit(root_comp, 0.005)), thermal)


from .base import package_3d_model_base

class Son3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "son"

    def create_model(self, params, design, component):
        son(params, design, component)

package_3d_model_base.factory.register_package(Son3DModel.type(), Son3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    son(params, design, target_comp)
