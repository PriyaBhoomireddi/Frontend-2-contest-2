/**
  Copyright (C) 2015-2021 by Autodesk, Inc.
  All rights reserved.

  $Revision: 43194 08c79bb5b30997ccb5fb33ab8e7c8c26981be334 $
  $Date: 2021-02-18 16:25:13 $
  
  FORKID {DE1313C4-B0CA-493D-9136-AE7AF65EF8E4}
*/

description = "Universal Laser DXF";
vendor = "Universal Laser Systems";
vendorUrl = "http://www.ulsinc.com";
legal = "Copyright (C) 2015-2021 by Autodesk, Inc.";
certificationLevel = 2;

longDescription = "This post outputs the toolpath in the DXF (AutoCAD) file format for use with Universal Laser Systems products. You need the DXF import feature enabled in the Universal Laser software. Note that the direction of the toolpath will only be preserved as long as you keep the 'forceSameDirection' property enabled which will trigger linearization of clockwise arcs. You can turn on 'onlyCutting' to only include the actual cutting passes the output. By default the property 'excludeRetracts' is enabled and will leave out retracts from the output. You can enable the property 'writeCuttingModes' property to output the cutting mode color assignments.";

capabilities = CAPABILITY_MILLING | CAPABILITY_JET;
extension = "dxf";
mimetype = "application/dxf";
setCodePage("utf-8");

minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = (1 << PLANE_XY); // allow XY plane only

properties = {
  useTimeStamp: {
    title: "Time stamp",
    description: "Specifies whether to output a time stamp.",
    type: "boolean",
    value: false,
    scope: "post"
  },
  onlyCutting: {
    title: "Only cutting",
    description: "If enabled, only cutting passes will be outputted, all linking moves will be ignored.",
    type: "boolean",
    value: true,
    scope: "post"
  },
  excludeRetracts: {
    title: "Exclude Retracts",
    description: "If enabled, all retract moves will be ignored.",
    type: "boolean",
    value: true,
    scope: "post"
  },
  forceSameDirection: {
    title: "Force same direction",
    description: "Enable to keep the direction of the toolpath, clockwise arcs will be linearized.",
    type: "boolean",
    value: true,
    scope: "post"
  },
  writeCuttingModes: {
    title: "Write cutting modes",
    description: "Enable to document the colors used for the laser cutting modes",
    type: "boolean",
    value: false,
    scope: "post"
  }
};

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var nFormat = createFormat({decimals:9});
var angleFormat = createFormat({decimals:6, scale:DEG});

var layer = 0; // the layer to output into

var BLACK = 0;
var RED = 1;
var YELLOW = 2;
var GREEN = 3;
var CYAN = 4;
var BLUE = 5;
var MAGENTA = 6;
var ORANGE = 30;

var AUTO = 0;
var HIGH = 1;
var MEDIUM = 2;
var LOW = 3;

var jetModes = new Array(
  {mode:JET_MODE_THROUGH, quality:AUTO, color:RED},
  {mode:JET_MODE_THROUGH, quality:HIGH, color:RED},
  {mode:JET_MODE_THROUGH, quality:MEDIUM, color:GREEN},
  {mode:JET_MODE_THROUGH, quality:LOW, color:YELLOW},
  {mode:JET_MODE_ETCHING, quality:AUTO, color:BLUE},
  {mode:JET_MODE_VAPORIZE, quality:AUTO, color:BLUE}
);

function getColorString(color) {
  switch (color) {
  case BLACK:
    return "BLACK";
  case RED:
    return "RED";
  case GREEN:
    return "GREEN";
  case YELLOW:
    return "YELLOW";
  case BLUE:
    return "BLUE";
  case MAGENTA:
    return "MAGENTA";
  case CYAN:
    return "CYAN";
  case ORANGE:
    return "ORANGE";
  default:
    return "UNKNOWN";
  }
}

