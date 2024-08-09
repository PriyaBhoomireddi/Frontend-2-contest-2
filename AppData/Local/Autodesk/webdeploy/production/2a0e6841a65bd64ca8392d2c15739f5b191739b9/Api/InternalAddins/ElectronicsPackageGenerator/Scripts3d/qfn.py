import adsk.core,traceback, adsk.fusion, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ

app = adsk.core.Application.get()


def create_chamfer(root_comp, ext, distance):
    edge_top = adsk.core.ObjectCollection.create()
    top_face = ext.startFaces[0]
    top_edges = top_face.edges
    for edgeI  in top_edges:
        edge_top.add(edgeI)

    chamfer_feats = root_comp.features.chamferFeatures
    chamfer_top = chamfer_feats.createInput(edge_top, True)
    chamfer_top.setToEqualDistance(adsk.core.ValueInput.createByString(distance))
    return chamfer_feats.add(chamfer_top)

def create_fillet(root_comp, ext, distance, face_index):
    fillets = root_comp.features.filletFeatures
    edgeBottom = adsk.core.ObjectCollection.create()
    bottomEdges1 = ext.bodies[0].faces[face_index].edges[0]
    bottomEdges2 = ext.bodies[0].faces[face_index].edges[2]
    edgeBottom.add(bottomEdges1)
    edgeBottom.add(bottomEdges2)

    radius1 = adsk.core.ValueInput.createByString(distance)
    input2 = fillets.createInput()
    input2.addConstantRadiusEdgeSet(edgeBottom, radius1, True)
    input2.isG2 = False
    input2.isRollingBallCorner = True
    fillet2 = fillets.add(input2)

