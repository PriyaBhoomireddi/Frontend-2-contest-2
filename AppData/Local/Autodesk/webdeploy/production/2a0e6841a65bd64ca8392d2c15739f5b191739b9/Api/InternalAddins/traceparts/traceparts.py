#Author-Autodesk
#Description-Insert content from TraceParts

import adsk.core # pylint: disable=import-error
from urllib.parse import urlparse
from .localization import _LCLZ # pylint: disable=relative-beyond-top-level
from .utils import addHandler, handleError, clearHandlers, ui # pylint: disable=relative-beyond-top-level
# pylint bug https://github.com/PyCQA/pylint/issues/3629

COMMANDID = 'traceparts_insert'
COMMANDNAME = _LCLZ('InsertName', 'Insert TraceParts Supplier Components')
COMMANDDESCRIPTION = _LCLZ('InsertDescription', 'With TraceParts, boost your design productivity and access millions of CAD models from hundreds of supplier catalogs.')
URL = _LCLZ('CatalogURL', 'https://www.traceparts.com/els/fusion-360/en/catalogs')
PALETTEID = 'traceparts_browser'
PALETTENAME = _LCLZ('PaletteName', 'Autodesk Fusion 360 Design Library - powered by TraceParts')
DOCKINGSTATE = adsk.core.PaletteDockingStates.PaletteDockStateRight


def run(context):
    try:
        createCommand()
    except:
        handleError('run')

def stop(context):
    try:
        clearHandlers()
        removeCommand()
    except:
        handleError('stop')

def createCommand():
    removeCommand()

    cmdDef = ui.commandDefinitions.addButtonDefinition(COMMANDID, COMMANDNAME, COMMANDDESCRIPTION, 'resources/insert')
    cmdDef.toolClipFilename = 'resources/insert/toolclip.svg'
    addHandler(cmdDef.commandCreated, onCommandCreated)

    controls = toolbarPanelControls()
    controls.addCommand(cmdDef)

def removeCommand():
    cmdDef = ui.commandDefinitions.itemById(COMMANDID)
    if cmdDef:
        cmdDef.deleteMe()

    controls = toolbarPanelControls()
    control = controls.itemById(COMMANDID)
    if control:
        control.deleteMe()

def toolbarPanelControls():
    workspace = ui.workspaces.itemById('FusionSolidEnvironment')
    return workspace.toolbarPanels.itemById('InsertPanel').controls

def onCommandCreated(args: adsk.core.CommandCreatedEventArgs):
    addHandler(args.command.execute, onExecute)

def onExecute(args: adsk.core.CommandEventArgs):
    # display the legal prompt
    import neu_dev
    neu_dev.run_text_command('Fusion.ShowLegalNotice traceparts')

    createPalette()

def createPalette():
    palettes = ui.palettes
    palette = palettes.itemById(PALETTEID)
    if palette:
        palette.deleteMe()
    palette = palettes.add(
        id=PALETTEID,
        name=PALETTENAME,
        htmlFileURL=URL,
        isVisible=True,
        showCloseButton=True,
        isResizable=True,
        width=650,
        height=600,
        useNewWebBrowser=True
    )
    palette.dockingState = DOCKINGSTATE
    addHandler(palette.closed, onClosed)
    addHandler(palette.navigatingURL, onNavigatingURL)

def onClosed(args: adsk.core.UserInterfaceGeneralEventArgs):
    palette = ui.palettes.itemById(PALETTEID)
    if palette:
        palette.deleteMe()

def onNavigatingURL(args: adsk.core.NavigationEventArgs):
    url = args.navigationURL

    # Change fusion360 open commands to insert
    if url.startswith('fusion360://') and 'command=open' in url:
        args.navigationURL = url.replace('command=open', 'command=insert')
        return

    # Launch links on different hosts in an external browser
    if urlparse(url).hostname != urlparse(URL).hostname:
        args.launchExternally = True
