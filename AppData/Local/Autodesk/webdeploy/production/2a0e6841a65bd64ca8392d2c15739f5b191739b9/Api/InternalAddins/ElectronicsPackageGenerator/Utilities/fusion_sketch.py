"""
this is the utility module which defined several functions to create sketches. 
"""
import adsk.core, adsk.fusion
import math
from . import addin_utility

TERMINAL_THICKNESS_J_LEAD = 0.02  # UNIT is cm

def get_dimension_text_point(dimension_entity):
    #support addDiameterDimension, addDistanceDimension, addRadialDimension which are currenly used.
    #for dimension between two diffrent lines or any two points pass any one point(better if non zero/ non origin point) as argument.
    offset = 0.1
    text_pos_x = offset
    text_pos_y = offset
    if (dimension_entity.objectType == 'adsk::fusion::SketchLine' or dimension_entity.objectType == 'adsk::fusion::SketchArc'):
        start_point = dimension_entity.startSketchPoint.geometry
        end_point = dimension_entity.endSketchPoint.geometry
        text_pos_x = (start_point.x + end_point.x)/2 + offset
        text_pos_y = (start_point.y + end_point.y)/2 + offset
    elif (dimension_entity.objectType == 'adsk::fusion::SketchCircle'):
        text_pos_x = dimension_entity.radius + offset
        text_pos_y = text_pos_x
    elif (dimension_entity.objectType == 'adsk::fusion::SketchPoint'):  
        text_pos_x = dimension_entity.geometry.x/2 + offset
        text_pos_y = dimension_entity.geometry.y/2 + offset
    return adsk.core.Point3D.create(text_pos_x, text_pos_y, 0)

def create_center_point_rectangle(sketch, center_point, param_point_x, param_point_y, end_point, param_horizontal, param_verticle):
    
    sketch.isComputeDeferred = True
    lines = sketch.sketchCurves.sketchLines
    line_count = lines.count
    rect = lines.addCenterPointRectangle(center_point, end_point)

    # Constrain the Rectangle to stay rectangular
    constraints = sketch.geometricConstraints
    constraints.addHorizontal(lines.item(line_count+0))
    constraints.addHorizontal(lines.item(line_count+2))
    constraints.addVertical(lines.item(line_count+1))
    constraints.addVertical(lines.item(line_count+3))

    # Add construction lines to constrain the rectangle to the center point
    lines = sketch.sketchCurves.sketchLines
    diagonal1 = lines.addByTwoPoints(lines.item(line_count+0).startSketchPoint, lines.item(line_count+2).startSketchPoint)
    diagonal1.isConstruction = True
    diagonal2 = lines.addByTwoPoints(lines.item(line_count+1).startSketchPoint, lines.item(line_count+3).startSketchPoint)
    diagonal2.isConstruction = True

    # Constrain the rectangle to be centered on the center point
    sketchpoints = sketch.sketchPoints
    sk_center = sketchpoints.add(center_point)
    constraints.addMidPoint(sk_center, diagonal1)

    # Dimension the rectangle with the user parameters
    if param_point_x == '':
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.value = abs(sk_center.worldGeometry.x)
    else:
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.expression = param_point_x

    if param_point_y == '':
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.value = abs(sk_center.worldGeometry.y)
    else:
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.expression = param_point_y
               
    if param_horizontal == '':
        sketch.sketchDimensions.addDistanceDimension(lines.item(line_count+0).startSketchPoint, lines.item(line_count+0).endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(lines.item(line_count+0))).parameter.value = abs(sk_center.worldGeometry.x - end_point.worldGeometry.x)*2
    else:    
        sketch.sketchDimensions.addDistanceDimension(lines.item(line_count+0).startSketchPoint, lines.item(line_count+0).endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(lines.item(line_count+0))).parameter.expression = param_horizontal
        
    if param_verticle == '':
        sketch.sketchDimensions.addDistanceDimension(lines.item(line_count+1).startSketchPoint, lines.item(line_count+1).endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         get_dimension_text_point(lines.item(line_count+1))).parameter.value = abs(sk_center.worldGeometry.y - end_point.worldGeometry.y)*2
    else:
        sketch.sketchDimensions.addDistanceDimension(lines.item(line_count+1).startSketchPoint, lines.item(line_count+1).endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         get_dimension_text_point(lines.item(line_count+1))).parameter.expression = param_verticle
    sketch.isComputeDeferred = False
    return rect


