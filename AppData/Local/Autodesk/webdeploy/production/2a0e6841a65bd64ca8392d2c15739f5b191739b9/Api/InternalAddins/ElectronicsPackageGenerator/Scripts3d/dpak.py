import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_model
from ..Utilities import fusion_sketch
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()
                        
def apply_truncate(root_comp, A, E, E1, L1, b):
    extrudes = root_comp.features.extrudeFeatures
    pin_cut_plane_xy = root_comp.xYConstructionPlane
    pin_cut_plane_xy.name = 'PinCutPlaneXy'
    sketch_truncate_pin = root_comp.sketches.add(pin_cut_plane_xy)
    sketch_truncate_pin.name = 'SketchTruncatePin'

    center_point = adsk.core.Point3D.create(-E/2,0, 0)
    end_point = adsk.core.Point3D.create(-E/2+(E/2-E1-L1)*0.75, -b/2, 0)
    fusion_sketch.create_center_point_rectangle(sketch_truncate_pin, center_point, 'param_E/2', '', end_point, '(param_E-param_E1-param_L1)*1.5', 'param_b')
    prof = sketch_truncate_pin.profiles[0]

    #prof = centerPointRectBody(None, adsk.core.Point3D.create(-E/2,0, 0), sketch_truncate_pin, -b/2, -E/2+(E/2-E1-L1)*0.75, A, 'param_b', '(param_E-param_E1-param_L1)*1.5')
    truncate = extrudes.addSimple(prof, adsk.core.ValueInput.createByReal(A), adsk.fusion.FeatureOperations.CutFeatureOperation)
    truncate.name = 'Truncate'                                                     
