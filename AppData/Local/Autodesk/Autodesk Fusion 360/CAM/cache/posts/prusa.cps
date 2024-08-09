/**
  Copyright (C) 2018-2021 by Autodesk, Inc.
  All rights reserved.

  3D additive printer post configuration.

  $Revision: 43294 426e6adfc5c63a393abb11432ed271081f206b49 $
  $Date: 2021-05-05 15:53:25 $

  FORKID {FEF3D431-E19A-4541-8E5C-A32A33348505}
*/

description = "Prusa";
vendor = "Prusa";
vendorUrl = "https://www.prusa3d.com/";
legal = "Copyright (C) 2012-2021 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 45702;

longDescription = "Post for exporting toolpath to the Prusa i3 family or mini in gcode format (i3, i3 MK2, i3 MK3 ..., mini)";

extension = "gcode";
setCodePage("ascii");

capabilities = CAPABILITY_ADDITIVE;
highFeedrate = 12000;
// used for arc support or linearization
tolerance = spatial(0.002, MM); // may be set higher i.e 0.02?
minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.4, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false; // disable helical support
allowSpiralMoves = false; // disable spiral support
allowedCircularPlanes = 1 << PLANE_XY; // allow XY circular motion

// needed for range checking, will be effectively passed from Fusion
var printerLimits = {
  x: {min: 0, max: 250.0}, // defines the x bed size
  y: {min: 0, max: 210.0}, // defines the y bed size
  z: {min: 0, max: 210.0} // defines the z bed size
};

// for information only
var bedCenter = {
  x: 0.0,
  y: 0.0,
  z: 0.0
};

var extruderOffsets = [[0, 0, 0], [0, 0, 0]];
var activeExtruder = 0; // track the active extruder.

// user-defined properties
properties = {
  printerModel: {
    title: "Printer model",
    description: "Select the printer model for generating the gcode.",
    type: "enum",
    values: [
      {title: "i3 Mk2, i3 Mk3", id: "i3mk2mk3"},
      {title: "mini", id: "mini"}
    ],
    value: "i3mk2mk3",
    scope: "machine"
  }
};

var xyzFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var xFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var yFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var zFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var gFormat = createFormat({prefix: "G", width: 1, zeropad: false, decimals: 0});
var mFormat = createFormat({prefix: "M", width: 2, zeropad: true, decimals: 0});
var tFormat = createFormat({prefix: "T", width: 1, zeropad: false, decimals: 0});
var feedFormat = createFormat({decimals: (unit == MM ? 0 : 1)});
var integerFormat = createFormat({decimals:0});
var dimensionFormat = createFormat({decimals: (unit == MM ? 3 : 4), zeropad: false, suffix: (unit == MM ? "mm" : "in")});

var gMotionModal = createModal({force: true}, gFormat); // modal group 1 _ G0-G3, ...
var gPlaneModal = createModal({onchange: function () {gMotionModal.reset();}}, gFormat); // modal group 2 _ G17-19 _ actually unused
var gAbsIncModal = createModal({}, gFormat); // modal group 3 _ G90-91

var xOutput = createVariable({prefix: "X"}, xFormat);
var yOutput = createVariable({prefix: "Y"}, yFormat);
var zOutput = createVariable({prefix: "Z"}, zFormat);
var feedOutput = createVariable({prefix: "F"}, feedFormat);
var eOutput = createVariable({prefix: "E"}, xyzFormat); // extrusion length
var sOutput = createVariable({prefix: "S", force: true}, xyzFormat); // parameter temperature or speed
var iOutput = createReferenceVariable({prefix:"I", force:true}, xyzFormat); // circular output
var jOutput = createReferenceVariable({prefix:"J", force:true}, xyzFormat); // circular output

// generic functions

// writes the specified block.
function writeBlock() {
  writeWords(arguments);
}

function writeComment(text) {
  writeln(";" + text);
}

// onOpen helper functions

function formatCycleTime(cycleTime) {
  var seconds = cycleTime % 60 | 0;
  var minutes = ((cycleTime - seconds) / 60 | 0) % 60;
  var hours = (cycleTime - minutes * 60 - seconds) / (60 * 60) | 0;
  if (hours > 0) {
    return subst(localize("%1h:%2m:%3s"), hours, minutes, seconds);
  } else if (minutes > 0) {
    return subst(localize("%1m:%2s"), minutes, seconds);
  } else {
    return subst(localize("%1s"), seconds);
  }
}