###############################################
#Gull Wing Lead

#                                     +                                +
#                                     +<---------+BodyWidth+---------->+

#                                     +--------------------------------+
#                                     |                                |
#                                     |                                |
#                               X+----+                                |
#                              X |   ||                                +--> bodyCenterZ
#                   slope<--+ X X+----+                                |
#           Land(L) <--+     X X      |                                |
#                      |    X X       |                                |
#                  +---+--+X X        |                                |
# terminalThickness|      | X         +---------------+----------------+
#                  +------+X                          |
#                  |                                  |
#                  + <-------+ span/2 +-------------> +


def create_gull_wing_lead(sketch, span, param_span, body_width,  param_body_width, body_center_z, terminal_thickness, L, lead_slope):

    sketch.isComputeDeferred = True
    lines = sketch.sketchCurves.sketchLines
    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(-span/2, 0, 0), adsk.core.Point3D.create(-span/2+L, 0, 0))
    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(-span/2+L+lead_slope, -(body_center_z-terminal_thickness/2), 0))
    line3 = lines.addByTwoPoints(line2.endSketchPoint, adsk.core.Point3D.create(max(-body_width/2,-span/2+L+lead_slope*2), -(body_center_z-terminal_thickness/2), 0))
    line4 = lines.addByTwoPoints(line3.endSketchPoint, adsk.core.Point3D.create(max(-body_width/2,-span/2+L+lead_slope*2), -(body_center_z+terminal_thickness/2), 0))
    line5 = lines.addByTwoPoints(line4.endSketchPoint, adsk.core.Point3D.create(-span/2+L+lead_slope-terminal_thickness, -(body_center_z+terminal_thickness/2), 0))
    line6 = lines.addByTwoPoints(line5.endSketchPoint, adsk.core.Point3D.create(-span/2+L-terminal_thickness, -terminal_thickness, 0))
    line7 = lines.addByTwoPoints(line6.endSketchPoint, adsk.core.Point3D.create(-span/2, -terminal_thickness, 0))
    line8 = lines.addByTwoPoints(line7.endSketchPoint, line1.startSketchPoint)
    arc = sketch.sketchCurves.sketchArcs.addFillet(line1, line1.endSketchPoint.geometry, line2, line2.startSketchPoint.geometry, terminal_thickness)
    arc1 = sketch.sketchCurves.sketchArcs.addFillet(line6, line6.endSketchPoint.geometry, line7, line7.startSketchPoint.geometry, terminal_thickness/4)
    arc2 = sketch.sketchCurves.sketchArcs.addFillet(line5, line5.endSketchPoint.geometry, line6, line6.startSketchPoint.geometry, terminal_thickness)
    arc3 = sketch.sketchCurves.sketchArcs.addFillet(line2, line2.endSketchPoint.geometry, line3, line3.startSketchPoint.geometry, terminal_thickness/4)

        #pin dimensions and constraints
    sketch.sketchDimensions.addDistanceDimension(lines.item(0).startSketchPoint, lines.item(0).endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(lines.item(0)))
    sketch.sketchDimensions.addDistanceDimension(lines.item(3).startSketchPoint, lines.item(3).endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(lines.item(3))).parameter.expression = 'param_terminalThickness'
    sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, lines.item(7).endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(lines.item(7).endSketchPoint)).parameter.expression = param_span

    sketch.sketchDimensions.addRadialDimension(arc, get_dimension_text_point(arc))
    sketch.sketchDimensions.addRadialDimension(arc1, get_dimension_text_point(arc1))
    sketch.geometricConstraints.addEqual(arc, arc2)
    sketch.geometricConstraints.addEqual(arc1, arc3)
    sketch.geometricConstraints.addEqual(line8, line4)
    sketch.geometricConstraints.addEqual(line2, line6)
    sketch.geometricConstraints.addPerpendicular(line8, line1)
    sketch.geometricConstraints.addPerpendicular(line7, line8)
    sketch.geometricConstraints.addPerpendicular(line3, line4)
    sketch.geometricConstraints.addPerpendicular(line4, line5)

    sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line6.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(line2.startSketchPoint)).parameter.expression = 'param_terminalThickness'
    sketch.sketchDimensions.addDistanceDimension(lines.item(3).startSketchPoint, sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(lines.item(3).startSketchPoint)).parameter.expression = param_body_width
    sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line5.startSketchPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(line1.startSketchPoint)).parameter.expression = '(param_A + param_A1 + param_terminalThickness)/2'
    line1.isFixed = True
    sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, line1.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(line1)).parameter.expression = '(param_L-param_terminalThickness)'
    sketch.isComputeDeferred = False



