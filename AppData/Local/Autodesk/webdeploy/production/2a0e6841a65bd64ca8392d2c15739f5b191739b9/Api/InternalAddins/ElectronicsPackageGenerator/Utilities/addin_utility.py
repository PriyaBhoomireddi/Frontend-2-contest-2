"""
this is the utility module which defined functions to 3d Package generator in general.
"""

import adsk.core, math
from . import fusion_model, fusion_sketch, constant
from ..Utilities.localization import _LCLZ
from typing import Optional
from pathlib import Path

ADDIN_ROOT_PATH = Path(__file__).parent.parent.parent.parent

# The AppObjects class wraps many common application objects required when writing a Fusion 360 Addin.
class AppObjects(object):

    def __init__(self):

        self.app = adsk.core.Application.get()

        # Get User Interface
        self.ui = self.app.userInterface

    @property
    def design(self) -> Optional[adsk.fusion.Design]:
        """adsk.fusion.Design from the active document

        Returns: adsk.fusion.Design from the active document

        """
        design_ = self.app.activeDocument.products.itemByProductType('DesignProductType')
        if design_ is not None:
            return design_
        else:
            return None

    @property
    def units_manager(self) -> Optional[adsk.core.UnitsManager]:
        """adsk.core.UnitsManager from the active document

        Returns: adsk.core.UnitsManager from the active document

        """
        if self.app.activeProduct.productType == 'DesignProductType':
            units_manager_ = self.design.fusionUnitsManager
        else:
            units_manager_ = self.app.activeProduct.unitsManager

        if units_manager_ is not None:
            return units_manager_
        else:
            return None


    @property
    def root_comp(self) -> Optional[adsk.fusion.Component]:
        """Every adsk.fusion.Design has exactly one Root Component

        It should also be noted that the Root Component in the Design does not have an associated Occurrence

        Returns: The Root Component of the adsk.fusion.Design

        """
        if self.app.activeProduct.productType == 'DesignProductType':
            root_comp_ = self.design.rootComponent
            return root_comp_
        else:
            return None

class Status:

    def __init__(self):
        self._errors = []

    # add error 
    def add_error(self, error):
        self._errors.append(error)

    # clear errors
    def clear(self):
        self._errors.clear()

    # last error
    def last_error(self):
        return self._errors[-1]

    #all errors
    def errors(self):
        return self._errors

    # check if there is any error
    def isOK(self):
        return len(self._errors) == 0

#status = Status()

def show_error(err):
    app = adsk.core.Application.get()
    ui = app.userInterface
    ui.messageBox(_LCLZ("InputError", "Input Error(s)" ) + " : \n{0}".format('\n'.join(map(str, err))), "", 0, 4)

def convert_rgb_color(hex_value):
    hex_value = hex_value.replace('#', '')
    if len(hex_value)== 3:
        c1 = hex_value[0]
        c2 = hex_value[1]
        c3 = hex_value[2]
        hex_value = c1 + c1 + c2 + c2 + c3 + c3
    
    r = int(hex_value[0:2],16)
    g = int(hex_value[2:4],16)
    b = int(hex_value[4:6],16)
    return r, g, b

#convert the internal unit to defualt unit
def convert_internal_to_default_unit(component, value):
    design = component.parentDesign
    default_unit = design.unitsManager.defaultLengthUnits
    result = design.unitsManager.convert(value, 'cm', default_unit)
    return result

#format(to string i.e. (.15)->'1.5 mm') the internal unit to defualt unit 
def format_internal_to_default_unit(component, value):
    design = component.parentDesign
    default_unit = design.unitsManager.defaultLengthUnits
    result = design.unitsManager.formatInternalValue(value, default_unit)
    return result

