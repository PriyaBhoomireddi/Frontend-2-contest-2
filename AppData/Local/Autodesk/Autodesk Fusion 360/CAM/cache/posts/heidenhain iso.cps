/**
  Copyright (C) 2012-2021 by Autodesk, Inc.
  All rights reserved.

  Heidenhain ISO post processor configuration.

  $Revision: 43263 d1615d43ae07bdf5d28ec24b1386c3a28bb743b7 $
  $Date: 2021-03-31 03:47:43 $
  
  FORKID {43354140-D681-47d0-B056-9A0A277F620D}
*/

description = "Heidenhain ISO";
vendor = "Heidenhain";
vendorUrl = "http://www.heidenhain.com";
legal = "Copyright (C) 2012-2021 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 45702;

longDescription = "Generic milling post for Heidenhain ISO.";

extension = "i";
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
  writeMachine: {
    title: "Write machine",
    description: "Output the machine settings in the header of the code.",
    group: 0,
    type: "boolean",
    value: true,
    scope: "post"
  },
  writeTools: {
    title: "Write tool list",
    description: "Output a tool list in the header of the code.",
    group: 0,
    type: "boolean",
    value: true,
    scope: "post"
  },
  preloadTool: {
    title: "Preload tool",
    description: "Preloads the next tool at a tool change (if any).",
    type: "boolean",
    value: false,
    scope: "post"
  },
  showSequenceNumbers: {
    title: "Use sequence numbers",
    description: "Use sequence numbers for each block of outputted code.",
    group: 1,
    type: "boolean",
    value: true,
    scope: "post"
  },
  sequenceNumberStart: {
    title: "Start sequence number",
    description: "The number at which to start the sequence numbers.",
    group: 1,
    type: "integer",
    value: 10,
    scope: "post"
  },
  sequenceNumberIncrement: {
    title: "Sequence number increment",
    description: "The amount by which the sequence number is incremented by in each block.",
    group: 1,
    type: "integer",
    value: 5,
    scope: "post"
  },
  optionalStop: {
    title: "Optional stop",
    description: "Outputs optional stop code during when necessary in the code.",
    type: "boolean",
    value: true,
    scope: "post"
  },
  separateWordsWithSpace: {
    title: "Separate words with space",
    description: "Adds spaces between words if 'yes' is selected.",
    type: "boolean",
    value: true,
    scope: "post"
  },
  useRadius: {
    title: "Radius arcs",
    description: "If yes is selected, arcs are outputted using radius values rather than IJK.",
    type: "boolean",
    value: false,
    scope: "post"
  },
  showNotes: {
    title: "Show notes",
    description: "Writes operation notes as comments in the outputted code.",
    type: "boolean",
    value: false,
    scope: "post"
  },
  useParametricFeed: {
    title: "Parametric feed",
    description: "Specifies the feed value that should be output using a Q value.",
    type: "boolean",
    value: false,
    scope: "post"
  },
  safePositionMethod: {
    title: "Safe Retracts",
    description: "Select your desired retract option. 'Clearance Height' retracts to the operation clearance height.",
    type: "enum",
    values: [
      {title: "Clearance Height", id: "clearanceHeight"},
      {title: "M91", id: "M91"},
      {title: "M92", id: "M92"}
    ],
    value: "M91",
    scope: "post"
  },
  useM140: {
    title: "Use M140",
    description: "Specifies to use M140 MB MAX for Z-axis retracts instead of M91/M92 positions.",
    type: "boolean",
    value: false,
    scope: "post"
  },
  homeXYAtEnd: {
    title: "Home XY at end",
    description: "Specifies that the machine moves to the home position in XY at the end of the program.",
    type: "boolean",
    value: false,
    scope: "post"
  },
  cycleFormat:{
    title:"Cycle format",
    description: "Select 'New' to output canned cycles in 'G2xx Q' format instead of in 'G8x. P0y' format.",
    type: "enum",
    values: [
      {title: "New", id: "new"},
      {title: "Old", id: "old"}
    ],
    value: "old",
    scope: "post"
  }
};

var singleLineCoolant = false; // specifies to output multiple coolant codes in one line rather than in separate lines
// samples:
// {id: COOLANT_THROUGH_TOOL, on: 88, off: 89}
// {id: COOLANT_THROUGH_TOOL, on: [8, 88], off: [9, 89]}
var coolants = [
  {id: COOLANT_FLOOD, on: 8},
  {id: COOLANT_MIST},
  {id: COOLANT_THROUGH_TOOL},
  {id: COOLANT_AIR},
  {id: COOLANT_AIR_THROUGH_TOOL},
  {id: COOLANT_SUCTION},
  {id: COOLANT_FLOOD_MIST},
  {id: COOLANT_FLOOD_THROUGH_TOOL},
  {id: COOLANT_OFF, off: 9}
];

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";

var gFormat = createFormat({prefix:"G", width:2, zeropad:true, decimals:1});
var mFormat = createFormat({prefix:"M", width:2, zeropad:true, decimals:1});
var hFormat = createFormat({prefix:"H", width:2, zeropad:true, decimals:1});
var dFormat = createFormat({prefix:"D", width:2, zeropad:true, decimals:1});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, forceSign:true});
var rFormat = xyzFormat; // radius
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 0 : 1), forceDecimal:true});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var angleFormat = createFormat({decimals:0, scale:DEG});
var pitchFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceSign:true});
var ratioFormat = createFormat({decimals:3});
var secFormat = createFormat({decimals:3}); // seconds - range 0.001-99999.999
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({onchange:function () {retracted = false;}, prefix: "Z"}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);

// circular output
var iOutput = createVariable({prefix:"I", force:true}, xyzFormat);
var jOutput = createVariable({prefix:"J", force:true}, xyzFormat);
var kOutput = createVariable({prefix:"K", force:true}, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gUnitModal = createModal({force:true}, gFormat); // modal group 6 // G70-71

// fixed settings
var WARNING_WORK_OFFSET = 0;
var retracted = false; // specifies that the tool has been retracted to the safe plane
var firstFeedParameter = 50;
var useCycl205 = false; // use CYCL 205 for universal pecking

// collected state
var sequenceNumber;
var currentWorkOffset;
var activeMovements; // do not use by default
var currentFeedId;

/**
  Writes the specified block.
*/
function writeBlock() {
  var text = formatWords(arguments);
  if (!text) {
    return;
  }
  if (getProperty("showSequenceNumbers")) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += getProperty("sequenceNumberIncrement");
  } else {
    writeWords(arguments);
  }
}

