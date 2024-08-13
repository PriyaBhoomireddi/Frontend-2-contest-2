#Author-Autodesk Inc.
#Description-This is sample addin.

import adsk.core, adsk.fusion, traceback, os, gettext

btnCmdIdOnQAT = 'demoButtonCommandOnQAT'
listCmdIdOnQAT = 'demoListCommandOnQAT'
commandIdOnPanel = 'demoCommandOnPanel'
selectionInputId = 'selectionInput'
distanceInputId = 'distanceValueCommandInput'
panelId = 'SolidCreatePanel'

# global set of event handlers to keep them referenced for the duration of the command
handlers = []

# Support localization
_ = None
def getUserLanguage():
    app = adsk.core.Application.get()
    
    return {
        adsk.core.UserLanguages.ChinesePRCLanguage: "zh-CN",
        adsk.core.UserLanguages.ChineseTaiwanLanguage: "zh-TW",
        adsk.core.UserLanguages.CzechLanguage: "cs-CZ",
        adsk.core.UserLanguages.EnglishLanguage: "en-US",
        adsk.core.UserLanguages.FrenchLanguage: "fr-FR",
        adsk.core.UserLanguages.GermanLanguage: "de-DE",
        adsk.core.UserLanguages.HungarianLanguage: "hu-HU",
        adsk.core.UserLanguages.ItalianLanguage: "it-IT",
        adsk.core.UserLanguages.JapaneseLanguage: "ja-JP",
        adsk.core.UserLanguages.KoreanLanguage: "ko-KR",
        adsk.core.UserLanguages.PolishLanguage: "pl-PL",
        adsk.core.UserLanguages.PortugueseBrazilianLanguage: "pt-BR",
        adsk.core.UserLanguages.RussianLanguage: "ru-RU",
        adsk.core.UserLanguages.SpanishLanguage: "es-ES"
    }[app.preferences.generalPreferences.userLanguage]

# Get loc string by language
def getLocStrings():
    currentDir = os.path.dirname(os.path.realpath(__file__))
    return gettext.translation('resource', currentDir, [getUserLanguage(), "en-US"]).gettext 
    
def commandDefinitionById(id):
    app = adsk.core.Application.get()
    ui = app.userInterface
    if not id:
        ui.messageBox(_('commandDefinition id is not specified'))
        return None
    commandDefinitions_ = ui.commandDefinitions
    commandDefinition_ = commandDefinitions_.itemById(id)
    return commandDefinition_

def commandControlByIdForQAT(id):
    app = adsk.core.Application.get()
    ui = app.userInterface
    if not id:
        ui.messageBox(_('commandControl id is not specified'))
        return None
    toolbars_ = ui.toolbars
    toolbarQAT_ = toolbars_.itemById('QAT')
    toolbarControls_ = toolbarQAT_.controls
    toolbarControl_ = toolbarControls_.itemById(id)
    return toolbarControl_

def commandControlByIdForPanel(id):
    app = adsk.core.Application.get()
    ui = app.userInterface
    if not id:
        ui.messageBox(_('commandControl id is not specified'))
        return None
    workspaces_ = ui.workspaces
    modelingWorkspace_ = workspaces_.itemById('FusionSolidEnvironment')
    toolbarPanels_ = modelingWorkspace_.toolbarPanels
    toolbarPanel_ = toolbarPanels_.itemById(panelId)
    toolbarControls_ = toolbarPanel_.controls
    toolbarControl_ = toolbarControls_.itemById(id)
    return toolbarControl_

def destroyObject(uiObj, tobeDeleteObj):
    if uiObj and tobeDeleteObj:
        if tobeDeleteObj.isValid:
            tobeDeleteObj.deleteMe()
        else:
            uiObj.messageBox(_('tobeDeleteObj is not a valid object'))

