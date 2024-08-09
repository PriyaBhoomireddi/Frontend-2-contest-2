"""
this is the utility module which defined several functions to create 3d features.

"""

import adsk.core
from . import addin_utility

# create one direction pattern feature for sigle base
def create_one_direction_pattern(root_comp, base, distance, count, axis):
    input_entites = adsk.core.ObjectCollection.create()
    input_entites.add(base)
    quantity_one = adsk.core.ValueInput.createByString(count)
    distance_one = adsk.core.ValueInput.createByString(distance)
    patterns = root_comp.features.rectangularPatternFeatures
    pattern_input = patterns.createInput(input_entites, axis, quantity_one, distance_one, adsk.fusion.PatternDistanceType.SpacingPatternDistanceType)

    # TODO: once FUS-76643 addressed at API level need to remove setDirectionTwo
    # reset default value for quantity_two 
    quantity_two = adsk.core.ValueInput.createByString('1')
    distance_two = adsk.core.ValueInput.createByString('0')
    pattern_input.setDirectionTwo(axis, quantity_two, distance_two)

    pattern_input.patternComputeOption = 0
    return patterns.add(pattern_input)

# create two direction pattern features for single base. the distance1 will align with the xAxis  and distance2 will align with the yAxis
def create_two_direction_pattern(root_comp, base, distance1, count1, axis1, distance2, count2, axis2):
    input_entites = adsk.core.ObjectCollection.create()

    input_entites.add(base)
    quantity_one = adsk.core.ValueInput.createByString(count1)
    distance_one = adsk.core.ValueInput.createByString(distance1)
    patterns = root_comp.features.rectangularPatternFeatures
    pattern_input = patterns.createInput(input_entites, axis1, quantity_one, distance_one, adsk.fusion.PatternDistanceType.SpacingPatternDistanceType)
    # Set the data for second direction
    quantity_two = adsk.core.ValueInput.createByString(count2)
    distance_two = adsk.core.ValueInput.createByString(distance2)
    pattern_input.setDirectionTwo(axis2, quantity_two, distance_two)
    pattern_input.patternComputeOption = 2
    return patterns.add(pattern_input)

# create single base mirror feature based on the input plan.
def create_mirror(root_comp, base, plane):
    input_entites = adsk.core.ObjectCollection.create()
    input_entites.add(base)
    mirrors = root_comp.features.mirrorFeatures
    mirror_input = mirrors.createInput(input_entites, plane)
    mirror_input.patternComputeOption = 0
    return mirrors.add(mirror_input)

# create single base mirror then do the one direction pattern algin with the input axis
def create_mirror_and_pattern(root_comp, base, pattern_distance, pattern_count, pattern_axis, mirror_plane):
    # create the mirror feature
    mirror_body = create_mirror(root_comp,base,mirror_plane)
    # Create input entities for rectangular pattern
    input_entites = adsk.core.ObjectCollection.create()
    input_entites.add(base)

    if base.objectType == 'adsk::fusion::BRepBody':
        input_entites.add(mirror_body.bodies[0])
    else:
        input_entites.add(mirror_body)

    quantity_one = adsk.core.ValueInput.createByString(pattern_count)
    distance_one = adsk.core.ValueInput.createByString(pattern_distance)
    patterns = root_comp.features.rectangularPatternFeatures
    pattern_input = patterns.createInput(input_entites, pattern_axis, quantity_one, distance_one, adsk.fusion.PatternDistanceType.SpacingPatternDistanceType)
    pattern_input.patternComputeOption = 0
    return patterns.add(pattern_input)

# create extrude feature
def create_extrude(root_comp ,profile, height, operation):
    extrudes = root_comp.features.extrudeFeatures
    extrude_input = extrudes.createInput(profile, operation)
    # Create a distance extent definition    
    distance_value = adsk.core.ValueInput.createByString(height)
    extent_distance = adsk.fusion.DistanceExtentDefinition.create(distance_value)
    extrude_input.setOneSideExtent(extent_distance, adsk.fusion.ExtentDirections.PositiveExtentDirection) #TODO: replace with addSimple 
    return extrudes.add(extrude_input)

# create chamfer feature on the face.
def create_face_chamfer(root_comp, face, distance1, distance2):
    edges = adsk.core.ObjectCollection.create()
    face_edges = face.edges

    for edge_i  in face_edges:
        edges.add(edge_i)

    #create chamfer on the edges
    chamfers = root_comp.features.chamferFeatures
    chamfer_face = chamfers.createInput(edges, True)
    chamfer_face.setToTwoDistances(adsk.core.ValueInput.createByString(distance1), adsk.core.ValueInput.createByString(distance2))
    chamfers.add(chamfer_face)

    return chamfers

# create chamfer feature on the box.
def create_start_end_face_chamfer(root_comp, box, distance1, distance2):
    edge_top = adsk.core.ObjectCollection.create()
    top_face = box.startFaces[0]
    top_edges = top_face.edges

    edge_bottom = adsk.core.ObjectCollection.create()
    bottom_face = box.endFaces[0]
    bottom_edges = bottom_face.edges

    for edge_i  in top_edges:
        edge_top.add(edge_i)
    for edge_i  in bottom_edges:
        edge_bottom.add(edge_i)

    #create chamfer on the edges
    chamfers = root_comp.features.chamferFeatures
    chamfer_top = chamfers.createInput(edge_top, True)
    chamfer_top.setToTwoDistances(adsk.core.ValueInput.createByString(distance1), adsk.core.ValueInput.createByString(distance2))
    chamfer_top_feature = chamfers.add(chamfer_top)
    chamfer_top_feature.name ='BodyChamferTop'

    chamfer_bottom = chamfers.createInput(edge_bottom, True)
    chamfer_bottom.setToTwoDistances(adsk.core.ValueInput.createByString(distance2), adsk.core.ValueInput.createByString(distance1))
    chamfer_bottom_feature = chamfers.add(chamfer_bottom)
    chamfer_bottom_feature.name ='BodyChamferBottom'

    return chamfers

def apply_thread(root_comp, side_face, full_length, thread_info, thread_length):
    threads = root_comp.features.threadFeatures
    faces = adsk.core.ObjectCollection.create()
    faces.add(side_face)
    # define the thread input with the lenght
    thread_input = threads.createInput(faces, thread_info)
    thread_input.threadLength = adsk.core.ValueInput.createByString(thread_length)
    thread_input.isFullLength = full_length
    thread_input.isModeled = True
    return threads.add(thread_input)

def find_proper_thread_size(ref_value, thread_unit, thread_size_collection):
    
    ao = addin_utility.AppObjects()

    pre_size_str = ''
    pre_size_real = 0
    result_size = ''
    for size in thread_size_collection:
        current_size_str = size
        #size_value = adsk.core.ValueInput.createByString(size)
        try:
            current_size_real = ao.units_manager.evaluateExpression(current_size_str, thread_unit)
            if ref_value > current_size_real:
                pre_size_str = current_size_str
                pre_size_real = current_size_real
            else: # need compare to get the close size option
                if (current_size_real - ref_value) > (ref_value - pre_size_real):
                    result_size = pre_size_str
                else:
                    result_size = current_size_str
                break
        except:
            pass
    if result_size == '': # cannot find the proper size. will return the last one
        result_size = pre_size_str

    return result_size