function formatComment(text) {
  return ";" + filterText(String(text).toUpperCase(), permittedCommentChars).replace(/[()]/g, "");
}
/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

function onOpen() {
  if (getProperty("useRadius")) {
    maximumCircularSweep = toRad(90); // avoid potential center calculation errors for CNC
  }

  if (false) { // note: setup your machine here
    var aAxis = createAxis({coordinate:0, table:false, axis:[1, 0, 0], range:[-360, 360], preference:1});
    var cAxis = createAxis({coordinate:2, table:false, axis:[0, 0, 1], range:[-360, 360], preference:1});
    machineConfiguration = new MachineConfiguration(aAxis, cAxis);

    setMachineConfiguration(machineConfiguration);
    optimizeMachineAngles2(0); // TCP mode
  }

  /*
  // NOTE: setup your home positions here
  machineConfiguration.setRetractPlane(-20.415); // home position Z
  machineConfiguration.setHomePositionX(-200); // home position X
  machineConfiguration.setHomePositionY(-5); // home position Y
*/

  if (!machineConfiguration.isMachineCoordinate(0)) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1)) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2)) {
    cOutput.disable();
  }
  
  if (!getProperty("separateWordsWithSpace")) {
    setWordSeparator("");
  }

  sequenceNumber = getProperty("sequenceNumberStart");

  writeln(
    "%" + programName + " " + gUnitModal.format((unit == MM) ? 71 : 70)
  );
  
  if (programComment) {
    writeComment(programComment);
  }

  { // stock - workpiece
    var workpiece = getWorkpiece();
    var delta = Vector.diff(workpiece.upper, workpiece.lower);
    if (delta.isNonZero()) {
      writeBlock(gFormat.format(30), gPlaneModal.format(17), "X" + xyzFormat.format(workpiece.lower.x) + " Y" + xyzFormat.format(workpiece.lower.y) + " Z" + xyzFormat.format(workpiece.lower.z));
      writeBlock(gFormat.format(31), gAbsIncModal.format(90), "X" + xyzFormat.format(workpiece.upper.x) + " Y" + xyzFormat.format(workpiece.upper.y) + " Z" + xyzFormat.format(workpiece.upper.z));
    }
  }

  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var description = machineConfiguration.getDescription();

  if (getProperty("writeMachine") && (vendor || model || description)) {
    writeComment(localize("Machine"));
    if (vendor) {
      writeComment("  " + localize("vendor") + ": " + vendor);
    }
    if (model) {
      writeComment("  " + localize("model") + ": " + model);
    }
    if (description) {
      writeComment("  " + localize("description") + ": "  + description);
    }
  }

  // dump tool information
  if (getProperty("writeTools")) {
    var zRanges = {};
    if (is3D()) {
      var numberOfSections = getNumberOfSections();
      for (var i = 0; i < numberOfSections; ++i) {
        var section = getSection(i);
        var zRange = section.getGlobalZRange();
        var tool = section.getTool();
        if (zRanges[tool.number]) {
          zRanges[tool.number].expandToRange(zRange);
        } else {
          zRanges[tool.number] = zRange;
        }
      }
    }

    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var comment = "T" + toolFormat.format(tool.number) + "  " +
          "D=" + xyzFormat.format(tool.diameter) + " " +
          localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);
        if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
          comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
        }
        if (zRanges[tool.number]) {
          comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
      }
    }
  }

  // absolute coordinates and feed per min
  writeBlock(gAbsIncModal.format(90), gPlaneModal.format(17));
}