function getJetModeString(mode) {
  switch (mode) {
  case JET_MODE_THROUGH:
    return "THROUGH";
  case JET_MODE_ETCHING:
    return "ETCHING";
  case JET_MODE_VAPORIZE:
    return "VAPORIZE";
  default:
    return "UNKNOWN";
  }
}

function getJetQualityString(mode) {
  switch (mode) {
  case AUTO:
    return "AUTO";
  case HIGH:
    return "HIGH";
  case MEDIUM:
    return "MEDIUM";
  case LOW:
    return "LOW";
  default:
    return "UNKNOWN";
  }
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln("999");
  writeln(text);
}

function onOpen() {
  // use this to force unit to mm
  // xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), scale:(unit == MM) ? 1 : 25.4});

  writeComment("Generated by Autodesk CAM - http://cam.autodesk.com");

  if (getProperty("useTimeStamp")) {
    var d = new Date();
    writeComment("Generated at " + d);
  }

  writeComment("UNIT = " + ((unit == MM) ? "MM" : "INCH"));

  if (hasGlobalParameter("material")) {
    writeComment("MATERIAL = " + getGlobalParameter("material"));
  }

  if (hasGlobalParameter("material-hardness")) {
    writeComment("MATERIAL_HARDNESS = " + getGlobalParameter("material-hardness"));
  }

  { // stock - workpiece
    var workpiece = getWorkpiece();
    var delta = Vector.diff(workpiece.upper, workpiece.lower);
    if (delta.isNonZero()) {
      writeComment("THICKNESS = " + xyzFormat.format(workpiece.upper.z - workpiece.lower.z));
    }
  }
  
  // dump tool information
  if (getProperty("writeCuttingModes")) {
    for (var i = 0; i < jetModes.length; ++i) {
      var qualityText = "";
      if (jetModes[i].mode == JET_MODE_THROUGH) {
        qualityText = localize("Quality") + ": " + getJetQualityString(jetModes[i].quality) + ", ";
      }
      writeComment(
        localize("Cutting Mode") + ": " + getJetModeString(jetModes[i].mode) + ", " +
        qualityText +
        localize("Color") + ": " + getColorString(jetModes[i].color)
      );
    }
  }
  
  writeln("0");
  writeln("SECTION");

  writeln("2");
  writeln("HEADER");
  
  writeln("9");
  writeln("$ACADVER");
  writeln("1");
  writeln("AC1006");

  writeln("9");
  writeln("$ANGBASE");
  writeln("50");
  writeln("0"); // along +X

  writeln("9");
  writeln("$ANGDIR");
  writeln("70");
  writeln("0"); // ccw arcs
  
  writeln("0");
  writeln("ENDSEC");

  writeln("0");
  writeln("SECTION");
  writeln("2");
  writeln("BLOCKS");
  writeln("0");
  writeln("ENDSEC");

  var box = new BoundingBox(); // always includes origin
  for (var i = 0; i < getNumberOfSections(); ++i) {
    box.expandToBox(getSection(i).getGlobalBoundingBox());
  }

  writeln("9");
  writeln("$EXTMIN");
  writeln("10"); // X
  writeln(xyzFormat.format(box.lower.x));
  writeln("20"); // Y
  writeln(xyzFormat.format(box.lower.y));
  writeln("30"); // Z
  writeln(xyzFormat.format(box.lower.z));

  writeln("9");
  writeln("$EXTMAX");
  writeln("10"); // X
  writeln(xyzFormat.format(box.upper.x));
  writeln("20"); // Y
  writeln(xyzFormat.format(box.upper.y));
  writeln("30"); // Z
  writeln(xyzFormat.format(box.upper.z));

  writeln("0");
  writeln("SECTION");
  writeln("2");
  writeln("ENTITIES");
  // entities start here
}

function onComment(text) {
}

var drillingMode = false;
var jetMode = JET_MODE_THROUGH;