def dpak(params, design = None, targetComponent = None):
    A = params.get('A') or 0.2 #Body Height
    D = params.get('D') or 0.8395 #Lead Span
    E = params.get('E') or 1.054 #Body length
    E1 = params.get('E1') or 0.7015 #Body width
    E2 = params['E2'] if 'E2' in params else 0.649 #odd terminal length
    e = params['e'] if 'e' in params else 0.254 #Terminal width
    L = params['L'] if 'L' in params else 0.0915 #Terminal length
    L1 = params['L1'] if 'L1' in params else 0.101 #odd terminal length outside body
    b = params['b'] if 'b' in params else 0.071 #Terminal thickness
    b1 = params['b1'] if 'b1' in params else 0.559 #Terminal thickness
    pins = params['DPins'] if 'DPins' in params else 4
    #Flag whether the middle pin is truncated or not for
    truncated_flag = params['truncatedFlag'] if 'truncatedFlag' in params else 0
		 #Middle pin total length
    L2 = params['L2'] if 'L2' in params else 0.1016
    #p = min(D1/5,1) # Polarity band size
    #normal value of terminal thickness from JEDEC doc, or calculate avg(min,max)
    c = 0.02

    if('terminalThickness' not in params):
        terminal_thickness = c
    else:
        if(params['terminalThickness']<0):
            terminal_thickness = c
        else:
            terminal_thickness = min(params['terminalThickness'],c)

    front_feet_num = 'param_DPins-1'

    chamfer_distance = '(param_A - param_terminalThickness)/2'
    chamfer_distance1 = 'param_A/10'
    chamfer_distance2 = '(param_A - param_terminalThickness)'

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design.
    root_comp = design.rootComponent

    if targetComponent:
        root_comp = targetComponent
        #paramatric thermal pad handling with addin
        truncate = root_comp.features.itemByName('Truncate')
        truncate_sketch = root_comp.sketches.itemByName('SketchTruncatePin')
        if truncate != None:
            truncate.deleteMe()
            truncate_sketch.deleteMe()
             
    unitsMgr = design.unitsManager
    mm = unitsMgr.defaultLengthUnits
    is_update = False
    A1 = 0 #used for reuse of gull wing :cab be removed
    is_update = addin_utility.process_user_param(design, 'param_A', A, mm, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_A1', A1, mm, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_E', E, mm, _LCLZ("Span", "span"))
    is_update = addin_utility.process_user_param(design, 'param_E1', E1, mm, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, mm, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_e', e, mm, _LCLZ("Pitch", "pitch"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, mm, _LCLZ("TerminalLength", "terminal length"))
    is_update = addin_utility.process_user_param(design, 'param_b1', b1, mm, _LCLZ("TabWidth", "tab width"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, mm, _LCLZ("TerminalWidth", "terminal width"))
    is_update = addin_utility.process_user_param(design, 'param_L1', L1, mm, _LCLZ("ThermalPadLength", "thermal pad length"))
    is_update = addin_utility.process_user_param(design, 'param_E2', E2, mm, _LCLZ("ThermalPadWidth", "thermal pad width"))
    is_update = addin_utility.process_user_param(design, 'param_terminalThickness', terminal_thickness, mm, _LCLZ("TerminalThickness", "terminal thickness"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', pins, '', _LCLZ("Pins", "pins"))
    if truncated_flag ==1 and is_update:
        apply_truncate(root_comp, A, E, E1, L1, b)
    # the paramters are already there, just update the models with the paramters. will skip the model creation process. 
    if is_update: return
            
    # Create a construction plane by offset
    sketches = root_comp.sketches

    body_plane_yz = addin_utility.create_offset_plane(root_comp,root_comp.yZConstructionPlane, 'param_E/2-param_E1-param_L1')
    body_plane_yz.name = 'BodyPlaneYz'
    sketch_body = sketches.add(body_plane_yz)
    sketch_body.name = 'SketchBody'

    front_pin_plane_xz = addin_utility.create_offset_plane(root_comp,root_comp.xZConstructionPlane, 'param_e/2 * (param_DPins-2)')
    front_pin_plane_xz.name = 'FrontPinPlaneXz'
    sketch_front_pin = sketches.add(front_pin_plane_xz)
    sketch_front_pin.name = 'SketchFrontPin'
    
    #thermal
    tab_pin_plane_yz = addin_utility.create_offset_plane(root_comp,root_comp.yZConstructionPlane, 'param_E/2-param_E2')
    tab_pin_plane_yz.name = 'TabPinPlaneYz'
    sketch_tab_pin = sketches.add(tab_pin_plane_yz)
    sketch_tab_pin.name = 'SketchTabPin'
    
    pinOneMarkPlaneYZ = addin_utility.create_offset_plane(root_comp,root_comp.yZConstructionPlane, 'param_E/2-param_E1-param_L1+param_A/10+param_D/10')
    pinOneMarkPlaneYZ.name = 'Pinonemarkplaneyz'
    sketch_pin_one_mark = sketches.add(pinOneMarkPlaneYZ)
    sketch_pin_one_mark.name = 'SketchPinOneMark'
        
    extrudes = root_comp.features.extrudeFeatures
    
    #body
    center_point = adsk.core.Point3D.create(-A/2,0,0)
    end_point = adsk.core.Point3D.create(-A,D/2,0)
    fusion_sketch.create_center_point_rectangle(sketch_body, center_point, 'param_A/2', '', end_point, 'param_A', 'param_D')
    prof = sketch_body.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body = extrudes.addSimple(prof, adsk.core.ValueInput.createByString('param_E1'), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    body.name = 'Body'
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)
    
    #Chamfer
    edge_back = adsk.core.ObjectCollection.create()
    back_face = body.endFaces[0]
    back_edges = back_face.edges
    edge_back.add(back_edges[3])
    
    edge_front = adsk.core.ObjectCollection.create()
    frontFace = body.startFaces[0]
    front_edges = frontFace.edges
    edge_front.add(front_edges[1])
    edge_front.add(front_edges[3])
    
    chamfer_back = root_comp.features.chamferFeatures
    chamfer_front = root_comp.features.chamferFeatures
    chamfer_back_input = chamfer_back.createInput(edge_back, True)
    chamfer_back_input.setToTwoDistances(adsk.core.ValueInput.createByString(chamfer_distance2), adsk.core.ValueInput.createByString(chamfer_distance1 + '*2'))
    chamfer_front_input = chamfer_front.createInput(edge_front, True)
    chamfer_front_input.setToTwoDistances(adsk.core.ValueInput.createByString(chamfer_distance), adsk.core.ValueInput.createByString(chamfer_distance1))

    chamfer_front.add(chamfer_back_input)
    chamfer_back.add(chamfer_front_input)
    
    #normal pins
    body_center_z = A/2
    lead_slope =  math.tan(math.pi/15) * (A/2-terminal_thickness/2)
    fusion_sketch.create_gull_wing_lead(sketch_front_pin, E, 'param_E/2', -2*(E/2-E1-L1), '-(param_E/2-param_E1-param_L1)', body_center_z, terminal_thickness, L, lead_slope)

    prof = sketch_front_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    distance = adsk.core.ValueInput.createByString('param_b')
    ext_input.setSymmetricExtent(distance, True)
    common_pin = extrudes.add(ext_input)
    common_pin.name = 'CommonPin'
    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, common_pin.bodies.item(0), constant.MATERIAL_ID_TIN)

    fusion_model.create_one_direction_pattern(root_comp, common_pin.bodies.item(0), '-param_e', front_feet_num, root_comp.yConstructionAxis)

    # thermal pin
    center_point = adsk.core.Point3D.create((-terminal_thickness+0.0002)/2,0,0)
    end_point = adsk.core.Point3D.create(0.0002,b1/2,0)
    fusion_sketch.create_center_point_rectangle(sketch_tab_pin, center_point, '(param_terminalThickness-0.0002)/2', '', end_point, 'param_terminalThickness', 'param_b1')
    prof = sketch_tab_pin.profiles[0]
    ext_input = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    tabPin = extrudes.addSimple(prof, adsk.core.ValueInput.createByString('param_E2'), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    tabPin.name = 'Tabpin'
    # assign the pysical material to pin.
    addin_utility.apply_material(app, design, tabPin.bodies.item(0), constant.MATERIAL_ID_TIN)

    #Chamfer
    edge_top = adsk.core.ObjectCollection.create()
    top_face = tabPin.endFaces[0]
    topEdges = top_face.edges
    edge_top.add(topEdges[1])
    edge_top.add(topEdges[3])
    chamfer_feats = root_comp.features.chamferFeatures
    chamfer_top = chamfer_feats.createInput(edge_top, True)
    chamfer_top.setToEqualDistance(adsk.core.ValueInput.createByString('param_E2/10'))
    chamfer = chamfer_feats.add(chamfer_top)
    
    #truncate middle pin                                               
    if truncated_flag ==1:
        apply_truncate(root_comp, A, E, E1, L1, b) 

    #pin one mark
    mark_radius = 1/20 * D
    mark_center = adsk.core.Point3D.create(0, D/2-A/10-D/10, A*0.9)
    sketch_points = sketch_pin_one_mark.sketchPoints
    sk_center = sketch_points.add(mark_center)
    sketch_mark = sketch_pin_one_mark.sketchCurves.sketchCircles.addByCenterRadius(sk_center, mark_radius)
     
    sketch_prof = adsk.core.ObjectCollection.create()
    sketch_prof.add(sketch_mark)
    # Create a move feature
    transform = adsk.core.Matrix3D.create()
    transform.setToRotation(-math.pi/2, adsk.core.Vector3D.create(0,1,0), adsk.core.Point3D.create(0,0,0))
    sketch_pin_one_mark.move(sketch_prof, transform)
    
    prof = sketch_pin_one_mark.profiles[0]
    extrudeInput = extrudes.createInput(prof, adsk.fusion.FeatureOperations.CutFeatureOperation)

    #get top face of body for pin one marking extent
    sideface_faces = body.sideFaces
    marking_face = None
    current_face_point = 0
    for face in sideface_faces:
        point = face.pointOnFace
        if point and (point.z > current_face_point):
            current_face_point = point.z
            marking_face = face

    isChained = False
    extent_toentity = adsk.fusion.ToEntityExtentDefinition.create(marking_face, isChained)
    extrudeInput.setOneSideExtent(extent_toentity, adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrudes.add(extrudeInput)

    lines = sketch_pin_one_mark.sketchCurves.sketchLines
    line_c = lines.addByTwoPoints(adsk.core.Point3D.create(0, 0, 0), adsk.core.Point3D.create(-0.1, 0, 0))
    sketch_pin_one_mark.sketchDimensions.addDistanceDimension(line_c.startSketchPoint, sk_center, 
                                                        adsk.fusion.DimensionOrientations.VerticalDimensionOrientation, 
                                                        adsk.core.Point3D.create(1, 0, 0)).parameter.expression = 'param_D/2-param_A/10-param_D/10'
    sketch_pin_one_mark.sketchDimensions.addDistanceDimension(line_c.startSketchPoint, sk_center, 
                                                        adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation, 
                                                        adsk.core.Point3D.create(1, 0, 0)).parameter.expression = 'param_A*0.9'
    sketch_pin_one_mark.sketchDimensions.addRadialDimension(sketch_pin_one_mark.sketchCurves[0],
                                                     adsk.core.Point3D.create(0.1, 0, 0)).parameter.expression = 'param_D/20'

from .base import package_3d_model_base

class Dpak3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "dpak"

    def create_model(self, params, design, component):
        dpak(params, design, component)

package_3d_model_base.factory.register_package(Dpak3DModel.type(), Dpak3DModel)                                              

def run(context):
    ui = app.userInterface
    
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, targetComponent = None):
    dpak(params, design, targetComponent)