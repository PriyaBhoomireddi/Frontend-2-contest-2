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
        if name == 'color_r' and params[name] == None: #default body color as per family
            return 10
        if name == 'color_g' and params[name] == None:
            return 10
        if name == 'color_b' and params[name] == None:
            return 10
        else:
            return params[name]
    else:
        if (name == 'e'):
            return 0.08 #Pin Pitch
        if (name == 'N'):
            return 12 #Total Pins
        if (name == 'A'):
            return 0.07 #Body Height
        if (name == 'b'):
            return 0.055 #Vertical Terminal Width
        if (name == 'b1'):
            return 0.065 #Horizontal Terminal Width
        if (name == 'D'):
            return 0.538 #Body Length
        if (name == 'E'):
            return 0.24 #Body Width
        if (name == 'L'):
            return 0.055 #Vertical Terminal Length
        if (name == 'L1'):
            return 0.055 #Horizontal Terminal Length
        if (name == 'isFlatLead'):
            return 0
        if (name == 'color_r'):
            return 10
        if (name == 'color_g'):
            return 10
        if (name == 'color_b'):
            return 10

def user_param(root_comp, design, params, default_unit, get_param):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 =addin_utility.process_user_param(design, 'param_e', get_param(params, 'e'), default_unit, _LCLZ("PinPitch", "pin pitch"))
    res_2 = addin_utility.process_user_param(design, 'param_DPins', get_param(params, 'N'), '', _LCLZ("TotalPins", "total pins"))
    res_3 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    res_4 =addin_utility.process_user_param(design, 'param_b', get_param(params, 'b'), default_unit, _LCLZ("HorizontalTerminalWidth", "horizontal terminal width"))
    res_5 =addin_utility.process_user_param(design, 'param_b1', get_param(params, 'b1'), default_unit, _LCLZ("VerticalTerminalWidth", "vertical terminal width"))
    res_6 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_7 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_8 = addin_utility.process_user_param(design, 'param_L', get_param(params, 'L'), default_unit, _LCLZ("HorizontalTerminalLength", "horizontal terminal length"))
    res_9 = addin_utility.process_user_param(design, 'param_L1', get_param(params, 'L1'), default_unit, _LCLZ("VerticalTerminalLength", "vertical terminal length"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 or res_6 or res_7 or res_8 or res_9
    if isUpdate:
        rgb = adsk.core.Color.create(get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), 0)
        body_color = addin_utility.get_appearance(app, design, constant.COLOR_NAME_CHIP_BODY)
        color_prop = adsk.core.ColorProperty.cast(body_color.appearanceProperties.itemById(constant.COLOR_PROP_ID_DEFAULT))
        color_prop.value = rgb

        lead_hori = root_comp.features.itemByName('LeadHoriJoin')
        sketch_hori = root_comp.sketches.itemByName('PinSketchHori')

        hori_entity = adsk.core.ObjectCollection.create()
        hori_entity.add(sketch_hori.profiles.item(2))
        hori_entity.add(sketch_hori.profiles.item(0))

        lead_hori.timelineObject.rollTo(True)
        if get_param(params, 'isFlatLead'):
            lead_hori.profile = hori_entity
        else:
            lead_hori.profile = sketch_hori.profiles.item(2)

        dist_def_hori = adsk.fusion.DistanceExtentDefinition.cast(lead_hori.extentOne)
        hori_dist = adsk.fusion.ModelParameter.cast(dist_def_hori.distance)
        hori_dist.expression = 'param_A'
        design.timeline.moveToEnd()
            
        terminal = root_comp.features.itemByName('Terminal')
        sketch_vert = root_comp.sketches.itemByName('PinSketchVert')

        entity = adsk.core.ObjectCollection.create()
        entity.add(sketch_vert.profiles.item(1))
        entity.add(sketch_vert.profiles.item(0))

        terminal.timelineObject.rollTo(True)
        if get_param(params, 'isFlatLead'):
            terminal.profile = entity
        else:
            terminal.profile = sketch_vert.profiles.item(1)

        dist_def_vert = adsk.fusion.DistanceExtentDefinition.cast(terminal.extentOne)
        vert_dist = adsk.fusion.ModelParameter.cast(dist_def_vert.distance)
        vert_dist.expression = 'param_A'
        design.timeline.moveToEnd()

        return isUpdate

def create_body_sketch(root_comp, params):
    offsetValue = addin_utility.convert_internal_to_default_unit(root_comp, 0.001)
    #Create body sketch
    sketches = root_comp.sketches
    body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, (addin_utility.format_internal_to_default_unit(root_comp, 0.0005)))
    body_offset.name = 'BodyOffset'
    body_sketch = sketches.add(body_offset)
    E_param = 'param_E -' + (addin_utility.format_internal_to_default_unit(root_comp, 0.005))
    fusion_sketch.create_center_point_rectangle(body_sketch,adsk.core.Point3D.create(0, 0, 0) , '', '',  
                adsk.core.Point3D.create(get_param(params, 'E')/2 - offsetValue/2, get_param(params, 'D')/2, 0), E_param, 'param_D')
    
    return body_sketch