# deal with the user paramters in the edit workflow. if it is exist, update it. if it is not exist, create it.
# the return value show the process result, true means update, false means create.
def process_user_param(design, name, value, units, comment):
    user_param = design.userParameters.itemByName(name)
    if user_param:  # the user parameter is already exist. update the value
        if user_param.value == value:
            return True
        else:
            user_param.value = value
            return True
    else:  # the user parameter is not exist, create a new one
        user_value = adsk.core.ValueInput.createByReal(value)
        new_param = design.userParameters.add(name, user_value, units, comment)
        return False

def apply_material(app, design, body, material_id):
    # get materials from current design
    material_in_design = design.materials.itemById(material_id)
    if material_in_design:
        body.material = material_in_design
    else:
        #get the material from library
        material_lib = app.materialLibraries.itemById(constant.MATERIAL_LIB_ID)
        material = material_lib.materials.itemById(material_id)
        if material:
            body.material = material            

# apply appearance to Brep entities
def apply_appearance(app, design, body, appear_id):
    # check if the appear is already in the current design
    appear_in_design = design.appearances.itemById(appear_id)
    if appear_in_design: # assign to the brep entity directly.
        body.appearance = appear_in_design
    else:
        # get the appearance from library
        appear_lib = app.materialLibraries.itemById(constant.APPEARANCE_LIB_ID)
        appear = appear_lib.appearances.itemById(appear_id)
        if appear:
            body.appearance = appear

# apply Emissive appearance to Brep entities
def apply_emissive_appearance(app, design, body, luminance, color_r, color_g, color_b, appear_name):
    
    appear_in_design = design.appearances.itemByName(appear_name)
    if appear_in_design:  # the appearance in design match the name, assign it
        new_appear = appear_in_design
    else:  # the appearance does not exist. get
        # Get the body appearance and create a copy by the given name.
        ref_appear = design.appearances.itemById(constant.APPEARANCE_ID_EMISSIVE_LED)
        if ref_appear:
            new_appear = ref_appear
        else:# find it in lib
            lib = app.materialLibraries.itemById(constant.APPEARANCE_LIB_ID)
            lib_appear = lib.appearances.itemById(constant.APPEARANCE_ID_EMISSIVE_LED)
            new_appear = design.appearances.addByCopy(lib_appear, appear_name)
    
    # update the emissive values to the apprearance 
    rgb = adsk.core.Color.create(color_r, color_g, color_b, 0)
    #updatebase body color
    body_color = new_appear.appearanceProperties.itemById(constant.COLOR_PROP_ID_DEFAULT)
    if body_color:
        color_prop = adsk.core.ColorProperty.cast(body_color)
        color_prop.value = rgb    
    #update light color
    light_color = new_appear.appearanceProperties.itemById(constant.COLOR_PROP_ID_LUMINANCE)
    if light_color:
        color_prop = adsk.core.ColorProperty.cast(light_color)
        color_prop.value = rgb
    #update the luminance value
    lumi = new_appear.appearanceProperties.itemById(constant.FLOAT_PROP_ID_LUMINANCE)
    if lumi:
        lumi.value = luminance  
    # assgin the new appearance back to the body
    body.appearance = new_appear

# update the emissive properties in the existing emissive appreance
def update_emissive_appearance(app, design, luminance, color_r, color_g, color_b, appear_name):
    appear_in_design = design.appearances.itemByName(appear_name)
    if appear_in_design:  # the appearance in design match the name, assign it       
        # update the emissive values to the apprearance 
        rgb = adsk.core.Color.create(color_r, color_g, color_b, 0)
        #updatebase body color
        body_color = appear_in_design.appearanceProperties.itemById(constant.COLOR_PROP_ID_DEFAULT)
        if body_color:
            color_prop = adsk.core.ColorProperty.cast(body_color)
            color_prop.value = rgb    
        #update light color
        light_color = appear_in_design.appearanceProperties.itemById(constant.COLOR_PROP_ID_LUMINANCE)
        if light_color:
            color_prop = adsk.core.ColorProperty.cast(light_color)
            color_prop.value = rgb
        #update the luminance value
        lumi = appear_in_design.appearanceProperties.itemById(constant.FLOAT_PROP_ID_LUMINANCE)
        if lumi:
            lumi.value = luminance  

