"""
define all the constants used in the addin
"""


#define the data schema version
CURRENT_VERSION = '1.0.0'

#footprint sketch default names
SKETCH_NAME_FOOTPRINT = 'Pad'
SKETCH_NAME_SILKSCREEN = 'Silkscreen'
SKETCH_NAME_TEXT = 'Text'

# define the package type as constant. so they can be used in different places. 
PKG_TYPE_SOIC   = 'soic'
PKG_TYPE_BGA    = 'bga'
PKG_TYPE_QFP    = 'qfp'
PKG_TYPE_QFN    = 'qfn'
PKG_TYPE_SOD    = 'sod'
PKG_TYPE_SODFL  = 'sodfl'
PKG_TYPE_SOTFL  = 'sotfl'
PKG_TYPE_SOT23  = 'sot23'
PKG_TYPE_SOT223 = 'sot223'
PKG_TYPE_SOT143 = 'sot143'
PKG_TYPE_DPAK   = 'dpak'
PKG_TYPE_DFN2   = 'dfn2'
PKG_TYPE_DFN3   = 'dfn3'
PKG_TYPE_DFN4   = 'dfn4'
PKG_TYPE_CRYSTAL = 'crystal'
PKG_TYPE_CHIP   = 'chip'
PKG_TYPE_MELF   = 'melf'
PKG_TYPE_MOLDEDBODY = 'moldedbody'
PKG_TYPE_AXIAL_RESISTOR = 'axial_resistor'
PKG_TYPE_AXIAL_POLARIZED_CAPACITOR = 'axial_polarized_capacitor'
PKG_TYPE_AXIAL_DIODE = 'axial_diode'
PKG_TYPE_AXIAL_FUSE = 'axial_fuse'
PKG_TYPE_DIP    = 'dip'
PKG_TYPE_HEADER_STRAIGHT = 'header_straight'
PKG_TYPE_HEADER_RIGHT_ANGLE = 'header_right_angle'
PKG_TYPE_HEADER_STRAIGHT_SOCKET = 'header_straight_socket'
PKG_TYPE_HEADER_RIGHT_ANGLE_SOCKET = 'header_right_angle_socket'
PKG_TYPE_SON = 'son'
PKG_TYPE_CRYSTAL_HC49 = 'crystal_hc49'
PKG_TYPE_OSCILLATOR_L = 'oscillator_l'
PKG_TYPE_OSCILLATOR_J = 'oscillator_j'
PKG_TYPE_CHIPARRAY2SIDECONVEX = 'chiparray2sideconvex'
PKG_TYPE_CHIPARRAY2SIDEFLAT = 'chiparray2sideflat'
PKG_TYPE_CHIPARRAY4SIDEFLAT = 'chiparray4sideflat'
PKG_TYPE_RADIAL_INDUCTOR = 'radial_inductor'
PKG_TYPE_RADIAL_ROUND_LED = 'radial_round_led'
PKG_TYPE_PLCC = 'plcc'
PKG_TYPE_CORNERCONCAVE = 'cornerconcave'
PKG_TYPE_SOJ = 'soj'
PKG_TYPE_RADIAL_ECAP = 'radial_ecap'
PKG_TYPE_ECAP = 'ecap'
PKG_TYPE_FEMALE_STANDOFF = 'female_standoff'
PKG_TYPE_MALE_FEMALE_STANDOFF = 'male_female_standoff'
PKG_TYPE_SNAP_LOCK = 'snap_lock'
PKG_TYPE_CHIP_LED = 'chip_led'