function onComment(message) {
  var comments = String(message).split(";");
  for (comment in comments) {
    writeComment(comments[comment]);
  }
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

function forceFeed() {
  currentFeedId = undefined;
  feedOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  forceFeed();
}

function onParameter(name, value) {
}

function FeedContext(id, description, feed) {
  this.id = id;
  this.description = description;
  this.feed = feed;
}

function getFeed(f) {
  if (activeMovements) {
    var feedContext = activeMovements[movement];
    if (feedContext != undefined) {
      if (!feedFormat.areDifferent(feedContext.feed, f)) {
        if (feedContext.id == currentFeedId) {
          return ""; // nothing has changed
        }
        forceFeed();
        currentFeedId = feedContext.id;
        return "F#" + (firstFeedParameter + feedContext.id);
      }
    }
    currentFeedId = undefined; // force Q feed next time
  }
  return feedOutput.format(f); // use feed value
}

function initializeActiveFeeds() {
  activeMovements = new Array();
  var movements = currentSection.getMovements();
  
  var id = 0;
  var activeFeeds = new Array();
  if (hasParameter("operation:tool_feedCutting")) {
    if (movements & ((1 << MOVEMENT_CUTTING) | (1 << MOVEMENT_LINK_TRANSITION) | (1 << MOVEMENT_EXTENDED))) {
      var feedContext = new FeedContext(id, localize("Cutting"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_CUTTING] = feedContext;
      activeMovements[MOVEMENT_LINK_TRANSITION] = feedContext;
      activeMovements[MOVEMENT_EXTENDED] = feedContext;
    }
    ++id;
    if (movements & (1 << MOVEMENT_PREDRILL)) {
      feedContext = new FeedContext(id, localize("Predrilling"), getParameter("operation:tool_feedCutting"));
      activeMovements[MOVEMENT_PREDRILL] = feedContext;
      activeFeeds.push(feedContext);
    }
    ++id;
  }
  
  if (hasParameter("operation:finishFeedrate")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:finishFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  }
  
  if (hasParameter("operation:tool_feedEntry")) {
    if (movements & (1 << MOVEMENT_LEAD_IN)) {
      var feedContext = new FeedContext(id, localize("Entry"), getParameter("operation:tool_feedEntry"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_IN] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LEAD_OUT)) {
      var feedContext = new FeedContext(id, localize("Exit"), getParameter("operation:tool_feedExit"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_OUT] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:noEngagementFeedrate")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), getParameter("operation:noEngagementFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting") &&
             hasParameter("operation:tool_feedEntry") &&
             hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), Math.max(getParameter("operation:tool_feedCutting"), getParameter("operation:tool_feedEntry"), getParameter("operation:tool_feedExit")));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  }
  
  if (hasParameter("operation:reducedFeedrate")) {
    if (movements & (1 << MOVEMENT_REDUCED)) {
      var feedContext = new FeedContext(id, localize("Reduced"), getParameter("operation:reducedFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_REDUCED] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedRamp")) {
    if (movements & ((1 << MOVEMENT_RAMP) | (1 << MOVEMENT_RAMP_HELIX) | (1 << MOVEMENT_RAMP_PROFILE) | (1 << MOVEMENT_RAMP_ZIG_ZAG))) {
      var feedContext = new FeedContext(id, localize("Ramping"), getParameter("operation:tool_feedRamp"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_RAMP] = feedContext;
      activeMovements[MOVEMENT_RAMP_HELIX] = feedContext;
      activeMovements[MOVEMENT_RAMP_PROFILE] = feedContext;
      activeMovements[MOVEMENT_RAMP_ZIG_ZAG] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedPlunge")) {
    if (movements & (1 << MOVEMENT_PLUNGE)) {
      var feedContext = new FeedContext(id, localize("Plunge"), getParameter("operation:tool_feedPlunge"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_PLUNGE] = feedContext;
    }
    ++id;
  }
  if (true) { // high feed
    if ((movements & (1 << MOVEMENT_HIGH_FEED)) || (highFeedMapping != HIGH_FEED_NO_MAPPING)) {
      var feed;
      if (hasParameter("operation:highFeedrateMode") && getParameter("operation:highFeedrateMode") != "disabled") {
        feed = getParameter("operation:highFeedrate");
      } else {
        feed = this.highFeedrate;
      }
      var feedContext = new FeedContext(id, localize("High Feed"), feed);
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_HIGH_FEED] = feedContext;
      activeMovements[MOVEMENT_RAPID] = feedContext;
    }
    ++id;
  }
  
  for (var i = 0; i < activeFeeds.length; ++i) {
    var feedContext = activeFeeds[i];
    writeBlock("#" + (firstFeedParameter + feedContext.id) + "=" + feedFormat.format(feedContext.feed), formatComment(feedContext.description));
  }
}

var currentWorkPlaneABC = undefined;

function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function setWorkPlane(abc) {
  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // ignore
  }

  if (!((currentWorkPlaneABC == undefined) ||
        abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
        abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
        abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z))) {
    return; // no change
  }
  if (!retracted) {
    writeRetract(Z);
  }

  onCommand(COMMAND_UNLOCK_MULTI_AXIS);

  // NOTE: add retract here

  writeBlock(
    gMotionModal.format(0),
    conditional(machineConfiguration.isMachineCoordinate(0), "A" + abcFormat.format(abc.x)),
    conditional(machineConfiguration.isMachineCoordinate(1), "B" + abcFormat.format(abc.y)),
    conditional(machineConfiguration.isMachineCoordinate(2), "C" + abcFormat.format(abc.z))
  );
  
  onCommand(COMMAND_LOCK_MULTI_AXIS);

  currentWorkPlaneABC = abc;
}

var closestABC = false; // choose closest machine angles
var currentMachineABC;

function getWorkPlaneMachineABC(workPlane) {
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
    currentMachineABC = abc;
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

  var tcp = true;
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    var O = machineConfiguration.getOrientation(abc);
    var R = machineConfiguration.getRemainingOrientation(abc, W);
    setRotation(R);
  }
  
  return abc;
}

function isProbeOperation() {
  return hasParameter("operation-strategy") && (getParameter("operation-strategy") == "probe");
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
    if (!getProperty("useM140") || !isFirstSection()) {
      writeRetract(Z);
    }
    writeBlock(gAbsIncModal.format(90));
  }

  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }
  
  if (getProperty("showNotes") && hasParameter("notes")) {
    var notes = getParameter("notes");
    if (notes) {
      var lines = String(notes).split("\n");
      var r1 = new RegExp("^[\\s]+", "g");
      var r2 = new RegExp("[\\s]+$", "g");
      for (line in lines) {
        var comment = lines[line].replace(r1, "").replace(r2, "");
        if (comment) {
          writeComment(comment);
        }
      }
    }
  }
  
  if (insertToolCall) {
    forceWorkPlane();

    onCommand(COMMAND_COOLANT_OFF);
  
    if (!isFirstSection() && getProperty("optionalStop")) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > 99) {
      warning(localize("Tool number exceeds maximum value."));
    }

    /*
    writeBlock(
      gFormat.format(99), "T" + tool.number, "L" + xyzFormat.format(tool.bodyLength), "R" + xyzFormat.format(tool.diameter/2)
    );
    */
    gPlaneModal.reset();
    writeBlock(
      "T" + tool.number, gPlaneModal.format(17), sOutput.format(spindleSpeed)
    );
    if (tool.comment) {
      writeComment(tool.comment);
    }
    var showToolZMin = false;
    if (showToolZMin) {
      if (is3D()) {
        var numberOfSections = getNumberOfSections();
        var zRange = currentSection.getGlobalZRange();
        var number = tool.number;
        for (var i = currentSection.getId() + 1; i < numberOfSections; ++i) {
          var section = getSection(i);
          if (section.getTool().number != number) {
            break;
          }
          zRange.expandToRange(section.getGlobalZRange());
        }
        writeComment(localize("ZMIN") + "=" + zRange.getMinimum());
      }
    }

    if (getProperty("preloadTool")) {
      var nextTool = getNextTool(tool.number);
      if (nextTool) {
        writeBlock(gFormat.format(51), "T" + toolFormat.format(nextTool.number));
      } else {
        // preload first tool
        var section = getSection(0);
        var firstToolNumber = section.getTool().number;
        if (tool.number != firstToolNumber) {
          writeBlock(gFormat.format(51), "T" + toolFormat.format(firstToolNumber));
        }
      }
    }
  }
  if (getProperty("useM140")) {
    writeRetract(Z);
  }
  
  if (insertToolCall ||
      isFirstSection() ||
      (rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent())) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) {
    if (spindleSpeed < 1) {
      error(localize("Spindle speed out of range."));
    }
    if (spindleSpeed > 99999) {
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock(
      sOutput.format(spindleSpeed), mFormat.format(tool.clockwise ? 3 : 4)
    );
  }

  // wcs
  /*
  if (insertToolCall) { // force work offset when changing tool
    currentWorkOffset = undefined;
  }
  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
    workOffset = 1;
  }
  if (workOffset > 0) {
    if (workOffset > 6) {
      var p = workOffset - 6; // 1->...
      error(localize("Work offset out of range."));
    } else {
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(53 + workOffset)); // G54->G59
        currentWorkOffset = workOffset;
      }
    }
  }
  */

  forceXYZ();

  if (machineConfiguration.isMultiAxisConfiguration()) { // use 5-axis indexing for multi-axis mode
    // set working plane after datum shift

    var abc = new Vector(0, 0, 0);
    if (currentSection.isMultiAxis()) {
      forceWorkPlane();
      cancelTransformation();
    } else {
      abc = getWorkPlaneMachineABC(currentSection.workPlane);
    }
    setWorkPlane(abc);
  } else { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  // set coolant after we have positioned at Z
  setCoolant(tool.coolant);

  forceAny();
  gMotionModal.reset();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted && !insertToolCall) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    }
  }

  if (insertToolCall) {
    gMotionModal.reset();
    writeBlock(gPlaneModal.format(17));
    
    if (!machineConfiguration.isHeadConfiguration()) {
      writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
      );
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    } else {
      writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0),
        xOutput.format(initialPosition.x),
        yOutput.format(initialPosition.y),
        zOutput.format(initialPosition.z)
      );
    }

    gMotionModal.reset();
  } else {
    writeBlock(
      gAbsIncModal.format(90),
      gMotionModal.format(0),
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y)
    );
  }

  if (getProperty("useParametricFeed") &&
    hasParameter("operation-strategy") &&
    (getParameter("operation-strategy") != "drill") && // legacy
    !(currentSection.hasAnyCycle && currentSection.hasAnyCycle())) {
    if (!insertToolCall &&
      activeMovements &&
      (getCurrentSectionId() > 0) &&
      ((getPreviousSection().getPatternId() == currentSection.getPatternId()) && (currentSection.getPatternId() != 0))) {
    // use the current feeds
    } else {
      initializeActiveFeeds();
    }
  } else {
    activeMovements = undefined;
  }

  retracted = false;
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  writeBlock(gFormat.format(4), "F" + secFormat.format(seconds));
}

