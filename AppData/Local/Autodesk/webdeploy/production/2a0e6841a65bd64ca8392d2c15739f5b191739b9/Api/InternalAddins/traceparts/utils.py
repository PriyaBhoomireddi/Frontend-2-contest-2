
import adsk.core # pylint: disable=import-error
import sys, traceback
from typing import Callable

app = adsk.core.Application.get()
ui = app.userInterface
_handlers = []

def clearHandlers():
    global _handlers
    _handlers = []

def log(msg: str):
    print(msg)
    if ui:
        ui.palettes.itemById('TextCommands').writeText(msg)

def handleError(name: str):
    log('{}\n{}'.format(name, traceback.format_exc()))

def addHandler(event: adsk.core.Event, callback: Callable, name: str = None):
    module = sys.modules[event.__module__]
    handlerType = module.__dict__[event.add.__annotations__['handler']]
    handler = createHandler(handlerType, callback, event, name)
    event.add(handler)

def createHandler(handlerType, callback: Callable, event: adsk.core.Event, name: str = None):
    handler = _defineHandler(handlerType, callback, name)()
    _handlers.append(handler)
    return handler

def _defineHandler(handlerType, callback, name: str = None):
    name = name or handlerType.__name__
    class Handler(handlerType):
        def __init__(self):
            super().__init__()
        def notify(self, args):
            try:
                callback(args)
            except:
                handleError(name)
    return Handler