def run(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface
        
        global _
        _ = getLocStrings()
        
        commandName = _('Demo')
        commandDescription = _('Demo Command')
        commandResources = './resources'
        iconResources = './resources'

        class InputChangedHandler(adsk.core.InputChangedEventHandler):
            def __init__(self):
                super().__init__()
            def notify(self, args):
                try:
                    command = args.firingEvent.sender
                    cmdInput = args.input
                    if cmdInput.id != distanceInputId:
                        ui.messageBox(_('Input: {} changed event triggered').format(command.parentCommandDefinition.id))
                        
                    if cmdInput.id == selectionInputId:
                        inputs = cmdInput.commandInputs
                        distanceInput = inputs.itemById(distanceInputId)
                        
                        if cmdInput.selectionCount > 0:
                            sel = cmdInput.selection(0)
                            selPt = sel.point
                            ent = sel.entity
                            plane = ent.geometry
                            
                            distanceInput.setManipulator(selPt, plane.normal)
                            distanceInput.expression = "10mm * 2"
                            distanceInput.isEnabled = True
                            distanceInput.isVisible = True
                        else:
                            distanceInput.isEnabled = False
                            distanceInput.isVisible = False
                except:
                    if ui:
                        ui.messageBox(_('Input changed event failed: {}').format(traceback.format_exc()))

        class CommandExecuteHandler(adsk.core.CommandEventHandler):
            def __init__(self):
                super().__init__()
            def notify(self, args):
                try:
                    command = args.firingEvent.sender
                    ui.messageBox(_('command: {} executed successfully').format(command.parentCommandDefinition.id))
                except:
                    if ui:
                        ui.messageBox(_('command executed failed: {}').format(traceback.format_exc()))

        class CommandCreatedEventHandlerPanel(adsk.core.CommandCreatedEventHandler):
            def __init__(self):
                super().__init__() 
            def notify(self, args):
                try:
                    cmd = args.command
                    cmd.helpFile = 'help.html'
                                        
                    onExecute = CommandExecuteHandler()
                    cmd.execute.add(onExecute)

                    onInputChanged = InputChangedHandler()
                    cmd.inputChanged.add(onInputChanged)
                    # keep the handler referenced beyond this function
                    handlers.append(onExecute)
                    handlers.append(onInputChanged)

                    commandInputs_ = cmd.commandInputs
                    commandInputs_.addValueInput('valueInput_', _('Value'), 'cm', adsk.core.ValueInput.createByString('0.0 cm'))
                    commandInputs_.addBoolValueInput('boolvalueInput_', _('Bool'), True)
                    commandInputs_.addStringValueInput('stringValueInput_', _('String Value'), _('Default value'))
                    selInput = commandInputs_.addSelectionInput(selectionInputId, _('Selection'), _('Select one'))
                    selInput.addSelectionFilter('PlanarFaces')
                    selInput.addSelectionFilter('ConstructionPlanes')
                    dropDownCommandInput_ = commandInputs_.addDropDownCommandInput('dropdownCommandInput', _('Drop Down'), adsk.core.DropDownStyles.LabeledIconDropDownStyle)
                    dropDownItems_ = dropDownCommandInput_.listItems
                    dropDownItems_.add(_('ListItem 1'), True)
                    dropDownItems_.add(_('ListItem 2'), False)
                    dropDownItems_.add(_('ListItem 3'), False)
                    dropDownCommandInput2_ = commandInputs_.addDropDownCommandInput('dropDownCommandInput2', _('Drop Down2'), adsk.core.DropDownStyles.CheckBoxDropDownStyle)
                    dropDownCommandInputListItems_ = dropDownCommandInput2_.listItems
                    dropDownCommandInputListItems_.add(_('ListItem 1'), True)
                    dropDownCommandInputListItems_.add(_('ListItem 2'), True)
                    dropDownCommandInputListItems_.add(_('ListItem 3'), False)
                    commandInputs_.addFloatSliderCommandInput('floatSliderCommandInput', _('Slider'), 'cm', 0.0, 10.0, True)
                    buttonRowCommandInput_ = commandInputs_.addButtonRowCommandInput('buttonRowCommandInput', _('Button Row'), False)
                    buttonRowCommandInputListItems_ = buttonRowCommandInput_.listItems
                    buttonRowCommandInputListItems_.add(_('ListItem 1'), False, iconResources)
                    buttonRowCommandInputListItems_.add(_('ListItem 2'), True, iconResources)
                    buttonRowCommandInputListItems_.add(_('ListItem 3'), False, iconResources)

                    distanceInput = commandInputs_.addDistanceValueCommandInput(distanceInputId, _('Distance'), adsk.core.ValueInput.createByReal(0.0))
                    distanceInput.isEnabled = False
                    distanceInput.isVisible = False
                    distanceInput.minimumValue = 1.0
                    distanceInput.maximumValue = 10.0
                    
                    directionInput = commandInputs_.addDirectionCommandInput('directionInput', _('Direction'))
                    directionInput.setManipulator(adsk.core.Point3D.create(0,0,0), adsk.core.Vector3D.create(1,0,0))
                    directionInput2 = commandInputs_.addDirectionCommandInput('directionInput2', _('Direction2'), iconResources)
                    directionInput2.setManipulator(adsk.core.Point3D.create(0,0,0), adsk.core.Vector3D.create(0,1,0))
                    
                    ui.messageBox(_('Panel command created successfully'))
                except:
                    if ui:
                        ui.messageBox(_('Panel command created failed: {}').format(traceback.format_exc()))

        class CommandCreatedEventHandlerQAT(adsk.core.CommandCreatedEventHandler):
            def __init__(self):
                super().__init__()
            def notify(self, args):
                try:
                    command = args.command
                    onExecute = CommandExecuteHandler()
                    command.execute.add(onExecute)
                    # keep the handler referenced beyond this function
                    handlers.append(onExecute)
                    ui.messageBox(_('QAT command created successfully'))
                except:
                    ui.messageBox(_('QAT command created failed: {}').format(traceback.format_exc()))

        commandDefinitions_ = ui.commandDefinitions

        # add a button command on Quick Access Toolbar
        toolbars_ = ui.toolbars
        toolbarQAT_ = toolbars_.itemById('QAT')
        toolbarControlsQAT_ = toolbarQAT_.controls
        btnCmdToolbarCtlQAT_ = toolbarControlsQAT_.itemById(btnCmdIdOnQAT)
        if not btnCmdToolbarCtlQAT_:
            btnCmdDefinitionQAT_ = commandDefinitions_.itemById(btnCmdIdOnQAT)
            if not btnCmdDefinitionQAT_:
                btnCmdDefinitionQAT_ = commandDefinitions_.addButtonDefinition(btnCmdIdOnQAT, commandName, commandDescription, commandResources)
            onButtonCommandCreated = CommandCreatedEventHandlerQAT()
            btnCmdDefinitionQAT_.commandCreated.add(onButtonCommandCreated)
            # keep the handler referenced beyond this function
            handlers.append(onButtonCommandCreated)
            btnCmdToolbarCtlQAT_ = toolbarControlsQAT_.addCommand(btnCmdDefinitionQAT_)
            btnCmdToolbarCtlQAT_.isVisible = True
            ui.messageBox(_('A demo button command is successfully added to the Quick Access Toolbar'))
            
        # add a list command on Quick Access Toolbar
        listCmdToolbarCtlQAT_ = toolbarControlsQAT_.itemById(listCmdIdOnQAT)
        if not listCmdToolbarCtlQAT_:
            listCmdDefinitionQAT_ = commandDefinitions_.itemById(listCmdIdOnQAT)
            if not listCmdDefinitionQAT_:
                listCmdDefinitionQAT_ = commandDefinitions_.addListDefinition(listCmdIdOnQAT, commandName, adsk.core.ListControlDisplayTypes.CheckBoxListType, commandResources)
                listItems_ = adsk.core.ListControlDefinition.cast(listCmdDefinitionQAT_.controlDefinition).listItems
                listItems_.add('Demo item 1', True)
                listItems_.add('Demo item 2', False)
                listItems_.add('Demo item 3', False)
                
            onListCommandCreated = CommandCreatedEventHandlerQAT()
            listCmdDefinitionQAT_.commandCreated.add(onListCommandCreated)
            # keep the handler referenced beyond this function
            handlers.append(onListCommandCreated)
            listCmdToolbarCtlQAT_ = toolbarControlsQAT_.addCommand(listCmdDefinitionQAT_)
            listCmdToolbarCtlQAT_.isVisible = True
            ui.messageBox(_('A demo list command is successfully added to the Quick Access Toolbar'))

        # add a command on create panel in modeling workspace
        workspaces_ = ui.workspaces
        modelingWorkspace_ = workspaces_.itemById('FusionSolidEnvironment')
        toolbarPanels_ = modelingWorkspace_.toolbarPanels
        toolbarPanel_ = toolbarPanels_.itemById(panelId) # add the new command under the CREATE panel
        toolbarControlsPanel_ = toolbarPanel_.controls
        toolbarControlPanel_ = toolbarControlsPanel_.itemById(commandIdOnPanel)
        if not toolbarControlPanel_:
            commandDefinitionPanel_ = commandDefinitions_.itemById(commandIdOnPanel)
            if not commandDefinitionPanel_:
                commandDefinitionPanel_ = commandDefinitions_.addButtonDefinition(commandIdOnPanel, commandName, commandDescription, commandResources)
            onCommandCreated = CommandCreatedEventHandlerPanel()
            commandDefinitionPanel_.commandCreated.add(onCommandCreated)
            # keep the handler referenced beyond this function
            handlers.append(onCommandCreated)
            toolbarControlPanel_ = toolbarControlsPanel_.addCommand(commandDefinitionPanel_)
            toolbarControlPanel_.isVisible = True
            ui.messageBox(_('A demo command is successfully added to the create panel in modeling workspace'))

    except:
        if ui:
            ui.messageBox(_('AddIn Start Failed: {}').format(traceback.format_exc()))

def stop(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface
        objArrayQAT = []
        objArrayPanel = []

        btnCmdToolbarCtlQAT_ = commandControlByIdForQAT(btnCmdIdOnQAT)
        if btnCmdToolbarCtlQAT_:
            objArrayQAT.append(btnCmdToolbarCtlQAT_)

        btnCmdDefinitionQAT_ = commandDefinitionById(btnCmdIdOnQAT)
        if btnCmdDefinitionQAT_:
            objArrayQAT.append(btnCmdDefinitionQAT_)
            
        listCmdToolbarCtlQAT_ = commandControlByIdForQAT(listCmdIdOnQAT)
        if listCmdToolbarCtlQAT_:
            objArrayQAT.append(listCmdToolbarCtlQAT_)

        listCmdDefinitionQAT_ = commandDefinitionById(listCmdIdOnQAT)
        if listCmdDefinitionQAT_:
            objArrayQAT.append(listCmdDefinitionQAT_)

        commandControlPanel_ = commandControlByIdForPanel(commandIdOnPanel)
        if commandControlPanel_:
            objArrayPanel.append(commandControlPanel_)

        commandDefinitionPanel_ = commandDefinitionById(commandIdOnPanel)
        if commandDefinitionPanel_:
            objArrayPanel.append(commandDefinitionPanel_)

        for obj in objArrayQAT:
            destroyObject(ui, obj)

        for obj in objArrayPanel:
            destroyObject(ui, obj)

    except:
        if ui:
            ui.messageBox(_('AddIn Stop Failed: {}').format(traceback.format_exc()))