function getPrinterGeometry() {
  machineConfiguration = getMachineConfiguration();

  // get the printer geometry from the machine configuration
  printerLimits.x.min = 0 - machineConfiguration.getCenterPositionX();
  printerLimits.y.min = 0 - machineConfiguration.getCenterPositionY();
  printerLimits.z.min = 0 + machineConfiguration.getCenterPositionZ();

  printerLimits.x.max = machineConfiguration.getWidth() - machineConfiguration.getCenterPositionX();
  printerLimits.y.max = machineConfiguration.getDepth() - machineConfiguration.getCenterPositionY();
  printerLimits.z.max = machineConfiguration.getHeight() + machineConfiguration.getCenterPositionZ();

  // can be used in the post for documenting purpose.
  bedCenter.x = (machineConfiguration.getWidth() / 2.0) - machineConfiguration.getCenterPositionX();
  bedCenter.y = (machineConfiguration.getDepth() / 2.0) - machineConfiguration.getCenterPositionY();
  bedCenter.z = machineConfiguration.getCenterPositionZ();

  // get the extruder configuration
  extruderOffsets[0][0] = machineConfiguration.getExtruderOffsetX(1);
  extruderOffsets[0][1] = machineConfiguration.getExtruderOffsetY(1);
  extruderOffsets[0][2] = machineConfiguration.getExtruderOffsetZ(1);
  if (numberOfExtruders > 1) {
    extruderOffsets[1] = [];
    extruderOffsets[1][0] = machineConfiguration.getExtruderOffsetX(2);
    extruderOffsets[1][1] = machineConfiguration.getExtruderOffsetY(2);
    extruderOffsets[1][2] = machineConfiguration.getExtruderOffsetZ(2);
  }
}

function onOpen() {
  getPrinterGeometry();

  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

  writeComment("Printer name: " + machineConfiguration.getVendor() + " " + machineConfiguration.getModel());
  writeComment("Print time: " + formatCycleTime(printTime));
  writeComment("Material used: " + dimensionFormat.format(getExtruder(1).extrusionLength));
  writeComment("Material name: " + getExtruder(1).materialName);
  writeComment("Filament diameter: " + dimensionFormat.format(getExtruder(1).filamentDiameter));
  writeComment("Nozzle diameter: " + dimensionFormat.format(getExtruder(1).nozzleDiameter));
  writeComment("Extruder offset x: " + dimensionFormat.format(extruderOffsets[0][0]));
  writeComment("Extruder offset y: " + dimensionFormat.format(extruderOffsets[0][1]));
  writeComment("Extruder offset z: " + dimensionFormat.format(extruderOffsets[0][2]));
  writeComment("Max temp: " + integerFormat.format(getExtruder(1).temperature));
  writeComment("Bed temp: " + integerFormat.format(bedTemp));
  writeComment("Layer Count: " + integerFormat.format(layerCount));

  writeComment("Width: " + dimensionFormat.format(printerLimits.x.max));
  writeComment("Depth: " + dimensionFormat.format(printerLimits.y.max));
  writeComment("Height: " + dimensionFormat.format(printerLimits.z.max));
  writeComment("Center x: " + dimensionFormat.format(bedCenter.x));
  writeComment("Center y: " + dimensionFormat.format(bedCenter.y));
  writeComment("Center z: " + dimensionFormat.format(bedCenter.z));
  writeComment("Count of bodies: " + integerFormat.format(partCount));
  writeComment("Fusion version: " + getGlobalParameter("version", "0"));
  writeBlock("M115 U3.0.10 ; tell printer latest fw version");
  if (getProperty("printerModel") == "i3mk2mk3") {
    writeBlock(gFormat.format(28), "W ; home all without mesh bed level");
  }  else if (getProperty("printerModel") == "mini") {
    writeBlock(gFormat.format(28), "; home all without mesh bed level");
  }
}

// generic helper functions

function setFeedRate(value) {
  feedOutput.reset();
  if (value > highFeedrate) {
    value = highFeedrate;
  }
  if (unit == IN) {
    value /= 25.4;
  }
  writeBlock(gFormat.format(1), feedOutput.format(value));
}

function forceXYZE() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
  eOutput.reset();
}

