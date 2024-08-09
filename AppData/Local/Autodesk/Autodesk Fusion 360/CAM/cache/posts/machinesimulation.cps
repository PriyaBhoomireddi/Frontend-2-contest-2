/**
  Copyright (C) 2012-2021 by Autodesk, Inc.
  All rights reserved.

  Machine simulation demo post configuration.

  $Revision: 43280 83c8f8797abc4b7de2a805397770ce02121adcf9 $
  $Date: 2021-04-23 02:30:55 $
  
  FORKID {C974E70C-B5BC-4772-AB36-A9FE6ED98411}
*/

description = "Machine Simulation";
vendor = "Autodesk";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2021 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 45702;

longDescription = "Sample post to demonstrate the usage of machine simulation.";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_MACHINE_SIMULATION; // required for machine simulation

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({onchange: function() {retracted = false;}, prefix:"Z"}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);

// ####
// #### The code below is relevant for machine configuration / simulation ####
// ####
var compensateToolLength = false; // set to true to add the tool length to the pivot distance for rotary heads
var receivedMachineConfiguration = false;
var tcpIsSupported = false;
function onMachine() {
  receivedMachineConfiguration = true;
}

function onOpen() {
  if (receivedMachineConfiguration || ((machineConfiguration.getDescription() != "") || machineConfiguration.isMultiAxisConfiguration())) {
    // use machineConfiguration received from CAM / command line
  } else if (false) {
    // NOTE: setup your machine here manually
    var aAxis = createAxis({coordinate:0, table:true, axis:[1, 0, 0], range:[-120.0001, 120.0001], preference: 1, tcp:true});
    //var bAxis = createAxis({coordinate:1, table:true, axis:[0, 1, 0], range:[-120.0001, 120.0001], preference:1});
    var cAxis = createAxis({coordinate:2, table:true, axis:[0, 0, 1], range:[0, 360], cyclic:true, tcp:true});
    machineConfiguration = new MachineConfiguration(aAxis, cAxis);
    setMachineConfiguration(machineConfiguration);

    // additional settings
    // machineConfiguration.enableMachineRewinds();
    // machineConfiguration.setVirtualTooltip(true);
  }

  if (machineConfiguration.isHeadConfiguration() || compensateToolLength) {
    for (var i = 0; i < getNumberOfSections(); ++i) {
      var section = getSection(i);
      if (section.isMultiAxis()) {
        machineConfiguration.setToolLength(section.getTool().getBodyLength()); // define the tool length for head adjustments
        section.optimizeMachineAnglesByMachine(machineConfiguration, OPTIMIZE_AXIS);
      }
    }
  } else {
    optimizeMachineAngles2(OPTIMIZE_AXIS);
  }

  // determine if TCP is supported by the machine
  var axes = [machineConfiguration.getAxisU(), machineConfiguration.getAxisV(), machineConfiguration.getAxisW()];
  for (var i = 0; i < axes.length; ++i) {
    if (axes[i].isEnabled() && axes[i].isTCPEnabled()) {
      tcpIsSupported = true;
      break;
    }
  }
  // enable non TCP feedrate modes if required
  if (!tcpIsSupported) { // temporary solution
    machineConfiguration.setMultiAxisFeedrate(
      FEED_INVERSE_TIME, // can be FEED_DPM
      999999.99, // maximum output value for inverse time feed rates
      INVERSE_MINUTES, // can be INVERSE_SECONDS or DPM_COMBINATION for DPM feeds
      0.5, // tolerance to determine when the DPM feed has changed
      unit == MM ? 1.0 : 0.1 // ratio of rotary accuracy to linear accuracy for DPM calculations
    );
  }
  // expand stock XYZ values for rewinds
  // machineConfiguration.setRewindStockExpansion(new Vector(toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN)));

  if (!machineConfiguration.isMachineCoordinate(0)) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1)) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2)) {
    cOutput.disable();
  }
}

function setWorkPlane(abc) {
  // setCurrentABC() does send back the calculated ABC angles for indexing operations to the simulation.
  setCurrentABC(abc); // required for machine simulation
}

// ####
// #### The code below is generic code only and can be ignored ####
// ####