function onSpindleSpeed(spindleSpeed) {
  writeBlock(sOutput.format(spindleSpeed));
}

function onDrilling(cycle) {
  writeBlock(gFormat.format(200) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE")  + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING")  + " ~" + EOL
    + "  Q202=" + xyzFormat.format(cycle.depth) + " ;" + localize("INFEED DEPTH") + " ~" + EOL
    + "  Q210=" + secFormat.format(0) + " ;" + localize("DWELL AT TOP") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q211=" + secFormat.format(0) + " ;" + localize("DWELL AT BOTTOM")
  );
}

function onCounterBoring(cycle) {
  writeBlock(gFormat.format(200) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q202=" + xyzFormat.format(cycle.depth) + " ;" + localize("INFEED DEPTH") + " ~" + EOL
    + "  Q210=" + secFormat.format(0) + " ;" + localize("DWELL AT TOP") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL AT BOTTOM")
  );
}

function onChipBreaking(cycle) {
  writeBlock(gFormat.format(203) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q202=" + xyzFormat.format(cycle.incrementalDepth) + " ;" + localize("INFEED DEPTH") + " ~" + EOL
    + "  Q210=" + secFormat.format(0) + " ;" + localize("DWELL AT TOP") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q212=" + xyzFormat.format(cycle.incrementalDepthReduction) + " ;" + localize("DECREMENT") + " ~" + EOL
    + "  Q213=" + cycle.plungesPerRetract + " ;" + localize("BREAKS") + " ~" + EOL
    + "  Q205=" + xyzFormat.format(cycle.minimumIncrementalDepth) + " ;" + localize("MIN. PLUNGING DEPTH") + " ~" + EOL
    + "  Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL TIME AT DEPTH") + " ~" + EOL
    + "  Q208=" + "MAX" + " ;" + localize("RETRACTION FEED RATE") + " ~" + EOL
    + "  Q256=" + xyzFormat.format((cycle.chipBreakDistance != undefined) ? cycle.chipBreakDistance : machineParameters.chipBreakingDistance) + " ;" + localize("DIST. FOR CHIP BRKNG")
  );
}

function onDeepDrilling(cycle) {
  if (useCycl205) {
    writeBlock(gFormat.format(205) + " ~" + EOL
      + " Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
      + " Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
      + " Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
      + " Q202=" + xyzFormat.format(cycle.incrementalDepth) + " ;" + localize("PLUNGING DEPTH") + " ~" + EOL
      + " Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
      + " Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
      + " Q212=" + xyzFormat.format(cycle.incrementalDepthReduction) + " ;" + localize("DECREMENT") + " ~" + EOL
      + " Q205=" + xyzFormat.format(cycle.minimumIncrementalDepth) + " ;" + localize("MIN. PLUNGING DEPTH") + " ~" + EOL
      + " Q258=" + xyzFormat.format(0.5) + " ;" + localize("UPPER ADV. STOP DIST.") + " ~" + EOL
      + " Q259=" + xyzFormat.format(1) + " ;" + localize("LOWER ADV. STOP DIST.") + " ~" + EOL
      + " Q257=" + xyzFormat.format(5) + " ;" + localize("DEPTH FOR CHIP BRKNG") + " ~" + EOL
      + " Q256=" + xyzFormat.format((cycle.chipBreakDistance != undefined) ? cycle.chipBreakDistance : machineParameters.chipBreakingDistance) + " ;" + localize("DIST. FOR CHIP BRKNG") + " ~" + EOL
      + " Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL TIME AT DEPTH") + " ~" + EOL
      + " Q379=" + "0" + " ;" + localize("STARTING POINT") + " ~" + EOL
      + " Q253=" + feedFormat.format(cycle.retractFeedrate) + " ;" + localize("F PRE-POSITIONING")
    );
  } else {
    writeBlock(gFormat.format(200) + " ~" + EOL
      + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
      + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
      + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
      + "  Q202=" + xyzFormat.format(cycle.incrementalDepth) + " ;" + localize("INFEED DEPTH") + " ~" + EOL
      + "  Q210=" + secFormat.format(0) + " ;" + localize("DWELL AT TOP") + " ~" + EOL
      + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
      + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
      + "  Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL AT BOTTOM")
    );
  }
}

