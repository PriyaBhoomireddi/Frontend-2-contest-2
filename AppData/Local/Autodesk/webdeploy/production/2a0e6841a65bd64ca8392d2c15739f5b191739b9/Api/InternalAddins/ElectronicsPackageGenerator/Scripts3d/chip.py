import adsk.core, adsk.fusion, traceback, math
from ..Utilities import fusion_sketch
from ..Utilities import fusion_model
from ..Utilities import addin_utility, constant
from ..Utilities.localization import _LCLZ
from .base import package_3d_model_base

app = adsk.core.Application.get()

#To create fillet for the terminals
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

#get param from the pallete
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
            return 0.18 #Body Width
        if (name == 'D'):
            return 0.34 #Body Length
        if (name == 'A'):
            return 0.07 #Body Height
        if (name == 'L'):
            return 0.075 #Normal Terminal Width
        if (name == 'L1'):
            return 0.075 #Odd Terminal Width
        if (name == 'color_r'):
            return 10
        if (name == 'color_g'):
            return 10
        if (name == 'color_b'):
            return 10

def user_param(design, params, default_unit):
    #Creating user parameters and updating them if they exist
    isUpdate = False
    res_1 = addin_utility.process_user_param(design, 'param_A', get_param(params, 'A'), default_unit, _LCLZ("BodyHeight", "body height"))
    res_2 = addin_utility.process_user_param(design, 'param_E', get_param(params, 'E'), default_unit, _LCLZ("BodyWidth", "body width"))
    res_3 = addin_utility.process_user_param(design, 'param_D', get_param(params, 'D'), default_unit, _LCLZ("BodyLength", "body length"))
    res_4 = addin_utility.process_user_param(design, 'param_L', get_param(params, 'L'), default_unit, _LCLZ("NormalTerminalWidth", "normal terminal width"))
    res_5 = addin_utility.process_user_param(design, 'param_L1', get_param(params, 'L1'), default_unit, _LCLZ("OddTerminalWidth", "odd terminal width"))
    isUpdate = res_1  or res_2 or res_3 or res_4 or res_5 
    if isUpdate:
        #Updating appearance
        rgb = adsk.core.Color.create(get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), 0)
        body_color = addin_utility.get_appearance(app, design, constant.COLOR_NAME_CHIP_BODY)
        color_prop = adsk.core.ColorProperty.cast(body_color.appearanceProperties.itemById(constant.COLOR_PROP_ID_DEFAULT))
        color_prop.value = rgb
        return isUpdate

def create_chip_body(root_comp, params, design, sketch_body):
    #Extrude bodies
    ext_odd = fusion_model.create_extrude(root_comp, sketch_body.profiles.item(0), 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_odd.name = 'OddPin'
    ext_even = fusion_model.create_extrude(root_comp, sketch_body.profiles.item(2), 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_even.name = 'EvenPin'
    ext_body = fusion_model.create_extrude(root_comp, sketch_body.profiles.item(1), 'param_A', adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    ext_body.name = 'ChipBody'
    create_fillet(root_comp, params, ext_odd)
    create_fillet(root_comp, params, ext_even)
    body = ext_body.bodies.item(0)

    #Assign materials to body and terminals
    addin_utility.apply_material(app, design, ext_odd.bodies.item(0), constant.MATERIAL_ID_TIN)
    addin_utility.apply_material(app, design, ext_even.bodies.item(0), constant.MATERIAL_ID_TIN)
    addin_utility.apply_material(app, design, ext_body.bodies.item(0), constant.MATERIAL_ID_CERAMIC)
    #Assign appearance to body
    addin_utility.apply_rgb_appearance(app, design, ext_body.bodies.item(0),get_param(params, 'color_r'), get_param(params, 'color_g'), get_param(params, 'color_b'), constant.COLOR_NAME_CHIP_BODY)
    return body

def chip(params, design = None, target_comp = None):

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
    param_updated = user_param(design, params, default_unit)
    if param_updated == True:
        return

    #Create chip sketch
    chip_sketch = fusion_sketch.create_chip_sketch(root_comp,params, get_param)
    #Create chip body
    create_chip_body(root_comp, params, design, chip_sketch)


class Chip3DModel(package_3d_model_base.Package3DModelBase):
    def __init__(self):
        super().__init__()

    @staticmethod
    def type():
        return "chip"

    def create_model(self, params, design, component):
        chip(params, design, component)

package_3d_model_base.factory.register_package(Chip3DModel.type(), Chip3DModel) 

def run(context):
    ui = app.userInterface

    try:
        runWithInput(context)
    except:
        if ui:
            ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))

def runWithInput(params, design = None, target_comp = None):
    chip(params, design, target_comp)