// Start of onRewindMachineEntry logic
safeRetractDistance = (unit == IN) ? 1 : 25; // additional distance to retract out of stock
safeRetractFeed = (unit == IN) ? 20 : 500; // retract feed rate
safePlungeFeed = (unit == IN) ? 10 : 250; // plunge feed rate
/** Allow user to override the onRewind logic. */
function onRewindMachineEntry(_a, _b, _c) {
  // reset the rotary encoder if supported to avoid large rewind
  if (false) {
    var c = _c;
    if ((abcFormat.getResultingValue(c) == 0) && !abcFormat.areDifferent(getCurrentDirection().y, _b)) {
      writeBlock(gAbsIncModal.format(91), gFormat.format(28), "C" + abcFormat.format(0));
      writeBlock(gAbsIncModal.format(90));
      return true;
    }
  }
  return false;
}

/** Retract to safe position before indexing rotaries. */
function onMoveToSafeRetractPosition() {
  writeRetract(Z); // retract to home position
  
  // cancel TCP so that tool doesn't follow rotaries
  if ((typeof lengthCompensationActive != "undefined") && lengthCompensationActive && tcpIsSupported) {
    writeBlock(gFormat.format(49), formatComment("TCPC OFF"));
  }

  if (false) { // enable to move to safe position in X & Y
    writeRetract(X, Y);
  }
}

/** Rotate axes to new position above reentry position */
function onRotateAxes(_x, _y, _z, _a, _b, _c) {
  // position rotary axes
  xOutput.disable();
  yOutput.disable();
  zOutput.disable();
  invokeOnRapid5D(_x, _y, _z, _a, _b, _c);
  xOutput.enable();
  yOutput.enable();
  zOutput.enable();
}

/** Return from safe position after indexing rotaries. */
function onReturnFromSafeRetractPosition(_x, _y, _z) {
  // reinstate TCP
  if ((typeof lengthCompensationActive != "undefined") && lengthCompensationActive && tcpIsSupported) {
    writeBlock(gFormat.format(43.4), hFormat.format(tool.lengthOffset), formatComment("TCPC ON"));
  }

  // position in XY
  forceXYZ();
  xOutput.reset();
  yOutput.reset();
  zOutput.disable();
  invokeOnRapid(_x, _y, _z);

  // position in Z
  zOutput.enable();
  invokeOnRapid(_x, _y, _z);
}
// End of onRewindMachineEntry logic

function defineWorkPlane(_section, _setWorkPlane) {
  var abc = new Vector(0, 0, 0);
  if (machineConfiguration.isMultiAxisConfiguration()) { // use 5-axis indexing for multi-axis mode
    if (_section.isMultiAxis()) {
      // handle multi axis operations here
    } else {
      abc = getWorkPlaneMachineABC(_section.workPlane, _setWorkPlane);
      if (_setWorkPlane) {
        setWorkPlane(abc);
      }
    }
  } else { // pure 3D
    var remaining = _section.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return abc;
    }
    setRotation(remaining);
  }
  return abc;
}

var closestABC = true; // choose closest machine angles
var currentMachineABC = new Vector(0, 0, 0);
function getWorkPlaneMachineABC(workPlane, _setWorkPlane) {
  var W = workPlane; // map to global frame

  var abc = machineConfiguration.getABC(W);
  if (closestABC) {
    if (currentMachineABC) {
      abc = machineConfiguration.remapToABC(abc, currentMachineABC);
    } else {
      abc = machineConfiguration.getPreferredABC(abc);
    }
  } else {
    abc = machineConfiguration.getPreferredABC(abc);
  }
  
  try {
    abc = machineConfiguration.remapABC(abc);
    if (_setWorkPlane) {
      currentMachineABC = abc;
    }
  } catch (e) {
    error(
      localize("Machine angles not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }
  
  var direction = machineConfiguration.getDirection(abc);
  if (!isSameDirection(direction, W.forward)) {
    error(localize("Orientation not supported."));
  }
  
  if (!machineConfiguration.isABCSupported(abc)) {
    error(
      localize("Work plane is not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }

  var tcp = false;
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    var O = machineConfiguration.getOrientation(abc);
    var R = machineConfiguration.getRemainingOrientation(abc, W);
    setRotation(R);
  }
  return abc;
}

function forceXYZ() {
}

function writeBlock() {
}

function onSection() {
  defineWorkPlane(currentSection, true);
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
}

function writeRetract() {
}

function onClose() {
  writeln("##########");
  writeln("THIS POSTPROCESSOR IS A SAMPLE FOR MACHINE SIMULATION USAGE, IT DOES NOT OUTPUT ANY NC PROGRAM.");
  writeln("##########");
}