def qfn(params, design = None, target_comp = None):

    e  =params.get('e') or 0.05 # pin pitch (e)
    L = params.get('L') or 0.04 # pin length(L)
    b = params.get('b') or 0.03 # pin width (b)
    E = params.get('D') or 0.51 # body length (D)
    D = params.get('E') or 0.41 # body width (E)
    A = params.get('A') or 0.1 # body height (A)
    EPins = params.get('DPins') or 8  # pin D side (DPins)
    DPins = params.get('EPins') or 6  # pin E side (EPins)
    E1 = params.get('D1') or 0.32 # Thermal pad length(D1)
    D1 = params.get('E1') or 0.42 # Thermal pad width(E1)
    thermal = params['thermal'] if 'thermal' in params else 0 #thermal pad boolean

    if not design:
        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = app.activeProduct

    # Get the root component of the active design
    root_comp = design.rootComponent
    if target_comp:
        root_comp = target_comp

    # get default system unit.
    default_unit = design.unitsManager.defaultLengthUnits

    is_update = False
    is_update = addin_utility.process_user_param(design, 'param_e', e, default_unit, _LCLZ("PinPitch", "pin pitch"))
    is_update = addin_utility.process_user_param(design, 'param_L', L, default_unit, _LCLZ("PinLength", "pin length"))
    is_update = addin_utility.process_user_param(design, 'param_b', b, default_unit, _LCLZ("PinWidth", "pin width"))
    is_update = addin_utility.process_user_param(design, 'param_D', D, default_unit, _LCLZ("BodyLength", "body length"))
    is_update = addin_utility.process_user_param(design, 'param_E', E, default_unit, _LCLZ("BodyWidth", "body width"))
    is_update = addin_utility.process_user_param(design, 'param_A', A, default_unit, _LCLZ("BodyHeight", "body height"))
    is_update = addin_utility.process_user_param(design, 'param_DPins', DPins, '', _LCLZ("DPins", "D pins"))
    is_update = addin_utility.process_user_param(design, 'param_EPins', EPins, '', _LCLZ("EPins", "E pins"))
    is_update = addin_utility.process_user_param(design, 'param_D1', D1, default_unit, _LCLZ("ThermalPadLength", "thermal pad length"))
    is_update = addin_utility.process_user_param(design, 'param_E1', E1, default_unit, _LCLZ("ThermalPadWidth", "thermal pad width"))
    if is_update:
        thermal_pad = root_comp.features.itemByName('ThermalPad')
        if thermal:
            thermal_pad.isSuppressed = False
        else:
            thermal_pad.isSuppressed = True

        return

    #Create offset plane for body
    body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    body_offset.name = 'BodyOffset'
    sketches = root_comp.sketches

    #Create body
    terminal_thickness = (addin_utility.format_internal_to_default_unit(root_comp, 0.005))
    terminal_thick = (addin_utility.format_internal_to_default_unit(root_comp, 0.005/2))
    body_sketch = sketches.add(body_offset)
    fusion_sketch.create_center_point_rectangle(body_sketch, adsk.core.Point3D.create(0, 0, 0), '', '', adsk.core.Point3D.create(E/2, D/2, 0), 
                                                                                                'param_E', 'param_D')
    ext_body = body_sketch.profiles.item(0)
    body = fusion_model.create_extrude(root_comp,ext_body, '-param_A +' + terminal_thickness, adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    body.name = 'Body'
    addin_utility.apply_material(app, design, body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)
    body_chamfer = create_chamfer(root_comp, body, '0.1 * (param_A -' + terminal_thickness + ')')
    body_chamfer.name = 'BodyChamfer'

    #Draw PIN1 marker on body
    pin1_sketch = sketches.add(body_offset)
    pin1_sketch.isComputeDeferred = True
    center_point = adsk.core.Point3D.create(-E/2 + 0.03 , D/2 - 0.03, 0)
    fusion_sketch.create_center_point_circle(pin1_sketch, center_point, 'param_E/2 - 0.3', 'param_D/2 - 0.3', 0.3, '0.3')
    pin1_sketch.isComputeDeferred = False
    ext_pin_one = pin1_sketch.profiles.item(0)
    pin_one = fusion_model.create_extrude(root_comp, ext_pin_one, (addin_utility.format_internal_to_default_unit(root_comp, -0.01)), 
                                                                                    adsk.fusion.FeatureOperations.CutFeatureOperation)

    #Draw D pins

    #create an offset plane
    Dpins_offset = addin_utility.create_offset_plane(root_comp, root_comp.xZConstructionPlane, '(param_DPins - 1) * param_e/2 - param_b/2')
    Dpins_offset.name = 'DpinsOffset'

    #create one part of sketch for D pins
    Dpin_sketch = sketches.add(Dpins_offset)
    Dpin_sketch.isComputeDeferred = True
    center_point = adsk.core.Point3D.create(E/2 - L/2, -0.005/2, 0)
    end_point = adsk.core.Point3D.create(E/2 , 0.005, 0)
    fusion_sketch.create_center_point_rectangle(Dpin_sketch, center_point, 'param_E/2 - param_L/2', terminal_thick, 
                                                end_point, 'param_L', terminal_thickness)

    #create another part for D pins
    center_point = adsk.core.Point3D.create(E/2 + 0.0001/2, -(0.005 + 0.01)/2, 0)
    end_point = adsk.core.Point3D.create(E/2 + 0.001 , 0.005 + 0.01, 0)
    x_axis = 'param_E/2 +' + (addin_utility.format_internal_to_default_unit(root_comp, 0.0001/2))
    y_axis = terminal_thick + '+' + (addin_utility.format_internal_to_default_unit(root_comp, 0.01/2))
    x_param = (addin_utility.format_internal_to_default_unit(root_comp, 0.0001))
    y_param = terminal_thickness + '+' + (addin_utility.format_internal_to_default_unit(root_comp, 0.01))
    fusion_sketch.create_center_point_rectangle(Dpin_sketch, center_point, x_axis, y_axis, end_point, x_param, y_param)

    #extrude the pin by creating a collection of profiles
    profile = adsk.core.ObjectCollection.create()
    profile.add(Dpin_sketch.profiles.item(0))
    profile.add(Dpin_sketch.profiles.item(1))
    #create the extrusion
    D_pin = fusion_model.create_extrude(root_comp, profile, 'param_b', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    D_pin.name = 'D Pin'
    addin_utility.apply_material(app, design, D_pin.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, D_pin.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    #create fillet for the pin structure
    create_fillet(root_comp, D_pin, 'param_b/2', 3)

    #Creating pattern and mirror to create rest of the pins
    pattern_Dpins = fusion_model.create_mirror_and_pattern(root_comp, D_pin.bodies.item(0), '-param_e', 'param_DPins', 
                                                            root_comp.yConstructionAxis, root_comp.yZConstructionPlane) 
    pattern_Dpins.name = 'DPinPattern'

    #Draw E Pins
    #create an offset plane
    Epins_offset = addin_utility.create_offset_plane(root_comp, root_comp.yZConstructionPlane, '(param_EPins - 1) * param_e/2 - param_b/2')
    Epins_offset.name = 'EpinsOffset'

    #create one part of sketch for E pins
    Epin_sketch = sketches.add(Epins_offset)
    Epin_sketch.isComputeDeferred = True
    center_point = adsk.core.Point3D.create(-0.005/2, D/2 - L/2, 0)
    end_point = adsk.core.Point3D.create(-0.005, D/2,0)
    fusion_sketch.create_center_point_rectangle(Epin_sketch, center_point, terminal_thick, 
                                                    'param_D/2 - param_L/2', end_point, terminal_thickness, 'param_L')

    #create another part for D pins
    center_point = adsk.core.Point3D.create(-(0.005 + 0.01)/2, D/2 + 0.0001/2, 0)
    end_point = adsk.core.Point3D.create(0.005 + 0.01, D/2 + 0.001, 0)
    y_axis = 'param_D/2 +' + (addin_utility.format_internal_to_default_unit(root_comp, 0.0001/2))
    z_axis = terminal_thick + '+' + (addin_utility.format_internal_to_default_unit(root_comp, 0.01/2))
    y_param = (addin_utility.format_internal_to_default_unit(root_comp, 0.0001))
    z_param = terminal_thickness + '+' + (addin_utility.format_internal_to_default_unit(root_comp, 0.01))
    fusion_sketch.create_center_point_rectangle(Epin_sketch, center_point, z_axis, y_axis, end_point, z_param, y_param)

    #extrude the pin by creating a collection of profiles
    profile = adsk.core.ObjectCollection.create()
    profile.add(Epin_sketch.profiles.item(0))
    profile.add(Epin_sketch.profiles.item(1))
    #create the extrusion
    E_pin = fusion_model.create_extrude(root_comp, profile, 'param_b', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    E_pin.name = 'E Pin'
    addin_utility.apply_material(app, design, E_pin.bodies.item(0), constant.MATERIAL_ID_COPPER_ALLOY)
    # assign the apparance to pin
    addin_utility.apply_appearance(app, design, E_pin.bodies.item(0), constant.APPEARANCE_ID_NICKEL_POLISHED)

    #create fillet for the pin structure
    create_fillet(root_comp, E_pin, 'param_b/2', 0)

    #Creating pattern and mirror to create rest of the pins
    pattern_Epins = fusion_model.create_mirror_and_pattern(root_comp, E_pin.bodies.item(0), '-param_e', 'param_EPins', 
                                                            root_comp.xConstructionAxis, root_comp.xZConstructionPlane) 
    pattern_Epins.name = 'EPinPattern'

    #draw thermal pad
    addin_utility.create_thermal_pad(app, root_comp, '0', adsk.core.Point3D.create(0, 0, 0), '', '', adsk.core.Point3D.create(E1/2, D1/2, 0), 
                                            'param_E1', 'param_D1', terminal_thickness, thermal)


from .base import package_3d_model_base

class Qfn3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "qfn"

    def create_model(self, params, design, component):
        qfn(params, design, component)

package_3d_model_base.factory.register_package(Qfn3DModel.type(), Qfn3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    qfn(params, design, target_comp)
