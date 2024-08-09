import traceback
import adsk.core
import os, sys
from pathlib import Path
from . import CommandBase
from ..Utilities import addin_utility, constant
import json
from xml.etree import ElementTree as ET

from ..Calculators import *
from ..Calculators import pkg_calculator
from ..Scripts3d import *
from ..Scripts3d.base import package_3d_model_base 
from ..Utilities.localization import _LCLZ, locale 
from ..FootprintGenerators import footprint_generator

TARGET_COMPONENT_NAME = 'Model'
ATTRI_GROUP_PKG_DATA = 'PackageGeneratorDataGroup'
ATTRI_FLAG_PKG_IN_PROGRESS = 'PackageInProgress'
ATTRI_ERROR_INPUT = 'ErrorPresent'
ATTRI_FLAG_FOOTPRINT_EXIST = 'FootprintImported'
ATTRI_VERSION = 'Version'
ATTRI_PKG_NAME = 'PackageName'
ATTRI_META_DATA = 'PackageMetaData'
ATTRI_FOOTPRINT = 'Footprint'
ATTRI_JSON_UI_INPUT = 'UIInput'


class PackageCommandFactory:
    def __init__(self):
        self._creators = {}

    def register_command(self, pkg_type, creator):
        self._creators[pkg_type] = creator

    def get_command(self, pkg_type):
        creator = self._creators.get(pkg_type)
        if not creator:
            raise ValueError(pkg_type)
        return creator(pkg_type,{})


cmd_factory = PackageCommandFactory()