function onGunDrilling(cycle) {
  var coolantCode = getCoolantCode(tool.coolant);
  writeBlock(gFormat.format(241) + " ~" + EOL
    + " Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + " Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + " Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + " Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL TIME AT DEPTH") + " ~" + EOL
    + " Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + " Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + " Q379=" + xyzFormat.format(cycle.startingDepth) + " ;" + localize("STARTING POINT") + " ~" + EOL
    + " Q253=" + feedFormat.format(cycle.positioningFeedrate) + " ;" + localize("F PRE-POSITIONING") + " ~" + EOL
    + " Q208=" + feedFormat.format(cycle.retractFeedrate) + " ;" + localize("RETRACT FEED RATE") + " ~" + EOL
    + " Q426=" + (cycle.stopSpindle ? 5 : (tool.clockwise ? 3 : 4)) + " ;" + localize("DIR. OF SPINDLE ROT.") + " ~" + EOL
    + " Q427=" + rpmFormat.format(cycle.positioningSpindleSpeed ? cycle.positioningSpindleSpeed : tool.spindleRPM) + " ;" + localize("ENTRY EXIT SPEED") + " ~" + EOL
    + " Q428=" + rpmFormat.format(tool.spindleRPM) + " ;" + localize("DRILLING SPEED") + " ~" + EOL
    + conditional(coolantCode, " Q429=" + (coolantCode ? coolantCode[0] : 0) + " ;" + localize("COOLANT ON") + " ~" + EOL)
    + conditional(coolantCode, " Q430=" + (coolantCode ? coolantCode[1] : 0) + " ;" + localize("COOLANT OFF") + " ~" + EOL)
    // Heidenhain manual doesn't specify Q435 fully - adjust to fit CNC
    + " Q435=" + xyzFormat.format(cycle.dwellDepth ? (cycle.depth + cycle.dwellDepth) : 0) + " ;" + localize("DWELL DEPTH") // 0 to disable
  );
}

function onTapping(cycle) {
  writeBlock(gFormat.format(207) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q239=" + pitchFormat.format((tool.type == TOOL_TAP_LEFT_HAND ? -1 : 1) * tool.threadPitch) + " ;" + localize("THREAD PITCH") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE")
  );
}

function onTappingWithChipBreaking(cycle) {
  writeBlock(gFormat.format(209) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q239=" + pitchFormat.format((tool.type == TOOL_TAP_LEFT_HAND ? -1 : 1) * tool.threadPitch) + " ;" + localize("THREAD PITCH") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q257=" + xyzFormat.format(cycle.incrementalDepth) + " ;" + localize("DEPTH FOR CHIP BRKNG") + " ~" + EOL
    + "  Q256=" + xyzFormat.format((cycle.chipBreakDistance != undefined) ? cycle.chipBreakDistance : machineParameters.chipBreakingDistance) + " ;" + localize("DIST. FOR CHIP BRKNG") + " ~" + EOL
    + "  Q336=" + angleFormat.format(0) + " ;" + localize("ANGLE OF SPINDLE")
  );
}

function onReaming(cycle) {
  writeBlock(gFormat.format(201) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL AT BOTTOM") + " ~" + EOL
    + "  Q208=" + feedFormat.format(cycle.retractFeedrate) + " ;" + localize("RETRACTION FEED TIME") + " ~" + EOL // retract at reaming feed rate
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE")
  );
}

function onStopBoring(cycle) {
  writeBlock(gFormat.format(202) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL AT BOTTOM") + " ~" + EOL
    + "  Q208=" + "MAX" + " ;" + localize("RETRACTION FEED RATE") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q214=" + 0 + " ;" + localize("DISENGAGING DIRECTION") + " ~" + EOL
    + "  Q336=" + angleFormat.format(0) + " ;" + localize("ANGLE OF SPINDLE")
  );
}

/** Returns the best discrete disengagement direction for the specified direction. */
function getDisengagementDirection(direction) {
  switch (getQuadrant(direction + 45 * Math.PI / 180)) {
  case 0:
    return 3;
  case 1:
    return 4;
  case 2:
    return 1;
  case 3:
    return 2;
  }
  error(localize("Invalid disengagement direction."));
  return 3;
}

function onFineBoring(cycle) {
  // we do not support cycle.shift
  
  writeBlock(gFormat.format(202) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL AT BOTTOM") + " ~" + EOL
    + "  Q208=" + "MAX" + " ;" + localize("RETRACTION FEED TIME") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q214=" + getDisengagementDirection(cycle.shiftDirection) + " ;" + localize("DISENGAGING DIRECTION") + " ~" + EOL
    + "  Q336=" + angleFormat.format(cycle.compensatedShiftOrientation) + " ;" + localize("ANGLE OF SPINDLE")
  );
}

function onBackBoring(cycle) {
  writeBlock(gFormat.format(204) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q249=" + xyzFormat.format(cycle.backBoreDistance) + " ;" + localize("DEPTH REDUCTION") + " ~" + EOL
    + "  Q250=" + xyzFormat.format(cycle.depth) + " ;" + localize("MATERIAL THICKNESS") + " ~" + EOL
    + "  Q251=" + xyzFormat.format(cycle.shift) + " ;" + localize("OFF-CENTER DISTANCE") + " ~" + EOL
    + "  Q252=" + xyzFormat.format(0) + " ;" + localize("TOOL EDGE HEIGHT") + " ~" + EOL
    + "  Q253=" + "MAX" + " ;" + localize("F PRE-POSITIONING") + " ~" + EOL
    + "  Q254=" + feedFormat.format(cycle.feedrate) + " ;" + localize("F COUNTERBORING") + " ~" + EOL
    + "  Q255=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL AT BOTTOM") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q214=" + getDisengagementDirection(cycle.shiftDirection) + " ;" + localize("DISENGAGING DIRECTION") + " ~" + EOL
    + "  Q336=" + angleFormat.format(cycle.compensatedShiftOrientation) + " ;" + localize("ANGLE OF SPINDLE")
  );
}

function onBoring(cycle) {
  writeBlock(gFormat.format(202) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q211=" + secFormat.format(cycle.dwell) + " ;" + localize("DWELL AT BOTTOM") + " ~" + EOL
    + "  Q208=" + feedFormat.format(cycle.retractFeedrate) + " ;" + localize("RETRACTION FEED RATE") + " ~" + EOL // retract at feed
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q214=" + 0 + " ;" + localize("DISENGAGING DIRECTION") + " ~" + EOL
    + "  Q336=" + angleFormat.format(0) + " ;" + localize("ANGLE OF SPINDLE")
  );
}

