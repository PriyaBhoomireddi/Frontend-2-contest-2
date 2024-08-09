class Package3DModelFactory:
    def __init__(self):
        self._creators = {}

    def register_package(self, type, creator):
        self._creators[type] = creator

    def get_package(self, type):
        creator = self._creators.get(type)
        if not creator:
            raise ValueError(type)
        return creator()

class Package3DModelBase:
    def __init__(self):
        pass

    def create_model(params, design, component):
        print("Base:create_model")
        pass

factory = Package3DModelFactory() 