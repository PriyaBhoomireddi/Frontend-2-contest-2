import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()


def radial_ecap(params, design = None, target_comp = None):

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp
    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    D = params.get('D') or 1 #Body diameter
    A = params.get('A') or 1.1 #Body height(A)
    b = params.get('b') or 0.065 #Pin width(b)
    e = params.get('e') or 0.508 #Pin pitch(e)
    board_thickness = params.get('boardThickness') or 0.16 #Board thickness
    polarityMarker = params['isPolarized'] if 'isPolarized' in params else 0 #Polarity marker

    curvedSurfaceRadius = D / 10
    lead_length = 1.2 * board_thickness
    fillet_amount = curvedSurfaceRadius / 3

    color_r = params.get('color_r')
    if color_r == None: color_r = 24
    color_g = params.get('color_g')
    if color_g == None: color_g = 37
    color_b = params.get('color_b')
    if color_b == None: color_b = 248

    
    isUpdate = False
    isUpdate = addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("BodyDiameter", "body diameter"))
    isUpdate = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    isUpdate = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("PinWidth", "pin width"))
    isUpdate = addin_utility.process_user_param(design, 'param_e', e, default_unit, _LCLZ("PinPitch", "pin pitch"))
    is_update = addin_utility.process_user_param(design, 'board_thickness', board_thickness, default_unit, _LCLZ("BoardThickness", "board thickness"))
    if isUpdate:
        #update the rgb appearance
        addin_utility.update_rgb_appearance(app, design, color_r, color_g, color_b, constant.COLOR_NAME_ECAP_BODY, constant.COLOR_PROP_ID_METAL)

        polarity_band = root_comp.features.itemByName('Band')
        polarity_band.timelineObject.rollTo(True)
        if polarityMarker:
            polarity_band.isSuppressed = False
        else:
            polarity_band.isSuppressed = True
        design.timeline.moveToEnd()

        marker = root_comp.features.itemByName('Marker')
        marker.timelineObject.rollTo(True)
        if polarityMarker:
            marker.isSuppressed = False
        else:
            marker.isSuppressed = True
        design.timeline.moveToEnd()

        return

    #Create body
    sketches = root_comp.sketches
    xzPlane = root_comp.xZConstructionPlane
    body_sketch = sketches.add(xzPlane)
    body_sketch.name = 'BodySketch'

    rect = fusion_sketch.create_center_point_rectangle(body_sketch,adsk.core.Point3D.create(D/4, -A/2, 0), 'param_D/4', 'param_A/2', adsk.core.Point3D.create(D/2, -A, 0), 'param_D/2', 'param_A')
    circle = fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create(D/2, -D/10 - A/10, 0),'param_D/2', 'param_D/10 + param_A/10',  D/10, 'param_D/10')

    line_collection = rect.item(3).trim(adsk.core.Point3D.create(D/2, -A/10 - D/10, 0))
    line_top = adsk.fusion.SketchLine.cast(line_collection.item(1))
    line_bottom = adsk.fusion.SketchLine.cast(line_collection.item(0))
    arc_collection = circle.trim(adsk.core.Point3D.create(D/2, -A/10 - D/10, 0))
    arc = adsk.fusion.SketchArc.cast(arc_collection.item(0))
    fillet = body_sketch.sketchCurves.sketchArcs.addFillet(line_top, line_top.startSketchPoint.geometry, arc, arc.endSketchPoint.geometry, fillet_amount)

    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(0.1, 0.1, 0), True).parameter.expression = 'param_D/30'
    fillet = body_sketch.sketchCurves.sketchArcs.addFillet(line_bottom, line_bottom.endSketchPoint.geometry, arc, arc.startSketchPoint.geometry, fillet_amount)

    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(0.1, 0.1, 0), True).parameter.expression = 'param_D/30'

    fillet = body_sketch.sketchCurves.sketchArcs.addFillet(rect.item(0), rect.item(0).startSketchPoint.geometry, line_top , line_top.startSketchPoint.geometry, fillet_amount)
 
    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(0.2, 0.1, 0), True).parameter.expression = 'param_D/30'
    fillet =body_sketch.sketchCurves.sketchArcs.addFillet(line_bottom, line_bottom.endSketchPoint.geometry, rect.item(2), rect.item(2).endSketchPoint.geometry, fillet_amount)

    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(-0.2, 0.1, 0), True).parameter.expression = 'param_D/30'

    #For offset
    lines = body_sketch.sketchCurves.sketchLines
    constraints = body_sketch.geometricConstraints

    line_top_off = lines.addByTwoPoints(rect.item(0).endSketchPoint, adsk.core.Point3D.create(D/2 + 0.002, A, 0))
    line_bottom_off = lines.addByTwoPoints(rect.item(2).startSketchPoint, adsk.core.Point3D.create(D/2 + 0.002, 0, 0 ))
    constraints.addHorizontal(line_top_off)
    constraints.addHorizontal(line_bottom_off)
    offset_name = (addin_utility.format_internal_to_default_unit(root_comp, 0.002))
 
    body_sketch.sketchDimensions.addDistanceDimension(line_top_off.startSketchPoint, line_top_off.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(D/4, A, 0)).parameter.expression = 'param_D/2 +' + offset_name
    body_sketch.sketchDimensions.addDistanceDimension(line_bottom_off.startSketchPoint, line_bottom_off.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         adsk.core.Point3D.create(D/4, 0, 0)).parameter.expression = 'param_D/2 +' + offset_name

    line_offset = lines.addByTwoPoints(line_top_off.endSketchPoint, line_bottom_off.endSketchPoint)
    circle = fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create(D/2 + 0.002, -D/10 - A/10, 0),'param_D/2 +'+ offset_name, 'param_D/10 + param_A/10',  D/10 - 0.002, 'param_D/10 -'+offset_name)
    line_collection = line_offset.trim(adsk.core.Point3D.create(D/2 + 0.002, -A/10 - D/10, 0))
    line_top = adsk.fusion.SketchLine.cast(line_collection.item(1))
    line_bottom = adsk.fusion.SketchLine.cast(line_collection.item(0))
    arc_collection = circle.trim(adsk.core.Point3D.create(D/2 + 0.002, -A/10 - D/10, 0))
    arc = adsk.fusion.SketchArc.cast(arc_collection.item(0))
    fillet = body_sketch.sketchCurves.sketchArcs.addFillet(line_top, line_top.startSketchPoint.geometry, arc, arc.startSketchPoint.geometry, fillet_amount)
 
    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(0.1, 0.1, 0), True).parameter.expression = 'param_D/30'

    fillet = body_sketch.sketchCurves.sketchArcs.addFillet(line_bottom, line_bottom.endSketchPoint.geometry, arc, arc.endSketchPoint.geometry, fillet_amount)

    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(0.1, 0.1, 0), True).parameter.expression = 'param_D/30'

    fillet = body_sketch.sketchCurves.sketchArcs.addFillet(line_top_off, line_top_off.startSketchPoint.geometry, line_top , line_top.startSketchPoint.geometry, fillet_amount)

    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(0.2, 0.1, 0), True).parameter.expression = 'param_D/30'
    fillet =body_sketch.sketchCurves.sketchArcs.addFillet(line_bottom, line_bottom.endSketchPoint.geometry, line_bottom_off, line_bottom_off.endSketchPoint.geometry, fillet_amount)

    body_sketch.sketchDimensions.addDiameterDimension(fillet, adsk.core.Point3D.create(-0.2, 0.1, 0), True).parameter.expression = 'param_D/30'

    #Revolving the body
    body_prof = body_sketch.profiles.item(0)
    revolves = root_comp.features.revolveFeatures
    rev_input = revolves.createInput(body_prof, rect.item(1), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    angle = adsk.core.ValueInput.createByReal(math.pi * 2)
    rev_input.setAngleExtent(False, angle)
    ext_body = revolves.add(rev_input)
    ext_body.name = 'RadialBody'

    #Giving color to the body
    addin_utility.apply_material(app, design, ext_body.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)
    addin_utility.apply_rgb_appearance(app, design, ext_body.bodies.item(0), color_r, color_g, color_b, constant.COLOR_NAME_ECAP_BODY)

    #Revolving the band
    band_prof = body_sketch.profiles.item(1)
    revolves = root_comp.features.revolveFeatures
    rev_input = revolves.createInput(band_prof, rect.item(1), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    band_angle = adsk.core.ValueInput.createByReal(math.pi/20)
    rev_input.setTwoSideAngleExtent(band_angle, band_angle)
    ext_band = revolves.add(rev_input)
    ext_band.name = 'Band'

    #Giving color to the band
    addin_utility.apply_material(app, design, ext_band.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)
    addin_utility.apply_rgb_appearance(app, design, ext_band.bodies.item(0), 190, 190, 190, constant.COLOR_NAME_ECAP_BAND)

    if not polarityMarker:
        ext_band.isSuppressed = True

    #creating top gap
    top_gap =  addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    top_gap.name = 'TopGap'
    top_gap_sketch = sketches.add(top_gap)
    top_gap_sketch.name = 'TopGapSketch'
    fusion_sketch.create_center_point_circle(top_gap_sketch, adsk.core.Point3D.create(0, 0, 0),'', '',  D - 8 * fillet_amount, 'param_D - 8 * param_D/30')
    ext_top_gap = top_gap_sketch.profiles.item(0)
    top_gap = fusion_model.create_extrude(root_comp,ext_top_gap, (addin_utility.format_internal_to_default_unit(root_comp, -0.01)), adsk.fusion.FeatureOperations.CutFeatureOperation )
    top_gap.name = 'TopGap'

    addin_utility.apply_appearance(app, design, top_gap.faces.item(0), constant.APPEARANCE_ID_ALUMINUM_POLISHED)
    addin_utility.apply_appearance(app, design, top_gap.faces.item(1), constant.APPEARANCE_ID_ALUMINUM_POLISHED)

    #Create terminals
    xyPlane = root_comp.xYConstructionPlane
    sketch_term = sketches.add(xyPlane)
    sketch_term.name = 'TerminalSketch'
    centerPoint = adsk.core.Point3D.create(e/2, 0, 0)
    fusion_sketch.create_center_point_circle(sketch_term, centerPoint, 'param_e/2', '', b, 'param_b')
    term = sketch_term.profiles.item(0)
    terminal = fusion_model.create_extrude(root_comp, term, '-1.2 * board_thickness -' + (addin_utility.format_internal_to_default_unit(root_comp, 0.0002)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    terminal.name = 'Terminal'
    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, terminal.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    fusion_model.create_mirror(root_comp, terminal, root_comp.yZConstructionPlane)

    #Creating black markers
    marker_sketch = sketches.add(xzPlane)
    marker_sketch.name = 'MarkerSketch'

    marker = fusion_sketch.create_center_point_rectangle(marker_sketch,adsk.core.Point3D.create(D/2 + 0.0021, - A/10 - 3 * D/20 - D/30 - 0.4/3 * (0.9 * A - 3/20 * D), 0),
                                        'param_D/2 +' +  (addin_utility.format_internal_to_default_unit(root_comp, 0.0021)), 
                                        'param_A/10 + 3/20 * param_D + param_D/30 + 0.4/3 * (0.9 * param_A - 3/20 * param_D)',
                                        adsk.core.Point3D.create(D/2 + 0.00205, - A/10 - 3 * D/20 - D/30 - 0.8/3 * (0.9 * A - 3/20 * D)),
                                         (addin_utility.format_internal_to_default_unit(root_comp, 0.0001)), '(9/10 * param_A - 3/20 * param_D) * 0.8/3')

    #Revolving the marker
    marker_prof = marker_sketch.profiles.item(0)
    revolves = root_comp.features.revolveFeatures
    rev_input = revolves.createInput(marker_prof, rect.item(1), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    marker_angle = adsk.core.ValueInput.createByReal(math.pi/60)
    rev_input.setTwoSideAngleExtent(marker_angle, marker_angle)
    ext_marker = revolves.add(rev_input)
    ext_marker.name = 'Marker'
    addin_utility.apply_material(app, design, ext_marker.bodies.item(0) , constant.MATERIAL_ID_ALUMINUM)
    addin_utility.apply_appearance(app, design, ext_marker.bodies.item(0), constant.APPEARANCE_ID_BODY_DEFAULT)

    #Create rectangular pattern based on extent
    marker_body = ext_marker.bodies.item(0)
    input_entites = adsk.core.ObjectCollection.create()
    input_entites.add(marker_body)
    zAxis = root_comp.zConstructionAxis
    quantity_one = adsk.core.ValueInput.createByString('3')
    distance_one = adsk.core.ValueInput.createByString('param_A - param_D/15 - 3/20 * param_D - param_A/10 - 0.8/3 * (0.9 * param_A - 3/20 * param_D)')
    rectangularPatterns = root_comp.features.rectangularPatternFeatures
    rectangularPatternInput = rectangularPatterns.createInput(input_entites, zAxis, quantity_one, distance_one, adsk.fusion.PatternDistanceType.ExtentPatternDistanceType)
    rectangularFeature = rectangularPatterns.add(rectangularPatternInput)
    rectangularFeature.name = 'Pattern'

    if not polarityMarker:
        ext_marker.isSuppressed = True

from .base import package_3d_model_base

class RadialEcap3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "radial_ecap"

    def create_model(self, params, design, component):
        radial_ecap(params, design, component)

package_3d_model_base.factory.register_package(RadialEcap3DModel.type(), RadialEcap3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    radial_ecap(params, design, target_comp)