def create_j_lead(sketch, body_width_E1, param_E1, pin_span_E, param_E, weld_space_E2, param_E2,
                    body_height_A, param_A, body_offset_A1, param_A1):
   
    sketch.isComputeDeferred = True
    # define some common value and parameter names
    circle_out_diameter = pin_span_E - weld_space_E2
    circle_out_diameter_param = param_E + '-' + param_E2
    circle_out_radius = circle_out_diameter /2
    circle_out_radius_param = '('+ circle_out_diameter_param+')/2'


    point_center = adsk.core.Point3D.create(weld_space_E2/2, - circle_out_diameter/2,0)
    # create the outer circle
    circle_out = create_center_point_circle(sketch, point_center, param_E2+'/2', circle_out_radius_param, circle_out_diameter, circle_out_diameter_param)
    # create the inner circle
    circles = sketch.sketchCurves.sketchCircles
    circle_in = circles.addByCenterRadius(circle_out.centerSketchPoint, circle_out_radius - TERMINAL_THICKNESS_J_LEAD)
    # add the diameter constrains for the inner circle:
    sketch.sketchDimensions.addDiameterDimension(circle_in, get_dimension_text_point(circle_in), 
                                                        True).parameter.expression = 'param_E - param_E2 -' + str(TERMINAL_THICKNESS_J_LEAD*2) + ' cm'
    


    point_left = adsk.core.Point3D.create(circle_out.centerSketchPoint.geometry.x+circle_out_radius, circle_out.centerSketchPoint.geometry.y, circle_out.centerSketchPoint.geometry.z)
    point_right = adsk.core.Point3D.create(circle_out.centerSketchPoint.geometry.x-circle_out_radius, circle_out.centerSketchPoint.geometry.y, circle_out.centerSketchPoint.geometry.z)
    point_top = adsk.core.Point3D.create(circle_out.centerSketchPoint.geometry.x,circle_out.centerSketchPoint.geometry.y-circle_out_radius, circle_out.centerSketchPoint.geometry.z)

    #draw a line to cut the circle to semi circle.
    lines = sketch.sketchCurves.sketchLines
    split_line = lines.addByTwoPoints(point_left,point_right)
    geom_constrains = sketch.geometricConstraints
    geom_constrains.addHorizontal(split_line)
    sketch.sketchDimensions.addDistanceDimension(split_line.startSketchPoint, sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(split_line.startSketchPoint)).parameter.expression = circle_out_radius_param
    # trim the circle to me the half 
    arc_collection = circle_out.trim(point_top)
    arc_out = adsk.fusion.SketchArc.cast(arc_collection.item(0))
    arc_collection = circle_in.trim(point_top)
    arc_in = adsk.fusion.SketchArc.cast(arc_collection.item(0))


    split_lines = split_line.trim(point_center)
    split_line_left = adsk.fusion.SketchLine.cast(split_lines.item(1))
    split_line_right = adsk.fusion.SketchLine.cast(split_lines.item(0))

    body_mid_place_height = (body_height_A + body_offset_A1)/2
    #start create the 2nd profile
    point_out_rect = adsk.core.Point3D.create(pin_span_E/2,-body_mid_place_height-TERMINAL_THICKNESS_J_LEAD,0)
    line_out_ver = lines.addByTwoPoints(split_line_right.startSketchPoint,point_out_rect) 
    point_in_rect = adsk.core.Point3D.create(pin_span_E/2-TERMINAL_THICKNESS_J_LEAD,-body_mid_place_height,0)
    line_in_ver = lines.addByTwoPoints(split_line_right.endSketchPoint,point_in_rect) 

    point_out_end = adsk.core.Point3D.create(body_width_E1/2,-body_mid_place_height-TERMINAL_THICKNESS_J_LEAD,0)
    line_out_hori = lines.addByTwoPoints(line_out_ver.endSketchPoint,point_out_end) 
    point_in_end = adsk.core.Point3D.create(body_width_E1/2,-body_mid_place_height,0)
    line_in_hori = lines.addByTwoPoints(line_in_ver.endSketchPoint,point_in_end) 

    line_end = lines.addByTwoPoints(line_out_hori.endSketchPoint,line_in_hori.endSketchPoint)

    # add line constrains 
    geom_constrains.addHorizontal(line_out_hori)
    geom_constrains.addHorizontal(line_in_hori)
    geom_constrains.addVertical(line_out_ver)
    geom_constrains.addVertical(line_in_ver)
    geom_constrains.addVertical(line_end)

    sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, line_out_ver.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(line_out_ver.endSketchPoint)).parameter.expression = 'param_A/2 + param_A1/2 +' + str(TERMINAL_THICKNESS_J_LEAD/2) + 'cm'

    sketch.sketchDimensions.addDistanceDimension(line_end.startSketchPoint, line_end.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(line_end)).parameter.value = TERMINAL_THICKNESS_J_LEAD

    sketch.sketchDimensions.addDistanceDimension(line_out_hori.startSketchPoint, line_out_hori.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(line_out_hori)).parameter.expression = '('+ param_E + '-' + param_E1+')/2'    

    sketch.isComputeDeferred = False                         