function onBoreMilling(cycle) {
  writeBlock(gFormat.format(208) + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q334=" + pitchFormat.format(cycle.pitch) + " ;" + localize("INFEED DEPTH") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q335=" + xyzFormat.format(cycle.diameter) + " ;" + localize("NOMINAL DIAMETER") + " ~" + EOL
    + "  Q342=" + xyzFormat.format(tool.diameter) + " ;" + localize("ROUGHING DIAMETER")
  );
}

function onThreadMilling(cycle) {
  cycle.numberOfThreads = 1;
  writeBlock(gFormat.format(262) + " ~" + EOL
    + "  Q335=" + xyzFormat.format(cycle.diameter) + " ;" + localize("NOMINAL DIAMETER") + " ~" + EOL
    // + for right-hand and - for left-hand
    + "  Q239=" + pitchFormat.format(cycle.threading == "right" ? cycle.pitch : -cycle.pitch) + " ;" + localize("PITCH") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("THREAD DEPTH") + " ~" + EOL
    // 0 for threads over entire depth
    + "  Q355=" + xyzFormat.format(cycle.numberOfThreads) + " ;" + localize("THREADS PER STEP") + " ~" + EOL
    + "  Q253=" + feedFormat.format(cycle.feedrate) + " ;" + localize("F PRE-POSITIONING") + " ~" + EOL
    + "  Q351=" + xyzFormat.format(cycle.direction == "climb" ? 1 : -1) + " ;" + localize("CLIMB OR UP-CUT") + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q207=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR MILLING")
  );
}

function onCircularPocketMilling(cycle) {
  if (tool.taperAngle > 0) {
    error(localize("Circular pocket milling is not supported for taper tools."));
    return;
  }
  
  // do NOT use with undercutting - doesnt move to the center before retracting
  writeBlock(gFormat.format(252) + " ~" + EOL
    + "  Q215=1 ;" + localize("MACHINE OPERATION") + " ~" + EOL
    + "  Q223=" + xyzFormat.format(cycle.diameter) + " ;" + localize("CIRCLE DIAMETER") + " ~" + EOL
    + "  Q368=" + xyzFormat.format(0) + " ;" + localize("FINISHING ALLOWANCE FOR SIDE") + " ~" + EOL
    + "  Q207=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR MILLING") + " ~" + EOL
    + "  Q351=" + xyzFormat.format(cycle.direction == "climb" ? 1 : -1) + " ;" + localize("CLIMB OR UP-CUT") + " ~" + EOL
    + "  Q201=" + xyzFormat.format(-cycle.depth) + " ;" + localize("DEPTH") + " ~" + EOL
    + "  Q202=" + xyzFormat.format(cycle.incrementalDepth) + " ;" + localize("INFEED DEPTH") + " ~" + EOL
    + "  Q369=" + xyzFormat.format(0) + " ;" + localize("FINISHING ALLOWANCE FOR FLOOR") + " ~" + EOL
    + "  Q206=" + feedFormat.format(cycle.plungeFeedrate) + " ;" + localize("FEED RATE FOR PLUNGING") + " ~" + EOL
    + "  Q338=0 ;" + localize("INFEED FOR FINISHING") + " ~" + EOL
    + "  Q200=" + xyzFormat.format(cycle.retract - cycle.stock) + " ;" + localize("SET-UP CLEARANCE") + " ~" + EOL
    + "  Q203=" + xyzFormat.format(cycle.stock) + " ;" + localize("SURFACE COORDINATE") + " ~" + EOL
    + "  Q204=" + xyzFormat.format(cycle.clearance - cycle.stock) + " ;" + localize("2ND SET-UP CLEARANCE") + " ~" + EOL
    + "  Q370=" + ratioFormat.format(cycle.stepover / (tool.diameter / 2)) + " ;" + localize("TOOL PATH OVERLAP") + " ~" + EOL
    + "  Q366=" + "0" + " ;" + localize("PLUNGING") + " ~" + EOL
    + "  Q385=" + feedFormat.format(cycle.feedrate) + " ;" + localize("FEED RATE FOR FINISHING")
  );
}

function setCyclePosition(_position) {
  zOutput.format(_position);
}

function onCycle() {
  writeBlock(gPlaneModal.format(17));
}

function getCommonCycle(x, y, z, r) {
  forceXYZ();
  return [xOutput.format(x), yOutput.format(y),
    zOutput.format(z),
    "R" + xyzFormat.format(r)];
}