class PackageCommand(CommandBase.CommandBase):
    def __init__(self, name: str, options: dict):
        super().__init__(name, options)

        #overwrite some specific settings of this command. 
        self.command_visible = False
        self.command_promoted = False
        self.command_promoted_by_Default = False
        self.cmd_resources = os.path.join(Path(__file__).parent.parent, 'Resources')
        self.toolbar_panel_id = 'Package3DPanel'
        self.ui_data = {}
        # define the command related object
        self.target_component = None
        self.footprint_generator = footprint_generator.FootprintGenerator()
        self.only_3d_model_generator = False
        self.footprint_exist = False # flag to identify if there is footprint alreay exist
        self.regenerate_model = False
        self.package_in_progress = False
        self.pre_pkg_name = ''  # stored the package name in the attribute storage
        self.package_metadata = {}
        self.dialog_width = 300
        self.dialog_height = 400

    def on_input_changed(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs,
                         changed_input: adsk.core.CommandInput, input_values: dict ):
        #TODO do some base class UIlevel check here.
        pass


    def on_create(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs):

        super().on_create(command, inputs)
        # initialize the dialog size
        command.setDialogInitialSize(self.dialog_width, self.dialog_height)
        command.isExecutedWhenPreEmpted = False
        ao = addin_utility.AppObjects()
        if addin_utility.is_occurance_in_component(TARGET_COMPONENT_NAME, ao.root_comp):
            command.okButtonText = _LCLZ('buttonUpdate', 'Update')
        else:
            command.okButtonText = _LCLZ('buttonAdd', 'Add')
        # read in the persistent data if it is exist
        self.load_data()
        # update the design context
        self.refresh_design_context()
        
    def validate_ui_input(self, inputs: adsk.core.CommandInputs):
        
        status = addin_utility.Status()
        #Check for generic min,max values from table
        command = inputs.itemById('bodyDimensionTable')
        if command :
            row_no = command.rowCount
            for i in range(1, row_no) :
                min_val = command.getInputAtPosition(i, 1)
                max_val = command.getInputAtPosition(i, 2)
                min_tooltip = min_val.tooltip
                max_tooltip = max_val.tooltip
                min_name = min_val.name
                max_name = max_val.name
                if min_val.id == 'bodyOffsetMin' : #case where body offest min is considered
                    if min_val.value <= 0 :
                        status.add_error(_LCLZ("OffsetMinError" , "Body Offset Min (A1) can't be equal to or less than 0."))
                else:
                    min_value = float('{:.6f}'.format(min_val.value))
                    max_value = float('{:.6f}'.format(max_val.value))
                    if min_value> max_value :
                        status.add_error(min_tooltip + " (" + min_name + ") " + _LCLZ("MinMaxError", "can't be greater than ") + max_tooltip + " (" + max_name + ") " + ".")
                    if max_value <= 0 :
                        status.add_error(max_tooltip + " (" + max_name + ") " + _LCLZ("MaxError", "can't be equal to or less than 0."))
                    if min_value < 0 :
                        status.add_error(max_tooltip + " (" + max_name + ") " + _LCLZ("MinError", "can't be less than 0."))

        #check for packages where pin pitch applicable
        command = inputs.itemById('verticalPinPitch')
        if command :
            pitch_tooltip = command.tooltip
            name = command.name
            if command.value <= 0 :
                status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

        #Check where pad roundness is applicable
        command = inputs.itemById('roundedPadCornerSize')
        if command :
            if command.value <= 0 :
                status.add_error(_LCLZ("PadRoundError", "Pad Roundness can't be equal to or less than 0."))

        #Check for custom footprint parameters
        if inputs.itemById('hasCustomFootprint') and inputs.itemById('hasCustomFootprint').value == True :

            #following checks are for negative and zero values
            command_custom_pad_dia = inputs.itemById('customPadDiameter')
            if command_custom_pad_dia :
                pitch_tooltip = command_custom_pad_dia.tooltip
                name = command_custom_pad_dia.name
                if command_custom_pad_dia.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command_custom_hole = inputs.itemById('customHoleDiameter')
            if command_custom_hole :
                pitch_tooltip = command_custom_hole.tooltip
                name = command_custom_hole.name
                if command_custom_hole.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customPadLength')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customPadWidth')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customOddPadLength')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customOddPadWidth')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customPadToPadGap')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customPadToPadGap1')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0.."))

            command = inputs.itemById('customPadSpan1')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customPadSpan2')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customPadDiameter')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            command = inputs.itemById('customPadPitch')
            if command :
                pitch_tooltip = command.tooltip
                name = command.name
                if command.value <= 0 :
                    status.add_error(pitch_tooltip + ' (' + name + ') ' +_LCLZ("MaxError", "can't be equal to or less than 0."))

            #following checks are for calculation related stuffs
            if command_custom_pad_dia and command_custom_hole :
                if float('{:.6f}'.format(command_custom_hole.value)) >= float('{:.6f}'.format(command_custom_pad_dia.value)) :
                    status.add_error(_LCLZ("CustomThruHoleError", "Custom Hole Diameter (b1) can't be greater than or equal to Custom Pad Diameter (p)."))

        return status

    def on_execute(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs,
                   args: adsk.core.CommandEventArgs, input_values: dict):
        
        ao = addin_utility.AppObjects()
        doc_attributes = ao.app.activeDocument.attributes

        # get the latest UI input
        self.update_ui_data(inputs)
        """
        #support QA to dump json temple of each pacakge
        file_name = 'd:\\temp\\' + self.ui_data['packageType']+'_template.json'
        with open(file_name,'w') as file: 
            json.dump(self.ui_data, file)  
            file.close() 
        """
        #check for input ui validation
        status = self.validate_ui_input(inputs)

        #generate 3D model and footprint if there is no error
        if status.isOK() is not True :
            addin_utility.show_error(status.errors())
            doc_attributes.add(ATTRI_GROUP_PKG_DATA, ATTRI_ERROR_INPUT, json.dumps(self.ui_data))

        else:
            #delete error attribute
            attri = doc_attributes.itemByName(ATTRI_GROUP_PKG_DATA, ATTRI_ERROR_INPUT)
            if attri :
                attri.deleteMe()
            #generate 3D model and footprint
            self.generate_packages(self.ui_data)
            #update the package name and view
            if not self.only_3d_model_generator:
                ao.app.activeDocument.name = self.footprint_generator.package_name

            #save the data into f3d
            self.save_data()

            ao.app.activeViewport.refresh()

    def on_destroy(self, command: adsk.core.Command, inputs: adsk.core.CommandInputs,
                reason: adsk.core.CommandTerminationReason, input_values: dict):
        
        # show the package generator palette. 
        ao = addin_utility.AppObjects()
        palette = ao.ui.palettes.itemById('packageGeneratorPalette_')
        if palette:
            palette.isVisible = True        

    def get_defalt_ui_data(self):
        pass
           
    def update_ui_data(self, inputs):
        pass


    def load_data(self):
        ao = addin_utility.AppObjects()
        doc_attributes = ao.app.activeDocument.attributes
        # initialize command data from attributes

        # read data version
        data_version = doc_attributes.itemByName(ATTRI_GROUP_PKG_DATA, ATTRI_VERSION)
        if data_version != None and data_version.value != constant.CURRENT_VERSION:
            #TODO need support the legacy data schema
            pass
        
        # read footprint exist flag
        attri = doc_attributes.itemByName(ATTRI_GROUP_PKG_DATA, ATTRI_FLAG_FOOTPRINT_EXIST)
        if attri == None:
            self.footprint_exist = False
        else:
            self.footprint_exist = attri.value

        # read UI data
        attri_error = doc_attributes.itemByName(ATTRI_GROUP_PKG_DATA, ATTRI_ERROR_INPUT)
        attri = doc_attributes.itemByName(ATTRI_GROUP_PKG_DATA, ATTRI_JSON_UI_INPUT)

        if attri == None and attri_error == None :
            self.ui_data = self.get_defalt_ui_data()
            self.regenerate_model = True

        else :
            if attri_error :
                stored_data = json.loads(attri_error.value)
            if attri and attri_error == None :
                stored_data = json.loads(attri.value)

            if self.cmd_id == stored_data['cmd_id']: # check the pacakge type match with command 
                self.ui_data = stored_data
            else:
                self.ui_data = self.get_defalt_ui_data()
                # since the command is not match the existing pacakge type. we will regenerate anyway
                # ignore the footprint flag.
                self.footprint_exist = False
                self.regenerate_model = True

        comp_attributes = ao.root_comp.attributes
        attri = comp_attributes.itemByName(ATTRI_GROUP_PKG_DATA, ATTRI_PKG_NAME)
        if attri != None:
            self.pre_pkg_name = attri.value
        

    def save_data(self):
        ao = addin_utility.AppObjects()

        # save attributes in current document object
        doc_attributes = ao.app.activeDocument.attributes
        # save the version 
        doc_attributes.add(ATTRI_GROUP_PKG_DATA, ATTRI_VERSION, constant.CURRENT_VERSION)
        # save the UI data
        doc_attributes.add(ATTRI_GROUP_PKG_DATA, ATTRI_JSON_UI_INPUT, json.dumps(self.ui_data))

        # save attributes in the root component
        comp_attributes = ao.root_comp.attributes
        # save the pacakge name
        comp_attributes.add(ATTRI_GROUP_PKG_DATA, ATTRI_PKG_NAME, self.footprint_generator.package_name)
        # save the meta data
        if self.only_3d_model_generator == True:# need inherit the old package name
            metadata_xml_str = self.get_metadata_xml(self.pre_pkg_name)
        else:
            metadata_xml_str = self.get_metadata_xml()
        comp_attributes.add(ATTRI_GROUP_PKG_DATA, ATTRI_META_DATA, metadata_xml_str)
        #save the footprint data
        footprint_xml_str = self.footprint_generator.get_footprint_xml()
        comp_attributes.add(ATTRI_GROUP_PKG_DATA, ATTRI_FOOTPRINT, footprint_xml_str)

    def refresh_design_context(self):

        ao = addin_utility.AppObjects()  
        ao.design.designType = adsk.fusion.DesignTypes.ParametricDesignType
        # set the proper target component
        for occur in ao.root_comp.occurrences:
            current_comp = occur.component
            if current_comp.name == TARGET_COMPONENT_NAME:
                self.target_component = current_comp

        # Check for existing attribute for model generation mode
        if self.footprint_generator.does_footprint_exists(ao.design.rootComponent):
            # Check if current package is being fully generated or not 
            pkg_in_progress_attr = ao.app.activeDocument.attributes.itemByName(ATTRI_GROUP_PKG_DATA, ATTRI_FLAG_PKG_IN_PROGRESS)
            # Load in full package generation mode if package is currently being generated otherwise load in model generation mode
            if pkg_in_progress_attr:
                self.only_3d_model_generator = False
            else:
                self.only_3d_model_generator = True
        # Handle package from imported empty footprint scenario
        elif self.footprint_exist:
            self.only_3d_model_generator = True
        else:
            # Add temp attribute when a full package generation is started
            ao.app.activeDocument.attributes.add(ATTRI_GROUP_PKG_DATA, ATTRI_FLAG_PKG_IN_PROGRESS, 'true')
            self.only_3d_model_generator = False

    def generate_packages(self, ui_data: dict):

        #check if we need generate footprint
        if self.only_3d_model_generator == False:
            self.generate_footprints(ui_data)
        
        #generate 3d model
        self.generate_model(ui_data)

    def generate_model(self, data: dict):
        ao = addin_utility.AppObjects()      
        try:
            # remove everything if the package need be regenerated
            if self.regenerate_model == True:
                # delete all the previous features. 
                addin_utility.remove_occurances_in_component(TARGET_COMPONENT_NAME, ao.root_comp)
                # delete all the related user paramters.
                addin_utility.remove_user_parameters(ao.design)
                # create a new target component
                occurrence = ao.root_comp.occurrences.addNewComponent(adsk.core.Matrix3D.create())
                occurrence.component.name = TARGET_COMPONENT_NAME
                self.target_component = occurrence.component

            # generate 3D model
            # create a calculator
            calculator = pkg_calculator.calc_factory.get_calculator(data['type'])
            if calculator == None: return False
            calculator.set_ui_input(data)
             
            model_data = calculator.get_ipc_3d_model_data()

            #create a 3D model generator
            package = package_3d_model_base.factory.get_package(data['type'])
            if package: 
                package.create_model(model_data, ao.design, self.target_component)
                # set the flag back if the model create process is successful.
                self.regenerate_model = False
                #get metadata for 3d package
                self.package_metadata = calculator.get_ipc_package_metadata()
            else: # the package is not supported. 
                ao.ui.messageBox(data['type'].title() + " 3D package generator not supported yet.")
            # set the camera
            ao.app.activeViewport.fit()
            return True

        except:
            ao.ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))


    def generate_footprints(self, data : dict):
        ao = addin_utility.AppObjects()
        # if the footprint is already exist
        if self.footprint_generator.does_footprint_exists(ao.root_comp):
            # remove footprint geometries.
            self.footprint_generator.remove_footprint(ao.root_comp)

        #create a calculator
        calculator = pkg_calculator.calc_factory.get_calculator(data['type'])
        if calculator == None: return False
        calculator.set_ui_input(data)
        
        footprint_list = calculator.get_footprint()
        self.footprint_generator.footprint_list = footprint_list
        self.footprint_generator.package_name = calculator.get_ipc_package_name()
        self.footprint_generator.package_description = calculator.get_ipc_package_description()

        ao = addin_utility.AppObjects()
        self.footprint_generator.draw_footprint(ao.design)

    def get_metadata_xml(self, pre_pkg_name = ''):
        if pre_pkg_name != '': # need inherit the old package name
            self.package_metadata['ipcName'] = pre_pkg_name

        root_node = ET.Element('package3d',{'name':self.package_metadata['ipcName']})
        # generate metadata node
        node_metadata = ET.Element('package3dMetadata')
        node_metadata.attrib = self.package_metadata
        root_node.append(node_metadata)

        xml_string = ET.tostring(root_node,encoding='unicode') #unicode is used to get string instead of bytestring
        return xml_string