def create_center_point_circle(sketch,center_point, param_point_x, param_point_y, diameter, param_diameter):
    
    sketch.isComputeDeferred = True
    constraints = sketch.geometricConstraints
    sketchpoints = sketch.sketchPoints
    sk_center = sketchpoints.add(center_point)
    
    # Draw circles and extrude them.
    circles = sketch.sketchCurves.sketchCircles
    circle1 = circles.addByCenterRadius(sk_center,diameter/2)
    #Give the radial dimension
    if param_diameter == '':
        sketch.sketchDimensions.addDiameterDimension(circle1, get_dimension_text_point(circle1), 
                                                        True).parameter.value = diameter
    else:
        sketch.sketchDimensions.addDiameterDimension(circle1, get_dimension_text_point(circle1), 
                                                        True).parameter.expression = param_diameter
        
    if param_point_x == '':
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.value = abs(sk_center.worldGeometry.x)
    else:
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.expression = param_point_x

    if param_point_y == '':
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.value = abs(sk_center.worldGeometry.y)
    else:
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, sk_center,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                         get_dimension_text_point(sk_center)).parameter.expression = param_point_y

    sketch.isComputeDeferred = False
    return circle1 


# this function is defined to create pin path for Axial packages 
def create_axial_pin_path(sketch, pin_pitch, param_pin_pitch, body_width,param_body_width, height_over_board, param_height_over_board, total_height, param_total_height, arc_radius, param_arc_radius):
    
    sketch.isComputeDeferred = True
    lines = sketch.sketchCurves.sketchLines
    line1 = lines.addByTwoPoints(adsk.core.Point3D.create(body_width/2, -height_over_board, 0), adsk.core.Point3D.create(pin_pitch/2, -height_over_board, 0))
    line2 = lines.addByTwoPoints(line1.endSketchPoint, adsk.core.Point3D.create(pin_pitch/2, total_height, 0))
    arc = sketch.sketchCurves.sketchArcs.addFillet(line1, line1.endSketchPoint.geometry, line2, line2.startSketchPoint.geometry, arc_radius)

    sketch.geometricConstraints.addHorizontal(line1)
    sketch.geometricConstraints.addPerpendicular(line1, line2)

    if param_body_width == '':
        sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(line1.startSketchPoint)).parameter.value = body_width/2
    else:
        sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(line1.startSketchPoint)).parameter.expression = param_body_width+'/2'
    
    if param_height_over_board == '':
        sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(line1.startSketchPoint)).parameter.value = height_over_board
    else:
        sketch.sketchDimensions.addDistanceDimension(line1.startSketchPoint, sketch.originPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(line1.startSketchPoint)).parameter.expression = param_height_over_board

    if param_pin_pitch == '':
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, line2.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(line2.endSketchPoint)).parameter.value = pin_pitch/2
    else:
        sketch.sketchDimensions.addDistanceDimension(sketch.originPoint, line2.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                     get_dimension_text_point(line2.endSketchPoint)).parameter.expression = param_pin_pitch+'/2'
    
    
    if param_total_height == '':
        sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(line2.endSketchPoint)).parameter.value = total_height               
    else:
        sketch.sketchDimensions.addDistanceDimension(line2.startSketchPoint, line2.endSketchPoint,
                                                     adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                     get_dimension_text_point(line2.endSketchPoint)).parameter.expression = param_total_height

    if  param_arc_radius == '':
        sketch.sketchDimensions.addRadialDimension(arc, get_dimension_text_point(arc)).parameter.value = arc_radius
    else:                                                                       
        sketch.sketchDimensions.addRadialDimension(arc, get_dimension_text_point(arc)).parameter.expression = param_arc_radius

    sketch.isComputeDeferred = False