function onCyclePoint(x, y, z) {
  if (!isSameDirection(getRotation().forward, new Vector(0, 0, 1))) {
    expandCyclePoint(x, y, z);
    return;
  }
  var useNewCycles = getProperty("cycleFormat") == "new";

  if (isFirstCyclePoint()) {
    repositionToCycleClearance(cycle, x, y, z);
    
    // return to initial Z which is clearance plane and set absolute mode

    var F = cycle.feedrate;
    var P = !cycle.dwell ? 0 : clamp(0.001, cycle.dwell, 99999.999); // in seconds

    switch (cycleType) {
    case "drilling":
      if (useNewCycles) {
        onDrilling(cycle);
      } else {
        writeBlock(
          gAbsIncModal.format(90), gFormat.format(83),
          "P01 " + xyzFormat.format(cycle.stock - cycle.clearance),
          "P02 " + xyzFormat.format(-cycle.depth),
          "P03 " + xyzFormat.format(-cycle.depth),
          "P04 " + secFormat.format(P),
          "P05 " + feedOutput.format(F)
        );
        writeBlock(xOutput.format(x), yOutput.format(y), mFormat.format(99));
      }
      break;
    case "counter-boring":
      if (useNewCycles) {
        onCounterBoring(cycle);
      } else {
        writeBlock(
          gAbsIncModal.format(90), gFormat.format(83),
          "P01 " + xyzFormat.format(cycle.stock - cycle.clearance),
          "P02 " + xyzFormat.format(-cycle.depth),
          "P03 " + xyzFormat.format(-cycle.depth),
          "P04 " + secFormat.format(P),
          "P05 " + feedOutput.format(F)
        );
        writeBlock(xOutput.format(x), yOutput.format(y), mFormat.format(99));
      }
      break;
    case "chip-breaking":
      if (useNewCycles) {
        onChipBreaking(cycle);
      } else {
        if (cycle.accumulatedDepth < cycle.depth) {
          expandCyclePoint(x, y, z);
        } else {
          writeBlock(
            gAbsIncModal.format(90), gFormat.format(83),
            "P01 " + xyzFormat.format(cycle.stock - cycle.clearance),
            "P02 " + xyzFormat.format(-cycle.depth),
            "P03 " + xyzFormat.format(cycle.incrementalDepth),
            "P04 " + secFormat.format(P),
            "P05 " + feedOutput.format(F)
          );
          writeBlock(xOutput.format(x), yOutput.format(y), mFormat.format(99));
        }
      }
      break;
    case "deep-drilling":
      if (useNewCycles) {
        onDeepDrilling(cycle);
      } else {
        writeBlock(
          gAbsIncModal.format(90), gFormat.format(83),
          "P01 " + xyzFormat.format(cycle.stock - cycle.clearance),
          "P02 " + xyzFormat.format(-cycle.depth),
          "P03 " + xyzFormat.format(cycle.incrementalDepth),
          "P04 " + secFormat.format(P),
          "P05 " + feedOutput.format(F)
        );
        writeBlock(xOutput.format(x), yOutput.format(y), mFormat.format(99));
      }
      break;
    case "tapping":
    case "left-tapping":
    case "right-tapping":
      if (useNewCycles) {
        onTapping(cycle);
      } else {
      // cycles calculates feed from spindle speed and pitch
        writeBlock(
          gAbsIncModal.format(90), gFormat.format(85),
          "P01 " + xyzFormat.format(cycle.stock - cycle.clearance),
          "P02 " + xyzFormat.format(-cycle.depth),
          "P03 " + xyzFormat.format(((tool.type == TOOL_TAP_LEFT_HAND) ? -1 : 1) * tool.threadPitch)
        );
        writeBlock(xOutput.format(x), yOutput.format(y), mFormat.format(99));
      }
      break;
    case "tapping-with-chip-breaking":
    case "left-tapping-with-chip-breaking":
    case "right-tapping-with-chip-breaking":
      if (useNewCycles) {
        onTappingWithChipBreaking(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "fine-boring":
      if (useNewCycles) {
        onFineBoring(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "back-boring":
      if (useNewCycles) {
        onBackBoring(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "reaming":
      if (useNewCycles) {
        onReaming(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "stop-boring":
      if (useNewCycles) {
        onStopBoring(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "manual-boring":
      expandCyclePoint(x, y, z);
      break;
    case "boring":
      if (useNewCycles) {
        onBoring(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "bore-milling":
      if (useNewCycles && !cycle.numberOfSteps > 1) {
        onBoreMilling(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "thread-milling":
      if (useNewCycles && !cycle.numberOfSteps > 1) {
        onThreadMilling(cycle);
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    case "circular-pocket-milling":
      if (useNewCycles) {
        onCircularPocketMilling(cycle);
        break;
      } else {
        expandCyclePoint(x, y, z);
      }
      break;
    default:
      expandCyclePoint(x, y, z);
    }
  } else {
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else {
      writeBlock(xOutput.format(x), yOutput.format(y), mFormat.format(99));
    }
  }
}

function onCycleEnd() {
  if (!cycleExpanded) {
    zOutput.reset();
  }
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    }
    writeBlock(gMotionModal.format(0), x, y, z);
    forceFeed();
  }
}

function onLinear(_x, _y, _z, feed) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = getFeed(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      writeBlock(gPlaneModal.format(17));
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gMotionModal.format(1), gFormat.format(42), x, y, z, f);
        break;
      default:
        writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, f);
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    return;
  }
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  writeBlock(gMotionModal.format(0), x, y, z, a, b, c);
  forceFeed();
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    return;
  }
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for 5-axis move."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  var f = getFeed(feed);
  if (x || y || z || a || b || c) {
    writeBlock(gMotionModal.format(1), x, y, z, a, b, c, f);
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  if (isFullCircle()) {
    if (getProperty("useRadius") || isHelical()) { // radius mode does not support full arcs
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(
        gAbsIncModal.format(90), iOutput.format(cx), jOutput.format(cy),
        gAbsIncModal.format(90), gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), getFeed(feed)
      );
      break;
    case PLANE_ZX:
      writeBlock(
        gAbsIncModal.format(90), iOutput.format(cx), kOutput.format(cz),
        gAbsIncModal.format(90), gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), getFeed(feed)
      );
      break;
    case PLANE_YZ:
      writeBlock(
        gAbsIncModal.format(90), jOutput.format(cy), kOutput.format(cz),
        gAbsIncModal.format(90), gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), getFeed(feed)
      );
      break;
    default:
      linearize(tolerance);
    }
  } else if (!getProperty("useRadius")) {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(
        gAbsIncModal.format(90), iOutput.format(cx), jOutput.format(cy),
        gAbsIncModal.format(90), gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), getFeed(feed)
      );
      break;
    case PLANE_ZX:
      writeBlock(
        iOutput.format(cx), kOutput.format(cz),
        gAbsIncModal.format(90), gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), getFeed(feed)
      );
      break;
    case PLANE_YZ:
      writeBlock(
        jOutput.format(cy), kOutput.format(cz),
        gAbsIncModal.format(90), gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), getFeed(feed)
      );
      break;
    default:
      linearize(tolerance);
    }
  } else { // use radius mode
    var r = getCircularRadius();
    if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
      r = -r; // allow up to <360 deg arcs
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(
        gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed)
      );
      break;
    case PLANE_ZX:
      writeBlock(
        gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed)
      );
      break;
    case PLANE_YZ:
      writeBlock(
        gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed)
      );
      break;
    default:
      linearize(tolerance);
    }
  }
}

var currentCoolantMode = COOLANT_OFF;
var coolantOff = undefined;

function setCoolant(coolant) {
  var coolantCodes = getCoolantCodes(coolant);
  if (Array.isArray(coolantCodes)) {
    if (singleLineCoolant) {
      writeBlock(coolantCodes.join(getWordSeparator()));
    } else {
      for (var c in coolantCodes) {
        writeBlock(coolantCodes[c]);
      }
    }
    return undefined;
  }
  return coolantCodes;
}