def create_body(root_comp, params, design, body_sketch):
    #Selecting the appropriate profile
    ext_body = body_sketch.profiles.item(0)
    body = fusion_model.create_extrude(root_comp,ext_body, 'param_A -' + str(addin_utility.format_internal_to_default_unit(root_comp, 0.0005)), adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    body.name = 'Body'
    mid_body = body.bodies.item(0)
    mid_body.name = 'ChipBody'
    # assign the pysical material to body.
    addin_utility.apply_material(app, design, mid_body, constant.MATERIAL_ID_CERAMIC)
    # assign the apparance to body
    addin_utility.apply_rgb_appearance(app, design, mid_body, get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_BODY)
   
def create_vertical_pin_sketch(root_comp, params):
    #Create vertical terminal sketch
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    pin_sketch_vert = sketches.add(xyPlane)
    pin_sketch_vert.name = 'PinSketchVert'
    pins = get_param(params, 'N') - 2
    #Create vertical terminals
    term_rect = fusion_sketch.create_center_point_rectangle(pin_sketch_vert, adsk.core.Point3D.create(get_param(params, 'E')/2 - get_param(params, 'L')/2 , -(get_param(params, 'e'))/2 * ((pins/2 + 1) % 2) , 0) , 'param_E/2 -param_L/2', 
                                         'param_e / 2 * ( ( (param_DPins  - 2)/ 2 + 1 ) % 2 ) ',adsk.core.Point3D.create(get_param(params, 'E')/2 , -(get_param(params, 'e'))/2 - (get_param(params, 'b'))/2, 0), 'param_L', 'param_b')
    
    #Draw circle
    b_param = 'param_b -' + (addin_utility.format_internal_to_default_unit(root_comp, 0.02))
    circle = fusion_sketch.create_center_point_circle(pin_sketch_vert, adsk.core.Point3D.create(get_param(params, 'E')/2 - get_param(params, 'L')/2 , -(get_param(params, 'e'))/2 * ((pins/2 + 1) % 2) , 0), 'param_E/2', 
                                                        'param_e / 2 * ( ( (param_DPins - 2) / 2 + 1 ) % 2 )', get_param(params, 'b') - 0.02, b_param)
    circle.trim(adsk.core.Point3D.create(get_param(params, 'E'), 0, 0))

    return pin_sketch_vert


def create_vertical_pins(root_comp, params, design, pin_sketch_vert):
    pins = get_param(params, 'N') - 2
    #selecting profile for cut extrude
    entitiy = adsk.core.ObjectCollection.create()
    entitiy.add(pin_sketch_vert.profiles.item(1))
    entitiy.add(pin_sketch_vert.profiles.item(0))

    #cutting spaces for terminal
    gap = fusion_model.create_extrude(root_comp, entitiy, 'param_A' , adsk.fusion.FeatureOperations.CutFeatureOperation )
    gap.name = 'GapVert'

    gap_pattern = fusion_model.create_mirror_and_pattern(root_comp, gap, 'param_e', "(param_DPins - 2 )/2", root_comp.yConstructionAxis, root_comp.yZConstructionPlane)
    gap_pattern.timelineObject.rollTo(True)
    gap_pattern.isSymmetricInDirectionOne = True
    design.timeline.moveToEnd()
    gap_pattern.name = 'GapPattern'

    #Choosing profile based on lead shape
    if get_param(params, 'isFlatLead'):
        profile = adsk.core.ObjectCollection.create()
        profile.add(pin_sketch_vert.profiles.item(0))
        profile.add(pin_sketch_vert.profiles.item(1))
    else:
        profile = pin_sketch_vert.profiles.item(1)

    ext_terminal = fusion_model.create_extrude(root_comp, profile, 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    ext_terminal.name = 'Terminal'

    # assign pysical material to terminal
    addin_utility.apply_material(app, design, ext_terminal.bodies.item(0), constant.MATERIAL_ID_TIN)

    #Create pattern and mirror
    pin_pattern = fusion_model.create_mirror_and_pattern(root_comp, ext_terminal, 'param_e', "(param_DPins - 2 )/2", root_comp.yConstructionAxis, root_comp.yZConstructionPlane)
    pin_pattern.timelineObject.rollTo(True)
    pin_pattern.isSymmetricInDirectionOne = True
    design.timeline.moveToEnd()
    pin_pattern.name = 'PinPattern'

def create_horizontal_pin_sketch(root_comp, params):
    #Create horizontal pin sketch
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    pin_sketch_hori = sketches.add(xyPlane)
    pin_sketch_hori.name = 'PinSketchHori'

    fusion_sketch.create_center_point_rectangle(pin_sketch_hori, adsk.core.Point3D.create(0, get_param(params, 'D')/2 - get_param(params, 'L1')/2, 0) , '' , 'param_D/2 - param_L1/2',
                                                         adsk.core.Point3D.create(get_param(params, 'b1')/2, get_param(params, 'D')/2, 0), 'param_b1', 'param_L1')
    
    b1_param = 'param_b1 -' + (addin_utility.format_internal_to_default_unit(root_comp, 0.02))
    circle = fusion_sketch.create_center_point_circle(pin_sketch_hori, adsk.core.Point3D.create(0, get_param(params, 'D')/2, 0), '', 'param_D/2',
                                                        get_param(params, 'b1') - 0.02, b1_param)

    return pin_sketch_hori

def create_horizontal_pins(root_comp, params, design, pin_sketch_hori):
    entities = adsk.core.ObjectCollection.create()
    entities.add(pin_sketch_hori.profiles.item(0))
    entities.add(pin_sketch_hori.profiles.item(2))
    gap = fusion_model.create_extrude(root_comp, entities, 'param_A', adsk.fusion.FeatureOperations.CutFeatureOperation )
    gap.name = 'GapHori'
    mirror = fusion_model.create_mirror(root_comp, gap, root_comp.xZConstructionPlane)
    mirror.name = 'GapMirrorHori'

    if get_param(params, 'isFlatLead'):
        profile = adsk.core.ObjectCollection.create()
        profile.add(pin_sketch_hori.profiles.item(0))
        profile.add(pin_sketch_hori.profiles.item(2))
    else:
        profile = pin_sketch_hori.profiles.item(2)

    ext_terminal = fusion_model.create_extrude(root_comp, profile, 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
 
    # assign pysical material to terminal
    addin_utility.apply_material(app, design, ext_terminal.bodies.item(0), constant.MATERIAL_ID_TIN)

    #Create mirror
    ext_terminal.name = 'LeadHoriJoin'
    mirror_hori = fusion_model.create_mirror(root_comp, ext_terminal, root_comp.xZConstructionPlane)
    mirror_hori.name = 'MirrorHori'

def chiparray4sideflat(params, design = None, target_comp = None):

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
    param_updated = user_param(root_comp, design, params, default_unit, get_param)
    if param_updated == True:
        return

    #Create body sketch
    body_sketch = create_body_sketch(root_comp, params)
    #Create body
    create_body(root_comp, params, design, body_sketch)
    #Create vertical terminal sketch
    vert_pin_sketch = create_vertical_pin_sketch(root_comp, params)
    #Create vertical terminals
    create_vertical_pins(root_comp, params, design, vert_pin_sketch)
    #Create horizontal terminal sketch
    hori_pin_sketch = create_horizontal_pin_sketch(root_comp, params)
    #Create horizontal terminal
    create_horizontal_pins(root_comp, params, design, hori_pin_sketch)


class ChipArray4SideFlat3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "chiparray4sideflat"

    def create_model(self, params, design, component):
        chiparray4sideflat(params, design, component)

package_3d_model_base.factory.register_package(ChipArray4SideFlat3DModel.type(), ChipArray4SideFlat3DModel) 

def run(context):
    ui = app.userInterface
    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    chiparray4sideflat(params, design, target_comp)