# apply new color by customizing the default appearance to Brep entities
def apply_rgb_appearance(app, design, body, color_r, color_g, color_b, appear_name):
    rgb = adsk.core.Color.create(color_r, color_g, color_b, 0)
    appear_in_design = design.appearances.itemByName(appear_name)

    if appear_in_design:  # the appearance in design match the name, assign it
        new_appear = appear_in_design
    else:  # the appearance does not exist. get
        # Get the body appearance and create a copy by the given name.
        new_appear = design.appearances.addByCopy(body.appearance, appear_name)

    # get the color property from the new appearance
    prop = new_appear.appearanceProperties.itemById(constant.COLOR_PROP_ID_DEFAULT)
    if prop :
        color_prop = adsk.core.ColorProperty.cast(prop)
        color_prop.value = rgb
    else :
        # try to get color property for metal appearance
        prop = new_appear.appearanceProperties.itemById(constant.COLOR_PROP_ID_METAL)
        if prop :
            color_prop = adsk.core.ColorProperty.cast(prop)
            color_prop.value = rgb
        else:
            # try to get color property for transparent appearance
            prop = new_appear.appearanceProperties.itemById(constant.COLOR_PROP_ID_TRANSPARENT)
            if prop :
                color_prop = adsk.core.ColorProperty.cast(prop)
                color_prop.value = rgb
            else:
                # try to get color property for layer appearance
                prop = new_appear.appearanceProperties.itemById(constant.COLOR_PROP_ID_LAYER)
                if prop :
                    color_prop = adsk.core.ColorProperty.cast(prop)
                    color_prop.value = rgb
                else: 
                    # try to get color property for wood appearance
                    prop = new_appear.appearanceProperties.itemById(constant.COLOR_PROP_ID_WOOD)
                    if prop :
                        color_prop = adsk.core.ColorProperty.cast(prop)
                        color_prop.value = rgb

    # assgin the new appearance back to the body
    body.appearance = new_appear

#update the RGB color  in the existing  appreance
def update_rgb_appearance(app, design, color_r, color_g, color_b, appear_name, color_id):
    appear_in_design = design.appearances.itemByName(appear_name)
    if appear_in_design:  # the appearance in design match the name, assign it       
        # update the emissive values to the apprearance 
        rgb = adsk.core.Color.create(color_r, color_g, color_b, 0)
        #updatebase body color
        body_color = appear_in_design.appearanceProperties.itemById(color_id)
        if body_color:
            color_prop = adsk.core.ColorProperty.cast(body_color)
            color_prop.value = rgb

# create an offset construction plane based on the input plane
def create_offset_plane(root_comp, base_plane, offset):
    planes = root_comp.constructionPlanes
    plane_input = planes.createInput()
    offset_distance = adsk.core.ValueInput.createByString(offset)
    plane_input.setByOffset(base_plane, offset_distance)
    return planes.add(plane_input)