function onSection() {
  var range = currentSection.getBoundingBox();
  axes = ["x", "y", "z"];
  formats = [xFormat, yFormat, zFormat];
  for (var element in axes) {
    var min = formats[element].getResultingValue(range.lower[axes[element]]);
    var max = formats[element].getResultingValue(range.upper[axes[element]]);
    if (printerLimits[axes[element]].max < max || printerLimits[axes[element]].min > min) {
      error(localize("A toolpath is outside of the build volume."));
    }
  }

  // probe bed after heating
  if (getProperty("printerModel") == "i3mk2mk3") {
    writeBlock(gFormat.format(80), "; mesh bed leveling");
  }  else if (getProperty("printerModel") == "mini") {
    writeBlock(gFormat.format(29), "; mesh bed leveling");
  }

  writeBlock(gFormat.format(92), eOutput.format(0));

  // set unit
  writeBlock(gFormat.format(unit == MM ? 21 : 20));
  writeBlock(gAbsIncModal.format(90)); // absolute spatial co-ordinates
  writeBlock(mFormat.format(82)); // absolute extrusion co-ordinates
}

// miscellaneous entry functions

function onComment(message) {
  writeComment(message);
}

function onParameter(name, value) {
  switch (name) {
  // feedrate is set before rapid moves and extruder change
  case "feedRate":
    setFeedRate(value);
    break;
    // warning or error message on unhandled parameter?
  }
}

// additive entry functions

function onBedTemp(temp, wait) {
  if (wait) {
    writeBlock(mFormat.format(190), sOutput.format(temp));
  } else {
    writeBlock(mFormat.format(140), sOutput.format(temp));
  }
}

function onExtruderChange(id) {
  if (id < numberOfExtruders) {
    writeBlock(tFormat.format(id));
    activeExtruder = id;
    forceXYZE();
  } else {
    error(localize("This printer doesn't support the extruder ") + integerFormat.format(id) + " !");
  }
}

function onExtrusionReset(length) {
  eOutput.reset();
  writeBlock(gFormat.format(92), eOutput.format(length));
}

function onExtruderTemp(temp, wait, id) {
  var extruderString = "";

  if (getProperty("printerModel") == "i3mk2mk3") {
    extruderString = tFormat.format(id);
  }
  if (id < numberOfExtruders) {
    if (wait) {
      writeBlock(mFormat.format(109), sOutput.format(temp), extruderString);
    } else {
      writeBlock(mFormat.format(104), sOutput.format(temp), extruderString);
    }
  } else {
    error(localize("This printer doesn't support the extruder ") + integerFormat.format(id) + " !");
  }
}

function onFanSpeed(speed, id) {
  if (speed == 0) {
    writeBlock(mFormat.format(107));
  } else {
    writeBlock(mFormat.format(106), sOutput.format(speed));
  }
}

function onLayer(num) {
  writeComment("Layer : " + integerFormat.format(num) + " of " + integerFormat.format(layerCount));
}

// motion entry functions
function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    writeBlock(gMotionModal.format(0), x, y, z);
    feedOutput.reset();
  }
}

function onLinearExtrude(_x, _y, _z, _f, _e) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(_f);
  var e = eOutput.format(_e);
  if (x || y || z || f || e) {
    writeBlock(gMotionModal.format(1), x, y, z, f, e);
  }
}

function onCircularExtrude(_clockwise, _cx, _cy, _cz, _x, _y, _z, _f, _e) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(_f);
  var e = eOutput.format(_e);
  var start = getCurrentPosition();
  var i = iOutput.format(_cx - start.x, 0); // arc center relative to start point
  var j = jOutput.format(_cy - start.y, 0);
  
  switch (getCircularPlane()) {
  case PLANE_XY:
    writeBlock(gMotionModal.format(_clockwise ? 2 : 3), x, y, i, j, f, e);
    break;
  default:
    linearize(tolerance);
  }
}

function onClose() {
  writeBlock("G4 ; wait");
  xOutput.reset();
  yOutput.reset();
  if (getProperty("printerModel") == "i3mk2mk3") {
    writeBlock(gMotionModal.format(1), xOutput.format(0), yOutput.format((unit == MM ? 200 : 7.8)), "; home X axis");
  } else if (getProperty("printerModel") == "mini") {
    writeBlock(gMotionModal.format(1), xOutput.format(0), yOutput.format((unit == MM ? 150 : 5.9)), "; home X axis");
  }
  writeBlock(mFormat.format(84), "; disable motors");
}

function setProperty(property, value) {
  properties[property].current = value;
}