def create_dfn_body_sketch(root_comp, params, get_param):
    #Create body offset plane
    sketches = root_comp.sketches
    body_offset = addin_utility.create_offset_plane(root_comp, root_comp.xYConstructionPlane, 'param_A')
    body_offset.name = 'BodyOffset'
    body_sketch = sketches.add(body_offset)
    #Create body sketch
    create_center_point_rectangle(body_sketch, adsk.core.Point3D.create(0, 0, 0), '', '', adsk.core.Point3D.create((get_param(params, 'D'))/2, (get_param(params, 'E'))/2, 0), 'param_D', 'param_E')
    return body_sketch

def create_chip_sketch(root_comp, params, get_param):
    param_d = get_param(params, 'D')
    param_e = get_param(params, 'E')
    param_L = get_param(params, 'L')
    param_L1 = get_param(params, 'L1')

    # Create a new sketch plane
    sketches = root_comp.sketches
    xyPlane = root_comp.xYConstructionPlane
    sketch_body = sketches.add(xyPlane)
    #Create base sketch for the chip
    body = create_center_point_rectangle(sketch_body, adsk.core.Point3D.create(0, 0, 0), '', '',
                 adsk.core.Point3D.create((param_d)/2, (param_e)/2, 0) , 'param_D', 'param_E')
    #Create side terminals and constrain them
    lines = sketch_body.sketchCurves.sketchLines;
    constraints = sketch_body.geometricConstraints
    line_odd = lines.addByTwoPoints(adsk.core.Point3D.create((param_d/2 - param_L1), (param_e)/2, 0),
                                    adsk.core.Point3D.create((param_d/2 - param_L1), -(param_e)/2, 0))
    constraints.addVertical(line_odd)
    line_even = lines.addByTwoPoints(adsk.core.Point3D.create((-(param_d)/2 + param_L), (param_e)/2, 0),
                                    adsk.core.Point3D.create((-(param_d)/2 + param_L), -(param_e)/2, 0))
    constraints.addVertical(line_even)
    constraints.addCoincident(line_even.startSketchPoint, body.item(0))
    constraints.addCoincident(line_odd.startSketchPoint, body.item(0))
    #Making the sketch parametric
    sketch_body.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, line_odd.endSketchPoint,
                                                        adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        get_dimension_text_point(line_odd.startSketchPoint)).parameter.expression = 'param_E'
    sketch_body.sketchDimensions.addDistanceDimension(line_odd.startSketchPoint, body.item(0).startSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(body.item(0).startSketchPoint)).parameter.expression = 'param_L1'

    sketch_body.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, line_even.endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                                                        get_dimension_text_point(line_even.startSketchPoint)).parameter.expression = 'param_E'
    sketch_body.sketchDimensions.addDistanceDimension(line_even.startSketchPoint, body.item(0).endSketchPoint,
                                                         adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                                                         get_dimension_text_point(body.item(0).endSketchPoint)).parameter.expression = 'param_L'

    return sketch_body

def make_fixed_sketch_outlines(sketch_objs):
    for sketch_obj in sketch_objs:
        sketch_obj.isFixed = True

def make_construction_sketch_outlines(sketch_objs):
    for sketch_obj in sketch_objs:
        sketch_obj.isConstruction = True

def draw_two_point_rectangle(sketch, x, y, w, h, angle, is_construction = False, is_fixed = False):
    topLeftCorner = adsk.core.Point3D.create(x - w / 2, y - h / 2, 0)
    bottomRightCorner = adsk.core.Point3D.create(x + w / 2, y + h / 2, 0)

    if angle != None:
        rot_mat = adsk.core.Matrix3D.create()
        rot_mat.setToRotation(math.radians(float(angle[1:])), adsk.core.Vector3D.create(0, 0, 1), adsk.core.Point3D.create(x, y, 0))
        topLeftCorner.transformBy(rot_mat)
        bottomRightCorner.transformBy(rot_mat)

    sketchLines = sketch.sketchCurves.sketchLines
    sketch_line_list = sketchLines.addTwoPointRectangle(topLeftCorner, bottomRightCorner)
    
    if is_construction:
        make_construction_sketch_outlines(sketch_line_list)

    if is_fixed:
        make_fixed_sketch_outlines(sketch_line_list)