# create the pin one mark feature on the input body
def create_pin_one_mark(root_comp, body_height_A, param_A, body_length_D, body_param_D, body_width_E, body_param_E):

    # step 5. create the pin one mark.
    pin_one_mark_plane_xy = create_offset_plane(root_comp, root_comp.xYConstructionPlane, param_A)
    pin_one_mark_plane_xy.name = 'PinOneMarkPlaneXy'
    pin_one_mark_sketch = root_comp.sketches.add(pin_one_mark_plane_xy)

    pin_one_mark_sketch.isComputeDeferred = True
    mark_radius = body_width_E/20
    circle_origin = adsk.core.Point3D.create(-body_width_E/2+ body_width_E/10 + mark_radius, body_length_D/2- body_width_E/10-mark_radius, 0)

    sketch_point = pin_one_mark_sketch.sketchPoints.add(circle_origin)
    pin_one_mark_sketch.sketchCurves.sketchCircles.addByCenterRadius(sketch_point, mark_radius)

    pin_one_mark_sketch.sketchDimensions.addRadialDimension(pin_one_mark_sketch.sketchCurves[0],
                                                     fusion_sketch.get_dimension_text_point(pin_one_mark_sketch.sketchCurves[0])).parameter.expression = body_param_E + '/20'
    pin_one_mark_sketch.sketchDimensions.addDistanceDimension(sketch_point, pin_one_mark_sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     fusion_sketch.get_dimension_text_point(sketch_point)).parameter.expression = body_param_E + '/2-' + param_A+'/10-'+ body_param_E + '/10'
    pin_one_mark_sketch.sketchDimensions.addDistanceDimension(sketch_point, pin_one_mark_sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     fusion_sketch.get_dimension_text_point(sketch_point)).parameter.expression = body_param_D + '/2-' + param_A+'/10-'+ body_param_E + '/10'

    pin_one_mark_sketch.isComputeDeferred = False
    prof = pin_one_mark_sketch.profiles[0]
    pin_one_mark = root_comp.features.extrudeFeatures.addSimple(prof, adsk.core.ValueInput.createByString(param_A + '* (-0.1)'), adsk.fusion.FeatureOperations.CutFeatureOperation)
    pin_one_mark.name = 'PinOneMark'
    return pin_one_mark

# get the appearance
def get_appearance(app, design, appear_name):
    
    appearance_in_design = design.appearances.itemByName(appear_name)
    
    if appearance_in_design:  # the appearance in design match the name, return the appreance
        appearance = appearance_in_design
    else:  # the appearance does not exist. get
        # Get a reference to an appearance in the library.
        ref_appearance = design.appearances.itemById(constant.APPEARANCE_ID_BODY_DEFAULT)
        if ref_appearance:
            lib_appearance = ref_appearance
        else:
            lib = app.materialLibraries.itemById(constant.APPEARANCE_LIB_ID)
            lib_appearance = lib.appearances.itemById(constant.APPEARANCE_ID_BODY_DEFAULT)
        # Create a copy of the existing appearance.
        appearance = design.appearances.addByCopy(lib_appearance, appear_name)
    return appearance

#Createing thermal pad
def create_thermal_pad(app, root_comp,plane_offset, center_point, param_x, param_y, end_point, length, width, thickness, thermal_flag ):
    sketches = root_comp.sketches
    thermal_plane_offset = create_offset_plane(root_comp, root_comp.xYConstructionPlane, plane_offset)
    thermal_plane_offset.name = 'ThermalPlaneOffset'
    thermal_sketch = sketches.add(thermal_plane_offset)
    thermal_sketch.name = 'ThermalSketch'
    fusion_sketch.create_center_point_rectangle(thermal_sketch, center_point , param_x, param_y,  end_point ,
                             length, width)
    thermal_ext = thermal_sketch.profiles.item(0)
    thermal_pad = fusion_model.create_extrude(root_comp, thermal_ext, thickness, adsk.fusion.FeatureOperations.NewBodyFeatureOperation )
    thermal_pad.name = 'ThermalPad'
    apply_material(app, root_comp.parentDesign, thermal_pad.bodies.item(0), constant.MATERIAL_ID_ALUMINUM)

    if not thermal_flag:
        thermal_pad.isSuppressed = True

def get_terminal_thickness(get_param, params, value_thick):
    #Terminal thickness
    if(get_param(params, 'terminal_thickness') == False):
        terminal_thickness = value_thick
    else:
        if(terminal_thickness < 0):
            terminal_thickness = value_thick
        else:
            terminal_thickness = min(terminal_thickness, value_thick)
    return terminal_thickness


def get_dfn_terminal_thickness(root_comp, A):
    if(A < 0.05):
        terminal_thickness = 0.002
    else:
        terminal_thickness = 0.005
    return terminal_thickness