function onSection() {
  var remaining = currentSection.workPlane;
  if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
    error(localize("Tool orientation is not supported."));
    return;
  }
  setRotation(remaining);

  drillingMode = hasParameter("operation-strategy") && (getParameter("operation-strategy") == "drill");
  jetMode = JET_MODE_THROUGH;

  if (currentSection.getType() == TYPE_JET) {
    switch (tool.type) {
    case TOOL_LASER_CUTTER:
      break;
    default:
      error(localize("The CNC only supports laser toolpath."));
      return;
    }

    // encode in DXF output
    switch (currentSection.jetMode) {
    case JET_MODE_THROUGH:
      jetMode = JET_MODE_THROUGH;
      break;
    case JET_MODE_ETCHING:
      jetMode = JET_MODE_ETCHING;
      break;
    case JET_MODE_VAPORIZE:
      jetMode = JET_MODE_VAPORIZE;
      break;
    default:
      error(localize("Unsupported cutting mode."));
      return;
    }
    // currentSection.quality
  }
}

function onParameter(name, value) {
  if ((name == "action") && (value == "pierce")) {
    // output point-pierce command here
  }
}

function onDwell(seconds) {
}

function onCycle() {
}

function onCyclePoint(x, y, z) {
/*
  if (!getProperty("includeDrill")) {
    return;
  }

  writeln("0");
  writeln("POINT");
  writeln("8"); // layer
  writeln(layer);
  writeln("62"); // color
  writeln(1);

  writeln("10"); // X
  writeln(xyzFormat.format(x));
  writeln("20"); // Y
  writeln(xyzFormat.format(y));
  writeln("30"); // Z
  writeln(xyzFormat.format(z));
*/
}

function onCycleEnd() {
}

function writeLine(x, y, z) {
  if (drillingMode) {
    return; // ignore since we only want points
  }

  if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
    error(localize("Compensation in control is not supported."));
    return;
  }
  
  var color;
  switch (movement) {
  case MOVEMENT_CUTTING:
  case MOVEMENT_REDUCED:
  case MOVEMENT_FINISH_CUTTING:
    color = getJetColor(currentSection.jetMode, currentSection.quality);
    break;
  case MOVEMENT_RAPID:
  case MOVEMENT_HIGH_FEED:
    if (getProperty("onlyCutting") || getProperty("excludeRetracts")) {
      return; // skip
    }
    color = YELLOW;
    break;
  case MOVEMENT_LEAD_IN:
  case MOVEMENT_LEAD_OUT:
  case MOVEMENT_LINK_TRANSITION:
  case MOVEMENT_LINK_DIRECT:
    if (getProperty("onlyCutting")) {
      return; // skip
    }
    color = getJetColor(currentSection.jetMode, currentSection.quality);
    break;
  default:
    if (getProperty("onlyCutting")) {
      return; // skip
    }
    color = YELLOW;
  }

  var start = getCurrentPosition();
  if (true) {
    if ((xyzFormat.format(start.x) == xyzFormat.format(x)) &&
        (xyzFormat.format(start.y) == xyzFormat.format(y))) {
      return; // ignore vertical
    }
  }

  writeln("0");
  writeln("LINE");
  writeln("8"); // layer
  writeln(layer);
  writeln("62"); // color
  writeln(color);

  writeln("10"); // X
  writeln(xyzFormat.format(start.x));
  writeln("20"); // Y
  writeln(xyzFormat.format(start.y));
  writeln("30"); // Z
  writeln(xyzFormat.format(0));

  writeln("11"); // X
  writeln(xyzFormat.format(x));
  writeln("21"); // Y
  writeln(xyzFormat.format(y));
  writeln("31"); // Z
  writeln(xyzFormat.format(0));
}

function getJetColor(_mode, _quality) {
  for (var i = 0; i < jetModes.length; ++i) {
    if ((_mode == jetModes[i].mode) && (_quality == jetModes[i].quality)) {
      return jetModes[i].color;
    }
  }
  error(localize("Unsupported Cutting Mode: ") + _mode + ", " + _quality);
  return 0;
}

function onPower(power) {
  // output power command here
}

function onRapid(x, y, z) {
  writeLine(x, y, z);
}