def draw_circle_center_radius(sketch, center, radius, is_construction = False, is_fixed = False):
    sketchCircles = sketch.sketchCurves.sketchCircles
    sketch_circle = sketchCircles.addByCenterRadius(center, radius)
    sketch_circle.isConstruction = is_construction
    sketch_circle.isFixed = is_fixed

def draw_pad_with_round_corner(sketch, x, y, w, h, roundness, angle, is_construction = False, is_fixed = False):
    topLeftCorner = adsk.core.Point3D.create(x - w / 2, y - h / 2, 0)
    topRightCorner = adsk.core.Point3D.create(x + w / 2, y - h / 2, 0)
    bottomRightCorner = adsk.core.Point3D.create(x + w / 2, y + h / 2, 0)
    bottomLeftCorner = adsk.core.Point3D.create(x - w / 2, y + h / 2, 0)

    if angle != None:
        rot_mat = adsk.core.Matrix3D.create()
        rot_mat.setToRotation(math.radians(float(angle[1:])), adsk.core.Vector3D.create(0, 0, 1), adsk.core.Point3D.create(x, y, 0))
        topLeftCorner.transformBy(rot_mat)
        topRightCorner.transformBy(rot_mat)
        bottomRightCorner.transformBy(rot_mat)
        bottomLeftCorner.transformBy(rot_mat)

    sketchLines = sketch.sketchCurves.sketchLines
    topLine = sketchLines.addByTwoPoints(topLeftCorner, topRightCorner)
    rightLine = sketchLines.addByTwoPoints(topRightCorner, bottomRightCorner)
    bottomLine = sketchLines.addByTwoPoints(bottomRightCorner, bottomLeftCorner)
    leftLine = sketchLines.addByTwoPoints(bottomLeftCorner, topLeftCorner)

    lines = []
    lines.append(topLine)
    lines.append(rightLine)
    lines.append(bottomLine)
    lines.append(leftLine)

    filletRadius = min(w / 2, h / 2) * roundness / 100
    sketchArcs = sketch.sketchCurves.sketchArcs
    
    arcs = []
    arcs.append(sketchArcs.addFillet(topLine, topLine.endSketchPoint.geometry, rightLine, rightLine.startSketchPoint.geometry, filletRadius))
    arcs.append(sketchArcs.addFillet(rightLine, rightLine.endSketchPoint.geometry, bottomLine, bottomLine.startSketchPoint.geometry, filletRadius))
    arcs.append(sketchArcs.addFillet(bottomLine, bottomLine.endSketchPoint.geometry, leftLine, leftLine.startSketchPoint.geometry, filletRadius))
    arcs.append(sketchArcs.addFillet(leftLine, leftLine.endSketchPoint.geometry, topLine, topLine.startSketchPoint.geometry, filletRadius))

    if is_construction:
        make_construction_sketch_outlines(lines)
        make_construction_sketch_outlines(arcs)

    if is_fixed:
        make_fixed_sketch_outlines(lines)
        make_fixed_sketch_outlines(arcs)

# delete the entire sketch in the target component 
def remove_sketch_by_name(target_component, sketch_name):
    target_sketch = target_component.sketches.itemByName(sketch_name)
    if target_sketch: target_sketch.deleteMe()

# delete all the sketch entities in the specified sketch in the target component 
def clear_sketch_entities(target_component, sketch_name):
    
    target_sketch = target_component.sketches.itemByName(sketch_name)

    if target_sketch:
        # remove the curves
        count = target_sketch.sketchCurves.count
        for i in range(count - 1, -1, -1):
            target_sketch.sketchCurves.item(i).deleteMe()
        # remove the points
        point_count = target_sketch.sketchPoints.count
        for i in range(point_count - 1, -1, -1):
            target_sketch.sketchPoints.item(i).deleteMe()
        
# delete all the text entities in the specified sketch in the target component
def clear_sketch_texts(target_component, sketch_name):
    
    target_sketch = target_component.sketches.itemByName(sketch_name)

    if target_sketch:
        # remove the texts
        count = target_sketch.sketchTexts.count
        for i in range(count - 1, -1, -1):
            target_sketch.sketchTexts.item(i).deleteMe()
