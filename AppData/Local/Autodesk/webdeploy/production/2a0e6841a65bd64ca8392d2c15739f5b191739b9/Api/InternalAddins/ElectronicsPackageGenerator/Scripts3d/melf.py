import adsk.core,traceback, adsk.fusion, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ
from .base import package_3d_model_base

app = adsk.core.Application.get()


def get_param(params, name):
    if name in params:
        if name == 'color_r' and params[name] == None:
            return 10
        if name == 'color_g' and params[name] == None:
            return 10
        if name == 'color_b' and params[name] == None:
            return 10
        else:
            return params[name]
    else:
        if (name == 'E'):
            return 0.16 #Body Width
        if (name == 'D'):
            return 0.37 #Body length
        if (name == 'L'):
            return 0.05 #bandwidth range
        if(name == 'isPolarized'):
            return 0
        if (name == 'color_r'):
            return 10
        if (name == 'color_g'):
            return 10
        if (name == 'color_b'):
            return 10

def user_param(design, params, default_unit, root_comp):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_2 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_3 = addin_utility.process_user_param(design, 'param_L', get_param(params, 'L'), default_unit, _LCLZ("BandwidthRange", "bandwidth range"))
    isUpdate = res_1  or res_2 or res_3
    if isUpdate:
        inner_body = root_comp.features.itemByName('InnerBody')
        outer_body = root_comp.features.itemByName('OuterBody')
        band = root_comp.features.itemByName('Band')            
        if get_param(params, 'isPolarized'):
            band.isSuppressed = False
            addin_utility.apply_material(app, design, outer_body.bodies.item(0), constant.MATERIAL_ID_GLASS)
            addin_utility.apply_appearance(app, design, outer_body.bodies.item(0), constant.APPEARANCE_ID_GLASS_CLEAR)
            addin_utility.apply_rgb_appearance(app, design, inner_body.bodies.item(0),get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_MELF_BODY)              
            addin_utility.apply_rgb_appearance(app, design, band.bodies.item(0), 10, 10, 10, constant.COLOR_NAME_MELF_BAND)
        else:
            band.isSuppressed = True
            addin_utility.apply_material(app, design, outer_body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)
            addin_utility.apply_appearance(app, design, outer_body.bodies.item(0),constant.APPEARANCE_ID_BODY_DEFAULT)                    
        
    return isUpdate

def create_body_sketch(root_comp, params):
    sketches = root_comp.sketches
    #Create body
    end_body_offset = addin_utility.create_offset_plane(root_comp, root_comp.yZConstructionPlane, 'param_D/2 - param_L')
    end_body_offset.name = 'EndBodyOffset'
    end_body_sketch = sketches.add(end_body_offset)
    end_body_sketch.name = 'EndBodySketch'
    
    sketchpoints = end_body_sketch.sketchPoints
    sk_center = sketchpoints.add(adsk.core.Point3D.create(-(get_param(params, 'E'))/2, 0, 0))
    
    # Draw circles and extrude them.
    circles = end_body_sketch.sketchCurves.sketchCircles
    circle2 = circles.addByCenterRadius(sk_center, (get_param(params, 'E'))*0.035)
    #Give the radial dimension
    end_body_sketch.sketchDimensions.addDiameterDimension(circle2, fusion_sketch.get_dimension_text_point(circle2), 
                                                        True).parameter.expression = 'param_E * 0.77'
    end_body_sketch.sketchDimensions.addDistanceDimension(end_body_sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(end_body_sketch.originPoint)).parameter.expression = 'param_E/2'
    end_body_sketch.sketchDimensions.addDistanceDimension(end_body_sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         fusion_sketch.get_dimension_text_point(end_body_sketch.originPoint)).parameter.expression = '0'

    circle1 = circles.addByCenterRadius(sk_center, get_param(params, 'E') * 0.04)
    end_body_sketch.sketchDimensions.addDiameterDimension(circle1, fusion_sketch.get_dimension_text_point(circle1), 
                                                        True).parameter.expression = 'param_E * 0.8'        
    return end_body_sketch