SUPPORT_PACKAGE_TYPE = [PKG_TYPE_AXIAL_DIODE, 
                        PKG_TYPE_AXIAL_FUSE,
                        PKG_TYPE_AXIAL_RESISTOR,
                        PKG_TYPE_AXIAL_POLARIZED_CAPACITOR,
                        PKG_TYPE_BGA,
                        PKG_TYPE_CHIP,
                        PKG_TYPE_SOIC,
                        PKG_TYPE_DFN2,
                        PKG_TYPE_DFN3,
                        PKG_TYPE_DFN4,
                        PKG_TYPE_HEADER_RIGHT_ANGLE,
                        PKG_TYPE_HEADER_RIGHT_ANGLE_SOCKET,
                        PKG_TYPE_HEADER_STRAIGHT,
                        PKG_TYPE_HEADER_STRAIGHT_SOCKET,
                        PKG_TYPE_SON,
                        PKG_TYPE_CHIP_LED,
                        PKG_TYPE_QFP,
                        PKG_TYPE_QFN,
                        PKG_TYPE_CHIPARRAY2SIDECONVEX,
                        PKG_TYPE_CHIPARRAY2SIDEFLAT,
                        PKG_TYPE_CHIPARRAY4SIDEFLAT,
                        PKG_TYPE_SOT143,
                        PKG_TYPE_SOT223,
                        PKG_TYPE_SOT23,
                        PKG_TYPE_SOTFL,
                        PKG_TYPE_PLCC,
                        PKG_TYPE_OSCILLATOR_J,
                        PKG_TYPE_OSCILLATOR_L,
                        PKG_TYPE_SOJ,
                        PKG_TYPE_CRYSTAL,
                        PKG_TYPE_CRYSTAL_HC49,
                        PKG_TYPE_DIP,
                        PKG_TYPE_ECAP,
                        PKG_TYPE_MELF,
                        PKG_TYPE_MOLDEDBODY,
                        PKG_TYPE_FEMALE_STANDOFF,
                        PKG_TYPE_MALE_FEMALE_STANDOFF,
                        PKG_TYPE_SOD,
                        PKG_TYPE_SNAP_LOCK,
                        PKG_TYPE_RADIAL_ECAP,
                        PKG_TYPE_RADIAL_INDUCTOR,
                        PKG_TYPE_RADIAL_ROUND_LED,
                        PKG_TYPE_CORNERCONCAVE,
                        PKG_TYPE_SODFL,
                        PKG_TYPE_DPAK
        ]


# define the materials by using the id 
MATERIAL_LIB_ID = 'C1EEA57C-3F56-45FC-B8CB-A9EC46A9994C'  # 'Fusion 360 Material Library'
MATERIAL_ID_BODY_DEFAULT = 'PrismMaterial-402'  #'Discrete Component' 
MATERIAL_ID_TERMINAL_DEFAULT = 'PrismMaterial-090' #'Copper, Alloy'
MATERIAL_ID_COPPER_ALLOY = 'PrismMaterial-090'
MATERIAL_ID_EPOXY_RESIN = 'PrismMaterial-220'
MATERIAL_ID_PBT_PLASTIC = 'PrismMaterial-277'
MATERIAL_ID_PLASTIC_TRANSP = 'PrismMaterial-052'
MATERIAL_ID_CERAMIC = 'PrismMaterial-213'
MATERIAL_ID_ALUMINUM = 'PrismMaterial-002'
MATERIAL_ID_GLASS = 'PrismMaterial-086'
MATERIAL_ID_DISCRETE_COMP = 'PrismMaterial-402'
MATERIAL_ID_BRASS = 'PrismMaterial-003'
MATERIAL_ID_NYLON = 'PrismMaterial-223'
MATERIAL_ID_TIN = "PrismMaterial-403"
MATERIAL_ID_LEAD_SOLDER = "PrismMaterial-404"
# define the appearance by using the id
APPEARANCE_LIB_ID = 'BA5EE55E-9982-449B-9D66-9F036540E140'  # 'Fusion 360 Appearance Library'
APPEARANCE_ID_BODY_DEFAULT = 'Prism-113'  # 'Plastic - Matte (Black)'
APPEARANCE_ID_TERMINAL_DEFAULT = 'Prism-053' # 'Nickel polished'
APPEARANCE_ID_NICKEL_POLISHED =  'Prism-053'
APPEARANCE_ID_ALUMINUM_POLISHED =  'Prism-027' 
APPEARANCE_ID_GLASS =  'Prism-155' 
APPEARANCE_ID_GLASS_CLEAR =  'Prism-152'
APPEARANCE_ID_GLASS_LIGHT = 'Prism-163'
APPEARANCE_ID_GOLD_POLISHED = 'Prism-052' 
APPEARANCE_ID_EMISSIVE_LED = 'Prism-417'

