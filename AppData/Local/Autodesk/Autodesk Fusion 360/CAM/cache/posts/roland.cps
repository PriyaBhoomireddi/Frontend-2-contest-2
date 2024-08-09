/**
  Copyright (C) 2012-2021 by Autodesk, Inc.
  All rights reserved.

  Roland post processor configuration.

  $Revision: 43194 08c79bb5b30997ccb5fb33ab8e7c8c26981be334 $
  $Date: 2021-02-18 16:25:13 $
  
  FORKID {972EA664-635A-4531-8C5D-E95C993B50EF}
*/

description = "Roland";
vendor = "Roland DG";
vendorUrl = "http://www.rolanddg.com";
legal = "Copyright (C) 2012-2021 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 45702;

longDescription = "Generic post for Roland.";

extension = "nc";
programNameIsInteger = true;
setCodePage("ascii");

capabilities = CAPABILITY_MILLING;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  mode: {
    title: "Mode",
    description: "Specifies the post mode.",
    type: "integer",
    values: [
      1,
      2
    ],
    value: 1,
    scope: "post"
  }
};

var mFormat = createFormat({decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var feedFormat = createFormat({decimals:(unit == MM ? 0 : 1), forceDecimal:true});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var milliFormat = createFormat({decimals:0}); // milliseconds

var xOutput = createVariable({}, xyzFormat);
var yOutput = createVariable({}, xyzFormat);
var zOutput = createVariable({onchange:function () {retracted = false;}}, xyzFormat);
var feedOutput = createVariable({}, feedFormat);
var sOutput = createVariable({force:true}, rpmFormat);

// collected state
var retracted = false; // specifies that the tool has been retracted to the safe plane

/**
  Writes the specified block.
*/
function writeBlock() {
  writeWords(arguments);
}

function onOpen() {
  setWordSeparator(",");

  if (programName) {
    var programId;
    try {
      programId = getAsInt(programName);
    } catch (e) {
      error(localize("Program name must be a number."));
    }
    if (!((programId >= 1) && (programId <= 9999))) {
      error(localize("Program number is out of range."));
    }
    if ((programId >= 8000) && (programId <= 9999)) {
      warning(localize("Program number is reserved by tool builder."));
    }
    var oFormat = createFormat({width:4, zeropad:true, decimals:0});
    writeln("O" + oFormat.format(programId));
  } else {
    error(localize("Program name has not been specified."));
  }

  if (getProperty("mode") == 2) {
    writeBlock("IN"); // reset - absolute coordinates, ...
  }

/*
  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(20));
    break;
  case MM:
    writeBlock(gUnitModal.format(21));
    break;
  }
*/
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onParameter(name, value) {
}

function onSection() {
  var insertToolCall = isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);
  
  retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis()) ||
    (currentSection.isOptimizedForMachine() && getPreviousSection().isOptimizedForMachine() &&
      Vector.diff(getPreviousSection().getFinalToolAxisABC(), currentSection.getInitialToolAxisABC()).length > 1e-4) ||
    (!machineConfiguration.isMultiAxisConfiguration() && currentSection.isMultiAxis()) ||
    (!getPreviousSection().isMultiAxis() && currentSection.isMultiAxis() ||
      getPreviousSection().isMultiAxis() && !currentSection.isMultiAxis()); // force newWorkPlane between indexing and simultaneous operations
  if (insertToolCall || newWorkOffset || newWorkPlane) {
    // retract to safe plane
    writeBlock("H"); // retract
    zOutput.reset();
  }

  if (insertToolCall) {
    if (!isFirstSection() && getProperty("optionalStop")) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > 99) {
      warning(localize("Tool number exceeds maximum value."));
    }

    writeBlock("T" + toolFormat.format(tool.number), mFormat.format(6));
  }
  
  if (insertToolCall ||
      isFirstSection() ||
      (rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent())) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) {
    if (spindleSpeed < 0) {
      error(localize("Spindle speed out of range."));
      return;
    }
    if (spindleSpeed > 8388607) {
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock(
      "!RC", // move 1 and 2
      sOutput.format(spindleSpeed)
    );
  }

  // wcs
  /*
  var workOffset = currentSection.workOffset;
  if (workOffset > 0) {
    error(localize("Work offset out of range."));
    return;
  }
*/

  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted && !insertToolCall) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(
        "!ZM",
        zOutput.format(initialPosition.z)
      );
    }
  }

  if (insertToolCall) {
    writeBlock(
      (getProperty("mode") == 2) ? "!ZZ" : "Z",
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y),
      zOutput.format(initialPosition.z)
    );
  }
}

function onDwell(seconds) {
  if (seconds > 32767 / 1000.0) {
    warning(localize("Dwelling time is out of range."));
  }
  milliseconds = clamp(1, seconds * 1000, 32767);
  writeBlock((getProperty("mode") == 2) ? "!DW" : "W", milliFormat.format(milliseconds));
}

function onSpindleSpeed(spindleSpeed) {
  writeBlock(sOutput.format(spindleSpeed));
}

function onRapid(_x, _y, _z) {
  if (radiusCompensation > 0) {
    error(localize("Radius compensation is not supported."));
    return;
  }

  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    writeBlock((getProperty("mode") == 2) ? "!ZZ" : "Z", x, y, z);
    //writeBlock("!ZE", x, y, z); // TAG: use prefix for this
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  if (radiusCompensation > 0) {
    error(localize("Radius compensation is not supported."));
    return;
  }

  var f = feedOutput.format(feed);
  if (f) {
    writeBlock("V", f);
  }

  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    writeBlock((getProperty("mode") == 2) ? "!ZZ" : "Z", x, y, z);
  }
}

function onCircular() {
  linearize(tolerance); // note: could use operation tolerance
}

function onCommand(command) {
  onUnsupportedCommand(command);
}

function onSectionEnd() {
  forceAny();
}

function onClose() {
  writeBlock("H"); // retract
  zOutput.reset();

  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock("H"); // spindle stop
}

function setProperty(property, value) {
  properties[property].current = value;
}