def create_body(root_comp, params, design, body_sketch):
    #extrude the bodies
    inner_prof = body_sketch.profiles.item(0)
    inner_body = fusion_model.create_extrude(root_comp, inner_prof, '-(param_D - 2 * param_L)', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    inner_body.name = 'InnerBody'
    addin_utility.apply_material(app, design, inner_body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)

    #get the proper profile
    for profile_i in body_sketch.profiles:
        if profile_i.profileLoops.count == 2: 
            outer_prof = profile_i

    outer_body = fusion_model.create_extrude(root_comp, outer_prof, '-(param_D - 2 * param_L)', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    outer_body.name = 'OuterBody'
    addin_utility.apply_material(app, design, outer_body.bodies.item(0), constant.MATERIAL_ID_GLASS)

    body_appear = design.appearances.itemByName(constant.COLOR_NAME_MELF_BODY)
    if body_appear == None:  # the appearance in design match the name, assign it
        lib = app.materialLibraries.itemById(constant.APPEARANCE_LIB_ID)
        lib_appear = lib.appearances.itemById(constant.APPEARANCE_ID_ALUMINUM_POLISHED)
        design.appearances.addByCopy(lib_appear, constant.COLOR_NAME_MELF_BODY) 
   
    addin_utility.apply_rgb_appearance(app, design, inner_body.bodies.item(0),  get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_MELF_BODY)
    return outer_body

    
def create_terminal_sketch(root_comp, params):
    # Create Terminal
    sketches = root_comp.sketches
    terminal_offset = addin_utility.create_offset_plane(root_comp, root_comp.yZConstructionPlane, 'param_D/2')
    terminal_offset.name = 'TerminalOffset'
    terminal_sketch = sketches.add(terminal_offset)

    fusion_sketch.create_center_point_circle(terminal_sketch, adsk.core.Point3D.create(-(get_param(params, 'E'))/2, 0, 0),'param_E/2', '',  get_param(params, 'E'), 'param_E')
    return terminal_sketch

def create_terminal(root_comp, params, design, terminal_sketch):
    ext_terminal = terminal_sketch.profiles.item(0)
    terminal = fusion_model.create_extrude(root_comp,ext_terminal, '-param_L', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    terminal.name = 'Terminal'
    addin_utility.apply_material(app, design, terminal.bodies.item(0), constant.MATERIAL_ID_TIN)

    fusion_model.create_mirror(root_comp, terminal, root_comp.yZConstructionPlane)

def create_band_sketch(root_comp, params):
    #create band
    sketches = root_comp.sketches
    band_offset = addin_utility.create_offset_plane(root_comp, root_comp.yZConstructionPlane, '-param_D/2 + param_L + (param_D - 2 * param_L) * 0.1')
    band_offset.name = 'BandOffset'
    band_sketch = sketches.add(band_offset)
    band_sketch.name = 'BandSketch'
    E_param = 'param_E * 0.77 + ' + (addin_utility.format_internal_to_default_unit(root_comp, 0.0003))
    circle = fusion_sketch.create_center_point_circle(band_sketch, adsk.core.Point3D.create(-(get_param(params, 'E'))/2, 0, 0),'param_E/2', '',  get_param(params, 'E') * 0.077 + 0.0003 , E_param)
    return band_sketch

def create_band(root_comp, params, design, band_sketch, outer_body):
    ext_band = band_sketch.profiles.item(0)
    band = fusion_model.create_extrude(root_comp,ext_band, '(param_D - 2 * param_L) * 0.2', adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    band.name = 'Band'
    #apply the band color
    addin_utility.apply_material(app, design, band.bodies.item(0), constant.MATERIAL_ID_PBT_PLASTIC)
    addin_utility.apply_rgb_appearance(app, design, band.bodies.item(0), 10, 10, 10,constant.COLOR_NAME_MELF_BAND)

    if not get_param(params, 'isPolarized'):
        band.isSuppressed = True
        addin_utility.apply_material(app, design, outer_body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)
        addin_utility.apply_appearance(app, design, outer_body.bodies.item(0),constant.APPEARANCE_ID_BODY_DEFAULT)        



def melf(params, design = None, target_comp = None):

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
    body = create_body(root_comp, params, design, body_sketch)
    #Create terminal sketch
    terminal_sketch = create_terminal_sketch(root_comp, params)
    #Create terminal
    create_terminal(root_comp, params, design, terminal_sketch)
    #Create band sketch
    band_sketch = create_band_sketch(root_comp, params)
    #Create band
    create_band(root_comp, params, design, band_sketch, body)


class Melf3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "melf"

    def create_model(self, params, design, component):
        melf(params, design, component)

package_3d_model_base.factory.register_package(Melf3DModel.type(), Melf3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    melf(params, design, target_comp)