# define the color property id to get the color
COLOR_PROP_ID_DEFAULT = 'opaque_albedo' # name is 'Color'
COLOR_PROP_ID_METAL = 'metal_f0' # name is 'Color'
COLOR_PROP_ID_TRANSPARENT = 'transparent_color' # name is 'Color'
COLOR_PROP_ID_LAYER = 'layered_diffuse' # name is 'Color'
COLOR_PROP_ID_WOOD = 'wood_early_color'
COLOR_PROP_ID_LUMINANCE = 'opaque_luminance_modifier' # the light color property 
FLOAT_PROP_ID_LUMINANCE = 'opaque_luminance' # the luminance value

# define the customerize color names which will be used in packages
COLOR_NAME_AXIAL_DIODE_BODY = 'Axial Diode Body'
COLOR_NAME_AXIAL_POLAR_CAP_BODY = 'Axial Capacitor Body'
COLOR_NAME_AXIAL_RESISTOR_BODY = 'Axial Resistor Body'
COLOR_NAME_BGA_MID_BODY = 'BGA Middle Body'
COLOR_NAME_CHIP_BODY = 'Chip Body'
COLOR_NAME_MELF_BODY = 'Melf Body'
COLOR_NAME_MELF_BAND = 'Melf Band'
COLOR_NAME_ECAP_BODY = 'ECap Body'
COLOR_NAME_ECAP_BAND = 'ECap Band'
COLOR_NAME_RADIAL_INDUCTOR_BODY = 'Radial Inductor Body'
COLOR_NAME_RADIAL_LED_LIGHT = 'Radial LED'
COLOR_NAME_RADIAL_LED_BODY = 'Radial LED Body'
COLOR_NAME_CHIP_LED_LIGHT = 'Chip LED'
COLOR_NAME_CHIP_LED_CASE = 'Chip LED Case'
COLOR_NAME_SNAP_LOCK_BODY = 'Snap Lock Body'

# define the propoerties for meta data schema.
META_PROPERTIES = ['ipcFamily', 'ipcName', 'jedecFamily', 
                'jedecVariant', 'pins', 'pitch', 
                'pitch2', 'bodyLength', 'bodyWidth', 
                'height', 'leadSpan', 'leadSpan2', 
                'mountingType']

# define the component family name
COMP_FAMILY_RESISTOR = 'Resistor'
COMP_FAMILY_NONPOLARIZED_CAPACITOR = 'Capacitor - Non polarized'
COMP_FAMILY_POLARIZED_CAPACITOR = 'Polarized Capacitor'
COMP_FAMILY_DIODE = 'Diode'
COMP_FAMILY_FUSE = 'Fuse'
COMP_FAMILY_NONPOLARIZED_DIODE = 'Diode - Non polarized'
COMP_FAMILY_FERRITE_BEAD = 'Ferrite Bead'
COMP_FAMILY_THERMISTOR = 'Thermistor'
COMP_FAMILY_VARISTOR = 'Varistor'
COMP_FAMILY_CRYSTAL = 'Crystal'
COMP_FAMILY_FILTER = 'Filter'
COMP_FAMILY_IC = 'Integrated Circuit (IC)'
COMP_FAMILY_TRANSISTOR = 'Transistor'
COMP_FAMILY_LED = 'LED'
COMP_FAMILY_INDUCTOR = 'Inductor'
COMP_FAMILY_PRECISION_INDUCTOR = 'Precision Inductor'
COMP_FAMILY_POLARIZED_INDUCTOR = 'Polarized Inductor'
COMP_FAMILY_NONPOLARIZED_INDUCTOR = 'Inductor - Non polarized'


# define terminal types for BGA package
TERMINAL_TYPE_COLLAPSING = 'Collapsing Ball'
TERMINAL_TYPE_NON_COLLAPSING = 'Non Collapsing Ball'

# define the dimention options for the UI selection
DIMENSION_OPTIONS_LEAD_SPAN = 'D (Lead Span)'
DIMENSION_OPTIONS_TERMINAL_GAP = 'D2 (Terminal Gap)'
DIMENSION_OPTIONS_TERMINAL_LEN = 'L (Terminal Length)'