function onLinear(x, y, z, feed) {
  writeLine(x, y, z);
}

function onRapid5D(x, y, z, dx, dy, dz) {
  onExpandedRapid(x, y, z);
}

function onLinear5D(x, y, z, dx, dy, dz, feed) {
  onExpandedLinear(x, y, z);
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (getCircularPlane() != PLANE_XY) {
    // start and end angle reference is unknown
    linearize(tolerance);
    return;
  }

  if (clockwise && getProperty("forceSameDirection")) {
    linearize(tolerance);
    return;
  }

  if (true) {
    if (getCircularPlane() != PLANE_XY) {
      linearize(tolerance);
      return;
    }
  }

  if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
    error(localize("Compensation in control is not supported."));
    return;
  }

  var color;
  switch (movement) {
  case MOVEMENT_CUTTING:
  case MOVEMENT_REDUCED:
  case MOVEMENT_FINISH_CUTTING:
    switch (jetMode) {
    case JET_MODE_THROUGH:
      color = RED;
      break;
    case JET_MODE_ETCHING:
      color = BLUE;
      break;
    case JET_MODE_VAPORIZE:
      color = BLUE;
      break;
    default:
      color = RED;
    }
    break;
  case MOVEMENT_RAPID:
  case MOVEMENT_HIGH_FEED:
    if (getProperty("onlyCutting") || getProperty("excludeRetracts")) {
      return; // skip
    }
    color = YELLOW;
    break;
  case MOVEMENT_LEAD_IN:
  case MOVEMENT_LEAD_OUT:
  case MOVEMENT_LINK_TRANSITION:
  case MOVEMENT_LINK_DIRECT:
    if (getProperty("onlyCutting")) {
      return; // skip
    }
    switch (jetMode) {
    case JET_MODE_THROUGH:
      color = RED;
      break;
    case JET_MODE_ETCHING:
      color = BLUE;
      break;
    case JET_MODE_VAPORIZE:
      color = BLUE;
      break;
    default:
      color = RED;
    }
    break;
  default:
    if (getProperty("onlyCutting")) {
      return; // skip
    }
    color = YELLOW;
  }

  writeln("0");
  writeln("ARC");
  writeln("8"); // layer
  writeln(layer);
  writeln("62"); // color
  writeln(color);

  writeln("10"); // X
  writeln(xyzFormat.format(cx));
  writeln("20"); // Y
  writeln(xyzFormat.format(cy));
  writeln("30"); // Z
  writeln(xyzFormat.format(0));

  writeln("40"); // radius
  writeln(xyzFormat.format(getCircularRadius()));

  var start = getCurrentPosition();
  var startAngle = Math.atan2(start.y - cy, start.x - cx);
  var endAngle = Math.atan2(y - cy, x - cx);
  // var endAngle = startAngle + (clockwise ? -1 : 1) * getCircularSweep();
  if (clockwise) { // we must be ccw
    var temp = startAngle;
    startAngle = endAngle;
    endAngle = temp;
  }
  writeln("50"); // start angle
  writeln(angleFormat.format(startAngle));
  writeln("51"); // end angle
  writeln(angleFormat.format(endAngle));
  
  if (getCircularPlane() != PLANE_XY) {
    var n = getCircularNormal();
    writeln("210"); // X
    writeln(nFormat.format(n.x));
    writeln("220"); // Y
    writeln(nFormat.format(n.y));
    writeln("230"); // Y
    writeln(nFormat.format(n.z));
  }
}

function onCommand() {
}

function onSectionEnd() {
}

function onClose() {
  writeln("0");
  writeln("ENDSEC");
  writeln("0");
  writeln("EOF");
}

function onTerminate() {
  var outputPath = getOutputPath();
  var args = "\"" + outputPath + "\"";
  // start external application here
  // if (getProperty("startUniversalLaser")) {
  //   execute("universallaser.exe", args, false, "");
  // }
}

function setProperty(property, value) {
  properties[property].current = value;
}