def create_dfn_body(root_comp, app, params, design, sketch_body, terminal):
    #Create body extrusion
    body_profile = sketch_body.profiles.item(0)
    extrudes = root_comp.features.extrudeFeatures
    extrude_input = extrudes.createInput(body_profile, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    isChained = False
    extent_to_entity = adsk.fusion.ToEntityExtentDefinition.create(terminal.endFaces[0], isChained)
    extrude_input.setOneSideExtent(extent_to_entity, adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrude_body = extrudes.add(extrude_input)
    extrude_body.name = 'Body'
    #Apply material to the body
    apply_material(app, design, extrude_body.bodies.item(0), constant.MATERIAL_ID_BODY_DEFAULT)

def create_dfn_pin_one_marker(root_comp, params, get_param, body_sketch):
    #Create pin one marker 
    fusion_sketch.create_center_point_circle(body_sketch, adsk.core.Point3D.create(-(get_param(params, 'D'))/2 + (get_param(params, 'E'))/10, (get_param(params, 'E'))/2 - (get_param(params, 'E'))/10, 0), 
                                                'param_D/2 - param_E/10', 'param_E/2 - param_E/10', (get_param(params, 'E'))/10, 'param_E/10')
    ext_cut = body_sketch.profiles.item(1)
    pin_one = fusion_model.create_extrude(root_comp, ext_cut, '-param_A /10' , adsk.fusion.FeatureOperations.CutFeatureOperation )
    pin_one.name = 'PinOne'

def does_footprint_exists(self, target_comp):
    # check for pads
    pad_sketch = target_comp.sketches.itemByName(constant.SKETCH_NAME_FOOTPRINT)
    if pad_sketch and pad_sketch.sketchCurves.count > 0:
        return True
    else:
        # check for silkscreens
        silkscreen_sketch = target_comp.sketches.itemByName(constant.SKETCH_NAME_SILKSCREEN)
        if silkscreen_sketch and silkscreen_sketch.sketchCurves.count > 0:
            return True
        else:
            # check for texts
            text_sketch = target_comp.sketches.itemByName(constant.SKETCH_NAME_TEXT)
            if text_sketch and text_sketch.sketchTexts.count > 0:
                return True
            else:
                return False

#check if the occurance exists
def is_occurance_in_component(occur_name, parent_component):
    for occurrence in parent_component.occurrences:
        if occurrence.isValid and occur_name in occurrence.name:
            return True
    return False

# loop through list of occurances in the parent component and deletes the occurances with the target name
def remove_occurances_in_component(occur_name, parent_component):
    removed = False
    for occurrence in parent_component.occurrences:
        if occurrence.isValid and occur_name in occurrence.name:
            occurrence.deleteMe()
            removed = True
    return removed

# delete all the user parameters in the specified design
def remove_user_parameters(design):
    param_count = design.userParameters.count
    for i in range(param_count - 1, -1, -1):
        user_param = design.userParameters.item(i)
        if user_param.isDeletable:
            user_param.deleteMe()

def get_arc_center(center_x, center_y, cord_mid_x, cord_mid_y, radius, angle):
    arc_mid_x = 0
    arc_mid_y = 0
    hx = cord_mid_x-center_x
    hy = cord_mid_y-center_y
    h = math.sqrt(hx**2+hy**2)
    ux = hx/h
    uy = hy/h

    if 0 > angle > -math.pi or 0 < angle < math.pi:
        arc_mid_x = center_x + radius*ux
        arc_mid_y = center_y + radius*uy
    elif angle == math.pi:
        arc_mid_x = cord_mid_x + radius*uy
        arc_mid_y = cord_mid_y - radius*ux
    elif angle == -math.pi:
        arc_mid_x = cord_mid_x - radius*uy
        arc_mid_y = cord_mid_y + radius*ux    
    else:
        arc_mid_x = center_x - radius*ux
        arc_mid_y = center_y - radius*uy
        
    return arc_mid_x, arc_mid_y