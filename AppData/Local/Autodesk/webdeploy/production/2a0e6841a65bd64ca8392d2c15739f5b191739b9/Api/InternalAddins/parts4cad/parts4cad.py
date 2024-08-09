
import adsk.core, adsk.fusion, os, traceback

# global set of event handlers to keep them referenced for the duration of the command
handlers = []
commandDefinition = None
toolbarControl = None


def run(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui  = app.userInterface


        class Parts4cadCommandCreatedHandler(adsk.core.CommandCreatedEventHandler):
            def __init__(self):
                super().__init__()
            def notify(self, args):
                try:
                    cmd = args.command

                    # display the legal prompt
                    import neu_dev
                    neu_dev.run_text_command('Fusion.ShowLegalNotice parts4cad')

                    # Start Website in Browser:
                    import webbrowser
                    webbrowser.open("http://autodesk-fusion.partcommunity.com", 2)

                except:
                    ui.messageBox('Failed:\n{}'.format(traceback.format_exc()))



        commandId = 'cadenasparts4cad'

        if app.preferences.generalPreferences.userLanguage == adsk.core.UserLanguages.GermanLanguage:
          commandName = 'Herstellerteil einfügen'
          commandDescription = 'Mit parts4cad können Sie Millionen von Teilen von über 400 Herstellern und Lieferanten durchsuchen und konfigurieren und in Ihre Konstruktionen einfügen.'
        elif app.preferences.generalPreferences.userLanguage == adsk.core.UserLanguages.ChinesePRCLanguage:
          commandName = '插入制造商零件'
          commandDescription = 'parts4cad 让您可以浏览和配置来自超过 400 个供应商和制造商目录的数百万个零件并将其插入到设计中。'
        elif app.preferences.generalPreferences.userLanguage == adsk.core.UserLanguages.JapaneseLanguage:
          commandName = '製造元部品を挿入'
          commandDescription = 'parts4cad により、400 以上ものサプライヤや製造元のカタログに含まれる数百万もの部品を参照および環境設定し、デザインの中に挿入することができます。'
        else:
          commandName = 'Insert a manufacturer part'
          commandDescription = 'parts4cad lets you browse and configure millions of parts from more than 400 supplier and manufacturer catalogs and insert them into your designs.'

        # create the command definition
        global commandDefinition
        commandDefinition = ui.commandDefinitions.itemById(commandId)
        # delete any existing command definition, and just recreate it
        if commandDefinition:
            commandDefinition.deleteMe()
        resourceDir = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'resources')
        commandDefinition = ui.commandDefinitions.addButtonDefinition(commandId, commandName, commandDescription, resourceDir)
        commandDefinition.toolClipFilename = resourceDir + '/parts4cad.png'
        onCommandCreated = Parts4cadCommandCreatedHandler()
        commandDefinition.commandCreated.add(onCommandCreated)
        handlers.append(onCommandCreated) # keep the handler referenced beyond this function

        # insert the command into the model:insert toolbar
        toolbarControls = ui.workspaces.itemById('FusionSolidEnvironment').toolbarPanels.itemById('InsertPanel').controls
        # delete any existing control, and just recreate it
        global toolbarControl
        toolbarControl = toolbarControls.itemById(commandId)
        if toolbarControl:
            toolbarControl.deleteMe()
        toolbarControl = toolbarControls.addCommand(commandDefinition)
        toolbarControl.isVisible = True

    except:
        pass


def stop(context):
    try:
        global commandDefinition
        if commandDefinition:
            commandDefinition.deleteMe()
            commandDefinition = None
        global toolbarControl
        if toolbarControl:
            toolbarControl.deleteMe()
            toolbarControl = None

    except:
        pass