DIMENSION_OPTIONS = {
        'DimOptionLeadSpan' : DIMENSION_OPTIONS_LEAD_SPAN,
        'DimOptionTerminalGap' : DIMENSION_OPTIONS_TERMINAL_GAP,
        'DimOptionTerminalLength' : DIMENSION_OPTIONS_TERMINAL_LEN
    }

# define footprint location
FOOTPRINT_LOCATION_CENTER = 'Center of pads'
FOOTPRINT_LOCATION_PIN1 = 'Pin 1'

# define the pin num sequence pattern.
PIN_NUM_SEQUENCE_LRCW = 'LRCW'  # LRCW - Clockwise from top left
PIN_NUM_SEQUENCE_LRCCW = 'LRCCW' #LRCCW - Counter-clockwise from bottom left
PIN_NUM_SEQUENCE_ZZBT = 'ZZBT' # ZZBT - ZigZag from bottom left

#define lens types for Chip LED
LENS_TYPE_FLAT_TOP = 'Rectangle with Flat Top'
LENS_TYPE_DOMED_TOP = 'Rectangle with Domed Top'
#define some common ui attributes 
PTH_PAD_SHAPE = {
    'Round': 'Round',
    'Square': 'Square',
    'RoundedSquare': 'Rounded Square'
}

SMD_PAD_SHAPE = {
    'Rectangle': 'Rectangle',
    'RoundedRectangle': 'Rounded Rectangle',
    'Oblong': 'Oblong'
}

DENSITY_LEVEL_TH = {
    'Most (A)': 0,
    'Nominal (B)': 1,
    'Least (C)': 2
} #For thru-hole

DENSITY_LEVEL_SMD = {
    'Most (M)': 0,
    'Nominal (N)': 1,
    'Least (L)': 2
} #For smd

SILKSCREEN_MAPPING_TO_BODY = {
    'MappingTypeToBodyMax': 'Maximum',
    'MappingTypeToBodyNom': 'Nominal',
    'MappingTypeToBodyMin': 'Minimum'
}

COLOR_VALUE_GREEN = '#1E5F41'
COLOR_VALUE_BLUE = '#1825F8'
COLOR_VALUE_YELLOW = '#FFFF00'
COLOR_VALUE_WHITE = '#FFFFFF'
COLOR_VALUE_RED = '#FF0000'
COLOR_VALUE_AMBER = '#FA9641'
COLOR_VALUE_PURPLE = '#800080'
COLOR_VALUE_BLACK = '#0A0A0A'
COLOR_VALUE_BROWN = '#503741'
COLOR_VALUE_CYAN = '#00FFFF'
COLOR_VALUE_MAROON = '#800000'
COLOR_VALUE_GREY = '#808080'
COLOR_VALUE_SILVER = '#C0C0C0'

BODY_COLOR = {
    'Green' :   COLOR_VALUE_GREEN,
    'Blue'  :   COLOR_VALUE_BLUE,
    'Yellow':   COLOR_VALUE_YELLOW,
    'White' :   COLOR_VALUE_WHITE,
    'Red'   :   COLOR_VALUE_RED,
    'Amber' :   COLOR_VALUE_AMBER,
    'Purple':   COLOR_VALUE_PURPLE,
    'Black' :   COLOR_VALUE_BLACK,
    'Custom':   ''
}


CUSTOM_DIMENSION_OPTIONS = {
    'padGap': 'g (Custom Pad Gap)',
    'padPitch': 'p (Custom Pad Pitch)'
}

THREAD_TYPES = {
    'threadType1' : 'ACME Screw Threads',
    'threadType2' : 'AFBMA Standard Locknuts',
    'threadType3' : 'ANSI Metric M Profile',
    'threadType4' : 'ANSI Unified Screw Threads',
    'threadType5' : 'BSP Pipe Threads',
    'threadType6' : 'DIN Pipe Threads',
    'threadType7' : 'GB Metric profile',
    'threadType8' : 'GB Pipe Threads without seal',
    'threadType9' : 'GOST Self-tapping Screw Thread',
    'threadType10' : 'ISO Metric Trapezoidal Threads',
    'threadType11' : 'ISO Metric profile',
    'threadType12' : 'ISO Pipe Threads',
    'threadType13' : 'Inch Tapping Threads',
    'threadType14' : 'JIS Pipe Threads',
    'threadType15' : 'Metric Forming Screw Threads'

}