function getCoolantCodes(coolant) {
  var multipleCoolantBlocks = new Array(); // create a formatted array to be passed into the outputted line
  if (!coolants) {
    error(localize("Coolants have not been defined."));
  }
  if (isProbeOperation()) { // avoid coolant output for probing
    coolant = COOLANT_OFF;
  }
  if (coolant == currentCoolantMode) {
    return undefined; // coolant is already active
  }
  if ((coolant != COOLANT_OFF) && (currentCoolantMode != COOLANT_OFF) && (coolantOff != undefined)) {
    if (Array.isArray(coolantOff)) {
      for (var i in coolantOff) {
        multipleCoolantBlocks.push(mFormat.format(coolantOff[i]));
      }
    } else {
      multipleCoolantBlocks.push(mFormat.format(coolantOff));
    }
  }

  var m;
  var coolantCodes = {};
  for (var c in coolants) { // find required coolant codes into the coolants array
    if (coolants[c].id == coolant) {
      coolantCodes.on = coolants[c].on;
      if (coolants[c].off != undefined) {
        coolantCodes.off = coolants[c].off;
        break;
      } else {
        for (var i in coolants) {
          if (coolants[i].id == COOLANT_OFF) {
            coolantCodes.off = coolants[i].off;
            break;
          }
        }
      }
    }
  }
  if (coolant == COOLANT_OFF) {
    m = !coolantOff ? coolantCodes.off : coolantOff; // use the default coolant off command when an 'off' value is not specified
  } else {
    coolantOff = coolantCodes.off;
    m = coolantCodes.on;
  }

  if (!m) {
    onUnsupportedCoolant(coolant);
    m = 9;
  } else {
    if (Array.isArray(m)) {
      for (var i in m) {
        multipleCoolantBlocks.push(mFormat.format(m[i]));
      }
    } else {
      multipleCoolantBlocks.push(mFormat.format(m));
    }
    currentCoolantMode = coolant;
    return multipleCoolantBlocks; // return the single formatted coolant value
  }
  return undefined;
}

var mapCommand = {
  COMMAND_STOP:0,
  COMMAND_OPTIONAL_STOP:1,
  COMMAND_END:2,
  COMMAND_SPINDLE_CLOCKWISE:3,
  COMMAND_SPINDLE_COUNTERCLOCKWISE:4,
  COMMAND_STOP_SPINDLE:5,
  COMMAND_ORIENTATE_SPINDLE:19,
  COMMAND_LOAD_TOOL:6
};

function onCommand(command) {
  switch (command) {
  case COMMAND_COOLANT_ON:
    setCoolant(COOLANT_FLOOD);
    return;
  case COMMAND_COOLANT_OFF:
    setCoolant(COOLANT_OFF);
    return;
  case COMMAND_START_SPINDLE:
    onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
    return;
  case COMMAND_LOCK_MULTI_AXIS:
    return;
  case COMMAND_UNLOCK_MULTI_AXIS:
    return;
  case COMMAND_BREAK_CONTROL:
    return;
  case COMMAND_TOOL_MEASURE:
    return;
  }

  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mFormat.format(mcode));
  } else {
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  writeBlock(gPlaneModal.format(17));
  if (!isLastSection() && (getNextSection().getTool().coolant != tool.coolant)) {
    setCoolant(COOLANT_OFF);
  }
  // the code below gets the machine angles from previous operation.  closestABC must also be set to true
  if (currentSection.isMultiAxis() && currentSection.isOptimizedForMachine()) {
    currentMachineABC = currentSection.getFinalToolAxisABC();
  }
  forceAny();
}

/** Output block to do safe retract and/or move to home position. */
function writeRetract() {
  var words = []; // store all retracted axes in an array
  var retractAxes = new Array(false, false, false);
  var method = getProperty("safePositionMethod");
  if (method == "clearanceHeight") {
    if (!is3D()) {
      error(localize("Retract option 'Clearance Height' is not supported for multi-axis machining."));
    } else {
      return;
    }
  }
  validate(arguments.length != 0, "No axis specified for writeRetract().");

  for (i in arguments) {
    retractAxes[arguments[i]] = true;
  }
  if ((retractAxes[0] || retractAxes[1]) && !retracted) { // retract Z first before moving to X/Y home
    error(localize("Retracting in X/Y is not possible without being retracted in Z."));
    return;
  }
  // special conditions
  /*
  if (retractAxes[2]) { // Z doesn't use G53
    method = "G28";
  }
  */

  // define home positions
  var _xHome;
  var _yHome;
  var _zHome;
  if (false && method == "G28") { // always use machine home positions
    _xHome = toPreciseUnit(0, MM);
    _yHome = toPreciseUnit(0, MM);
    _zHome = toPreciseUnit(0, MM);
  } else {
    _xHome = machineConfiguration.hasHomePositionX() ? machineConfiguration.getHomePositionX() : toPreciseUnit(0, MM);
    _yHome = machineConfiguration.hasHomePositionY() ? machineConfiguration.getHomePositionY() : toPreciseUnit(0, MM);
    _zHome = machineConfiguration.getRetractPlane() != 0 ? machineConfiguration.getRetractPlane() : toPreciseUnit(0, MM);
  }
  for (var i = 0; i < arguments.length; ++i) {
    switch (arguments[i]) {
    case X:
      words.push("X" + xyzFormat.format(_xHome));
      xOutput.reset();
      break;
    case Y:
      words.push("Y" + xyzFormat.format(_yHome));
      yOutput.reset();
      break;
    case Z:
      if (getProperty("useM140")) {
        gMotionModal.reset();
        validate((arguments.length <= 1), "Retracts for the Z-axis have to be specified separately by using the useM140 property.");
        writeBlock(gMotionModal.format(0), gFormat.format(40), mFormat.format(140), "MB MAX");
        zOutput.reset();
        retracted = true;
        return;
      } else {
        words.push("Z" + xyzFormat.format(_zHome));
        zOutput.reset();
        retracted = true;
        break;
      }
    default:
      error(localize("Unsupported axis specified for writeRetract()."));
      return;
    }
  }
  if (words.length > 0) {
    switch (method) {
    case "M91":
    case "M92":
      gMotionModal.reset();
      writeBlock(gMotionModal.format(0), gFormat.format(40), gAbsIncModal.format(90), words.join(getWordSeparator()) + SP + mFormat.format(method == "M92" ? 92 : 91));
      break;
    default:
      error(localize("Unsupported safe position method."));
      return;
    }
  }
}

function onClose() {
  onCommand(COMMAND_COOLANT_OFF);

  writeRetract(Z);

  if (getProperty("homeXYAtEnd")) {
    writeRetract(X, Y);
  }
  
  setWorkPlane(new Vector(0, 0, 0)); // reset working plane
  
  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off

  writeln(
    "N99999999 %" + programName + " " + gUnitModal.format((unit == MM) ? 71 : 70)
  );
}

function setProperty(property, value) {
  properties[property].current = value;
}

