local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local OUTPUT_FOLDER = "GameStructureDump"
local SELECTION = {
    Structure = false,
    GUI = false,
    Remotes = false,
    Scripts = false,
    Values = false,
    PlayersTools = false,
    AvatarInspection = false,
    Visuals = false,
    Runtime = false,
    LocalSources = false,
    ModuleSources = false,
    InteractionResearch = false,
    ClosureResearch = false,
    OutgoingHook = false,
    CallbackTrace = false
}
local selectionGui
local selectionStatus
local selectionStartButton
local selectedSnapshotNodes
local dumpRunning = false
local SCHEMA_NAME = "Averyn.GameStructureDump"
local SCHEMA_VERSION = 3.9

local META_FILE = OUTPUT_FOLDER .. "/meta.json"
local TREE_FILE = OUTPUT_FOLDER .. "/structure.txt"
local STRUCTURE_FILE = OUTPUT_FOLDER .. "/structure.json"
local INSTANCES_FILE = OUTPUT_FOLDER .. "/instances.json"
local VISUAL_ASSETS_FILE = OUTPUT_FOLDER .. "/visual_assets.json"
local GUI_FILE = OUTPUT_FOLDER .. "/gui.json"
local RUNTIME_VISUAL_ASSETS_FILE = OUTPUT_FOLDER .. "/runtime_visual_assets.json"
local REMOTES_FILE = OUTPUT_FOLDER .. "/remotes.json"
local SCRIPTS_FILE = OUTPUT_FOLDER .. "/scripts.json"
local SUMMARY_FILE = OUTPUT_FOLDER .. "/summary.txt"
local INVENTORY_FILE = OUTPUT_FOLDER .. "/inventory.json"
local ATTRIBUTES_FILE = OUTPUT_FOLDER .. "/attributes.json"
local TOOLS_FILE = OUTPUT_FOLDER .. "/tools.json"
local VALUES_FILE = OUTPUT_FOLDER .. "/values.json"
local PLAYERS_FILE = OUTPUT_FOLDER .. "/players.json"
local AVATAR_INSPECTION_FILE = OUTPUT_FOLDER .. "/avatar_inspection.json"
local PLAYER_REFERENCES_FILE = OUTPUT_FOLDER .. "/player_references.json"
local STATE_FILE = OUTPUT_FOLDER .. "/state.json"
local RUNTIME_FILES = {
    Events = OUTPUT_FOLDER .. "/runtime_events.json",
    Gui = OUTPUT_FOLDER .. "/runtime_gui.json",
    EventsRemoteEvent = OUTPUT_FOLDER .. "/runtime_events_remote_event.json",
    EventsUnreliableRemoteEvent = OUTPUT_FOLDER .. "/runtime_events_unreliable_remote_event.json",
    EventsRemoteFunction = OUTPUT_FOLDER .. "/runtime_events_remote_function.json",
    EventsOther = OUTPUT_FOLDER .. "/runtime_events_other.json",
    Values = OUTPUT_FOLDER .. "/runtime_values.json",
    Attributes = OUTPUT_FOLDER .. "/runtime_attributes.json",
    Character = OUTPUT_FOLDER .. "/runtime_character.json",
    Logs = OUTPUT_FOLDER .. "/runtime_logs.json",
    Timeline = OUTPUT_FOLDER .. "/runtime_timeline.json",
    Disconnect = OUTPUT_FOLDER .. "/runtime_disconnect.json",
    Hooks = OUTPUT_FOLDER .. "/runtime_hooks.json",
    HookIntegrity = OUTPUT_FOLDER .. "/runtime_hook_integrity.json"
}
local MANIFEST_FILE = OUTPUT_FOLDER .. "/manifest.json"
local ERRORS_FILE = OUTPUT_FOLDER .. "/errors.json"
local WARNINGS_FILE = OUTPUT_FOLDER .. "/warnings.json"
local DIAGNOSTICS_FILE = OUTPUT_FOLDER .. "/diagnostics.json"
local CRASH_FILE = OUTPUT_FOLDER .. "/crash_report.json"
local PREVIOUS_RUN_FILE = OUTPUT_FOLDER .. "/previous_run_interrupted.json"
local RECOVERY_FOLDER = OUTPUT_FOLDER .. "/recovery"
local TAGS_FILE = OUTPUT_FOLDER .. "/tags.json"
local INTERACTIONS_FILE = OUTPUT_FOLDER .. "/interactions.json"
local PHYSICS_FILE = OUTPUT_FOLDER .. "/physics.json"
local REMOTE_USAGE_FILE = OUTPUT_FOLDER .. "/remote_usage.json"
local INTERACTION_RESEARCH_FILE = OUTPUT_FOLDER .. "/interaction_research.json"
local INTERACTION_EVENTS_FILE = OUTPUT_FOLDER .. "/interaction_events.json"
local SOURCE_REFERENCES_FILE = OUTPUT_FOLDER .. "/source_references.json"
local CONNECTION_RESEARCH_FILE = OUTPUT_FOLDER .. "/connection_research.json"
local MODULE_SOURCES_FOLDER = OUTPUT_FOLDER .. "/modules"
local CLIENT_SOURCES_FOLDER = OUTPUT_FOLDER .. "/localscripts"

local YIELD_EVERY = 128
local lastTraversalYield = os.clock()
local lastSelectionYield = os.clock()
local MAX_SERIALIZE_DEPTH = 32

local CONFIG = {
    RecoveryEnabled = true,
    RecoveryFlushSeconds = 3,
    RecoverySnapshotBatch = 2500,
    RecoveryRuntimeBatch = 160,
    SkipEngineInternals = true,
    HeavyGameYieldSeconds = 0,
    HeavyGameYieldAfterNodes = 12000,
    MaxTraversalSliceSeconds = 0.014,
    MaxSelectionSliceSeconds = 0.013,
    ProgressLogEverySeconds = 2,
    ProgressLogEveryNodes = 1250,
    FastSelectiveCapture = true,
    CompactSecondaryIndexes = true,
    RecoveryIssueBatch = 80,
    DiagnosticsIntervalSeconds = 2,
    MaxInteractionRecords = 20000,
    MaxPhysicsRecords = 20000,
    MaxTagRecords = 30000,
    RuntimeTrace = true,
    RuntimeTracePostSeconds = 90,
    VisualCapture = true,
    GuiCapture = true,
    GuiMaxSnapshotEntries = 100000,
    RuntimeTraceGui = true,
    RuntimeMaxObservedGui = 4500,
    RuntimeMaxGuiChanges = 20000,
    VisualMaxSnapshotEntries = 60000,
    VisualMaxDynamicEntries = 24000,
    VisualEssentialOverflowEntries = 6000,
    VisualMaxAnimationPlaybackEntries = 3500,
    VisualAnimatorSampleInterval = 0.6,
    VisualAnimatorKeepaliveInterval = 3,
    VisualMaxTrackedAnimators = 100,
    VisualSecondPassDelay = 0.35,
    RuntimeRingWindowSeconds = 30,
    RuntimeTraceIncomingRemotes = true,
    RuntimeTraceOutgoingRemotes = false,
    InteractionMaxEvents = 14000,
    InteractionMaxSourceReferences = 14000,
    InteractionMaxReferencesPerScript = 110,
    InteractionMaxToolDescendants = 150,
    InteractionMaxObservedTools = 1200,
    InteractionMaxObservedInteractions = 1200,
    InteractionMaxGuiButtonObservers = 200,
    InteractionMaxRemoteCandidates = 6000,
    InteractionMaxConnectionRecords = 800,
    InteractionMaxClosuresPerSignal = 24,
    InteractionMaxUpvalueNodes = 900,
    RuntimeTraceDynamicRemotes = true,
    RuntimeTraceToolAttributes = true,
    RuntimeTraceAllAttributes = true,
    RuntimeTraceAllValues = true,
    RuntimeCaptureCaller = true,
    RuntimeCaptureCallerStack = false,
    RuntimeCallerStackDepth = 10,
    RuntimeCaptureInvokeReturns = true,
    RuntimeCaptureBuffers = true,
    RuntimeMaxBufferBytes = 4096,
    RuntimeMaxSerializedTableItems = 512,
    RuntimeMaxSerializedStringBytes = 16384,
    RuntimeTraceCharacter = true,
    RuntimeCharacterSampleInterval = 0.15,
    RuntimeMaxCharacterRecords = 10000,
    RuntimeCaptureLogs = true,
    RuntimeMaxLogRecords = 5000,
    RuntimeTraceHookDiagnostics = false,
    RuntimeHookIntegrityInterval = 0.20,
    RuntimeMaxHookRecords = 12000,
    RuntimeMaxHookIntegrityRecords = 4000,
    RuntimeFreezeOnDisconnectError = true,
    RuntimeFreezeErrorKeywords = {
        "267",
        "kicked",
        "kick",
        "removed",
        "expelled",
        "expuls",
        "moderation",
        "cheat",
        "desconect",
        "disconnect"
    },
    RuntimeFlushEvery = 1000,
    RuntimeFlushMinSeconds = 5.0,
    RuntimePrimeYieldEvery = 150,
    RuntimePrimeBeforeSnapshot = false,
    RuntimeFlushDuringSnapshot = false,
    RuntimeMaxEvents = 40000,
    RuntimeMaxEventsPerCategory = {
        RemoteEvent = 20000,
        UnreliableRemoteEvent = 10000,
        RemoteFunction = 8000,
        Other = 8000
    },
    RuntimeMaxTimelineRecords = 40000,
    RuntimeMaxValueChanges = 16000,
    RuntimeMaxAttributeChanges = 16000,
    RuntimeMaxObservedRemotes = 5000,
    RuntimeMaxObservedAttributes = 3500,
    RuntimeMaxObservedValues = 5000,
    ProgressCheckpointEvery = 5000,
    StateIndexMaxPerBucket = 1500,
    DecompileModuleScripts = true,
    DecompileLocalScripts = true,
    LocalDecompilerMaxScripts = 500,
    LocalDecompilerWorkers = 3,
    LocalDecompilerTimeout = 10,
    LocalDecompilerAbortAfterTimeouts = 4,
    LocalDecompilerPriority = "HierarchyDepthThenPath",
    ModuleDecompilerEndpoint = "https://decompiler.bytefall.dev/decompile",
    ModuleDecompilerWorkers = 4,
    ModuleDecompilerTimeout = 10,
    ModuleDecompilerIgnore = { "Chat", "CoreGui", "CorePackages" },
    ModuleDecompilerRetryCount = 0,
    ModuleDecompilerRetryDelay = 0.35,
    ModuleDecompilerAbortAfterTimeouts = 3,
    ModuleDecompilerProgressEvery = 10,
    ModuleDecompilerCheckpointEvery = 60,
    V38MaxObserved = 1800,
    V38MaxEvents = 12000,
    V38MaxAssetIds = 7000,
    V38MaxReferencesPerAsset = 48,
    V38MaxTags = 100,
    V38MaxDependencyEdges = 6000,
    V38MaxNestedDepth = 4,
    V38MaxNestedItems = 40,
    V38MaxAnimationMarkers = 16,
    V38MaxMarkerListeners = 1200,
    V38DiscoverAnimationMarkers = true,
    V38MaxMarkerAssetLookups = 18,
    V38MaxMarkerLookupConcurrent = 2,
    V38EffectGroupWindow = 0.45,
    V38CameraSampleSeconds = 0.2,
    V38PoseTranslationTolerance = 0.12,
    V38PoseRotationTolerance = 0.12,
    V38CaptureCallbackCalls = false
}

local executorRequest =
    (type(syn) == "table" and type(syn.request) == "function" and syn.request)
    or (type(http) == "table" and type(http.request) == "function" and http.request)
    or (type(http_request) == "function" and http_request)
    or (type(fluxus) == "table" and type(fluxus.request) == "function" and fluxus.request)
    or (type(request) == "function" and request)
    or nil

local nativeBase64Encoder =
    (type(base64_encode) == "function" and base64_encode)
    or (type(crypt) == "table" and type(crypt.base64encode) == "function" and crypt.base64encode)
    or (
        type(crypt) == "table"
        and type(crypt.base64) == "table"
        and type(crypt.base64.encode) == "function"
        and crypt.base64.encode
    )
    or nil

local capabilities = {
    writefile = type(writefile) == "function",
    getscriptbytecode = type(getscriptbytecode) == "function",
    http_request = type(executorRequest) == "function",
    base64_native = type(nativeBase64Encoder) == "function",
    makefolder = type(makefolder) == "function",
    isfolder = type(isfolder) == "function",
    hookmetamethod = type(hookmetamethod) == "function",
    getnamecallmethod = type(getnamecallmethod) == "function",
    newcclosure = type(newcclosure) == "function",
    checkcaller = type(checkcaller) == "function",
    getcallingscript = type(getcallingscript) == "function",
    getconnections = type(getconnections) == "function",
    getupvalues = type(debug) == "table" and type(debug.getupvalues) == "function",
    getupvalue = type(debug) == "table" and type(debug.getupvalue) == "function",
    debug_info = debug ~= nil and type(debug.info) == "function",
    buffer = type(buffer) == "table",
    buffer_len = type(buffer) == "table" and type(buffer.len) == "function",
    buffer_readu8 = type(buffer) == "table" and type(buffer.readu8) == "function",
    buffer_tostring = type(buffer) == "table" and type(buffer.tostring) == "function",
    getrawmetatable = type(getrawmetatable) == "function",
    isreadonly = type(isreadonly) == "function",
        isexecutorclosure = type(isexecutorclosure) == "function",
    iscclosure = type(iscclosure) == "function"
}

local started = os.clock()
local nodeCount = 0
local nextInstanceId = 0

local classCounts = {}
local errors = {}
local warnings = {}
local attributeIndex = {}
local toolRecords = {}
local valueRecords = {}
local playerReferences = {}
local instanceIds = setmetatable({}, { __mode = "k" })
local instanceMetaById = {}
local traversedInstances = {}
local invalidUtf8Cache = {}
local invalidUtf8StringCount = 0
local invalidClassObjects = setmetatable({}, { __mode = "k" })
local invalidClassWarned = setmetatable({}, { __mode = "k" })
local invalidClassNameCount = 0
local runtimeEventRecords = {}
local runtimeEventCategoryRecords = {
    RemoteEvent = {},
    UnreliableRemoteEvent = {},
    RemoteFunction = {},
    Other = {}
}
local runtimeEventCategoryDropped = {
    RemoteEvent = 0,
    UnreliableRemoteEvent = 0,
    RemoteFunction = 0,
    Other = 0
}
local runtimeValueRecords = {}
local runtimeAttributeRecords = {}
local runtimeCharacterRecords = {}
local runtimeLogRecords = {}
local runtimeTimelineRecords = {}
local runtimeErrorRecords = {}
local runtimeConnections = {}
local runtimeCharacterConnections = {}
local runtimeObservedRemotes = setmetatable({}, { __mode = "k" })
local runtimeObservedAttributes = setmetatable({}, { __mode = "k" })
local runtimeObservedValues = setmetatable({}, { __mode = "k" })
local runtimeObserverCounts = {
    Remotes = 0,
    Attributes = 0,
    Values = 0
}
local runtimeObserverCapWarned = {
    Remotes = false,
    Attributes = false,
    Values = false
}
local runtimeAttributeLastValues = setmetatable({}, { __mode = "k" })
local runtimeValueLastValues = setmetatable({}, { __mode = "k" })
local runtimeTraceActive = false
local runtimeHookState = {
    Active = false,
    Frozen = false,
    FreezeInfo = nil,
    LastFlushAt = 0,
    MutationsSinceFlush = 0,
    LastPruneAt = 0,
    LastGuiErrorMessage = nil,
    HookRecords = {},
    HookIntegrityRecords = {},
    HookIntegrityBaseline = nil,
    HookIntegrityLast = nil,
    HookIntegrityLastCheckAt = 0,
        FlushScheduled = false
}
local runtimeOutgoingHookInstalled = false
local runtimeStartedAt = os.clock()
local snapshotFinalized = false
local guiCapture = {
    Snapshot = {},
    Observed = setmetatable({}, { __mode = "k" }),
    Records = {},
    SnapshotOmitted = 0,
    SnapshotSaved = 0,
    ObservedCount = 0,
    OmittedObservers = 0,
    ObserverCapWarned = false
}
local visualSnapshotRecords = {}
local visualDynamicRecords = {}
local visualDynamicByInstance = setmetatable({}, { __mode = "k" })
local visualSnapshotSaved = 0
local visualSnapshotOmitted = 0
local visualDynamicOmitted = 0
local visualEssentialOverflowSaved = 0
local visualAnimationPlaybackRecords = {}
local visualAnimationPlaybackOmitted = 0
local visualAnimatorInstances = setmetatable({}, { __mode = "k" })
local visualAnimatorStates = setmetatable({}, { __mode = "k" })
local visualTrackedAnimatorCount = 0
local visualRuntimeIdentityIds = setmetatable({}, { __mode = "k" })
local nextVisualRuntimeIdentity = 0
local visualCaptureErrors = 0
local snapshotBusy = false
local currentStage = "init"
local currentDumpId = nil
local currentModuleSourcesFolder = nil
local currentClientSourcesFolder = nil
local checkpointStage
local journalRecord
local flushRecovery
local writeDiagnostics
local initRecovery
local recoveryLastPath = "game"
local recoveryLastClass = "DataModel"
local recoveryLastError = nil
local recoveryLastFlush = 0
local recoveryFlushBusy = false
local recoveryLastDiagnostics = 0
local recoveryState = { Folder = nil, Buffers = { Snapshot = {}, Runtime = {}, Issues = {} }, Sequences = { Snapshot = 0, Runtime = 0, Issues = 0 }, Saved = { Snapshot = 0, Runtime = 0, Issues = 0 }, FailedWrites = 0, LastFailure = nil }
local remoteUsageByKey = {}
local remoteUsageRecords = {}
local remoteUsageOverflow = 0
local interactionEvents = {}
local interactionDropped = 0
local interactionSourceReferences = {}
local interactionSourceRefsDropped = 0
local interactionObservedTools = setmetatable({}, { __mode = "k" })
local interactionObservedRemotes = setmetatable({}, { __mode = "k" })
local interactionToolCounts = { Tools = 0, Activations = 0, Equips = 0 }
local interactionRemoteLifecycleCounts = { Added = 0, Removed = 0, Renamed = 0, Reparented = 0 }
local interactionObservedRemoteCount = 0
local interactionConnectionRecords = {}
local interactionConnectionDropped = 0
local REMOTE_USAGE_LIMIT = 6000
local REMOTE_USAGE_SAMPLE_LIMIT = 12
local tagRecords = {}
local tagCounts = {}
local tagOmitted = 0
local interactionRecords = {}
local interactionOmitted = 0
local physicsRecords = {}
local physicsOmitted = 0
local INTERACTION_CLASSES = { ProximityPrompt = true, ClickDetector = true, DragDetector = true, TouchTransmitter = true, Seat = true, VehicleSeat = true, SpawnLocation = true }
local PHYSICS_CLASSES = { Weld = true, ManualWeld = true, Snap = true, Motor6D = true, WeldConstraint = true, BallSocketConstraint = true, HingeConstraint = true, PrismaticConstraint = true, RodConstraint = true, RopeConstraint = true, SpringConstraint = true, CylindricalConstraint = true, AlignPosition = true, AlignOrientation = true, LinearVelocity = true, AngularVelocity = true, VectorForce = true, Torque = true, LineForce = true, PlaneConstraint = true, NoCollisionConstraint = true, Attachment = true, Bone = true, RigidConstraint = true, AnimationConstraint = true, UniversalConstraint = true, TorsionSpringConstraint = true }

local remoteIndex = {
    RemoteEvents = {},
    UnreliableRemoteEvents = {},
    RemoteFunctions = {},
    BindableEvents = {},
    BindableFunctions = {}
}

local scriptIndex = {
    LocalScripts = {},
    ModuleScripts = {},
    Scripts = {},
    CoreScripts = {}
}

local moduleScriptQueue = {}
local clientScriptQueue = {}
local clientDecompileStats = {
    Enabled = CONFIG.DecompileLocalScripts,
    Queued = 0,
    Attempted = 0,
    Succeeded = 0,
    Failed = 0,
    Skipped = 0,
    TimedOut = 0,
    Aborted = 0,
    Written = 0,
    BytecodeBytes = 0,
    SourceBytes = 0,
    ElapsedSeconds = 0,
    OutputFolder = nil
}
local moduleDecompileStats = {
    Enabled = CONFIG.DecompileModuleScripts,
    Endpoint = CONFIG.ModuleDecompilerEndpoint,
    Queued = 0,
    Attempted = 0,
    Succeeded = 0,
    Failed = 0,
    Skipped = 0,
    Ignored = 0,
    TimedOut = 0,
    Aborted = 0,
    Written = 0,
    BytecodeBytes = 0,
    SourceBytes = 0,
    ElapsedSeconds = 0
}

local inventoryToolIds = {
    Backpack = {},
    Character = {},
    StarterGear = {}
}

local F = {}
local progressLastLoggedAt = os.clock()
local progressLastCount = 0
local progressLastStage = nil

function F.log(...)
    print("[GameStructureDump]", ...)
end

function F.logProgress(force, stage)
    local now = os.clock()
    local interval = math.max(0.25, tonumber(CONFIG.ProgressLogEverySeconds) or 2)
    if not force and now - progressLastLoggedAt < interval then
        return
    end
    local elapsed = math.max(0.001, now - started)
    local rate = math.floor((nodeCount - progressLastCount) /
        math.max(0.001, now - progressLastLoggedAt) + 0.5)
    F.log(string.format("%s | %d instances | %d/s | %.1fs | %d errors, %d warnings",
        tostring(stage or currentStage), nodeCount, rate, elapsed, #errors, #warnings))
    progressLastLoggedAt = now
    progressLastCount = nodeCount
    if selectionStatus and selectionStatus.Parent then
        selectionStatus.Text = string.format("%s: %d nodes, %d/s", tostring(stage or currentStage), nodeCount, rate)
    end
end

function F.isContinuationByte(value)
    return value ~= nil and value >= 0x80 and value <= 0xBF
end

function F.sanitizeString(value)
    if type(value) ~= "string" then
        value = tostring(value)
    end

    local utf8Ok, utf8Length = pcall(utf8.len, value)
    if utf8Ok and utf8Length ~= nil then
        return value
    end

    local cached = invalidUtf8Cache[value]
    if cached then
        return cached
    end

    local output = {}
    local index = 1
    local length = #value

    while index <= length do
        local b1 = string.byte(value, index)
        local sequenceLength = 0

        if b1 <= 0x7F then
            sequenceLength = 1
        elseif b1 >= 0xC2 and b1 <= 0xDF then
            local b2 = string.byte(value, index + 1)
            if F.isContinuationByte(b2) then
                sequenceLength = 2
            end
        elseif b1 >= 0xE0 and b1 <= 0xEF then
            local b2 = string.byte(value, index + 1)
            local b3 = string.byte(value, index + 2)
            local secondValid = false

            if b1 == 0xE0 then
                secondValid = b2 ~= nil and b2 >= 0xA0 and b2 <= 0xBF
            elseif b1 == 0xED then
                secondValid = b2 ~= nil and b2 >= 0x80 and b2 <= 0x9F
            else
                secondValid = F.isContinuationByte(b2)
            end

            if secondValid and F.isContinuationByte(b3) then
                sequenceLength = 3
            end
        elseif b1 >= 0xF0 and b1 <= 0xF4 then
            local b2 = string.byte(value, index + 1)
            local b3 = string.byte(value, index + 2)
            local b4 = string.byte(value, index + 3)
            local secondValid = false

            if b1 == 0xF0 then
                secondValid = b2 ~= nil and b2 >= 0x90 and b2 <= 0xBF
            elseif b1 == 0xF4 then
                secondValid = b2 ~= nil and b2 >= 0x80 and b2 <= 0x8F
            else
                secondValid = F.isContinuationByte(b2)
            end

            if secondValid and F.isContinuationByte(b3) and F.isContinuationByte(b4) then
                sequenceLength = 4
            end
        end

        if sequenceLength > 0 then
            table.insert(output, string.sub(value, index, index + sequenceLength - 1))
            index = index + sequenceLength
        else
            table.insert(output, string.format("\\x%02X", b1))
            index = index + 1
        end
    end

    local sanitized = table.concat(output)
    invalidUtf8Cache[value] = sanitized
    invalidUtf8StringCount = invalidUtf8StringCount + 1
    return sanitized
end

function F.escapeText(value)
    value = F.sanitizeString(value)
    local output = {}

    for index = 1, #value do
        local byte = string.byte(value, index)

        if byte == 9 then
            table.insert(output, "\\t")
        elseif byte == 10 then
            table.insert(output, "\\n")
        elseif byte == 13 then
            table.insert(output, "\\r")
        elseif byte < 32 or byte == 127 then
            table.insert(output, string.format("\\x%02X", byte))
        else
            table.insert(output, string.char(byte))
        end
    end

    return table.concat(output)
end

function F.safeName(object)
    local ok, value = pcall(function()
        return object.Name
    end)

    if ok then
        return F.sanitizeString(value)
    end

    return "<unknown>"
end

function F.safeClassName(object)
    local ok, value = pcall(function()
        return object.ClassName
    end)

    if ok and type(value) == "string" then
        value = F.sanitizeString(value)
        if value ~= "" then
            return value
        end
    end

    if not invalidClassObjects[object] then
        invalidClassObjects[object] = true
        invalidClassNameCount = invalidClassNameCount + 1
    end

    return "Instance"
end

function F.safeFullName(object)
    local ok, result = pcall(function()
        return object:GetFullName()
    end)

    if ok then
        return F.sanitizeString(result)
    end

    return F.safeName(object)
end

function F.makeIssue(stage, object, message, property)
    local entry = {
        Stage = F.sanitizeString(stage),
        Error = F.sanitizeString(message)
    }

    if object then
        entry.Id = instanceIds[object]
        entry.Name = F.safeName(object)
        entry.ClassName = F.safeClassName(object)
        entry.Path = F.safeFullName(object)
    end

    if property then
        entry.Property = F.sanitizeString(property)
    end

    return entry
end

function F.recordError(stage, object, message, property)
    local entry = F.makeIssue(stage, object, message, property)
    table.insert(errors, entry)
    recoveryLastError = entry
    if journalRecord then journalRecord("Issues", { Severity = "Error", Data = entry }) end
end

function F.recordWarning(stage, object, message, property)
    local entry = F.makeIssue(stage, object, message, property)
    table.insert(warnings, entry)
    if journalRecord then journalRecord("Issues", { Severity = "Warning", Data = entry }) end
end

function F.safeGet(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)

    if ok then
        return value, true, nil
    end

    return nil, false, value
end

function F.safeIsA(object, className)
    local ok, result = pcall(function()
        return object:IsA(className)
    end)

    return ok and result or false
end

-- Class inheritance does not change per instance. Cache the result per Roblox class.
-- If ClassName was unreadable, do not share an unsafe cached result.
local isaByClass = {}
function F.classIsA(object, objectClass, targetClass)
    if objectClass == "Instance" and invalidClassObjects[object] then
        return F.safeIsA(object, targetClass)
    end
    local classCache = isaByClass[objectClass]
    if not classCache then
        classCache = {}
        isaByClass[objectClass] = classCache
    end
    local result = classCache[targetClass]
    if result == nil then
        result = F.safeIsA(object, targetClass)
        classCache[targetClass] = result
    end
    return result
end

function F.safeIsDescendantOf(object, ancestor)
    if not object or not ancestor then
        return false
    end

    local ok, result = pcall(function()
        return object:IsDescendantOf(ancestor)
    end)

    return ok and result or false
end

function F.assignInstanceId(object)
    local existing = instanceIds[object]
    if existing then
        return existing
    end

    nextInstanceId = nextInstanceId + 1
    local id = nextInstanceId
    instanceIds[object] = id

    instanceMetaById[id] = {
        Id = id,
        Name = F.safeName(object),
        ClassName = F.safeClassName(object),
        Path = F.safeFullName(object),
        ReferencedOnly = true
    }

    return id
end

function F.updateInstanceMeta(object, id, parentId, name, className, path)
    local meta = instanceMetaById[id]
    if not meta then
        meta = { Id = id }
        instanceMetaById[id] = meta
    end

    meta.Name = name or F.safeName(object)
    meta.ClassName = className or F.safeClassName(object)
    meta.Path = path or F.safeFullName(object)
    meta.ParentId = parentId
    meta.ReferencedOnly = false
end

function F.makeInstanceReference(object, allowAssign)
    if not object then
        return nil
    end

    if allowAssign == nil then
        allowAssign = true
    end

    local id = instanceIds[object]
    if not id and not snapshotFinalized and allowAssign then
        id = F.assignInstanceId(object)
    end

    local reference = {
        Name = F.safeName(object),
        ClassName = F.safeClassName(object),
        Path = F.safeFullName(object)
    }

    if id then
        reference.Id = id
    end

    return reference
end

function F.finiteNumber(value)
    if value ~= value then
        return false
    end

    return value ~= math.huge and value ~= -math.huge
end

function F.serializeComponentNumber(value)
    if F.finiteNumber(value) then
        return value
    end

    return {
        __type = "NonFiniteNumber",
        value = F.sanitizeString(tostring(value))
    }
end

function F.optionalMap(value)
    if next(value) == nil then
        return nil
    end

    return value
end

function F.isArrayTable(value)
    local count = 0
    local highest = 0

    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        count = count + 1
        if key > highest then
            highest = key
        end
    end

    return highest == count
end

function F.stableKey(value)
    local valueType = typeof(value)

    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return valueType .. ":" .. tostring(value)
    end

    if valueType == "EnumItem" then
        return valueType .. ":" .. tostring(value)
    end

    return valueType .. ":" .. tostring(value)
end

-- A portable comparison checksum: not cryptographic and not a security identifier.
-- Multiplication remains within the exact integer range of Luau's number type.
function F.comparisonDigest(value)
    if type(value) ~= "string" then return nil end
    local h1, h2 = 0, 1
    for index = 1, #value do
        local byte = string.byte(value, index)
        h1 = (h1 * 131 + byte) % 4294967296
        h2 = (h2 + byte) % 65521
    end
    return string.format("%08x-%04x-%d", h1, h2, #value)
end

function F.normalizeComparisonPath(path)
    return tostring(path or ""):gsub("[^%.]+", function(part)
        if part:match("^[%x]+$") and #part >= 32 and #part <= 128 then
            return "<HEX>"
        end
        if part:match("^%x%x%x%x%x%x%x%x%-[%x]+%-[%x]+%-[%x]+%-[%x]+$")
            and #part == 36 then
            return "<UUID>"
        end
        return part
    end)
end

function F.researchEvent(kind, object, details)
    if not SELECTION.InteractionResearch then return end
    if #interactionEvents >= CONFIG.InteractionMaxEvents then
        interactionDropped = interactionDropped + 1
        return
    end
    local className = object and F.safeClassName(object) or nil
    local path = object and F.safeFullName(object) or nil
    interactionEvents[#interactionEvents + 1] = {
        Time = os.clock() - runtimeStartedAt,
        Kind = kind,
        Name = object and F.safeName(object) or nil,
        ClassName = className,
        Path = path,
        NormalizedPath = path and F.normalizeComparisonPath(path) or nil,
        Details = details
    }
end

function F.scanSourceReferences(source, record, file)
    if not SELECTION.InteractionResearch or type(source) ~= "string" or not record then return end
    local tokens = {
        "require(", "getservice(", "findfirstchild(", "waitforchild(",
        "findfirstancestor(", "getdescendants(", "getchildren(",
        "fireserver(", "invokeserver(", "onclientevent", "onclientinvoke",
        "remoteevent", "remotefunction", "bindableevent", "bindablefunction",
        "getattribute(", "setattribute(", "getpropertychangedsignal(",
        "gettagged(", "getinstanceaddedsignal(", "getinstanceremovedsignal(",
        ":connect(", ":once(", ":fire(", ":invoke(",
        "activated:connect", "triggered:connect", "touched:connect",
        "raycast(", "blockcast(", "shapecast(", "overlapparts(",
        "getconnections(", "getupvalue(", "getupvalues(", "hookfunction(",
        "hookmetamethod(", "getnamecallmethod(", "task.spawn(", "task.defer("
    }
    local lines = string.split(source, "\n")
    local perScript = 0
    for index, line in ipairs(lines) do
        if #interactionSourceReferences >= CONFIG.InteractionMaxSourceReferences then
            interactionSourceRefsDropped = interactionSourceRefsDropped + 1
            return
        end
        local lower = string.lower(line)
        local matched = {}
        for _, token in ipairs(tokens) do
            if string.find(lower, token, 1, true) then matched[#matched + 1] = token end
        end
        if #matched > 0 then
            interactionSourceReferences[#interactionSourceReferences + 1] = {
                ScriptPath = record.Path,
                ScriptClass = record.ClassName,
                File = file,
                Line = index,
                Matches = matched,
                Text = line:sub(1, 300),
                Previous = index > 1 and lines[index - 1]:sub(1, 200) or nil,
                Next = index < #lines and lines[index + 1]:sub(1, 200) or nil
            }
            perScript = perScript + 1
            if perScript >= CONFIG.InteractionMaxReferencesPerScript then break end
        end
    end
end

function F.bytesToHex(value)
    local output = table.create(math.ceil(#value / 32))

    for index = 1, #value, 32 do
        local stopIndex = math.min(index + 31, #value)
        local chunk = table.create(stopIndex - index + 1)

        for byteIndex = index, stopIndex do
            chunk[#chunk + 1] = string.format("%02X", string.byte(value, byteIndex))
        end

        output[#output + 1] = table.concat(chunk)
    end

    return table.concat(output)
end

function F.readBufferRange(value, offset, length)
    if length <= 0 then
        return ""
    end

    if capabilities.buffer_tostring then
        local ok, raw = pcall(buffer.tostring, value)
        if ok and type(raw) == "string" then
            return string.sub(raw, offset + 1, offset + length)
        end
    end

    if capabilities.buffer_readu8 then
        local bytes = table.create(length)

        for index = 0, length - 1 do
            local ok, byte = pcall(buffer.readu8, value, offset + index)
            if not ok then
                return nil
            end

            bytes[index + 1] = string.char(byte)
        end

        return table.concat(bytes)
    end

    return nil
end

function F.serializeBufferValue(value)
    local result = {
        __type = "buffer"
    }

    if not CONFIG.RuntimeCaptureBuffers then
        result.Captured = false
        result.Value = F.sanitizeString(tostring(value))
        return result
    end

    if not capabilities.buffer_len then
        result.Captured = false
        result.Error = "buffer.len unavailable"
        result.Value = F.sanitizeString(tostring(value))
        return result
    end

    local lengthOk, length = pcall(buffer.len, value)
    if not lengthOk or type(length) ~= "number" then
        result.Captured = false
        result.Error = F.sanitizeString(length)
        result.Value = F.sanitizeString(tostring(value))
        return result
    end

    result.Length = length

    local maxBytes = math.max(0, tonumber(CONFIG.RuntimeMaxBufferBytes) or 0)
    if maxBytes == 0 then
        result.Captured = false
        return result
    end

    if length <= maxBytes then
        local raw = F.readBufferRange(value, 0, length)
        if raw then
            result.Captured = true
            result.CapturedBytes = length
            result.Truncated = false
            result.Hex = F.bytesToHex(raw)
        else
            result.Captured = false
            result.Error = "buffer bytes could not be read"
        end

        return result
    end

    local prefixLength = math.floor(maxBytes / 2)
    local suffixLength = maxBytes - prefixLength
    local prefix = F.readBufferRange(value, 0, prefixLength)
    local suffix = F.readBufferRange(value, math.max(0, length - suffixLength), suffixLength)

    if prefix and suffix then
        result.Captured = true
        result.CapturedBytes = prefixLength + suffixLength
        result.Truncated = true
        result.HexPrefix = F.bytesToHex(prefix)
        result.HexSuffix = F.bytesToHex(suffix)
        result.OmittedBytes = math.max(0, length - prefixLength - suffixLength)
    else
        result.Captured = false
        result.Error = "buffer bytes could not be read"
    end

    return result
end

local serializeValue

serializeValue = function(value, state)
    if value == nil then
        return nil
    end

    state = state or {
        seen = {},
        depth = 0
    }

    if state.depth > MAX_SERIALIZE_DEPTH then
        return {
            __type = "MaxDepth",
            depth = state.depth
        }
    end

    local valueType = typeof(value)

    if valueType == "string" then
        local serializedString = F.sanitizeString(value)
        local maxStringBytes = tonumber(state.maxStringBytes)
        if maxStringBytes and maxStringBytes > 0 and #serializedString > maxStringBytes then
            local omitted = #serializedString - maxStringBytes
            return string.sub(serializedString, 1, maxStringBytes)
                .. string.format("...<truncated %d bytes>", omitted)
        end
        return serializedString
    end

    if valueType == "buffer" then
        return F.serializeBufferValue(value)
    end

    if valueType == "boolean" then
        return value
    end

    if valueType == "number" then
        if F.finiteNumber(value) then
            return value
        end

        return {
            __type = "Number",
            value = F.sanitizeString(tostring(value))
        }
    end

    if valueType == "Vector2int16" or valueType == "Vector3int16" then
        local result = {
            __type = valueType,
            x = value.X,
            y = value.Y
        }
        if valueType == "Vector3int16" then result.z = value.Z end
        return result
    end

    if valueType == "PhysicalProperties" then
        return {
            __type = "PhysicalProperties",
            Density = F.serializeComponentNumber(value.Density),
            Friction = F.serializeComponentNumber(value.Friction),
            Elasticity = F.serializeComponentNumber(value.Elasticity),
            FrictionWeight = F.serializeComponentNumber(value.FrictionWeight),
            ElasticityWeight = F.serializeComponentNumber(value.ElasticityWeight)
        }
    end

    if valueType == "Axes" then
        return { __type = "Axes", X = value.X, Y = value.Y, Z = value.Z }
    end

    if valueType == "Faces" then
        return {
            __type = "Faces", Top = value.Top, Bottom = value.Bottom,
            Left = value.Left, Right = value.Right,
            Front = value.Front, Back = value.Back
        }
    end

    if valueType == "DateTime" then
        return { __type = "DateTime", UnixTimestampMillis = value.UnixTimestampMillis }
    end

    if valueType == "TweenInfo" then
        return {
            __type = "TweenInfo", Time = value.Time,
            EasingStyle = serializeValue(value.EasingStyle),
            EasingDirection = serializeValue(value.EasingDirection),
            RepeatCount = value.RepeatCount,
            Reverses = value.Reverses,
            DelayTime = value.DelayTime
        }
    end

    if valueType == "Region3" then
        return {
            __type = "Region3", CFrame = serializeValue(value.CFrame),
            Size = serializeValue(value.Size)
        }
    end

    if valueType == "Region3int16" then
        return {
            __type = "Region3int16", Min = serializeValue(value.Min),
            Max = serializeValue(value.Max)
        }
    end

    if valueType == "Vector3" then
        return {
            __type = "Vector3",
            x = F.serializeComponentNumber(value.X),
            y = F.serializeComponentNumber(value.Y),
            z = F.serializeComponentNumber(value.Z)
        }
    end

    if valueType == "Vector2" then
        return {
            __type = "Vector2",
            x = F.serializeComponentNumber(value.X),
            y = F.serializeComponentNumber(value.Y)
        }
    end

    if valueType == "Color3" then
        return {
            __type = "Color3",
            r = F.serializeComponentNumber(value.R),
            g = F.serializeComponentNumber(value.G),
            b = F.serializeComponentNumber(value.B)
        }
    end

    if valueType == "CFrame" then
        local rawComponents = { value:GetComponents() }
        local components = {}
        for index, component in ipairs(rawComponents) do
            components[index] = F.serializeComponentNumber(component)
        end

        return {
            __type = "CFrame",
            components = components
        }
    end

    if valueType == "UDim" then
        return {
            __type = "UDim",
            scale = F.serializeComponentNumber(value.Scale),
            offset = F.serializeComponentNumber(value.Offset)
        }
    end

    if valueType == "UDim2" then
        return {
            __type = "UDim2",
            xScale = F.serializeComponentNumber(value.X.Scale),
            xOffset = F.serializeComponentNumber(value.X.Offset),
            yScale = F.serializeComponentNumber(value.Y.Scale),
            yOffset = F.serializeComponentNumber(value.Y.Offset)
        }
    end

    if valueType == "BrickColor" then
        return {
            __type = "BrickColor",
            name = F.sanitizeString(value.Name),
            number = value.Number
        }
    end

    if valueType == "EnumItem" then
        return {
            __type = "EnumItem",
            value = F.sanitizeString(tostring(value))
        }
    end

    if valueType == "Font" then
        return {
            __type = "Font",
            family = F.sanitizeString(value.Family),
            weight = serializeValue(value.Weight),
            style = serializeValue(value.Style)
        }
    end

    if valueType == "NumberRange" then
        return {
            __type = "NumberRange",
            min = F.serializeComponentNumber(value.Min),
            max = F.serializeComponentNumber(value.Max)
        }
    end

    if valueType == "Rect" then
        return {
            __type = "Rect",
            min = serializeValue(value.Min),
            max = serializeValue(value.Max)
        }
    end

    if valueType == "Ray" then
        return {
            __type = "Ray",
            origin = serializeValue(value.Origin),
            direction = serializeValue(value.Direction)
        }
    end

    if valueType == "NumberSequence" then
        local keypoints = {}
        for _, keypoint in ipairs(value.Keypoints) do
            table.insert(keypoints, {
                time = F.serializeComponentNumber(keypoint.Time),
                value = F.serializeComponentNumber(keypoint.Value),
                envelope = F.serializeComponentNumber(keypoint.Envelope)
            })
        end

        return {
            __type = "NumberSequence",
            keypoints = keypoints
        }
    end

    if valueType == "ColorSequence" then
        local keypoints = {}
        for _, keypoint in ipairs(value.Keypoints) do
            table.insert(keypoints, {
                time = F.serializeComponentNumber(keypoint.Time),
                value = serializeValue(keypoint.Value)
            })
        end

        return {
            __type = "ColorSequence",
            keypoints = keypoints
        }
    end

    if valueType == "Instance" then
        local reference = F.makeInstanceReference(value, not state.noAssignInstanceId)
        reference.__type = "Instance"
        return reference
    end

    if valueType == "table" then
        if state.seen[value] then
            return {
                __type = "CircularReference"
            }
        end

        state.seen[value] = true

        local childState = {
            seen = state.seen,
            depth = state.depth + 1,
            noAssignInstanceId = state.noAssignInstanceId,
            maxTableItems = state.maxTableItems,
            maxStringBytes = state.maxStringBytes
        }

        local result

        local maxTableItems = tonumber(state.maxTableItems)
        if maxTableItems and maxTableItems <= 0 then
            maxTableItems = nil
        end

        if F.isArrayTable(value) then
            result = {}
            local total = #value
            local limit = maxTableItems and math.min(total, maxTableItems) or total

            for index = 1, limit do
                result[index] = serializeValue(value[index], childState)
            end

            if limit < total then
                result[limit + 1] = {
                    __type = "TruncatedArray",
                    OmittedItems = total - limit
                }
            end
        else
            local entries = {}
            local totalEntries = 0

            for key, item in pairs(value) do
                totalEntries = totalEntries + 1
                if not maxTableItems or #entries < maxTableItems then
                    table.insert(entries, {
                        _sort = F.stableKey(key),
                        key = serializeValue(key, childState),
                        value = serializeValue(item, childState)
                    })
                end
            end

            table.sort(entries, function(a, b)
                return a._sort < b._sort
            end)

            for _, entry in ipairs(entries) do
                entry._sort = nil
            end

            result = {
                __type = "Table",
                entries = entries
            }

            if totalEntries > #entries then
                result.Truncated = true
                result.OmittedEntries = totalEntries - #entries
            end
        end

        state.seen[value] = nil
        return result
    end

    return {
        __type = F.sanitizeString(valueType),
        value = F.sanitizeString(tostring(value))
    }
end

function F.serializeRuntimeValue(value)
    local ok, result = pcall(serializeValue, value, {
        seen = {},
        depth = 0,
        noAssignInstanceId = true,
        maxTableItems = CONFIG.RuntimeMaxSerializedTableItems,
        maxStringBytes = CONFIG.RuntimeMaxSerializedStringBytes
    })

    if ok then
        return result
    end

    return {
        __type = "SerializationError",
        value = F.sanitizeString(result)
    }
end

function F.serializePackedRuntimeValues(packed)
    local output = {}
    for index = 1, packed.n do
        local value = packed[index]
        if value == nil then
            output[index] = { __type = "Nil" }
        else
            output[index] = F.serializeRuntimeValue(value)
        end
    end
    return output
end

function F.getAttributes(object)
    local ok, attributes = pcall(function()
        return object:GetAttributes()
    end)

    if not ok then
        F.recordError("GetAttributes", object, attributes)
        return {}
    end

    local output = {}

    for name, value in pairs(attributes) do
        local safeAttributeName = F.sanitizeString(name)
        local success, serialized = pcall(serializeValue, value)
        if success then
            output[safeAttributeName] = serialized
        else
            F.recordError("SerializeAttribute", object, serialized, safeAttributeName)
        end
    end

    return output
end

function F.getTags(object)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(object)
    end)

    if not ok then
        F.recordError("GetTags", object, tags)
        return {}
    end

    for index, tag in ipairs(tags) do
        tags[index] = F.sanitizeString(tag)
    end

    table.sort(tags)
    return tags
end

F.PROPERTY_GROUPS = {
    {
        Class = "ValueBase",
        Properties = { "Value" }
    },
    {
        Class = "BasePart",
        Properties = {
            "Position",
            "Size",
            "CFrame",
            "Anchored",
            "CanCollide",
            "CanTouch",
            "CanQuery",
            "Transparency",
            "Material",
            "Color"
        }
    },
    {
        Class = "Animation",
        Properties = { "AnimationId" }
    },
    {
        Class = "Sound",
        Properties = {
            "SoundId",
            "Volume",
            "Looped",
            "PlaybackSpeed"
        }
    },
    {
        Class = "Decal",
        Properties = { "Texture", "Transparency" }
    },
    {
        Class = "Texture",
        Properties = { "Texture", "Transparency" }
    },
    {
        Class = "MeshPart",
        Properties = { "MeshId", "TextureID" }
    },
    {
        Class = "SpecialMesh",
        Properties = {
            "MeshId",
            "TextureId",
            "MeshType",
            "Scale"
        }
    },
    {
        Class = "Humanoid",
        Properties = {
            "Health",
            "MaxHealth",
            "WalkSpeed",
            "JumpPower",
            "RigType"
        }
    },
    {
        Class = "Tool",
        Properties = {
            "ToolTip",
            "CanBeDropped",
            "RequiresHandle",
            "Enabled",
            "Grip",
            "TextureId"
        }
    },
    {
        Class = "BaseScript",
        Properties = { "Disabled", "Enabled", "RunContext" }
    },
    {
        Class = "ProximityPrompt",
        Properties = {
            "ActionText",
            "ObjectText",
            "HoldDuration",
            "MaxActivationDistance",
            "KeyboardKeyCode"
        }
    }
}

-- Optional properties are always read under pcall.  Unsupported, protected and
-- newer engine properties are omitted without treating a version difference as
-- an error.  Existing property maps and output field names stay unchanged.
F.GUI_CLASSES = {
    ScreenGui = true, BillboardGui = true, SurfaceGui = true, Frame = true,
    CanvasGroup = true, ScrollingFrame = true, TextLabel = true,
    TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true,
    VideoFrame = true, ViewportFrame = true, UIListLayout = true,
    UIGridLayout = true, UITableLayout = true, UIPageLayout = true,
    UIAspectRatioConstraint = true, UISizeConstraint = true,
    UITextSizeConstraint = true, UIPadding = true, UIScale = true,
    UICorner = true, UIStroke = true, UIGradient = true, UIFlexItem = true,
    UIGridStyleLayout = true, UIComponent = true, LocalizationTable = true
}

F.TEXT_GUI_CLASSES = {
    TextLabel = true, TextButton = true, TextBox = true
}

F.GUI_PROPERTY_GROUPS = {
    GuiObject = {
        "Visible", "Active", "Interactable", "Selectable", "SelectionOrder",
        "SelectionImageObject", "NextSelectionUp", "NextSelectionDown",
        "NextSelectionLeft", "NextSelectionRight", "Position", "Size",
        "AnchorPoint", "Rotation", "AutomaticSize", "SizeConstraint",
        "BackgroundColor3", "BackgroundTransparency", "BorderColor3",
        "BorderSizePixel", "BorderMode", "ClipsDescendants", "LayoutOrder",
        "ZIndex", "AbsolutePosition", "AbsoluteSize", "AbsoluteRotation",
        "AutoLocalize", "RootLocalizationTable"
    },
    GuiButton = { "AutoButtonColor", "Modal", "Selected", "Style" },
    Text = {
        "Text", "ContentText", "LocalizedText", "RichText", "Font",
        "FontFace", "TextSize", "TextScaled", "TextWrapped", "TextTruncate",
        "TextXAlignment", "TextYAlignment", "TextColor3", "TextTransparency",
        "TextStrokeColor3", "TextStrokeTransparency", "LineHeight",
        "MaxVisibleGraphemes", "TextDirection", "TextBounds", "TextFits"
    },
    Image = {
        "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset",
        "ImageRectSize", "ScaleType", "SliceCenter", "SliceScale", "TileSize",
        "ResampleMode", "IsLoaded", "ContentImageSize"
    }
}

F.EXTRA_CLASS_PROPERTIES = {
    ScreenGui = { "Enabled", "DisplayOrder", "IgnoreGuiInset", "ResetOnSpawn", "ZIndexBehavior", "ScreenInsets", "ClipToDeviceSafeArea", "SafeAreaCompatibility", "OnTopOfCoreBlur" },
    BillboardGui = { "Enabled", "Adornee", "AlwaysOnTop", "Brightness", "LightInfluence", "MaxDistance", "Size", "SizeOffset", "StudsOffset", "StudsOffsetWorldSpace", "ExtentsOffset", "ExtentsOffsetWorldSpace", "PlayerToHideFrom", "ClipsDescendants", "Active", "ZIndexBehavior", "ResetOnSpawn" },
    SurfaceGui = { "Enabled", "Adornee", "AlwaysOnTop", "Brightness", "LightInfluence", "CanvasSize", "Face", "PixelsPerStud", "PixelsPerStuds", "SizingMode", "ZOffset", "ToolPunchThroughDistance", "Active", "ZIndexBehavior", "ResetOnSpawn" },
    Frame = { "Style" },
    CanvasGroup = { "GroupColor3", "GroupTransparency", "ResolutionScale" },
    ScrollingFrame = { "CanvasPosition", "CanvasSize", "AbsoluteCanvasSize", "AutomaticCanvasSize", "ScrollingDirection", "ScrollingEnabled", "ScrollBarThickness", "ScrollBarImageColor3", "ScrollBarImageTransparency", "VerticalScrollBarInset", "HorizontalScrollBarInset", "ElasticBehavior", "TopImage", "MidImage", "BottomImage" },
    TextBox = { "PlaceholderText", "PlaceholderColor3", "ClearTextOnFocus", "MultiLine", "TextEditable", "ShowNativeInput", "CursorPosition", "SelectionStart", "TextInputType", "ReturnKeyType" },
    ImageButton = { "HoverImage", "PressedImage" },
    ViewportFrame = { "CurrentCamera", "Ambient", "LightColor", "LightDirection", "ImageColor3", "ImageTransparency", "IsMirrored" },
    VideoFrame = { "Video", "Looped", "Playing", "Volume", "TimePosition", "TimeLength", "IsLoaded", "ResampleMode" },
    UIListLayout = { "Padding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Wraps", "HorizontalFlex", "VerticalFlex", "ItemLineAlignment", "AbsoluteContentSize" },
    UIGridLayout = { "CellSize", "CellPadding", "FillDirection", "FillDirectionMaxCells", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "StartCorner", "AbsoluteContentSize" },
    UITableLayout = { "FillEmptySpaceColumns", "FillEmptySpaceRows", "MajorAxis", "Padding", "AbsoluteContentSize" },
    UIPageLayout = { "CurrentPage", "EasingDirection", "EasingStyle", "GamepadInputEnabled", "ScrollWheelInputEnabled", "TouchInputEnabled", "TweenTime", "Circular", "Padding", "Animated", "AbsoluteContentSize" },
    UIAspectRatioConstraint = { "AspectRatio", "AspectType", "DominantAxis" },
    UISizeConstraint = { "MinSize", "MaxSize" },
    UITextSizeConstraint = { "MinTextSize", "MaxTextSize" },
    UIPadding = { "PaddingBottom", "PaddingLeft", "PaddingRight", "PaddingTop" },
    UIScale = { "Scale" },
    UICorner = { "CornerRadius" },
    UIStroke = { "ApplyStrokeMode", "Color", "Enabled", "LineJoinMode", "Thickness", "Transparency", "StrokeSizingMode" },
    UIGradient = { "Color", "Transparency", "Rotation", "Offset", "Enabled" },
    UIFlexItem = { "FlexMode", "GrowRatio", "ShrinkRatio", "ItemLineAlignment" },
    UIGridStyleLayout = { "AbsoluteContentSize", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder" },
    LocalizationTable = { "SourceLocale", "Root", "DevelopmentLanguage" },
    Player = { "DisplayName", "UserId", "AccountAge", "Character", "CharacterAppearanceId", "Team", "TeamColor", "Neutral", "CameraMode", "CameraMaxZoomDistance", "CameraMinZoomDistance", "AutoJumpEnabled", "DevComputerMovementMode", "DevTouchMovementMode", "MembershipType", "FollowUserId", "HasVerifiedBadge" },
    Team = { "TeamColor", "AutoAssignable" },
    Camera = { "CFrame", "Focus", "CameraSubject", "CameraType", "FieldOfView", "FieldOfViewMode", "DiagonalFieldOfView", "MaxAxisFieldOfView", "ViewportSize", "HeadLocked", "HeadScale", "NearPlaneZ" },
    Lighting = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "TimeOfDay", "FogColor", "FogStart", "FogEnd", "GlobalShadows", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness", "GeographicLatitude", "Technology", "ColorShift_Top", "ColorShift_Bottom" },
    Workspace = { "CurrentCamera", "Gravity", "FallenPartsDestroyHeight", "StreamingEnabled", "StreamingMinRadius", "StreamingTargetRadius", "StreamingIntegrityMode", "GlobalWind", "DistributedGameTime", "Terrain", "AirDensity", "Retargeting" },
    Terrain = { "WaterColor", "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed", "Decoration", "MaterialColors" },
    Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId", "SunAngularSize", "MoonAngularSize", "StarCount", "CelestialBodiesShown" },
    Atmosphere = { "Color", "Decay", "Density", "Glare", "Haze", "Offset" },
    Clouds = { "Color", "Cover", "Density", "Enabled" },
    BloomEffect = { "Enabled", "Intensity", "Size", "Threshold" },
    BlurEffect = { "Enabled", "Size" },
    ColorCorrectionEffect = { "Enabled", "Brightness", "Contrast", "Saturation", "TintColor" },
    DepthOfFieldEffect = { "Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity" },
    SunRaysEffect = { "Enabled", "Intensity", "Spread" },
    Highlight = { "Adornee", "Enabled", "DepthMode", "FillColor", "FillTransparency", "OutlineColor", "OutlineTransparency" },
    ProximityPrompt = { "ActionText", "ObjectText", "Enabled", "Exclusivity", "Style", "HoldDuration", "MaxActivationDistance", "RequiresLineOfSight", "ClickablePrompt", "KeyboardKeyCode", "GamepadKeyCode", "UIOffset" },
    ClickDetector = { "MaxActivationDistance", "CursorIcon" },
    DragDetector = { "ActivatedCursorIcon", "CursorIcon", "DragStyle", "ResponseStyle", "RunLocally", "Enabled", "MaxActivationDistance", "ReferenceInstance" },
    Humanoid = { "DisplayName", "DisplayDistanceType", "HealthDisplayType", "NameDisplayDistance", "HealthDisplayDistance", "HipHeight", "AutoRotate", "PlatformStand", "Sit", "SeatPart", "MoveDirection", "Jump", "JumpHeight", "UseJumpPower", "FloorMaterial", "BreakJointsOnDeath", "RequiresNeck", "MaxSlopeAngle", "WalkToPoint", "WalkToPart" },
    Sound = { "Playing", "IsPlaying", "TimePosition", "TimeLength", "RollOffMode", "RollOffMinDistance", "RollOffMaxDistance", "EmitterSize", "SoundGroup", "PlayOnRemove", "PlaybackRegionsEnabled", "PlaybackRegion", "LoopRegion" },
    AnimationTrack = { "Animation", "IsPlaying", "TimePosition", "Length", "Looped", "Priority", "Speed", "WeightCurrent", "WeightTarget" },
    Tool = { "GripForward", "GripPos", "GripRight", "GripUp", "ManualActivationOnly" },
    Seat = { "Occupant", "Disabled" },
    VehicleSeat = { "Occupant", "Disabled", "Throttle", "Steer", "MaxSpeed", "Torque", "TurnSpeed" },
    SpawnLocation = { "Enabled", "AllowTeamChangeOnTouch", "Neutral", "TeamColor", "Duration" },
    TextChatCommand = { "PrimaryAlias", "SecondaryAlias", "Enabled", "AutocompleteVisible" },
    TextChannel = { "DisplayName", "DirectChatRequester", "ShouldDeliverCallback" },
    TextChatService = { "ChatVersion", "CreateDefaultTextChannels", "CreateDefaultCommands", "BubbleChatConfiguration", "ChatWindowConfiguration", "ChatInputBarConfiguration" },
    Model = { "PrimaryPart", "WorldPivot", "LevelOfDetail", "ModelStreamingMode", "Scale" },
    Accessory = { "AccessoryType", "AttachmentPoint" },
    Shirt = { "ShirtTemplate", "Color3" },
    Pants = { "PantsTemplate", "Color3" },
    ShirtGraphic = { "Graphic", "Color3" },
    CharacterMesh = { "BodyPart", "BaseTextureId", "OverlayTextureId", "MeshId" },
    BodyColors = { "HeadColor3", "LeftArmColor3", "LeftLegColor3", "RightArmColor3", "RightLegColor3", "TorsoColor3" },
    HumanoidDescription = {
        "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
        "Face", "Shirt", "Pants", "GraphicTShirt", "HairAccessory",
        "HatAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory",
        "FrontAccessory", "BackAccessory", "WaistAccessory", "EyebrowAccessory",
        "EyelashAccessory", "HeadColor", "TorsoColor", "LeftArmColor",
        "RightArmColor", "LeftLegColor", "RightLegColor", "HeightScale",
        "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale",
        "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation",
        "FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation"
    },
    SpecialMesh = { "MeshId", "TextureId", "MeshType", "Scale", "Offset", "VertexColor" },
    SurfaceAppearance = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap", "AlphaMode", "AlphaCutoff", "Color" },
    WrapLayer = { "ReferenceMeshId", "CageMeshId", "Order", "Puffiness", "AutoSkin" },
    WrapTarget = { "CageMeshId", "Stiffness" },
    Part = { "Shape", "TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface" },
    MeshPart = { "MeshId", "TextureID", "DoubleSided", "RenderFidelity", "CollisionFidelity" },
    PathfindingModifier = { "Label", "PassThrough" },
    PathfindingLink = { "Attachment0", "Attachment1", "Label", "IsBidirectional" },
    BodyGyro = { "CFrame", "MaxTorque", "P", "D" },
    BodyPosition = { "Position", "MaxForce", "P", "D" },
    BodyVelocity = { "Velocity", "MaxForce", "P" },
    BodyAngularVelocity = { "AngularVelocity", "MaxTorque", "P" },
    BodyForce = { "Force" },
    BodyThrust = { "Force", "Location" },
    Weld = { "Part0", "Part1", "C0", "C1", "Enabled" },
    ManualWeld = { "Part0", "Part1", "C0", "C1", "Enabled" },
    Motor6D = { "Part0", "Part1", "C0", "C1", "Transform", "CurrentAngle", "DesiredAngle", "MaxVelocity", "Enabled" },
    WeldConstraint = { "Part0", "Part1", "Enabled", "Active" },
    Attachment = { "CFrame", "WorldCFrame", "Position", "WorldPosition", "Orientation", "Axis", "SecondaryAxis", "Visible" },
    Bone = { "CFrame", "WorldCFrame", "Transform", "TransformedWorldCFrame" },
    HingeConstraint = { "Attachment0", "Attachment1", "ActuatorType", "AngularSpeed", "AngularVelocity", "MotorMaxTorque", "LimitsEnabled", "LowerAngle", "UpperAngle", "TargetAngle", "ServoMaxTorque" },
    BallSocketConstraint = { "Attachment0", "Attachment1", "LimitsEnabled", "UpperAngle", "TwistLimitsEnabled", "TwistLowerAngle", "TwistUpperAngle" },
    SpringConstraint = { "Attachment0", "Attachment1", "Stiffness", "Damping", "FreeLength", "MinLength", "MaxLength" },
    RopeConstraint = { "Attachment0", "Attachment1", "Length", "Thickness", "Visible" },
    RodConstraint = { "Attachment0", "Attachment1", "Length", "Thickness", "Visible" },
    PrismaticConstraint = { "Attachment0", "Attachment1", "ActuatorType", "LimitsEnabled", "LowerLimit", "UpperLimit", "Speed", "TargetPosition" },
    AlignPosition = { "Attachment0", "Attachment1", "Mode", "Position", "MaxForce", "MaxVelocity", "Responsiveness", "RigidityEnabled", "ReactionForceEnabled", "ApplyAtCenterOfMass" },
    AlignOrientation = { "Attachment0", "Attachment1", "Mode", "CFrame", "MaxTorque", "MaxAngularVelocity", "Responsiveness", "RigidityEnabled", "ReactionTorqueEnabled" },
    LinearVelocity = { "Attachment0", "RelativeTo", "VelocityConstraintMode", "VectorVelocity", "LineVelocity", "PlaneVelocity", "MaxForce", "ForceLimitsEnabled" },
    AngularVelocity = { "Attachment0", "RelativeTo", "AngularVelocity", "MaxTorque", "TorqueLimitsEnabled" },
    VectorForce = { "Attachment0", "RelativeTo", "Force", "ApplyAtCenterOfMass" },
    LineForce = { "Attachment0", "Attachment1", "Magnitude", "InverseSquareLaw", "MaxForce" },
    Torque = { "Attachment0", "RelativeTo", "Torque" },
    Vector3Value = {},
    StringValue = {},
    IntValue = {},
    NumberValue = {}
}

F.PHYSICS_PROPERTY_GROUPS = {
    JointInstance = { "Part0", "Part1", "C0", "C1", "Enabled", "Active" },
    Constraint = { "Attachment0", "Attachment1", "Enabled", "Active", "Visible", "Color" },
    Motor6D = { "Transform", "CurrentAngle", "DesiredAngle", "MaxVelocity" },
    WeldConstraint = { "Part0", "Part1", "Enabled", "Active" },
    NoCollisionConstraint = { "Part0", "Part1", "Enabled" },
    HingeConstraint = { "ActuatorType", "AngularVelocity", "MotorMaxTorque", "LimitsEnabled", "LowerAngle", "UpperAngle", "CurrentAngle", "AngularSpeed", "ServoMaxTorque", "TargetAngle" },
    BallSocketConstraint = { "LimitsEnabled", "UpperAngle", "TwistLimitsEnabled", "TwistLowerAngle", "TwistUpperAngle" },
    SpringConstraint = { "Stiffness", "Damping", "FreeLength", "MinLength", "MaxLength", "LimitsEnabled", "CurrentLength" },
    RopeConstraint = { "Length", "Restitution", "Thickness", "CurrentDistance" },
    RodConstraint = { "Length", "Thickness", "CurrentDistance" },
    AlignPosition = { "Mode", "Position", "Responsiveness", "MaxForce", "MaxVelocity", "RigidityEnabled" },
    AlignOrientation = { "Mode", "CFrame", "Responsiveness", "MaxTorque", "MaxAngularVelocity", "RigidityEnabled" },
    LinearVelocity = { "VelocityConstraintMode", "VectorVelocity", "LineVelocity", "PlaneVelocity", "MaxForce", "RelativeTo", "ForceLimitsEnabled" },
    AngularVelocity = { "AngularVelocity", "MaxTorque", "RelativeTo" },
    VectorForce = { "Force", "RelativeTo", "ApplyAtCenterOfMass" },
    Torque = { "Torque", "RelativeTo" },
    PlaneConstraint = { "Attachment0", "Attachment1" }
}

F.EXTENDED_BASEPART_PROPERTIES = {
    "AssemblyLinearVelocity", "AssemblyAngularVelocity", "AssemblyMass",
    "AssemblyCenterOfMass", "Massless", "CollisionGroup", "CastShadow",
    "Reflectance", "MaterialVariant", "CustomPhysicalProperties", "RootPriority",
    "PivotOffset", "LocalTransparencyModifier", "Locked", "Shape",
    "TopSurface", "BottomSurface", "Velocity", "RotVelocity"
}

function F.captureExtendedProperties(object, output, className)
    local function capture(properties)
        if not properties then return end
        for _, property in ipairs(properties) do
            F.captureOptionalVisualProperty(object, output, property)
        end
    end

    if F.GUI_CLASSES[className] then
        if F.classIsA(object, className, "GuiObject") then
            capture(F.GUI_PROPERTY_GROUPS.GuiObject)
        end
        if className == "TextButton" or className == "ImageButton" then
            capture(F.GUI_PROPERTY_GROUPS.GuiButton)
        end
        if F.TEXT_GUI_CLASSES[className] then
            capture(F.GUI_PROPERTY_GROUPS.Text)
        end
        if className == "ImageLabel" or className == "ImageButton" then
            capture(F.GUI_PROPERTY_GROUPS.Image)
        end
        if F.classIsA(object, className, "UIListLayout") or F.classIsA(object, className, "UIGridStyleLayout") then
            capture(F.EXTRA_CLASS_PROPERTIES.UIGridStyleLayout)
        end
    end

    if F.classIsA(object, className, "BasePart") then
        capture(F.EXTENDED_BASEPART_PROPERTIES)
    end
    if F.classIsA(object, className, "JointInstance") then
        capture(F.PHYSICS_PROPERTY_GROUPS.JointInstance)
    end
    if F.classIsA(object, className, "Constraint") then
        capture(F.PHYSICS_PROPERTY_GROUPS.Constraint)
    end
    capture(F.PHYSICS_PROPERTY_GROUPS[className])
    capture(F.EXTRA_CLASS_PROPERTIES[className])

    if className == "LocalizationTable" then
        local ok, entries = pcall(function() return object:GetEntries() end)
        if ok and type(entries) == "table" then
            local count = #entries
            -- All entries are preserved; avoid indexing an inaccessible table.
            local success, serialized = pcall(serializeValue, entries)
            if success then
                output.Entries = serialized
                output.EntryCount = count
            end
        end
    end
end

-- Resource catalog based exclusively on Roblox class types. No names, effect
-- folders, asset IDs or game-specific paths are hardcoded.
F.VISUAL_CLASSES = {
    ParticleEmitter = true, Beam = true, Trail = true,
    Fire = true, Smoke = true, Sparkles = true, Explosion = true,
    Attachment = true, Bone = true, WrapLayer = true, WrapTarget = true,
    PointLight = true, SpotLight = true, SurfaceLight = true,
    Highlight = true, SelectionBox = true, BoxHandleAdornment = true,
    SphereHandleAdornment = true, CylinderHandleAdornment = true,
    Decal = true, Texture = true, SurfaceAppearance = true,
    SpecialMesh = true, BlockMesh = true, CylinderMesh = true, FileMesh = true,
    Sound = true, SoundGroup = true, MaterialVariant = true, AudioPlayer = true, AudioEmitter = true, AudioListener = true, Wire = true, EqualizerSoundEffect = true,
    ReverbSoundEffect = true, EchoSoundEffect = true, ChorusSoundEffect = true,
    DistortionSoundEffect = true, FlangeSoundEffect = true,
    CompressorSoundEffect = true, PitchShiftSoundEffect = true,
    TremoloSoundEffect = true,
    Model = true, Folder = true, Tool = true, Accessory = true,
    BillboardGui = true, SurfaceGui = true, ScreenGui = true,
    ImageLabel = true, ImageButton = true, TextLabel = true, TextButton = true,
    TextBox = true, Frame = true, CanvasGroup = true, ScrollingFrame = true,
    VideoFrame = true, ViewportFrame = true, UIListLayout = true,
    UIGridLayout = true, UITableLayout = true, UIPageLayout = true,
    UIAspectRatioConstraint = true, UISizeConstraint = true,
    UITextSizeConstraint = true, UIPadding = true, UIScale = true,
    UIFlexItem = true, UIGradient = true,
    UICorner = true, UIStroke = true,
    Animation = true, Animator = true, AnimationController = true,
    AnimationConstraint = true, KeyframeSequence = true, Keyframe = true,
    KeyframeMarker = true, Pose = true, NumberPose = true,
    CurveAnimation = true, EulerRotationCurve = true,
    RotationCurve = true, Vector3Curve = true, FloatCurve = true,
    Humanoid = true,
    Motor6D = true, Motor = true, Weld = true, ManualWeld = true,
    ManualGlue = true, Glue = true, Snap = true, WeldConstraint = true,
    RigidConstraint = true, NoCollisionConstraint = true,
    BallSocketConstraint = true, HingeConstraint = true,
    PrismaticConstraint = true, CylindricalConstraint = true,
    SpringConstraint = true, RodConstraint = true, RopeConstraint = true,
    AlignPosition = true, AlignOrientation = true,
    UniversalConstraint = true, PlaneConstraint = true,
    TorsionSpringConstraint = true, AngularVelocity = true,
    LinearVelocity = true, VectorForce = true, Torque = true
}

F.VISUAL_PROPERTIES = {
    MaterialVariant = { "BaseMaterial", "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap", "StudsPerTile", "Pattern", "MaterialPattern", "OverrideStudsPerTile" },
    AudioPlayer = { "AssetId", "AutoLoad", "IsReady", "Looping", "Playing", "PlaybackSpeed", "TimePosition", "Volume" },
    AudioEmitter = { "AudioInteractionGroup", "DistanceAttenuation", "AngleAttenuation", "AcousticSimulationEnabled" },
    AudioListener = { "AudioInteractionGroup", "AcousticSimulationEnabled" },
    Wire = { "SourceInstance", "TargetInstance", "SourceName", "TargetName" },
    ParticleEmitter = {
        "Texture", "Enabled", "Rate", "Lifetime", "Speed", "Drag", "Acceleration",
        "SpreadAngle", "EmissionDirection", "LockedToPart", "VelocityInheritance",
        "Rotation", "RotSpeed", "Size", "Color", "Transparency", "ZOffset",
        "LightEmission", "LightInfluence", "Brightness", "Orientation", "Squash",
        "TimeScale", "WindAffectsDrag", "Shape", "ShapeInOut", "ShapeStyle",
        "ShapePartial", "FlipbookLayout", "FlipbookMode", "FlipbookFramerate",
        "FlipbookStartRandom"
    },
    Beam = {
        "Attachment0", "Attachment1", "Texture", "TextureLength", "TextureMode",
        "TextureSpeed", "Color", "Transparency", "Width0", "Width1", "CurveSize0",
        "CurveSize1", "Segments", "FaceCamera", "Enabled", "ZOffset",
        "LightEmission", "LightInfluence", "Brightness"
    },
    Trail = {
        "Attachment0", "Attachment1", "Texture", "TextureLength", "TextureMode",
        "Color", "Transparency", "WidthScale", "Lifetime", "MinLength", "MaxLength",
        "FaceCamera", "Enabled", "LightEmission", "LightInfluence", "Brightness"
    },
    Attachment = { "CFrame", "Position", "Orientation", "Axis", "SecondaryAxis", "Visible", "WorldCFrame" },
    Bone = { "CFrame", "Position", "Orientation", "Transform", "TransformedWorldCFrame" },
    Fire = { "Color", "SecondaryColor", "Heat", "Size", "Enabled", "TimeScale" },
    Smoke = { "Color", "Opacity", "RiseVelocity", "Size", "Enabled", "TimeScale" },
    Sparkles = { "SparkleColor", "Enabled", "TimeScale" },
    Explosion = { "Position", "BlastRadius", "BlastPressure", "DestroyJointRadiusPercent", "ExplosionType", "Visible" },
    PointLight = { "Color", "Brightness", "Range", "Shadows", "Enabled" },
    SpotLight = { "Color", "Brightness", "Range", "Shadows", "Enabled", "Angle", "Face" },
    SurfaceLight = { "Color", "Brightness", "Range", "Shadows", "Enabled", "Angle", "Face" },
    Highlight = { "Adornee", "Enabled", "FillColor", "FillTransparency", "OutlineColor", "OutlineTransparency", "DepthMode" },
    SelectionBox = { "Adornee", "Color3", "Transparency", "SurfaceColor3", "SurfaceTransparency", "LineThickness", "Visible" },
    Decal = { "Texture", "Color3", "Transparency", "Face", "ZIndex" },
    Texture = { "Texture", "Color3", "Transparency", "Face", "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV" },
    SurfaceAppearance = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap", "AlphaMode", "AlphaCutoff", "Color" },
    SpecialMesh = { "MeshId", "TextureId", "MeshType", "Scale", "Offset", "VertexColor" },
    BlockMesh = { "Scale", "Offset", "VertexColor" },
    CylinderMesh = { "Scale", "Offset", "VertexColor" },
    Sound = {
        "SoundId", "Volume", "PlaybackSpeed", "Looped", "PlayOnRemove", "TimePosition",
        "RollOffMaxDistance", "RollOffMinDistance", "RollOffMode", "EmitterSize",
        "SoundGroup", "PlaybackRegionsEnabled", "PlaybackRegion", "LoopRegion"
    },
    SoundGroup = { "Volume" },
    EqualizerSoundEffect = { "Enabled", "LowGain", "MidGain", "HighGain", "Priority" },
    ReverbSoundEffect = { "Enabled", "DecayTime", "Density", "Diffusion", "DryLevel", "WetLevel", "Priority" },
    EchoSoundEffect = { "Enabled", "Delay", "DryLevel", "Feedback", "WetLevel", "Priority" },
    ChorusSoundEffect = { "Enabled", "Depth", "Mix", "Rate", "Priority" },
    DistortionSoundEffect = { "Enabled", "Level", "Priority" },
    FlangeSoundEffect = { "Enabled", "Depth", "Mix", "Rate", "Priority" },
    CompressorSoundEffect = { "Enabled", "Attack", "GainMakeup", "Ratio", "Release", "SideChain", "Threshold", "Priority" },
    PitchShiftSoundEffect = { "Enabled", "Octave", "Priority" },
    TremoloSoundEffect = { "Enabled", "Depth", "Duty", "Frequency", "Priority" },
    Animation = { "AnimationId" },
    BillboardGui = { "Adornee", "AlwaysOnTop", "Brightness", "ClipsDescendants", "Enabled", "LightInfluence", "MaxDistance", "Size", "SizeOffset", "StudsOffset", "StudsOffsetWorldSpace" },
    SurfaceGui = { "Adornee", "AlwaysOnTop", "Brightness", "CanvasSize", "Enabled", "Face", "LightInfluence", "PixelsPerStuds", "SizingMode", "ZOffset" },
    ScreenGui = { "Enabled", "DisplayOrder", "IgnoreGuiInset", "ResetOnSpawn", "ZIndexBehavior" },
    ImageLabel = { "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize", "ScaleType", "SliceCenter", "SliceScale", "ResampleMode", "Size", "Position", "Rotation", "BackgroundTransparency" },
    ImageButton = { "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize", "ScaleType", "SliceCenter", "SliceScale", "ResampleMode", "Size", "Position", "Rotation", "BackgroundTransparency" },
    UIGradient = { "Color", "Transparency", "Rotation", "Offset", "Enabled" },
    UICorner = { "CornerRadius" },
    UIStroke = { "Color", "Transparency", "Thickness", "ApplyStrokeMode", "LineJoinMode", "Enabled" },
    Model = { "PrimaryPart", "WorldPivot", "LevelOfDetail", "ModelStreamingMode" },
    Tool = { "Grip", "TextureId", "Enabled" },
    Humanoid = { "RigType", "HipHeight", "Health", "MaxHealth", "AutoRotate", "BreakJointsOnDeath", "RequiresNeck" },
    Motor6D = { "Part0", "Part1", "C0", "C1", "Enabled", "Transform", "CurrentAngle", "DesiredAngle", "MaxVelocity" },
    Motor = { "Part0", "Part1", "C0", "C1", "Enabled", "CurrentAngle", "DesiredAngle", "MaxVelocity" },
    Weld = { "Part0", "Part1", "C0", "C1", "Enabled" },
    ManualWeld = { "Part0", "Part1", "C0", "C1", "Enabled" },
    ManualGlue = { "Part0", "Part1", "C0", "C1", "Enabled" },
    Glue = { "Part0", "Part1", "C0", "C1", "Enabled" },
    Snap = { "Part0", "Part1", "C0", "C1", "Enabled" },
    WeldConstraint = { "Part0", "Part1", "Enabled", "Active" },
    RigidConstraint = { "Attachment0", "Attachment1", "Enabled", "Active" },
    NoCollisionConstraint = { "Part0", "Part1", "Enabled" },
    AnimationConstraint = { "Attachment0", "Attachment1", "Enabled", "Transform", "IsKinematic", "C0", "C1", "Part0", "Part1" },
    BallSocketConstraint = { "Attachment0", "Attachment1", "Enabled", "LimitsEnabled", "UpperAngle", "TwistLimitsEnabled", "TwistLowerAngle", "TwistUpperAngle", "MaxFrictionTorque", "Restitution" },
    HingeConstraint = { "Attachment0", "Attachment1", "Enabled", "ActuatorType", "AngularSpeed", "AngularVelocity", "TargetAngle", "MotorMaxTorque", "ServoMaxTorque", "LimitsEnabled", "LowerAngle", "UpperAngle" },
    PrismaticConstraint = { "Attachment0", "Attachment1", "Enabled", "ActuatorType", "Speed", "Velocity", "TargetPosition", "LowerLimit", "UpperLimit", "LimitsEnabled", "MotorMaxForce", "ServoMaxForce" },
    CylindricalConstraint = { "Attachment0", "Attachment1", "Enabled", "ActuatorType", "AngularActuatorType", "AngularVelocity", "AngularSpeed", "TargetAngle", "TargetPosition", "LimitsEnabled" },
    SpringConstraint = { "Attachment0", "Attachment1", "Enabled", "FreeLength", "Stiffness", "Damping", "MaxLength", "MinLength", "LimitsEnabled" },
    RodConstraint = { "Attachment0", "Attachment1", "Enabled", "Length", "Thickness", "LimitsEnabled", "MinLength", "MaxLength" },
    RopeConstraint = { "Attachment0", "Attachment1", "Enabled", "Length", "Thickness", "Restitution", "WinchEnabled", "WinchTarget" },
    AlignPosition = { "Attachment0", "Attachment1", "Enabled", "Mode", "Position", "MaxForce", "Responsiveness", "RigidityEnabled", "ApplyAtCenterOfMass", "ReactionForceEnabled" },
    AlignOrientation = { "Attachment0", "Attachment1", "Enabled", "Mode", "CFrame", "MaxTorque", "Responsiveness", "RigidityEnabled", "ReactionTorqueEnabled" },
    UniversalConstraint = { "Attachment0", "Attachment1", "Enabled", "LimitsEnabled", "MaxAngle" },
    PlaneConstraint = { "Attachment0", "Attachment1", "Enabled" },
    TorsionSpringConstraint = { "Attachment0", "Attachment1", "Enabled", "Stiffness", "Damping", "MaxAngle", "LimitsEnabled" },
    AngularVelocity = { "Attachment0", "Attachment1", "Enabled", "AngularVelocity", "MaxTorque", "RelativeTo", "ReactionTorqueEnabled" },
    LinearVelocity = { "Attachment0", "Attachment1", "Enabled", "VectorVelocity", "LineVelocity", "PlaneVelocity", "RelativeTo", "MaxForce", "ForceLimitsEnabled" },
    VectorForce = { "Attachment0", "Enabled", "Force", "RelativeTo", "ApplyAtCenterOfMass" },
    Torque = { "Attachment0", "Enabled", "Torque", "RelativeTo" },
    KeyframeSequence = { "Priority", "Loop" },
    Keyframe = { "Time" },
    KeyframeMarker = { "Value" },
    Pose = { "CFrame", "Weight", "EasingStyle", "EasingDirection", "MaskWeight" },
    NumberPose = { "Value", "Weight", "EasingStyle", "EasingDirection" },
    CurveAnimation = { "Priority", "Loop" },
    FloatCurve = { "Length" },
    Vector3Curve = { "Length" },
    RotationCurve = { "Length" },
    EulerRotationCurve = { "Length" }
}

F.VISUAL_PART_PROPERTIES = {
    "CFrame", "Size", "Position", "Color", "Material", "MaterialVariant",
    "Transparency", "Reflectance", "CastShadow", "Anchored", "CanCollide",
    "CanQuery", "CanTouch", "CollisionGroup", "Massless", "Shape", "PivotOffset"
}

F.VISUAL_PART_CLASSES = {
    Part = true, MeshPart = true, UnionOperation = true, WedgePart = true,
    CornerWedgePart = true, TrussPart = true, Seat = true, VehicleSeat = true,
    SpawnLocation = true, NegateOperation = true, IntersectOperation = true
}

F.VISUAL_MESH_PROPERTIES = {
    "MeshId", "TextureID", "DoubleSided", "RenderFidelity", "CollisionFidelity"
}

F.VISUAL_ESSENTIAL_CLASSES = {
    Motor6D = true, Motor = true, Weld = true, ManualWeld = true,
    WeldConstraint = true, AnimationConstraint = true, RigidConstraint = true,
    Animation = true, Animator = true, AnimationController = true,
    ParticleEmitter = true, Beam = true, Trail = true, Sound = true,
    Attachment = true, MeshPart = true, SpecialMesh = true,
    KeyframeSequence = true, Keyframe = true, Pose = true
}

function F.isVisualAsset(object, className)
    className = className or F.safeClassName(object)
    return F.VISUAL_CLASSES[className] == true or F.VISUAL_PART_CLASSES[className] == true
end

function F.captureOptionalVisualProperty(object, output, property)
    if output[property] ~= nil then return end
    local ok, value = pcall(function() return object[property] end)
    if not ok or value == nil then return end
    local serializedOk, serialized = pcall(serializeValue, value, {
        seen = {}, depth = 0, noAssignInstanceId = true
    })
    if serializedOk then
        output[property] = serialized
    else
        visualCaptureErrors = visualCaptureErrors + 1
    end
end

F.VISUAL_REFERENCE_PROPERTIES = {
    Motor6D = { "Part0", "Part1" }, Motor = { "Part0", "Part1" },
    Weld = { "Part0", "Part1" }, ManualWeld = { "Part0", "Part1" },
    ManualGlue = { "Part0", "Part1" }, Glue = { "Part0", "Part1" },
    Snap = { "Part0", "Part1" }, WeldConstraint = { "Part0", "Part1" },
    NoCollisionConstraint = { "Part0", "Part1" },
    RigidConstraint = { "Attachment0", "Attachment1" },
    AnimationConstraint = { "Attachment0", "Attachment1" },
    BallSocketConstraint = { "Attachment0", "Attachment1" },
    HingeConstraint = { "Attachment0", "Attachment1" },
    PrismaticConstraint = { "Attachment0", "Attachment1" },
    CylindricalConstraint = { "Attachment0", "Attachment1" },
    SpringConstraint = { "Attachment0", "Attachment1" },
    RodConstraint = { "Attachment0", "Attachment1" },
    RopeConstraint = { "Attachment0", "Attachment1" },
    AlignPosition = { "Attachment0", "Attachment1" },
    AlignOrientation = { "Attachment0", "Attachment1" },
    UniversalConstraint = { "Attachment0", "Attachment1" },
    PlaneConstraint = { "Attachment0", "Attachment1" },
    TorsionSpringConstraint = { "Attachment0", "Attachment1" },
    AngularVelocity = { "Attachment0" }, LinearVelocity = { "Attachment0" },
    VectorForce = { "Attachment0" }, Torque = { "Attachment0" },
    Beam = { "Attachment0", "Attachment1" },
    Trail = { "Attachment0", "Attachment1" }
}

function F.getVisualRuntimeId(object)
    if not object then return nil end
    local id = visualRuntimeIdentityIds[object]
    if not id then
        nextVisualRuntimeIdentity = nextVisualRuntimeIdentity + 1
        id = nextVisualRuntimeIdentity
        visualRuntimeIdentityIds[object] = id
    end
    return id
end

function F.addVisualProperties(object, output, className)
    if not CONFIG.VisualCapture or not F.isVisualAsset(object, className) then return end
    if F.VISUAL_PART_CLASSES[className] then
        for _, property in ipairs(F.VISUAL_PART_PROPERTIES) do
            F.captureOptionalVisualProperty(object, output, property)
        end
    end
    if className == "MeshPart" then
        for _, property in ipairs(F.VISUAL_MESH_PROPERTIES) do
            F.captureOptionalVisualProperty(object, output, property)
        end
    end
    local visualProperties = F.VISUAL_PROPERTIES[className]
    if visualProperties then
        for _, property in ipairs(visualProperties) do
            F.captureOptionalVisualProperty(object, output, property)
        end
    end
    if className == "Animator" then
        output.PlayingAnimationTracks = F.getAnimatorPlaybackTracks(object)
    end
    local links = F.VISUAL_REFERENCE_PROPERTIES[className]
    if links then
        for _, property in ipairs(links) do
            local readOk, target = pcall(function() return object[property] end)
            if readOk and target and typeof(target) == "Instance" then
                local reference = output[property]
                if type(reference) == "table" and reference.__type == "Instance" then
                    if not reference.Id and not snapshotFinalized then
                        reference.Id = F.assignInstanceId(target)
                    end
                    reference.VisualRuntimeId = F.getVisualRuntimeId(target)
                end
            end
        end
        local missing = nil
        for _, property in ipairs(links) do
            if output[property] == nil then
                missing = missing or {}
                missing[#missing + 1] = property
            end
        end
        if missing then
            output._MissingVisualLinks = missing
        end
    end
end

function F.getVisualAncestors(object)
    local result = {}
    local cursor, depth = object.Parent, 0
    while cursor and depth < 64 do
        table.insert(result, 1, {
            Name = F.safeName(cursor),
            ClassName = F.safeClassName(cursor),
            Path = F.safeFullName(cursor)
        })
        cursor = cursor.Parent
        depth = depth + 1
    end
    return result
end

function F.getAnimatorPlaybackTracks(animator)
    local ok, tracks = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if not ok or type(tracks) ~= "table" then
        return nil
    end
    local result = {}
    for _, track in ipairs(tracks) do
        local record = {}
        local properties = {
            "Name", "IsPlaying", "Looped", "Priority", "Speed", "Length",
            "TimePosition", "WeightCurrent", "WeightTarget"
        }
        for _, property in ipairs(properties) do
            F.captureOptionalVisualProperty(track, record, property)
        end
        local animationOk, animation = pcall(function() return track.Animation end)
        if animationOk and animation then
            record.Animation = F.makeInstanceReference(animation, false)
            local idOk, animationId = pcall(function() return animation.AnimationId end)
            if idOk and animationId then
                record.AnimationId = F.sanitizeString(animationId)
            end
        end
        result[#result + 1] = record
    end
    table.sort(result, function(a, b)
        local an = tostring(a.AnimationId or a.Name or "")
        local bn = tostring(b.AnimationId or b.Name or "")
        if an ~= bn then return an < bn end
        return tostring(a.Name or "") < tostring(b.Name or "")
    end)
    return result
end

function F.registerVisualAnimator(animator)
    if not CONFIG.VisualCapture or visualAnimatorInstances[animator] then return end
    if visualTrackedAnimatorCount >= math.max(0, CONFIG.VisualMaxTrackedAnimators) then return end
    visualTrackedAnimatorCount = visualTrackedAnimatorCount + 1
    visualAnimatorInstances[animator] = true
end

function F.captureAnimatorPlayback(animator, pass)
    if not CONFIG.VisualCapture or not visualAnimatorInstances[animator] then return end
    local tracks = F.getAnimatorPlaybackTracks(animator)
    if not tracks then return end
    local current = os.clock() - runtimeStartedAt
    local signatureParts = {}
    for _, track in ipairs(tracks) do
        signatureParts[#signatureParts + 1] = table.concat({
            tostring(track.AnimationId or track.Name or ""),
            tostring(track.Priority and track.Priority.value or ""),
            tostring(track.Speed or ""), tostring(track.Looped or false)
        }, "|")
    end
    local signature = table.concat(signatureParts, ";")
    local state = visualAnimatorStates[animator]
    local keepalive = math.max(0.25, tonumber(CONFIG.VisualAnimatorKeepaliveInterval) or 3)
    if state and state.Signature == signature and current - state.LastSaved < keepalive then
        return
    end
    visualAnimatorStates[animator] = { Signature = signature, LastSaved = current }
    if #visualAnimationPlaybackRecords >= math.max(0, CONFIG.VisualMaxAnimationPlaybackEntries) then
        visualAnimationPlaybackOmitted = visualAnimationPlaybackOmitted + 1
        return
    end
    visualAnimationPlaybackRecords[#visualAnimationPlaybackRecords + 1] = {
        TimeSeconds = current,
        CapturePass = pass,
        Animator = F.makeInstanceReference(animator, false),
        Tracks = tracks
    }
end

function F.makeVisualRecord(object, id, parentId, name, className, path, attributes, tags, properties, withAncestors)
    F.V38.trackAssets(object, properties, withAncestors and "RuntimeVisual" or "SnapshotVisual")
    local parent = object.Parent
    local compact = CONFIG.CompactSecondaryIndexes and SELECTION.Structure and not withAncestors
    return {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        ParentId = parentId,
        ParentPath = (not compact and parent) and F.safeFullName(parent) or nil,
        VisualRuntimeId = withAncestors and F.getVisualRuntimeId(object) or nil,
        ParentVisualRuntimeId = withAncestors and F.getVisualRuntimeId(parent) or nil,
        Ancestors = withAncestors and F.getVisualAncestors(object) or nil,
        Attributes = not compact and F.optionalMap(attributes) or nil,
        Tags = not compact and tags or nil,
        Properties = not compact and F.optionalMap(properties) or nil
    }
end

function F.captureDynamicVisual(object, pass)
    if not runtimeTraceActive or not CONFIG.VisualCapture then return end
    local className = F.safeClassName(object)
    if not F.isVisualAsset(object, className) then return end

    local existing = visualDynamicByInstance[object]
    if not existing and #visualDynamicRecords >= math.max(0, CONFIG.VisualMaxDynamicEntries) then
        if not F.VISUAL_ESSENTIAL_CLASSES[className]
            or visualEssentialOverflowSaved >= math.max(0, CONFIG.VisualEssentialOverflowEntries)
        then
            visualDynamicOmitted = visualDynamicOmitted + 1
            return
        end
        visualEssentialOverflowSaved = visualEssentialOverflowSaved + 1
    end

    if className == "Animator" then
        F.registerVisualAnimator(object)
        F.captureAnimatorPlayback(object, pass)
    end
    local name = F.safeName(object)
    local path = F.safeFullName(object)
    local properties = F.getUsefulProperties(object, className)
    local attributes = F.getAttributes(object)
    local tags = F.getTags(object)
    local record = F.makeVisualRecord(
        object, instanceIds[object],
        object.Parent and instanceIds[object.Parent] or nil,
        name, className, path, attributes, tags, properties, true
    )
    record.DynamicId = existing and existing.DynamicId or (#visualDynamicRecords + 1)
    record.FirstObservedSeconds = existing and existing.FirstObservedSeconds or (os.clock() - runtimeStartedAt)
    record.LastObservedSeconds = os.clock() - runtimeStartedAt
    record.CapturePass = pass
    record.Observations = (existing and existing.Observations or 0) + 1
    if existing then
        for key, value in pairs(record) do existing[key] = value end
    else
        visualDynamicByInstance[object] = record
        visualDynamicRecords[#visualDynamicRecords + 1] = record
    end
end

function F.buildVisualDocument(records, dynamic)
    return {
        DumpId = currentDumpId,
        Scope = dynamic and "ObservedWhileRunning" or "Snapshot",
        CaptureAllNames = true,
        ClassBasedSelection = true,
        IndexedPropertiesSource = not dynamic and SELECTION.Structure and CONFIG.CompactSecondaryIndexes and "structure.json" or nil,
        Description = "Visual instances visible to this client. No access to server-only/unreplicated assets.",
        Total = #records,
        OmittedByCap = dynamic and visualDynamicOmitted or visualSnapshotOmitted,
        SerializationErrors = visualCaptureErrors,
        EssentialOverflowSaved = dynamic and visualEssentialOverflowSaved or nil,
        AnimationPlaybackOmitted = dynamic and visualAnimationPlaybackOmitted or nil,
        AnimationPlayback = dynamic and visualAnimationPlaybackRecords or nil,
        VisualRuntimeIdScope = dynamic and "SnapshotAndRuntimeLocal" or nil,
        Assets = records
    }
end

local REMOTE_BUCKETS = {
    RemoteEvent = "RemoteEvents",
    UnreliableRemoteEvent = "UnreliableRemoteEvents",
    RemoteFunction = "RemoteFunctions",
    BindableEvent = "BindableEvents",
    BindableFunction = "BindableFunctions"
}

local SCRIPT_BUCKETS = {
    LocalScript = "LocalScripts",
    ModuleScript = "ModuleScripts",
    Script = "Scripts",
    CoreScript = "CoreScripts"
}

function F.captureProperty(object, output, property)
    local value, readable, readError = F.safeGet(object, property)

    if not readable then
        F.recordError("ReadProperty", object, readError, property)
        return
    end

    if value == nil then
        return
    end

    local ok, serialized = pcall(serializeValue, value)
    if ok then
        output[property] = serialized
    else
        F.recordError("SerializeProperty", object, serialized, property)
    end
end

function F.getUsefulProperties(object, className)
    local data = {}
    className = className or F.safeClassName(object)

    for _, group in ipairs(F.PROPERTY_GROUPS) do
        if F.classIsA(object, className, group.Class) then
            for _, property in ipairs(group.Properties) do
                F.captureProperty(object, data, property)
            end
        end
    end

    F.captureExtendedProperties(object, data, className)
    F.addVisualProperties(object, data, className)

    if REMOTE_BUCKETS[className] then
        data.RemoteType = className
    end

    if SCRIPT_BUCKETS[className] then
        data.ScriptType = className
    end

    return data
end

function F.makeGuiRecord(object, id, parentId, name, className, path, properties)
    return {
        Id = id,
        ParentId = parentId,
        Name = name,
        ClassName = className,
        Path = path,
        Properties = (not CONFIG.CompactSecondaryIndexes or not SELECTION.Structure) and F.optionalMap(properties) or nil
    }
end

function F.captureSnapshotGui(object, id, parentId, name, className, path, properties)
    if not CONFIG.GuiCapture or not F.GUI_CLASSES[className] then return end
    if #guiCapture.Snapshot >= CONFIG.GuiMaxSnapshotEntries then
        guiCapture.SnapshotOmitted = guiCapture.SnapshotOmitted + 1
        return
    end
    guiCapture.Snapshot[#guiCapture.Snapshot + 1] = F.makeGuiRecord(
        object, id, parentId, name, className, path, properties
    )
    guiCapture.SnapshotSaved = guiCapture.SnapshotSaved + 1
end

local LIVE_GUI_FIELDS = {
    Text = true, ContentText = true, PlaceholderText = true,
    Visible = true, Enabled = true, Image = true, Video = true,
    DisplayName = true, Adornee = true
}

function F.appendGuiRuntimeRecord(object, eventName, property)
    if not runtimeTraceActive or not CONFIG.RuntimeTraceGui then return end
    local record = {
        Time = os.clock() - runtimeStartedAt,
        Event = eventName,
        Id = instanceIds[object],
        Name = F.safeName(object),
        ClassName = F.safeClassName(object),
        Path = F.safeFullName(object)
    }
    if property then
        local value, readable = F.safeGet(object, property)
        if not readable then return end
        record.Property = property
        record.IsNil = value == nil
        if value ~= nil then record.Value = F.serializeRuntimeValue(value) end
    else
        record.Properties = F.getUsefulProperties(object, record.ClassName)
    end
    guiCapture.Records[#guiCapture.Records + 1] = record
    if journalRecord then journalRecord("Runtime", { Kind = "Gui", Data = record }) end
    F.maybeFlushRuntimeTrace()
end

local runtimeCoreGui = nil
if CONFIG.SkipEngineInternals then
    local ok, service = pcall(game.GetService, game, "CoreGui")
    if ok then runtimeCoreGui = service end
end

function F.watchRuntimeGui(object, eventName)
    if selectionGui and (object == selectionGui or F.safeIsDescendantOf(object, selectionGui)) then return end
    if not CONFIG.RuntimeTraceGui or not runtimeTraceActive then return end
    if runtimeCoreGui and F.safeIsDescendantOf(object, runtimeCoreGui) then return end
    local className = F.safeClassName(object)
    if not F.GUI_CLASSES[className] then return end

    local tracked = guiCapture.Observed[object]
    if not tracked then
        if guiCapture.ObservedCount >= CONFIG.RuntimeMaxObservedGui then
            guiCapture.OmittedObservers = guiCapture.OmittedObservers + 1
            if not guiCapture.ObserverCapWarned then
                guiCapture.ObserverCapWarned = true
                F.recordWarning("RuntimeGuiObserverCap", object, "GUI observer cap reached")
            end
            return
        end
        guiCapture.Observed[object] = true
        guiCapture.ObservedCount = guiCapture.ObservedCount + 1
        local ok, connection = pcall(function()
            return object.Changed:Connect(function(property)
                if runtimeTraceActive and LIVE_GUI_FIELDS[property] then
                    F.appendGuiRuntimeRecord(object, "Changed", property)
                end
            end)
        end)
        if ok and connection then
            table.insert(runtimeConnections, connection)
        else
            guiCapture.Observed[object] = nil
            guiCapture.ObservedCount = guiCapture.ObservedCount - 1
        end
    end
    if eventName then
        F.appendGuiRuntimeRecord(object, eventName)
    end
end

function F.registerAttributes(id, name, className, path, attributes)
    if next(attributes) == nil then
        return
    end

    table.insert(attributeIndex, {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        Attributes = attributes
    })
end

function F.getRemoteClientMetadata(object, className)
    local metadata = {}

    if (className == "RemoteEvent" or className == "UnreliableRemoteEvent") and capabilities.getconnections then
        local signalOk, signal = pcall(function()
            return object.OnClientEvent
        end)

        if signalOk and signal then
            local connectionsOk, connections = pcall(getconnections, signal)
            if connectionsOk and type(connections) == "table" then
                metadata.ClientConnectionCount = #connections
            end
        end
    elseif className == "RemoteFunction" then
        local callbackOk, callback = pcall(function()
            return object.OnClientInvoke
        end)

        if callbackOk then
            metadata.HasOnClientInvoke = type(callback) == "function"

            if type(callback) == "function" and debug and type(debug.info) == "function" then
                local infoOk, source, line, name = pcall(debug.info, callback, "sln")
                if infoOk then
                    metadata.OnClientInvokeDebug = {
                        Source = source and F.sanitizeString(source) or nil,
                        Line = line,
                        Name = name and F.sanitizeString(name) or nil
                    }
                end
            end
        end
    end

    return F.optionalMap(metadata)
end

function F.registerRemote(object, id, name, className, parentId, path, attributes, tags)
    local bucket = REMOTE_BUCKETS[className]
    if not bucket then
        return
    end

    local record = {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        ParentId = parentId,
        Attributes = F.optionalMap(attributes),
        Tags = tags
    }

    local clientMetadata = F.getRemoteClientMetadata(object, className)
    if clientMetadata then
        record.Client = clientMetadata
    end

    table.insert(remoteIndex[bucket], record)
end

function F.moduleDecompileIgnoreReason(path)
    local cleanPath = tostring(path or "")
    for _, ignoredRoot in ipairs(CONFIG.ModuleDecompilerIgnore or {}) do
        local rootName = tostring(ignoredRoot)
        if cleanPath == rootName or cleanPath:sub(1, #rootName + 1) == rootName .. "." then
            return "ignored by DecompileIgnore: " .. rootName
        end
    end
    return nil
end

function F.registerScript(object, id, name, className, parentId, path, properties)
    local bucket = SCRIPT_BUCKETS[className]
    if not bucket then
        return
    end

    local record = {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        ParentId = parentId
    }

    if properties.Disabled ~= nil then
        record.Disabled = properties.Disabled
    end

    table.insert(scriptIndex[bucket], record)

    if className == "LocalScript" and CONFIG.DecompileLocalScripts then
        table.insert(clientScriptQueue, {
            Object = object,
            Record = record
        })
        clientDecompileStats.Queued = clientDecompileStats.Queued + 1
    end

    if className == "ModuleScript" and CONFIG.DecompileModuleScripts then
        local ignoreReason = F.moduleDecompileIgnoreReason(path)
        if ignoreReason then
            record.Decompile = {
                Status = "Skipped",
                Reason = ignoreReason
            }
            moduleDecompileStats.Skipped = moduleDecompileStats.Skipped + 1
            moduleDecompileStats.Ignored = moduleDecompileStats.Ignored + 1
        else
            table.insert(moduleScriptQueue, {
                Object = object,
                Record = record
            })
            moduleDecompileStats.Queued = moduleDecompileStats.Queued + 1
        end
    end
end

function F.registerValue(object, id, name, className, parentId, path, attributes, tags)
    if not F.safeIsA(object, "ValueBase") then
        return
    end

    local rawValue, readable, readError = F.safeGet(object, "Value")
    local record = {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        ParentId = parentId,
        Attributes = F.optionalMap(attributes),
        Tags = tags,
        Readable = readable
    }

    if readable then
        if rawValue == nil then
            record.IsNil = true
        else
            record.Value = serializeValue(rawValue)
        end
    else
        record.ReadError = F.sanitizeString(readError)
    end

    table.insert(valueRecords, record)
end

local backpack = LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack") or nil
local character = LocalPlayer and LocalPlayer.Character or nil
local starterGear = LocalPlayer and LocalPlayer:FindFirstChild("StarterGear") or nil

local playerDescriptors = {}
local playerReferenceKeys = {}

function F.preparePlayerDescriptors()
    playerDescriptors = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local descriptor = {
            Player = player,
            Name = player.Name,
            DisplayName = player.DisplayName,
            UserId = player.UserId,
            Character = player.Character,
            Backpack = player:FindFirstChildOfClass("Backpack"),
            PlayerGui = player:FindFirstChildOfClass("PlayerGui"),
            StarterGear = player:FindFirstChild("StarterGear")
        }

        table.insert(playerDescriptors, descriptor)
    end

    table.sort(playerDescriptors, function(a, b)
        if a.UserId ~= b.UserId then
            return a.UserId < b.UserId
        end

        return a.Name < b.Name
    end)
end

function F.addPlayerReference(descriptor, objectId, field, matchKind, value)
    local key = table.concat({
        tostring(descriptor.UserId),
        tostring(objectId),
        tostring(field),
        tostring(matchKind)
    }, "|")

    if playerReferenceKeys[key] then
        return
    end

    playerReferenceKeys[key] = true
    table.insert(playerReferences, {
        PlayerName = F.sanitizeString(descriptor.Name),
        DisplayName = F.sanitizeString(descriptor.DisplayName),
        UserId = descriptor.UserId,
        ObjectId = objectId,
        Field = F.sanitizeString(field),
        MatchKind = F.sanitizeString(matchKind),
        Value = serializeValue(value)
    })
end

function F.scanValueForPlayerReferences(objectId, field, value)
    local valueType = typeof(value)

    for _, descriptor in ipairs(playerDescriptors) do
        if valueType == "string" then
            local lowered = string.lower(value)
            local username = string.lower(descriptor.Name)
            local displayName = string.lower(descriptor.DisplayName)
            local userIdString = tostring(descriptor.UserId)
            if value == descriptor.Name then
                F.addPlayerReference(descriptor, objectId, field, "Username", value)
            elseif #username > 0 and string.find(lowered, username, 1, true) then
                F.addPlayerReference(descriptor, objectId, field, "UsernameContained", value)
            end
            if descriptor.DisplayName ~= descriptor.Name and #displayName >= 3 then
                if value == descriptor.DisplayName then
                    F.addPlayerReference(descriptor, objectId, field, "DisplayName", value)
                elseif string.find(lowered, displayName, 1, true) then
                    F.addPlayerReference(descriptor, objectId, field, "DisplayNameContained", value)
                end
            end
            if value == userIdString then
                F.addPlayerReference(descriptor, objectId, field, "UserIdString", value)
            elseif #userIdString >= 6 and string.find(value, userIdString, 1, true)
                and not string.find(string.lower(field), "image", 1, true)
                and not string.find(string.lower(field), "texture", 1, true)
            then
                F.addPlayerReference(descriptor, objectId, field, "UserIdContained", value)
            end
        elseif valueType == "number" and value == descriptor.UserId then
            F.addPlayerReference(descriptor, objectId, field, "UserIdNumber", value)
        elseif valueType == "Instance" then
            if value == descriptor.Player then
                F.addPlayerReference(descriptor, objectId, field, "PlayerInstance", value)
            elseif descriptor.Character and value == descriptor.Character then
                F.addPlayerReference(descriptor, objectId, field, "CharacterInstance", value)
            elseif descriptor.Backpack and value == descriptor.Backpack then
                F.addPlayerReference(descriptor, objectId, field, "BackpackInstance", value)
            elseif descriptor.PlayerGui and value == descriptor.PlayerGui then
                F.addPlayerReference(descriptor, objectId, field, "PlayerGuiInstance", value)
            end
        end
    end
end

function F.scanAttributesForPlayerReferences(objectId, attributes)
    for name, value in pairs(attributes) do
        F.scanValueForPlayerReferences(objectId, "Attribute:" .. F.sanitizeString(name), value)
    end
end

function F.findTopServiceName(object)
    local current = object
    local previous = object

    while current do
        previous = current
        local parent, readable = F.safeGet(current, "Parent")
        if not readable or parent == nil then
            break
        end

        if parent == game then
            return F.safeName(current)
        end

        current = parent
    end

    return F.safeName(previous)
end

function F.describeToolLocation(object, source)
    local result = {
        Location = source or F.findTopServiceName(object)
    }

    for _, descriptor in ipairs(playerDescriptors) do
        local ownerLocation

        if descriptor.Backpack and F.safeIsDescendantOf(object, descriptor.Backpack) then
            ownerLocation = "PlayerBackpack"
        elseif descriptor.Character and F.safeIsDescendantOf(object, descriptor.Character) then
            ownerLocation = "PlayerCharacter"
        elseif descriptor.StarterGear and F.safeIsDescendantOf(object, descriptor.StarterGear) then
            ownerLocation = "PlayerStarterGear"
        end

        if ownerLocation then
            result.Location = ownerLocation
            result.OwnerName = F.sanitizeString(descriptor.Name)
            result.OwnerUserId = descriptor.UserId
            result.IsLocalPlayer = descriptor.Player == LocalPlayer
            break
        end
    end

    return result
end

function F.resolveInventorySource(object, inheritedSource)
    if object == backpack then
        return "Backpack"
    end

    if object == character then
        return "Character"
    end

    if object == starterGear then
        return "StarterGear"
    end

    return inheritedSource
end

function F.createToolRecord(object, id, name, className, path, source, attributes, properties)
    local location = F.describeToolLocation(object, source)
    local record = {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        Source = source,
        Location = location.Location,
        OwnerName = location.OwnerName,
        OwnerUserId = location.OwnerUserId,
        IsLocalPlayer = location.IsLocalPlayer,
        Attributes = F.optionalMap(attributes),
        Properties = F.optionalMap(properties),
        HandleId = nil,
        AnimationIds = {},
        SoundIds = {},
        ValueIds = {},
        DescendantIds = {},
        DescendantCount = 0
    }

    table.insert(toolRecords, record)

    if source and inventoryToolIds[source] then
        table.insert(inventoryToolIds[source], id)
    end

    return {
        Instance = object,
        Record = record
    }
end

function F.registerToolDescendant(toolState, object, id, className, name)
    if not toolState then
        return
    end

    local record = toolState.Record
    table.insert(record.DescendantIds, id)
    record.DescendantCount = record.DescendantCount + 1

    if className == "Animation" then
        table.insert(record.AnimationIds, id)
    end

    if className == "Sound" then
        table.insert(record.SoundIds, id)
    end

    if F.safeIsA(object, "ValueBase") then
        table.insert(record.ValueIds, id)
    end

    local parent, parentReadable = F.safeGet(object, "Parent")
    if parentReadable and parent == toolState.Instance and name == "Handle" and record.HandleId == nil then
        record.HandleId = id
    end
end

local flushRuntimeTrace
local freezeRuntimeTrace

function F.shouldPrimeRuntimeAttributes(object)
    if not CONFIG.RuntimeTraceAllAttributes and not CONFIG.RuntimeTraceToolAttributes then
        return false
    end
    local maxObservers = tonumber(CONFIG.RuntimeMaxObservedAttributes) or 0
    if maxObservers > 0 and (runtimeObserverCounts.Attributes or 0) >= maxObservers then
        return false
    end
    return true
end

function F.trimRuntimeArray(records, maxCount, cutoffTime)
    local firstKeep = 1
    local total = #records

    if cutoffTime ~= nil then
        while firstKeep <= total do
            local record = records[firstKeep]
            local recordTime = record and record.Time

            if type(recordTime) ~= "number" or recordTime >= cutoffTime then
                break
            end

            firstKeep = firstKeep + 1
        end
    end

    local expired = firstKeep - 1
    local remaining = total - expired
    local overflow = 0

    if maxCount and maxCount >= 0 and remaining > maxCount then
        overflow = remaining - maxCount
        firstKeep = firstKeep + overflow
    end

    local removeCount = firstKeep - 1
    if removeCount > 0 then
        local kept = total - firstKeep + 1

        if kept > 0 and type(table.move) == "function" then
            table.move(records, firstKeep, total, 1, records)
        elseif kept > 0 then
            for source = firstKeep, total do
                records[source - firstKeep + 1] = records[source]
            end
        end

        for index = kept + 1, total do
            records[index] = nil
        end
    end

    return expired, overflow
end

function F.pruneRuntimeCaches(force)
    local now = os.clock()

    if not force and now - runtimeHookState.LastPruneAt < 1 then
        return
    end

    runtimeHookState.LastPruneAt = now

    local elapsed = now - runtimeStartedAt
    local window = math.max(0, tonumber(CONFIG.RuntimeRingWindowSeconds) or 0)
    local cutoff = window > 0 and math.max(0, elapsed - window) or nil

    F.trimRuntimeArray(runtimeEventRecords, CONFIG.RuntimeMaxEvents, cutoff)
    F.trimRuntimeArray(runtimeValueRecords, CONFIG.RuntimeMaxValueChanges, cutoff)
    F.trimRuntimeArray(runtimeAttributeRecords, CONFIG.RuntimeMaxAttributeChanges, cutoff)
    F.trimRuntimeArray(runtimeCharacterRecords, CONFIG.RuntimeMaxCharacterRecords, cutoff)
    F.trimRuntimeArray(runtimeLogRecords, CONFIG.RuntimeMaxLogRecords, cutoff)
    F.trimRuntimeArray(guiCapture.Records, CONFIG.RuntimeMaxGuiChanges, cutoff)
    F.trimRuntimeArray(runtimeTimelineRecords, CONFIG.RuntimeMaxTimelineRecords, cutoff)
    F.trimRuntimeArray(runtimeErrorRecords, 256, cutoff)
    F.trimRuntimeArray(
        runtimeHookState.HookRecords,
        CONFIG.RuntimeMaxHookRecords,
        cutoff
    )
    F.trimRuntimeArray(
        runtimeHookState.HookIntegrityRecords,
        CONFIG.RuntimeMaxHookIntegrityRecords,
        cutoff
    )

    for category, records in pairs(runtimeEventCategoryRecords) do
        local maxCount = CONFIG.RuntimeMaxEventsPerCategory
            and CONFIG.RuntimeMaxEventsPerCategory[category]
            or CONFIG.RuntimeMaxEvents

        local _, overflow = F.trimRuntimeArray(records, maxCount, cutoff)
        if overflow > 0 then
            runtimeEventCategoryDropped[category] =
                (runtimeEventCategoryDropped[category] or 0) + overflow
        end
    end
end

function F.scheduleRuntimeFlush()
    if not flushRuntimeTrace or runtimeHookState.FlushScheduled then
        return
    end

    runtimeHookState.FlushScheduled = true
    task.defer(function()
        runtimeHookState.FlushScheduled = false

        if not flushRuntimeTrace then
            return
        end

        local ok, flushError = pcall(flushRuntimeTrace)
        if not ok then
            F.recordError("RuntimeFlush", nil, flushError)
        end
    end)
end

function F.maybeFlushRuntimeTrace()
    runtimeHookState.MutationsSinceFlush = runtimeHookState.MutationsSinceFlush + 1
    F.pruneRuntimeCaches(false)

    if not flushRuntimeTrace then
        return
    end

    if snapshotBusy
        and not CONFIG.RuntimeFlushDuringSnapshot
        and not runtimeHookState.Frozen
    then
        return
    end

    local every = math.max(1, tonumber(CONFIG.RuntimeFlushEvery) or 1000)
    local minSeconds = math.max(0, tonumber(CONFIG.RuntimeFlushMinSeconds) or 0)
    local now = os.clock()

    if runtimeHookState.MutationsSinceFlush >= every
        and now - runtimeHookState.LastFlushAt >= minSeconds
    then
        runtimeHookState.MutationsSinceFlush = 0
        runtimeHookState.LastFlushAt = now
        F.scheduleRuntimeFlush()
    end
end

function F.appendRuntimeTimeline(record)
    if type(record) ~= "table" then
        return
    end

    if record.Time == nil then
        record.Time = os.clock() - runtimeStartedAt
    end

    table.insert(runtimeTimelineRecords, record)
end

function F.classifyRuntimeRemote(remote, path)
    local className = F.safeClassName(remote)
    if className == "RemoteEvent" or className == "UnreliableRemoteEvent"
        or className == "RemoteFunction" then
        return className
    end
    return "Other"
end

function F.captureRuntimeCallerStack()
    if not CONFIG.RuntimeCaptureCaller
        or not CONFIG.RuntimeCaptureCallerStack
        or not capabilities.debug_info
    then
        return nil
    end

    local frames = {}
    local maxDepth = math.max(1, tonumber(CONFIG.RuntimeCallerStackDepth) or 10)

    for level = 4, 3 + maxDepth do
        local ok, source, line, name = pcall(debug.info, level, "sln")
        if not ok or source == nil then
            break
        end

        table.insert(frames, {
            Level = level,
            Source = F.sanitizeString(source),
            Line = line,
            Name = name and F.sanitizeString(name) or nil
        })
    end

    return #frames > 0 and frames or nil
end

function F.getRuntimeCallerInfo()
    local callerInfo = nil
    local callerScript = nil

    if CONFIG.RuntimeCaptureCaller and capabilities.getcallingscript then
        local ok, result = pcall(getcallingscript)
        if ok and typeof(result) == "Instance" then
            callerScript = result
            callerInfo = F.makeInstanceReference(result, false)

            if callerInfo then
                if not callerInfo.Name or callerInfo.Name == "" then
                    callerInfo.Name = F.safeName(result)
                end
                if not callerInfo.Path or callerInfo.Path == "" then
                    callerInfo.Path = F.safeFullName(result)
                end
            end
        end
    end

    local isExecutor = nil
    if capabilities.checkcaller then
        local ok, result = pcall(checkcaller)
        if ok then
            isExecutor = result and true or false
        end
    end

    local stack = F.captureRuntimeCallerStack()
    if callerInfo and stack and stack[1] then
        callerInfo.DebugSource = stack[1].Source
        callerInfo.DebugLine = stack[1].Line
        callerInfo.DebugName = stack[1].Name
    end

    return callerInfo, callerScript, isExecutor, stack
end

function F.describeRuntimeHookValue(value)
    local description = {
        Type = typeof(value),
        Text = F.sanitizeString(tostring(value))
    }

    local fingerprintParts = {
        description.Type,
        description.Text
    }

    if type(value) == "function" and capabilities.debug_info then
        local ok, source, line, name = pcall(debug.info, value, "sln")
        if ok then
            description.Source = source and F.sanitizeString(source) or nil
            description.Line = line
            description.Name = name and F.sanitizeString(name) or nil

            table.insert(fingerprintParts, description.Source or "")
            table.insert(fingerprintParts, tostring(description.Line or ""))
            table.insert(fingerprintParts, description.Name or "")
        end
    end

    if type(value) == "function" and capabilities.isexecutorclosure then
        local ok, result = pcall(isexecutorclosure, value)
        if ok then
            description.IsExecutorClosure = result and true or false
            table.insert(
                fingerprintParts,
                "executor=" .. tostring(description.IsExecutorClosure)
            )
        end
    end

    if type(value) == "function" and capabilities.iscclosure then
        local ok, result = pcall(iscclosure, value)
        if ok then
            description.IsCClosure = result and true or false
            table.insert(
                fingerprintParts,
                "cclosure=" .. tostring(description.IsCClosure)
            )
        end
    end

    description.Fingerprint = table.concat(fingerprintParts, "|")
    return description
end

function F.getRuntimeHookSnapshot(source)
    local snapshot = {
        Time = os.clock() - runtimeStartedAt,
        Source = source
    }

    local function describeMetatable(object)
        if not object or not capabilities.getrawmetatable then
            return nil
        end

        local ok, metatableValue = pcall(getrawmetatable, object)
        if not ok or type(metatableValue) ~= "table" then
            return {
                Available = false,
                Error = not ok and F.sanitizeString(metatableValue) or "not a table"
            }
        end

        local result = {
            Available = true,
            Index = F.describeRuntimeHookValue(rawget(metatableValue, "__index")),
            Namecall = F.describeRuntimeHookValue(rawget(metatableValue, "__namecall")),
            NewIndex = F.describeRuntimeHookValue(rawget(metatableValue, "__newindex"))
        }

        if capabilities.isreadonly then
            local readonlyOk, readonlyValue = pcall(isreadonly, metatableValue)
            if readonlyOk then
                result.ReadOnly = readonlyValue and true or false
            end
        end

        return result
    end

    snapshot.Game = describeMetatable(game)

    if LocalPlayer then
        local mouseOk, mouseObject = pcall(function()
            return LocalPlayer:GetMouse()
        end)

        if mouseOk and mouseObject then
            snapshot.Mouse = describeMetatable(mouseObject)
        else
            snapshot.Mouse = {
                Available = false,
                Error = F.sanitizeString(mouseObject)
            }
        end
    end


    return snapshot
end

function F.appendRuntimeHookRecord(record)
    if not runtimeTraceActive
        or not CONFIG.RuntimeTraceHookDiagnostics
        or type(record) ~= "table"
    then
        return nil
    end

    if record.Time == nil then
        record.Time = os.clock() - runtimeStartedAt
    end

    table.insert(runtimeHookState.HookRecords, record)

    F.appendRuntimeTimeline({
        Time = record.Time,
        Kind = "HookObservation",
        HookKind = record.HookKind,
        Metamethod = record.Metamethod,
        Method = record.Method,
        CallerIsExecutor = record.CallerIsExecutor,
        CallerPath = record.Caller and record.Caller.Path or nil,

    })

    F.maybeFlushRuntimeTrace()
    return record
end

function F.checkRuntimeHookIntegrity(force, source)
    if not CONFIG.RuntimeTraceHookDiagnostics or not runtimeTraceActive then
        return
    end

    local now = os.clock()
    local interval =
        math.max(0.03, tonumber(CONFIG.RuntimeHookIntegrityInterval) or 0.20)

    if not force
        and now - (runtimeHookState.HookIntegrityLastCheckAt or 0) < interval
    then
        return
    end

    runtimeHookState.HookIntegrityLastCheckAt = now

    local current = F.getRuntimeHookSnapshot(source)
    local previous = runtimeHookState.HookIntegrityLast
    local changes = {}

    local function compareDescription(label, previousValue, currentValue)
        local previousFingerprint =
            previousValue and previousValue.Fingerprint or "<nil>"
        local currentFingerprint =
            currentValue and currentValue.Fingerprint or "<nil>"

        if previousFingerprint ~= currentFingerprint then
            table.insert(changes, {
                Field = label,
                Previous = previousValue,
                Current = currentValue
            })
        end
    end

    if previous then
        compareDescription(
            "Game.__namecall",
            previous.Game and previous.Game.Namecall or nil,
            current.Game and current.Game.Namecall or nil
        )
        compareDescription(
            "Game.__index",
            previous.Game and previous.Game.Index or nil,
            current.Game and current.Game.Index or nil
        )
        compareDescription(
            "Mouse.__namecall",
            previous.Mouse and previous.Mouse.Namecall or nil,
            current.Mouse and current.Mouse.Namecall or nil
        )
        compareDescription(
            "Mouse.__index",
            previous.Mouse and previous.Mouse.Index or nil,
            current.Mouse and current.Mouse.Index or nil
        )

    end

    local shouldRecord = previous == nil or #changes > 0 or force
    if shouldRecord then
        local record = {
            Time = current.Time,
            Source = source,
            Event = previous == nil
                and "Baseline"
                or (#changes > 0 and "Changed" or "Snapshot"),
            Changes = #changes > 0 and changes or nil,
            Snapshot = current
        }

        table.insert(runtimeHookState.HookIntegrityRecords, record)

        local fields = {}
        for _, change in ipairs(changes) do
            table.insert(fields, change.Field)
        end

        F.appendRuntimeTimeline({
            Time = current.Time,
            Kind = "HookIntegrity",
            Source = source,
            Event = record.Event,
            ChangedFields = #fields > 0 and fields or nil
        })

        F.maybeFlushRuntimeTrace()
    end

    if runtimeHookState.HookIntegrityBaseline == nil then
        runtimeHookState.HookIntegrityBaseline = current
    end

    runtimeHookState.HookIntegrityLast = current
end

function F.recordRemoteUsage(record)
    local key = tostring(record.RemoteId or "") .. "|" .. record.ClassName .. "|" .. record.Path
    local summary = remoteUsageByKey[key]
    if not summary then
        if #remoteUsageRecords >= REMOTE_USAGE_LIMIT then
            remoteUsageOverflow = remoteUsageOverflow + 1
            return
        end
        summary = {
            RemoteId = record.RemoteId,
            Name = record.Name,
            ClassName = record.ClassName,
            Path = record.Path,
            Category = record.Category,
            FirstSeenSeconds = record.Time,
            LastSeenSeconds = record.Time,
            TotalCalls = 0,
            ByDirection = {},
            ByMethod = {},
            CallerCounts = {},
            ArgumentShapeCounts = {},
            NormalizedPath = F.normalizeComparisonPath(record.Path),
            Samples = {}
        }
        remoteUsageByKey[key] = summary
        remoteUsageRecords[#remoteUsageRecords + 1] = summary
    end
    summary.TotalCalls = summary.TotalCalls + 1
    summary.LastSeenSeconds = record.Time
    local dir = record.Direction or "Unknown"
    local method = record.Method or "Unknown"
    summary.ByDirection[dir] = (summary.ByDirection[dir] or 0) + 1
    summary.ByMethod[method] = (summary.ByMethod[method] or 0) + 1
    local shape = record.ArgumentShape or "<unknown>"
    if summary.ArgumentShapeCounts[shape] then
        summary.ArgumentShapeCounts[shape] = summary.ArgumentShapeCounts[shape] + 1
    else
        local distinct = 0
        for _ in pairs(summary.ArgumentShapeCounts) do distinct = distinct + 1 end
        if distinct < 24 then summary.ArgumentShapeCounts[shape] = 1 end
    end
    local caller = record.Caller and record.Caller.Path
    if caller and (summary.CallerCounts[caller] or 0) > 0 then
        summary.CallerCounts[caller] = summary.CallerCounts[caller] + 1
    elseif caller then
        local count = 0
        for _ in pairs(summary.CallerCounts) do count = count + 1 end
        if count < 12 then summary.CallerCounts[caller] = 1 end
    end
    local sample = {
        Time = record.Time, Direction = dir, Method = method,
        ArgumentCount = record.ArgumentCount, Arguments = record.Arguments,
        ArgumentShape = record.ArgumentShape,
        ReturnCount = record.ReturnCount, Returns = record.Returns,
        CallerPath = caller
    }
    if #summary.Samples < REMOTE_USAGE_SAMPLE_LIMIT then
        summary.Samples[#summary.Samples + 1] = sample
    else
        -- The final slot is a rolling latest sample; other slots preserve the first calls.
        summary.Samples[REMOTE_USAGE_SAMPLE_LIMIT] = sample
    end
end

function F.appendRuntimeRemoteRecord(remote, direction, method, packedArguments, extra)
    if not runtimeTraceActive then
        return nil
    end

    extra = extra or {}
    local className = F.safeClassName(remote)
    local path = F.safeFullName(remote)
    local category = extra.Category or F.classifyRuntimeRemote(remote, path)
    local callerInfo = extra.Caller

    local argumentTypes = {}
    for index = 1, packedArguments.n do
        argumentTypes[index] = typeof(packedArguments[index])
    end
    local record = {
        Time = os.clock() - runtimeStartedAt,
        Direction = direction,
        Method = method,
        Category = category,
        Phase = extra.Phase,
        RemoteId = instanceIds[remote],
        Name = F.safeName(remote),
        ClassName = className,
        Path = path,
        NormalizedPath = F.normalizeComparisonPath(path),
        SnapshotPath = extra.SnapshotPath,
        ArgumentCount = packedArguments.n,
        ArgumentShape = packedArguments.n == 0 and "(empty)" or table.concat(argumentTypes, ","),
        Arguments = F.serializePackedRuntimeValues(packedArguments),
        NestedArgumentShapes = F.V38.inferPacked(packedArguments),
        Caller = callerInfo,
        CallerIsExecutor = direction == "ClientToServer" and extra.CallerIsExecutor or nil,
        CallerStack = extra.CallerStack,
        ObservedByExecutor = extra.ObservedByExecutor,
        Observer = extra.Observer,
        DurationSeconds = extra.DurationSeconds
    }

    if extra.Returns then
        record.ReturnCount = extra.Returns.n
        record.Returns = F.serializePackedRuntimeValues(extra.Returns)
    end

    table.insert(runtimeEventRecords, record)

    local categoryRecords = runtimeEventCategoryRecords[category]
    if not categoryRecords then
        category = "Other"
        record.Category = category
        categoryRecords = runtimeEventCategoryRecords.Other
    end

    table.insert(categoryRecords, record)
    F.recordRemoteUsage(record)
    F.V38.onRemoteRecord(record)
    if journalRecord then journalRecord("Runtime", { Kind = "Remote", Data = record }) end

    F.appendRuntimeTimeline({
        Time = record.Time,
        Kind = "Remote",
        Category = category,
        Direction = direction,
        Method = method,
        Name = record.Name,
        Path = record.Path,
        ArgumentCount = record.ArgumentCount,
        CallerIsExecutor = record.CallerIsExecutor,
        CallerPath = callerInfo and callerInfo.Path or nil
    })

    F.maybeFlushRuntimeTrace()
    return record
end

function F.claimRuntimeObserver(kind, object, limit, warningStage)
    limit = tonumber(limit)
    if not limit or limit <= 0 then
        return true
    end

    local count = runtimeObserverCounts[kind] or 0
    if count >= limit then
        if not runtimeObserverCapWarned[kind] then
            runtimeObserverCapWarned[kind] = true
            F.recordWarning(
                warningStage,
                object,
                string.format(
                    "Runtime %s observer cap reached (%d); static dump continues, extra runtime observers are skipped",
                    string.lower(kind),
                    limit
                )
            )
        end
        return false
    end

    runtimeObserverCounts[kind] = count + 1
    return true
end

local function researchToolDetails(tool)
    local details = { Attributes = F.optionalMap(F.getAttributes(tool)), Children = {} }
    local ok, descendants = pcall(function() return tool:GetDescendants() end)
    if not ok then
        details.Error = F.sanitizeString(descendants)
        return details
    end
    for _, child in ipairs(descendants) do
        local className = F.safeClassName(child)
        local isValue = F.safeIsA(child, "ValueBase")
        if isValue or SCRIPT_BUCKETS[className] or REMOTE_BUCKETS[className]
            or className == "Animation" or className == "Sound"
            or className == "ParticleEmitter" or className == "Beam"
            or className == "Trail" or className == "ProximityPrompt"
            or className == "ClickDetector" or className == "Attachment"
            or className == "Motor6D" or className == "WeldConstraint"
        then
            local entry = { Name = F.safeName(child), ClassName = className,
                Path = F.safeFullName(child) }
            if isValue then
                local value, readable = F.safeGet(child, "Value")
                if readable then entry.Value = F.serializeRuntimeValue(value) end
            end
            local attributes = F.getAttributes(child)
            if next(attributes) ~= nil then entry.Attributes = attributes end
            details.Children[#details.Children + 1] = entry
            if #details.Children >= CONFIG.InteractionMaxToolDescendants then
                details.Truncated = true
                break
            end
        end
    end
    return details
end

-- Optional research-only closure inspection. Nothing is hooked, called, or mutated.
-- Connections are inspected without invoking or replacing game callbacks.
function F.captureResearchConnections(object, signalName, phase)
    if not SELECTION.InteractionResearch or not SELECTION.ClosureResearch then return end
    if #interactionConnectionRecords >= CONFIG.InteractionMaxConnectionRecords then
        interactionConnectionDropped = interactionConnectionDropped + 1
        return
    end
    local record = {
        Time = os.clock() - runtimeStartedAt,
        ObjectPath = F.safeFullName(object), ClassName = F.safeClassName(object),
        Signal = signalName, Phase = phase,
        Available = capabilities.getconnections,
        Connections = {}, RemoteReferences = {},
        VisitedNodes = 0
    }
    if not capabilities.getconnections then
        record.Status = "getconnections unavailable"
        interactionConnectionRecords[#interactionConnectionRecords + 1] = record
        return
    end
    local okConnections, connections = pcall(function()
        return getconnections(object[signalName])
    end)
    if not okConnections or type(connections) ~= "table" then
        record.Status = "getconnections failed: " .. F.sanitizeString(connections)
        interactionConnectionRecords[#interactionConnectionRecords + 1] = record
        return
    end
    record.Status = "Inspected"
    record.TotalConnections = #connections
    local seen = {}
    local function inspect(value, route, depth)
        if depth > 5 or record.VisitedNodes >= CONFIG.InteractionMaxUpvalueNodes then return end
        record.VisitedNodes = record.VisitedNodes + 1
        local kind = typeof(value)
        if kind == "Instance" then
            local className = F.safeClassName(value)
            if REMOTE_BUCKETS[className] then
                if #record.RemoteReferences < 100 then
                    record.RemoteReferences[#record.RemoteReferences + 1] = {
                        Path = F.safeFullName(value), ClassName = className,
                        Via = route,
                        NormalizedPath = F.normalizeComparisonPath(F.safeFullName(value))
                    }
                end
            end
        elseif kind == "table" then
            if seen[value] then return end
            seen[value] = true
            local count = 0
            for key, item in pairs(value) do
                if count >= 100 then break end
                count = count + 1
                inspect(item, route .. "." .. F.sanitizeString(tostring(key)):sub(1, 70), depth + 1)
                if record.VisitedNodes >= CONFIG.InteractionMaxUpvalueNodes then break end
            end
        elseif kind == "function" then
            if seen[value] then return end
            seen[value] = true
            if capabilities.getupvalues then
                local ok, upvalues = pcall(debug.getupvalues, value)
                if ok and type(upvalues) == "table" then
                    local n = 0
                    for key, item in pairs(upvalues) do
                        if n >= 40 then break end
                        n = n + 1
                        inspect(item, route .. ".upvalue[" .. tostring(key) .. "]", depth + 1)
                        if record.VisitedNodes >= CONFIG.InteractionMaxUpvalueNodes then break end
                    end
                end
            elseif capabilities.getupvalue then
                for index = 1, 30 do
                    local ok, a, b = pcall(debug.getupvalue, value, index)
                    if not ok then break end
                    local resolved = b ~= nil and b or a
                    if resolved ~= nil then
                        inspect(resolved, route .. ".upvalue[" .. tostring(index) .. "]", depth + 1)
                    end
                    if record.VisitedNodes >= CONFIG.InteractionMaxUpvalueNodes then break end
                end
            end
        end
    end
    for index, connection in ipairs(connections) do
        if index > CONFIG.InteractionMaxClosuresPerSignal then break end
        local info = { Index = index }
        local ok, callback = pcall(function() return connection.Function end)
        if ok and type(callback) == "function" then
            info.HasCallback = true
            if capabilities.debug_info then
                local debugOk, source, line, name = pcall(debug.info, callback, "sln")
                if debugOk then
                    info.Source = source and F.sanitizeString(source) or nil
                    info.Line = line
                    info.Name = name and F.sanitizeString(name) or nil
                end
            end
            inspect(callback, "connection[" .. index .. "]", 0)
        else
            info.HasCallback = false
        end
        local statusOk, enabled = pcall(function() return connection.Enabled end)
        if statusOk and type(enabled) == "boolean" then info.Enabled = enabled end
        record.Connections[#record.Connections + 1] = info
    end
    record.Truncated = #connections > CONFIG.InteractionMaxClosuresPerSignal
        or record.VisitedNodes >= CONFIG.InteractionMaxUpvalueNodes
    interactionConnectionRecords[#interactionConnectionRecords + 1] = record
end

function F.watchResearchTool(tool)
    if not SELECTION.InteractionResearch or not runtimeTraceActive
        or not F.safeIsA(tool, "Tool") or interactionObservedTools[tool] then return end
    if interactionToolCounts.Tools >= CONFIG.InteractionMaxObservedTools then return end
    interactionObservedTools[tool] = true
    interactionToolCounts.Tools = interactionToolCounts.Tools + 1
    F.researchEvent("ToolObserved", tool, researchToolDetails(tool))
    F.captureResearchConnections(tool, "Activated", "Observed")
    local function listen(signalName, callback)
        local connected, connection = pcall(function()
            return tool[signalName]:Connect(callback)
        end)
        if connected and connection then
            runtimeConnections[#runtimeConnections + 1] = connection
        end
    end
    listen("Equipped", function()
        if not runtimeTraceActive then return end
        interactionToolCounts.Equips = interactionToolCounts.Equips + 1
        F.researchEvent("ToolEquipped", tool, researchToolDetails(tool))
        if SELECTION.ClosureResearch then
            task.defer(function()
                if runtimeTraceActive and tool.Parent then
                    F.captureResearchConnections(tool, "Activated", "Equipped")
                end
            end)
        end
    end)
    listen("Unequipped", function()
        if runtimeTraceActive then F.researchEvent("ToolUnequipped", tool) end
    end)
    listen("Activated", function()
        if not runtimeTraceActive then return end
        interactionToolCounts.Activations = interactionToolCounts.Activations + 1
        F.researchEvent("ToolActivated", tool, {
            Enabled = select(1, F.safeGet(tool, "Enabled")),
            Attributes = F.optionalMap(F.getAttributes(tool))
        })
    end)
    listen("Deactivated", function()
        if runtimeTraceActive then F.researchEvent("ToolDeactivated", tool) end
    end)
end

local RESEARCH_INTERACTION_SIGNALS = {
    ProximityPrompt = { "Triggered", "TriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
    ClickDetector = { "MouseClick", "RightMouseClick", "MouseHoverEnter", "MouseHoverLeave" },
    DragDetector = { "DragStart", "DragEnd", "DragContinue" },
    TextButton = { "Activated" }, ImageButton = { "Activated" }
}
local researchObservedInteractions = setmetatable({}, { __mode = "k" })
local researchInteractionCount = 0
local researchGuiButtonCount = 0

function F.watchResearchInteraction(object, className)
    if not SELECTION.InteractionResearch or not runtimeTraceActive
        or researchObservedInteractions[object] then return end
    className = className or F.safeClassName(object)
    local signals = RESEARCH_INTERACTION_SIGNALS[className]
    if not signals or researchInteractionCount >= CONFIG.InteractionMaxObservedInteractions then return end
    local isGuiButton = className == "TextButton" or className == "ImageButton"
    if isGuiButton and researchGuiButtonCount >= CONFIG.InteractionMaxGuiButtonObservers then return end
    researchObservedInteractions[object] = true
    researchInteractionCount = researchInteractionCount + 1
    if isGuiButton then researchGuiButtonCount = researchGuiButtonCount + 1 end
    F.researchEvent("InteractionObserved", object, { Signals = signals })
    for _, signalName in ipairs(signals) do
        local okSignal, signal = pcall(function() return object[signalName] end)
        if okSignal and signal then
            if SELECTION.ClosureResearch then
                F.captureResearchConnections(object, signalName, "Observed")
            end
            local okConnect, connection = pcall(function()
                return signal:Connect(function(...)
                    if not runtimeTraceActive then return end
                    local packed = table.pack(...)
                    F.researchEvent("InteractionSignal", object, {
                        Signal = signalName, ArgumentCount = packed.n,
                        Arguments = F.serializePackedRuntimeValues(packed)
                    })
                end)
            end)
            if okConnect and connection then
                runtimeConnections[#runtimeConnections + 1] = connection
            end
        end
    end
end

function F.watchResearchRemote(remote)
    if not SELECTION.InteractionResearch or not runtimeTraceActive
        or interactionObservedRemotes[remote] then return end
    local className = F.safeClassName(remote)
    if not REMOTE_BUCKETS[className] then return end
    if interactionObservedRemoteCount >= CONFIG.InteractionMaxRemoteCandidates then return end
    interactionObservedRemotes[remote] = true
    interactionObservedRemoteCount = interactionObservedRemoteCount + 1
    local lastName = F.safeName(remote)
    local lastParent = remote.Parent
    interactionRemoteLifecycleCounts.Added = interactionRemoteLifecycleCounts.Added + 1
    F.researchEvent("RemoteObserved", remote, {
        Attributes = F.optionalMap(F.getAttributes(remote)),
        Tags = F.getTags(remote),
        ParentPath = lastParent and F.safeFullName(lastParent) or nil
    })
    local okName, nameConnection = pcall(function()
        return remote:GetPropertyChangedSignal("Name"):Connect(function()
            if not runtimeTraceActive then return end
            local newName = F.safeName(remote)
            if newName == lastName then return end
            interactionRemoteLifecycleCounts.Renamed = interactionRemoteLifecycleCounts.Renamed + 1
            F.researchEvent("RemoteRenamed", remote, { From = lastName, To = newName })
            lastName = newName
        end)
    end)
    if okName and nameConnection then runtimeConnections[#runtimeConnections + 1] = nameConnection end
    local okAncestry, ancestryConnection = pcall(function()
        return remote.AncestryChanged:Connect(function(_, newParent)
            if not runtimeTraceActive then return end
            if newParent == lastParent then return end
            if newParent == nil then
                interactionRemoteLifecycleCounts.Removed = interactionRemoteLifecycleCounts.Removed + 1
                F.researchEvent("RemoteRemoved", remote, {
                    PreviousParentPath = lastParent and F.safeFullName(lastParent) or nil
                })
            else
                interactionRemoteLifecycleCounts.Reparented = interactionRemoteLifecycleCounts.Reparented + 1
                F.researchEvent("RemoteReparented", remote, {
                    PreviousParentPath = lastParent and F.safeFullName(lastParent) or nil,
                    NewParentPath = F.safeFullName(newParent)
                })
            end
            lastParent = newParent
        end)
    end)
    if okAncestry and ancestryConnection then runtimeConnections[#runtimeConnections + 1] = ancestryConnection end
end

function F.watchRuntimeRemote(object, id, name, className, path)
    F.watchResearchRemote(object)
    if not CONFIG.RuntimeTrace or not runtimeTraceActive or not CONFIG.RuntimeTraceIncomingRemotes then
        return
    end

    if className ~= "RemoteEvent" and className ~= "UnreliableRemoteEvent" then
        return
    end

    if runtimeObservedRemotes[object] then
        return
    end

    if not F.claimRuntimeObserver(
        "Remotes",
        object,
        CONFIG.RuntimeMaxObservedRemotes,
        "RuntimeRemoteObserverCap"
    ) then
        return
    end

    runtimeObservedRemotes[object] = true

    local ok, signal = pcall(function()
        return object.OnClientEvent
    end)

    if not ok or not signal then
        return
    end

    local connectionOk, connection = pcall(function()
        return signal:Connect(function(...)
            if not runtimeTraceActive then
                return
            end

            F.appendRuntimeRemoteRecord(
                object,
                "ServerToClient",
                "OnClientEvent",
                table.pack(...),
                {
                    SnapshotPath = path,
                    ObservedByExecutor = true,
                    Observer = "DumperOnClientEventConnection"
                }
            )
        end)
    end)

    if connectionOk and connection then
        table.insert(runtimeConnections, connection)
    else
        F.recordWarning("RuntimeRemoteTrace", object, connection)
    end
end

function F.installOutgoingRemoteHook()
    if not CONFIG.RuntimeTrace or not CONFIG.RuntimeTraceOutgoingRemotes then
        return false
    end

    if runtimeOutgoingHookInstalled then
        runtimeHookState.Active = true
        return true
    end

    if not capabilities.hookmetamethod or not capabilities.getnamecallmethod then
        F.recordWarning(
            "RuntimeOutgoingRemoteTrace",
            nil,
            "hookmetamethod/getnamecallmethod unavailable; outgoing FireServer/InvokeServer calls cannot be observed"
        )
        return false
    end

    local oldNamecall

    local function handler(self, ...)
        local methodOk, method = pcall(getnamecallmethod)
        if not methodOk then
            return oldNamecall(self, ...)
        end

        local traceActive = runtimeHookState.Active
        local observeRemote = traceActive
            and (method == "FireServer" or method == "InvokeServer")

        if not observeRemote then
            return oldNamecall(self, ...)
        end

        local className = typeof(self) == "Instance" and F.safeClassName(self) or nil
        local isFireServer = method == "FireServer"
            and (className == "RemoteEvent" or className == "UnreliableRemoteEvent")
        local isInvokeServer = method == "InvokeServer" and className == "RemoteFunction"
        if not isFireServer and not isInvokeServer then
            return oldNamecall(self, ...)
        end

        local packedArguments = table.pack(...)
        local callStarted = os.clock()
        local returns = table.pack(oldNamecall(self, ...))
        local duration = os.clock() - callStarted

        if observeRemote then
            if isFireServer or isInvokeServer then
                local callerInfo, _, callerIsExecutor, callerStack = F.getRuntimeCallerInfo()
                local snapshotPath = F.safeFullName(self)
                local record = F.appendRuntimeRemoteRecord(
                    self,
                    "ClientToServer",
                    isInvokeServer and "InvokeServer" or "FireServer",
                    packedArguments,
                    {
                        SnapshotPath = snapshotPath,
                        Caller = callerInfo,
                        CallerIsExecutor = callerIsExecutor,
                        CallerStack = callerStack,
                        Phase = "PostCall",
                        DurationSeconds = duration,
                        Returns = isInvokeServer
                            and CONFIG.RuntimeCaptureInvokeReturns
                            and returns
                            or nil
                    }
                )

                if isInvokeServer and record then
                    F.appendRuntimeTimeline({
                        Time = os.clock() - runtimeStartedAt,
                        Kind = "RemoteReturn",
                        Category = record.Category,
                        Direction = "ServerToClient",
                        Method = "InvokeServerReturn",
                        Name = record.Name,
                        Path = record.Path,
                        ReturnCount = returns.n,
                        DurationSeconds = duration
                    })
                    F.maybeFlushRuntimeTrace()
                end
            end
        end

        return table.unpack(returns, 1, returns.n)
    end

    local wrappedHandler = capabilities.newcclosure and newcclosure(handler) or handler
    local hookOk, hookResult = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", wrappedHandler)
    end)

    if not hookOk or type(oldNamecall) ~= "function" then
        F.recordWarning("RuntimeOutgoingRemoteTrace", nil, hookResult or "failed to install __namecall hook")
        return false
    end

    runtimeOutgoingHookInstalled = true
    runtimeHookState.Active = true
    return true
end

function F.shouldWatchRuntimeAttributes(object, name, path, attributes)
    if not runtimeTraceActive then return false end
    if CONFIG.RuntimeTraceToolAttributes and F.safeIsA(object, "Tool") then
        return true
    end
    if not CONFIG.RuntimeTraceAllAttributes then return false end
    if next(attributes or {}) ~= nil then return true end
    return F.safeIsA(object, "Player") or F.safeIsA(object, "Humanoid")
end

function F.watchRuntimeAttributes(object, id, name, className, path, attributes)
    if not CONFIG.RuntimeTrace or not runtimeTraceActive then
        return
    end

    if runtimeObservedAttributes[object] then
        return
    end

    if not F.shouldWatchRuntimeAttributes(object, name, path, attributes) then
        return
    end

    if not F.claimRuntimeObserver(
        "Attributes",
        object,
        CONFIG.RuntimeMaxObservedAttributes,
        "RuntimeAttributeObserverCap"
    ) then
        return
    end

    runtimeObservedAttributes[object] = true
    local initialValues = {}
    local initialOk, initialAttributes = pcall(function()
        return object:GetAttributes()
    end)

    if initialOk and type(initialAttributes) == "table" then
        for attributeName, value in pairs(initialAttributes) do
            initialValues[attributeName] = value
        end
    end

    runtimeAttributeLastValues[object] = initialValues

    local signalOk, signal = pcall(function()
        return object.AttributeChanged
    end)
    if not signalOk or not signal then
        return
    end

    local connectionOk, connection = pcall(function()
        return signal:Connect(function(attributeName)
            if not runtimeTraceActive then
                return
            end

            local oldValue = runtimeAttributeLastValues[object]
                and runtimeAttributeLastValues[object][attributeName]
                or nil

            local newOk, newValue = pcall(function()
                return object:GetAttribute(attributeName)
            end)

            if not newOk then
                newValue = nil
            end

            if runtimeAttributeLastValues[object] then
                runtimeAttributeLastValues[object][attributeName] = newValue
            end

            local previousSerialized = nil
            if oldValue ~= nil then
                previousSerialized = F.serializeRuntimeValue(oldValue)
            end

            local newSerialized = nil
            if newValue ~= nil then
                newSerialized = F.serializeRuntimeValue(newValue)
            end

            local record = {
                Time = os.clock() - runtimeStartedAt,
                Id = instanceIds[object] or id,
                Name = F.safeName(object),
                ClassName = F.safeClassName(object),
                Path = F.safeFullName(object),
                SnapshotPath = path,
                Attribute = F.sanitizeString(attributeName),
                PreviousIsNil = oldValue == nil,
                PreviousValue = previousSerialized,
                ValueIsNil = newValue == nil,
                Value = newSerialized
            }

            table.insert(runtimeAttributeRecords, record)
            if journalRecord then journalRecord("Runtime", { Kind = "Attribute", Data = record }) end

            F.appendRuntimeTimeline({
                Time = record.Time,
                Kind = "Attribute",
                Name = record.Name,
                Path = record.Path,
                Field = record.Attribute
            })

            F.maybeFlushRuntimeTrace()
        end)
    end)

    if connectionOk and connection then
        table.insert(runtimeConnections, connection)
    else
        F.recordWarning("RuntimeAttributeTrace", object, connection)
    end
end

function F.watchRuntimeValue(object, id, name, className, path)
    if not CONFIG.RuntimeTrace or not runtimeTraceActive or not F.safeIsA(object, "ValueBase") then
        return
    end

    if not CONFIG.RuntimeTraceAllValues then
        return
    end

    if runtimeObservedValues[object] then
        return
    end

    if not F.claimRuntimeObserver(
        "Values",
        object,
        CONFIG.RuntimeMaxObservedValues,
        "RuntimeValueObserverCap"
    ) then
        return
    end

    runtimeObservedValues[object] = true

    if runtimeValueLastValues[object] == nil then
        local initialValue, initialReadable = F.safeGet(object, "Value")
        if initialReadable then
            runtimeValueLastValues[object] = {
                HasValue = initialValue ~= nil,
                Value = initialValue
            }
        else
            runtimeValueLastValues[object] = {
                HasValue = false,
                Value = nil
            }
        end
    end

    local signalOk, signal = pcall(function()
        return object:GetPropertyChangedSignal("Value")
    end)

    if not signalOk or not signal then
        return
    end

    local connectionOk, connection = pcall(function()
        return signal:Connect(function()
            if not runtimeTraceActive then
                return
            end

            local previousState = runtimeValueLastValues[object]
                or { HasValue = false, Value = nil }
            local value, readable, readError = F.safeGet(object, "Value")
            local serialized
            local previousSerialized = previousState.HasValue
                and F.serializeRuntimeValue(previousState.Value)
                or nil

            if readable then
                serialized = value == nil
                    and { __type = "Nil" }
                    or F.serializeRuntimeValue(value)

                runtimeValueLastValues[object] = {
                    HasValue = value ~= nil,
                    Value = value
                }
            else
                serialized = {
                    __type = "ReadError",
                    value = F.sanitizeString(readError)
                }
            end

            local record = {
                Time = os.clock() - runtimeStartedAt,
                Id = instanceIds[object] or id,
                Name = name,
                ClassName = className,
                Path = F.safeFullName(object),
                SnapshotPath = path,
                PreviousIsNil = not previousState.HasValue,
                PreviousValue = previousSerialized,
                ValueIsNil = readable and value == nil or nil,
                Value = serialized
            }

            table.insert(runtimeValueRecords, record)
            if journalRecord then journalRecord("Runtime", { Kind = "Value", Data = record }) end

            F.appendRuntimeTimeline({
                Time = record.Time,
                Kind = "Value",
                Name = record.Name,
                Path = record.Path
            })

            F.maybeFlushRuntimeTrace()
        end)
    end)

    if connectionOk and connection then
        table.insert(runtimeConnections, connection)
    else
        F.recordWarning("RuntimeValueTrace", object, connection)
    end
end

function F.disconnectConnections(connections)
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(connections)
end

function F.appendRuntimeCharacterRecord(eventName, object, details)
    if not runtimeTraceActive then
        return nil
    end

    local record = {
        Time = os.clock() - runtimeStartedAt,
        Event = eventName,
        Object = object and F.makeInstanceReference(object, false) or nil,
        Details = details
    }

    table.insert(runtimeCharacterRecords, record)
    if journalRecord then journalRecord("Runtime", { Kind = "Character", Data = record }) end

    F.appendRuntimeTimeline({
        Time = record.Time,
        Kind = "Character",
        Event = eventName,
        Name = record.Object and record.Object.Name or nil,
        Path = record.Object and record.Object.Path or nil
    })

    F.maybeFlushRuntimeTrace()
    return record
end

function F.readRuntimeProperty(object, property)
    local value, readable, readError = F.safeGet(object, property)

    if not readable then
        return {
            __type = "ReadError",
            value = F.sanitizeString(readError)
        }
    end

    if value == nil then
        return {
            __type = "Nil"
        }
    end

    return F.serializeRuntimeValue(value)
end

function F.watchCharacterObject(object)
    if not object or not runtimeTraceActive then
        return
    end

    if F.safeIsA(object, "Humanoid") then
        local humanoidProperties = {
            "Health",
            "MaxHealth",
            "WalkSpeed",
            "JumpPower",
            "JumpHeight",
            "HipHeight",
            "UseJumpPower",
            "AutoRotate",
            "PlatformStand",
            "Sit"
        }

        for _, property in ipairs(humanoidProperties) do
            local ok, signal = pcall(function()
                return object:GetPropertyChangedSignal(property)
            end)

            if ok and signal then
                local connected, connection = pcall(function()
                    return signal:Connect(function()
                        if not runtimeTraceActive then
                            return
                        end

                        F.appendRuntimeCharacterRecord(
                            "HumanoidPropertyChanged",
                            object,
                            {
                                Property = property,
                                Value = F.readRuntimeProperty(object, property)
                            }
                        )
                    end)
                end)

                if connected and connection then
                    table.insert(runtimeCharacterConnections, connection)
                end
            end
        end

        local stateOk, stateConnection = pcall(function()
            return object.StateChanged:Connect(function(oldState, newState)
                if not runtimeTraceActive then
                    return
                end

                F.appendRuntimeCharacterRecord(
                    "HumanoidStateChanged",
                    object,
                    {
                        OldState = F.serializeRuntimeValue(oldState),
                        NewState = F.serializeRuntimeValue(newState)
                    }
                )
            end)
        end)

        if stateOk and stateConnection then
            table.insert(runtimeCharacterConnections, stateConnection)
        end
    elseif F.safeIsA(object, "BasePart") and F.safeName(object) == "HumanoidRootPart" then
        for _, property in ipairs({ "Anchored", "CanCollide", "Massless" }) do
            local ok, signal = pcall(function()
                return object:GetPropertyChangedSignal(property)
            end)

            if ok and signal then
                local connected, connection = pcall(function()
                    return signal:Connect(function()
                        if not runtimeTraceActive then
                            return
                        end

                        F.appendRuntimeCharacterRecord(
                            "RootPropertyChanged",
                            object,
                            {
                                Property = property,
                                Value = F.readRuntimeProperty(object, property)
                            }
                        )
                    end)
                end)

                if connected and connection then
                    table.insert(runtimeCharacterConnections, connection)
                end
            end
        end
    end
end

function F.watchLocalCharacter(character)
    if not CONFIG.RuntimeTraceCharacter then
        return
    end

    F.disconnectConnections(runtimeCharacterConnections)

    if not character then
        F.appendRuntimeCharacterRecord("CharacterMissing", nil, nil)
        return
    end

    F.appendRuntimeCharacterRecord(
        "CharacterAttached",
        character,
        {
            CharacterId = instanceIds[character]
        }
    )

    for _, descendant in ipairs(character:GetDescendants()) do
        if F.safeIsA(descendant, "Humanoid")
            or (F.safeIsA(descendant, "BasePart") and F.safeName(descendant) == "HumanoidRootPart")
        then
            F.watchCharacterObject(descendant)
        end
    end

    local addedOk, addedConnection = pcall(function()
        return character.DescendantAdded:Connect(function(object)
            if not runtimeTraceActive then
                return
            end

            F.appendRuntimeCharacterRecord(
                "DescendantAdded",
                object,
                {
                    Parent = F.makeInstanceReference(object.Parent, false)
                }
            )

            if F.safeIsA(object, "Humanoid")
                or (F.safeIsA(object, "BasePart") and F.safeName(object) == "HumanoidRootPart")
            then
                F.watchCharacterObject(object)
            end
        end)
    end)

    if addedOk and addedConnection then
        table.insert(runtimeCharacterConnections, addedConnection)
    end

    local removingOk, removingConnection = pcall(function()
        return character.DescendantRemoving:Connect(function(object)
            if not runtimeTraceActive then
                return
            end

            F.appendRuntimeCharacterRecord(
                "DescendantRemoving",
                object,
                {
                    Parent = F.makeInstanceReference(object.Parent, false)
                }
            )
        end)
    end)

    if removingOk and removingConnection then
        table.insert(runtimeCharacterConnections, removingConnection)
    end
end

function F.sampleLocalCharacter()
    if not CONFIG.RuntimeTraceCharacter or not runtimeTraceActive or not LocalPlayer then
        return
    end

    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    local record = {
        Time = os.clock() - runtimeStartedAt,
        Event = "Sample",
        Character = F.makeInstanceReference(character, false)
    }

    if humanoid then
        local stateOk, humanoidState = pcall(function()
            return humanoid:GetState()
        end)

        record.Humanoid = {
            Id = instanceIds[humanoid],
            Path = F.safeFullName(humanoid),
            Health = F.readRuntimeProperty(humanoid, "Health"),
            MaxHealth = F.readRuntimeProperty(humanoid, "MaxHealth"),
            WalkSpeed = F.readRuntimeProperty(humanoid, "WalkSpeed"),
            JumpPower = F.readRuntimeProperty(humanoid, "JumpPower"),
            JumpHeight = F.readRuntimeProperty(humanoid, "JumpHeight"),
            HipHeight = F.readRuntimeProperty(humanoid, "HipHeight"),
            MoveDirection = F.readRuntimeProperty(humanoid, "MoveDirection"),
            FloorMaterial = F.readRuntimeProperty(humanoid, "FloorMaterial"),
            State = stateOk and F.serializeRuntimeValue(humanoidState) or nil
        }
    end

    if root and F.safeIsA(root, "BasePart") then
        record.Root = {
            Id = instanceIds[root],
            Path = F.safeFullName(root),
            CFrame = F.readRuntimeProperty(root, "CFrame"),
            Position = F.readRuntimeProperty(root, "Position"),
            AssemblyLinearVelocity = F.readRuntimeProperty(root, "AssemblyLinearVelocity"),
            AssemblyAngularVelocity = F.readRuntimeProperty(root, "AssemblyAngularVelocity"),
            Anchored = F.readRuntimeProperty(root, "Anchored"),
            CanCollide = F.readRuntimeProperty(root, "CanCollide")
        }
    end

    table.insert(runtimeCharacterRecords, record)
    if journalRecord then journalRecord("Runtime", { Kind = "Character", Data = record }) end

    F.appendRuntimeTimeline({
        Time = record.Time,
        Kind = "CharacterSample",
        Path = record.Character and record.Character.Path or nil
    })

    F.maybeFlushRuntimeTrace()
end

function F.appendRuntimeLog(message, messageType)
    if not runtimeTraceActive or not CONFIG.RuntimeCaptureLogs then
        return
    end

    local record = {
        Time = os.clock() - runtimeStartedAt,
        Message = F.sanitizeString(message),
        MessageType = F.serializeRuntimeValue(messageType)
    }

    table.insert(runtimeLogRecords, record)
    if journalRecord then journalRecord("Runtime", { Kind = "Log", Data = record }) end

    local severity = tostring(messageType)
    if severity == "Enum.MessageType.MessageError"
        or severity == "Enum.MessageType.MessageWarning" then
        F.appendRuntimeTimeline({
            Time = record.Time,
            Kind = "Log",
            Message = record.Message,
            MessageType = record.MessageType
        })
    end

    F.maybeFlushRuntimeTrace()
end

function F.getCurrentGuiErrorMessage()
    local ok, message = pcall(function()
        return game:GetService("GuiService"):GetErrorMessage()
    end)

    if ok and type(message) == "string" then
        return F.sanitizeString(message)
    end

    return nil
end

function F.shouldFreezeForErrorMessage(message)
    if not CONFIG.RuntimeFreezeOnDisconnectError or type(message) ~= "string" then
        return false
    end

    local lowered = string.lower(message)

    for _, keyword in ipairs(CONFIG.RuntimeFreezeErrorKeywords or {}) do
        if string.find(lowered, string.lower(keyword), 1, true) then
            return true
        end
    end

    return false
end

function F.handleGuiErrorMessage(message, source)
    if type(message) ~= "string" or message == "" then
        return
    end

    message = F.sanitizeString(message)

    if message == runtimeHookState.LastGuiErrorMessage then
        return
    end

    runtimeHookState.LastGuiErrorMessage = message

    local code = string.match(message, "[Ee]rror%s*[Cc]ode[^%d]*(%d+)")
        or string.match(message, "Código%s+de%s+error[^%d]*(%d+)")
        or string.match(message, "codigo%s+de%s+error[^%d]*(%d+)")
        or string.match(message, "%f[%d]267%f[%D]")

    local record = {
        Time = os.clock() - runtimeStartedAt,
        Source = source,
        Message = message,
        ErrorCode = code
    }

    table.insert(runtimeErrorRecords, record)
    if journalRecord then journalRecord("Runtime", { Kind = "GuiError", Data = record }) end

    F.appendRuntimeTimeline({
        Time = record.Time,
        Kind = "GuiError",
        Source = source,
        Message = message,
        ErrorCode = code
    })

    F.maybeFlushRuntimeTrace()

    if F.shouldFreezeForErrorMessage(message) and freezeRuntimeTrace then
        freezeRuntimeTrace(
            "DisconnectError",
            {
                Source = source,
                Message = message,
                ErrorCode = code
            }
        )
    end
end

freezeRuntimeTrace = function(reason, details)
    if runtimeHookState.Frozen then
        return false
    end

    if CONFIG.RuntimeTraceHookDiagnostics then
        pcall(F.checkRuntimeHookIntegrity, true, "BeforeFreeze")
    end

    local freezeTime = os.clock() - runtimeStartedAt

    runtimeHookState.Frozen = true
    runtimeTraceActive = false
    runtimeHookState.Active = false
    runtimeHookState.FreezeInfo = {
        Time = freezeTime,
        Reason = F.sanitizeString(reason or "Unknown"),
        Details = details
    }

    F.appendRuntimeTimeline({
        Time = freezeTime,
        Kind = "TraceFrozen",
        Reason = runtimeHookState.FreezeInfo.Reason
    })

    F.pruneRuntimeCaches(true)
    if journalRecord then journalRecord("Runtime", { Kind = "TraceFrozen", Data = runtimeHookState.FreezeInfo }) end
    if flushRecovery then pcall(flushRecovery, true) end
    if writeDiagnostics then pcall(writeDiagnostics, "Disconnected", runtimeHookState.FreezeInfo) end

    for _, record in ipairs(runtimeTimelineRecords) do
        if type(record.Time) == "number" then
            record.SecondsBeforeFreeze = freezeTime - record.Time
        end
    end

    for _, record in ipairs(runtimeHookState.HookRecords) do
        if type(record.Time) == "number" then
            record.SecondsBeforeFreeze = freezeTime - record.Time
        end
    end

    for _, record in ipairs(runtimeHookState.HookIntegrityRecords) do
        if type(record.Time) == "number" then
            record.SecondsBeforeFreeze = freezeTime - record.Time
        end
    end

    if flushRuntimeTrace then
        pcall(flushRuntimeTrace)
    end

    task.defer(function()
        F.disconnectConnections(runtimeCharacterConnections)
        F.disconnectConnections(runtimeConnections)
    end)

    return true
end

function F.primeRuntimeObservers()
    if not CONFIG.RuntimeTrace or not runtimeTraceActive then
        return
    end

    local childrenOk, rootChildren = pcall(function()
        return game:GetChildren()
    end)
    if not childrenOk then
        F.recordWarning("RuntimePrime", nil, rootChildren)
        return
    end

    local stack = {}
    for index = #rootChildren, 1, -1 do
        stack[#stack + 1] = rootChildren[index]
    end
    rootChildren = nil

    local processed = 0
    local yieldEvery = math.max(25, tonumber(CONFIG.RuntimePrimeYieldEvery) or 150)

    while #stack > 0 and runtimeTraceActive do
        local object = stack[#stack]
        stack[#stack] = nil

        if object then
            local className = F.safeClassName(object)
            local name = F.safeName(object)
            local path = F.safeFullName(object)

            if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
                F.watchRuntimeRemote(object, instanceIds[object], name, className, path)
            end

            if F.shouldPrimeRuntimeAttributes(object) then
                local attributes = F.getAttributes(object)
                F.watchRuntimeAttributes(object, instanceIds[object], name,
                    className, path, attributes)
            end

            if F.safeIsA(object, "ValueBase") then
                F.watchRuntimeValue(object, instanceIds[object], name, className, path)
            end
            F.watchResearchTool(object)
            F.watchResearchInteraction(object, className)
            F.watchRuntimeGui(object)
            F.V38.observeInstance(object, className)

            local descendantsOk, children = pcall(function()
                return object:GetChildren()
            end)

            if descendantsOk and type(children) == "table" then
                for index = #children, 1, -1 do
                    stack[#stack + 1] = children[index]
                end
            elseif not descendantsOk then
                F.recordWarning("RuntimePrimeGetChildren", object, children)
            end
        end

        processed = processed + 1
        if processed % yieldEvery == 0 then
            task.wait()
        end
    end
end

function F.startRuntimeTrace()
    if not CONFIG.RuntimeTrace then
        return
    end

    runtimeTraceActive = true
    F.V38.startRuntime()
    runtimeHookState.Frozen = false
    runtimeHookState.Active = true
    runtimeHookState.LastFlushAt = os.clock()
    runtimeHookState.MutationsSinceFlush = 0
    runtimeHookState.LastPruneAt = 0
    runtimeHookState.HookIntegrityLastCheckAt = 0
    runtimeHookState.HookIntegrityBaseline = nil
    runtimeHookState.HookIntegrityLast = nil
    runtimeHookState.FlushScheduled = false

    if CONFIG.RuntimeTraceHookDiagnostics then
        F.checkRuntimeHookIntegrity(true, "BeforeDumperNamecallHook")
    end

    F.installOutgoingRemoteHook()

    if CONFIG.RuntimeTraceHookDiagnostics then
        F.checkRuntimeHookIntegrity(true, "AfterDumperNamecallHook")
    end

    if CONFIG.RuntimeTraceDynamicRemotes or CONFIG.RuntimeTraceGui then
        local ok, connection = pcall(function()
            return game.DescendantAdded:Connect(function(object)
                if not runtimeTraceActive then
                    return
                end

                -- Snapshot short-lived notifications before they are removed.
                if CONFIG.RuntimeTraceGui and F.GUI_CLASSES[F.safeClassName(object)] then
                    F.watchRuntimeGui(object, "Added")
                end

                task.defer(function()
                    if not runtimeTraceActive or not object or not object.Parent then
                        return
                    end

                    local className = F.safeClassName(object)
                    local name = F.safeName(object)
                    local path = F.safeFullName(object)
                    F.V38.observeInstance(object, className)
                    if SELECTION.InteractionResearch then
                        F.watchResearchTool(object)
                        F.watchResearchInteraction(object, className)
                        F.watchResearchRemote(object)
                    end

                    if CONFIG.RuntimeTraceDynamicRemotes
                        and (className == "RemoteEvent" or className == "UnreliableRemoteEvent")
                    then
                        F.watchRuntimeRemote(object, instanceIds[object], name, className, path)
                    end

                    if CONFIG.RuntimeTraceToolAttributes
                        or CONFIG.RuntimeTraceAllAttributes
                    then
                        F.watchRuntimeAttributes(
                            object,
                            instanceIds[object],
                            name,
                            className,
                            path,
                            F.getAttributes(object)
                        )
                    end

                    if F.safeIsA(object, "ValueBase") then
                        F.watchRuntimeValue(object, instanceIds[object], name, className, path)
                    end
                end)
            end)
        end)

        if ok and connection then
            table.insert(runtimeConnections, connection)
        else
            F.recordWarning("RuntimeDynamicTrace", nil, connection)
        end
    end

    if CONFIG.RuntimeTraceGui then
        local ok, connection = pcall(function()
            return game.DescendantRemoving:Connect(function(object)
                if guiCapture.Observed[object] and runtimeTraceActive then
                    F.appendGuiRuntimeRecord(object, "Removing")
                end
            end)
        end)
        if ok and connection then
            table.insert(runtimeConnections, connection)
        end
    end

    if CONFIG.VisualCapture then
        local visualOk, visualConnection = pcall(function()
            return game.DescendantAdded:Connect(function(object)
                if not runtimeTraceActive or not F.isVisualAsset(object) then return end
                -- Capture immediately: short-lived effects may be destroyed next frame.
                F.captureDynamicVisual(object, "OnAdded")
                local delaySeconds = math.max(0, tonumber(CONFIG.VisualSecondPassDelay) or 0)
                if delaySeconds > 0 then
                    task.delay(delaySeconds, function()
                        if runtimeTraceActive and object.Parent then
                            F.captureDynamicVisual(object, "AfterInitialization")
                        end
                    end)
                end
            end)
        end)
        if visualOk and visualConnection then
            table.insert(runtimeConnections, visualConnection)
        else
            F.recordWarning("RuntimeVisualCapture", nil, visualConnection)
        end
        local removingOk, removingConnection = pcall(function()
            return game.DescendantRemoving:Connect(function(object)
                if runtimeTraceActive and visualDynamicByInstance[object] then
                    F.captureDynamicVisual(object, "BeforeRemoval")
                end
            end)
        end)
        if removingOk and removingConnection then
            table.insert(runtimeConnections, removingConnection)
        else
            F.recordWarning("RuntimeVisualRemoval", nil, removingConnection)
        end
        task.spawn(function()
            local sampleDelay = math.max(0.25, tonumber(CONFIG.VisualAnimatorSampleInterval) or 0.6)
            while runtimeTraceActive do
                for animator in pairs(visualAnimatorInstances) do
                    if not runtimeTraceActive then break end
                    if animator.Parent then
                        F.captureAnimatorPlayback(animator, "RuntimeSample")
                    end
                end
                task.wait(sampleDelay)
            end
        end)
    end

    if CONFIG.RuntimePrimeBeforeSnapshot then
        F.primeRuntimeObservers()
    end

    if LocalPlayer then
        if SELECTION.InteractionResearch then
            for _, parent in ipairs({
                LocalPlayer:FindFirstChildOfClass("Backpack"),
                LocalPlayer.Character,
                LocalPlayer:FindFirstChildOfClass("StarterGear")
            }) do
                if parent then
                    for _, child in ipairs(parent:GetChildren()) do
                        F.watchResearchTool(child)
                    end
                end
            end
        end
        F.watchLocalCharacter(LocalPlayer.Character)

        local addedOk, addedConnection = pcall(function()
            return LocalPlayer.CharacterAdded:Connect(function(newCharacter)
                if not runtimeTraceActive then
                    return
                end

                F.watchLocalCharacter(newCharacter)
                if SELECTION.InteractionResearch then
                    for _, child in ipairs(newCharacter:GetChildren()) do
                        F.watchResearchTool(child)
                    end
                end
            end)
        end)

        if addedOk and addedConnection then
            table.insert(runtimeConnections, addedConnection)
        end

        local removingOk, removingConnection = pcall(function()
            return LocalPlayer.CharacterRemoving:Connect(function(oldCharacter)
                if not runtimeTraceActive then
                    return
                end

                F.appendRuntimeCharacterRecord(
                    "CharacterRemoving",
                    oldCharacter,
                    nil
                )
            end)
        end)

        if removingOk and removingConnection then
            table.insert(runtimeConnections, removingConnection)
        end
    end

    if CONFIG.RuntimeCaptureLogs then
        local logOk, logConnection = pcall(function()
            return game:GetService("LogService").MessageOut:Connect(function(message, messageType)
                if not runtimeTraceActive then
                    return
                end

                F.appendRuntimeLog(message, messageType)
            end)
        end)

        if logOk and logConnection then
            table.insert(runtimeConnections, logConnection)
        else
            F.recordWarning("RuntimeLogTrace", nil, logConnection)
        end
    end

    local errorSignalOk, errorSignal = pcall(function()
        return game:GetService("GuiService").ErrorMessageChanged
    end)

    if errorSignalOk and errorSignal then
        local connectionOk, connection = pcall(function()
            return errorSignal:Connect(function(message)
                if runtimeHookState.Frozen then
                    return
                end

                local current = F.getCurrentGuiErrorMessage()
                if (not current or current == "") and type(message) == "string" then
                    current = message
                end

                F.handleGuiErrorMessage(current, "GuiService.ErrorMessageChanged")
            end)
        end)

        if connectionOk and connection then
            table.insert(runtimeConnections, connection)
        else
            F.recordWarning("RuntimeDisconnectTrace", nil, connection)
        end
    else
        F.recordWarning(
            "RuntimeDisconnectTrace",
            nil,
            "GuiService.ErrorMessageChanged unavailable; polling fallback will be used"
        )
    end

    local sampleAccumulator = 0
    local errorAccumulator = 0
    local hookIntegrityAccumulator = 0
    local recoveryAccumulator = 0

    local heartbeatOk, heartbeatConnection = pcall(function()
        return game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
            recoveryAccumulator = recoveryAccumulator + deltaTime
            if recoveryAccumulator >= CONFIG.RecoveryFlushSeconds then
                recoveryAccumulator = 0
                if flushRecovery then pcall(flushRecovery, false) end
                if writeDiagnostics and currentStage ~= "complete" then
                    pcall(writeDiagnostics, runtimeHookState.Frozen and "Disconnected" or "InProgress")
                end
            end
            if not runtimeTraceActive then
                return
            end

            sampleAccumulator = sampleAccumulator + deltaTime
            errorAccumulator = errorAccumulator + deltaTime
            hookIntegrityAccumulator = hookIntegrityAccumulator + deltaTime

            local sampleInterval = math.max(
                0.03,
                tonumber(CONFIG.RuntimeCharacterSampleInterval) or 0.15
            )

            if CONFIG.RuntimeTraceCharacter and sampleAccumulator >= sampleInterval then
                sampleAccumulator = 0
                F.sampleLocalCharacter()
            end

            if errorAccumulator >= 0.25 then
                errorAccumulator = 0
                local message = F.getCurrentGuiErrorMessage()
                if message and message ~= "" then
                    F.handleGuiErrorMessage(message, "GuiServicePoll")
                end
            end

            local hookInterval =
                math.max(0.03, tonumber(CONFIG.RuntimeHookIntegrityInterval) or 0.20)
            if CONFIG.RuntimeTraceHookDiagnostics
                and hookIntegrityAccumulator >= hookInterval
            then
                hookIntegrityAccumulator = 0
                F.checkRuntimeHookIntegrity(false, "Heartbeat")
            end
        end)
    end)

    if heartbeatOk and heartbeatConnection then
        table.insert(runtimeConnections, heartbeatConnection)
    else
        F.recordWarning("RuntimeHeartbeatTrace", nil, heartbeatConnection)
    end
end

function F.getSortedChildren(object)
    local ok, children = pcall(function()
        return object:GetChildren()
    end)
    if not ok then
        F.recordError("GetChildren", object, children)
        return {}
    end
    if selectedSnapshotNodes then
        local filtered = {}
        for index = 1, #children do
            local child = children[index]
            if selectedSnapshotNodes[child] then
                filtered[#filtered + 1] = child
            end
        end
        children = filtered
    end
    if #children <= 1 then return children end
    local keys = {}
    for _, child in ipairs(children) do
        keys[child] = { Class = F.safeClassName(child):lower(), Name = F.safeName(child):lower() }
    end
    table.sort(children, function(a, b)
        local left, right = keys[a], keys[b]
        if left.Class ~= right.Class then return left.Class < right.Class end
        return left.Name < right.Name
    end)
    return children
end

function F.makeFailedNode(object, parentId, dumpError)
    local id = F.assignInstanceId(object)
    local name = F.safeName(object)
    local className = F.safeClassName(object)
    local path = F.safeFullName(object)
    F.updateInstanceMeta(object, id, parentId, name, className, path)

    return {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        ParentId = parentId,
        DumpError = F.sanitizeString(dumpError),
        Tags = {},
        Children = {}
    }
end

local dumpNode

dumpNode = function(object, parentId, context)
    if (selectedSnapshotNodes and not selectedSnapshotNodes[object])
        or object == selectionGui then
        return nil, "filtered"
    end
    local previousVisitId = traversedInstances[object]
    if previousVisitId then
        local previousMeta = instanceMetaById[previousVisitId]
        F.recordWarning(
            "RevisitedInstance",
            object,
            string.format(
                "Instance #%d was already traversed at %s and was skipped on a later encounter",
                previousVisitId,
                previousMeta and previousMeta.Path or "<unknown>"
            )
        )
        return nil, "revisited"
    end

    local id = F.assignInstanceId(object)
    local expectedParent = context and context.ParentObject or nil
    if expectedParent then
        local actualParent, parentReadable = F.safeGet(object, "Parent")
        if parentReadable and actualParent ~= expectedParent then
            F.recordWarning(
                "ParentChangedBeforeVisit",
                object,
                "Instance changed parent after GetChildren() and was skipped from the stale parent snapshot"
            )
            return nil, "parent_changed"
        end
    end

    local name = F.safeName(object)
    local className = F.safeClassName(object)
    local path = F.safeFullName(object)
    recoveryLastPath = path
    recoveryLastClass = className

    if invalidClassObjects[object] and not invalidClassWarned[object] then
        invalidClassWarned[object] = true
        F.recordWarning(
            "InvalidClassName",
            object,
            "ClassName was empty or unreadable and was replaced with Instance"
        )
    end

    traversedInstances[object] = id
    F.updateInstanceMeta(object, id, parentId, name, className, path)

    nodeCount = nodeCount + 1

    local checkpointEvery = math.max(0, tonumber(CONFIG.ProgressCheckpointEvery) or 0)
    if checkpointEvery > 0
        and nodeCount % checkpointEvery == 0
        and checkpointStage
    then
        checkpointStage("snapshot_traversal")
    end

    if nodeCount % YIELD_EVERY == 0 then
        F.logProgress(false, "snapshot")
        local now = os.clock()
        if now - lastTraversalYield >= (CONFIG.MaxTraversalSliceSeconds or 0.014) then
            local heavy = CONFIG.HeavyGameYieldAfterNodes or 12000
            task.wait(nodeCount >= heavy and (CONFIG.HeavyGameYieldSeconds or 0) or 0)
            lastTraversalYield = os.clock()
        end
    end
    local source = F.resolveInventorySource(object, context and context.InventorySource or nil)
    local parentToolState = context and context.ToolState or nil

    classCounts[className] = (classCounts[className] or 0) + 1

    -- A filtered export needs full data for selected classes, but its
    -- ancestor-only nodes do not need expensive visual/physics property reads.
    local isValue = SELECTION.Values and F.classIsA(object, className, "ValueBase")
    local isVisual = SELECTION.Visuals and F.isVisualAsset(object, className)
    local isRemote = REMOTE_BUCKETS[className] ~= nil
    local isScript = SCRIPT_BUCKETS[className] ~= nil
    local needsAttributes = not CONFIG.FastSelectiveCapture or SELECTION.Structure
        or SELECTION.Values or SELECTION.PlayersTools or SELECTION.Runtime
        or (SELECTION.Remotes and isRemote) or isVisual
    local needsTags = not CONFIG.FastSelectiveCapture or SELECTION.Structure
        or (SELECTION.Remotes and isRemote) or isValue or isVisual
    local needsProperties = not CONFIG.FastSelectiveCapture or SELECTION.Structure
        or SELECTION.PlayersTools or isVisual or isValue
        or (SELECTION.GUI and F.GUI_CLASSES[className])
        or ((SELECTION.Scripts or SELECTION.LocalSources or SELECTION.ModuleSources) and isScript)
    local attributes = needsAttributes and F.getAttributes(object) or {}
    local tags = needsTags and F.getTags(object) or {}
    if runtimeTraceActive then
        for _, tag in ipairs(tags) do F.V38.watchTags(tag) end
    end
    local properties = needsProperties and F.getUsefulProperties(object, className) or {}
    local metaRecord = instanceMetaById[id]
    if metaRecord then
        metaRecord.HasAttributes = next(attributes) ~= nil
        metaRecord.IsValueBase = F.classIsA(object, className, "ValueBase")
    end
    if SELECTION.Visuals then F.V38.trackAssets(object, properties, "Snapshot") end

    if SELECTION.Structure and #tags > 0 then
        for _, tag in ipairs(tags) do tagCounts[tag] = (tagCounts[tag] or 0) + 1 end
        if #tagRecords < CONFIG.MaxTagRecords then
            tagRecords[#tagRecords + 1] = { Id = id, Path = path, ClassName = className, Tags = tags }
        else
            tagOmitted = tagOmitted + 1
        end
    end
    if SELECTION.Structure and INTERACTION_CLASSES[className] then
        if #interactionRecords < CONFIG.MaxInteractionRecords then
            interactionRecords[#interactionRecords + 1] = {
                Id = id, ParentId = parentId, Name = name, Path = path,
                ClassName = className,
                Properties = not CONFIG.CompactSecondaryIndexes and properties or nil,
                Attributes = not CONFIG.CompactSecondaryIndexes and F.optionalMap(attributes) or nil,
                Tags = tags
            }
        else interactionOmitted = interactionOmitted + 1 end
    end
    if SELECTION.Structure and PHYSICS_CLASSES[className] then
        if #physicsRecords < CONFIG.MaxPhysicsRecords then
            physicsRecords[#physicsRecords + 1] = {
                Id = id, ParentId = parentId, Name = name, Path = path,
                ClassName = className,
                Properties = not CONFIG.CompactSecondaryIndexes and properties or nil,
                Attributes = not CONFIG.CompactSecondaryIndexes and F.optionalMap(attributes) or nil
            }
        else physicsOmitted = physicsOmitted + 1 end
    end
    if journalRecord then
        journalRecord("Snapshot", {
            Id = id, ParentId = parentId, Name = name, ClassName = className,
            Path = path, Attributes = F.optionalMap(attributes), Tags = tags,
            Properties = F.optionalMap(properties)
        })
    end
    if flushRecovery and nodeCount % math.max(1, CONFIG.RecoverySnapshotBatch) == 0 then
        flushRecovery(true)
    end

    if className == "Animator" and CONFIG.VisualCapture then
        F.registerVisualAnimator(object)
        F.captureAnimatorPlayback(object, "Snapshot")
    end

    if CONFIG.VisualCapture and isVisual then
        if #visualSnapshotRecords < math.max(0, CONFIG.VisualMaxSnapshotEntries) then
            visualSnapshotSaved = visualSnapshotSaved + 1
            visualSnapshotRecords[#visualSnapshotRecords + 1] = F.makeVisualRecord(
                object, id, parentId, name, className, path, attributes, tags, properties
            )
        else
            visualSnapshotOmitted = visualSnapshotOmitted + 1
        end
    end

    if SELECTION.Values then F.registerAttributes(id, name, className, path, attributes) end
    if SELECTION.GUI then F.captureSnapshotGui(object, id, parentId, name, className, path, properties) end
    if SELECTION.Remotes then F.registerRemote(object, id, name, className, parentId, path, attributes, tags) end
    if SELECTION.Scripts or SELECTION.LocalSources or SELECTION.ModuleSources then
        F.registerScript(object, id, name, className, parentId, path, properties)
    end
    if SELECTION.Values then F.registerValue(object, id, name, className, parentId, path, attributes, tags) end
    if SELECTION.PlayersTools then F.registerToolDescendant(parentToolState, object, id, className, name) end

    if SELECTION.PlayersTools then
        F.scanAttributesForPlayerReferences(id, attributes)
        F.scanValueForPlayerReferences(id, "Name", name)
        for property, value in pairs(properties) do
            if type(value) == "string" then
                F.scanValueForPlayerReferences(id, "Property:" .. property, value)
            end
        end
        if F.safeIsA(object, "ValueBase") then
            local rawValue, readable = F.safeGet(object, "Value")
            if readable then F.scanValueForPlayerReferences(id, "Value", rawValue) end
        end
    end

    F.watchRuntimeRemote(object, id, name, className, path)
    F.watchResearchTool(object)
    F.watchResearchInteraction(object, className)
    F.watchRuntimeAttributes(object, id, name, className, path, attributes)
    F.watchRuntimeValue(object, id, name, className, path)
    F.watchRuntimeGui(object)
    F.V38.observeInstance(object, className)

    local currentToolState = parentToolState
    if SELECTION.PlayersTools and (className == "Tool" or F.safeIsA(object, "Tool")) then
        currentToolState = F.createToolRecord(
            object,
            id,
            name,
            className,
            path,
            source,
            attributes,
            properties
        )
    end

    local node = {
        Id = id,
        Name = name,
        ClassName = className,
        Path = path,
        ParentId = parentId,
        Attributes = F.optionalMap(attributes),
        Tags = tags,
        Properties = F.optionalMap(properties),
        Children = {}
    }

    for _, child in ipairs(F.getSortedChildren(object)) do
        local ok, childData, childStatus = pcall(
            dumpNode,
            child,
            id,
            {
                InventorySource = source,
                ToolState = currentToolState,
                ParentObject = object
            }
        )

        if ok then
            if childData then
                table.insert(node.Children, childData)
            elseif childStatus == nil then
                F.recordError("DumpNode", child, "dumpNode returned no data")
            end
        else
            F.recordError("DumpNode", child, childData)
            table.insert(node.Children, F.makeFailedNode(child, id, childData))
        end
    end

    if expectedParent then
        local finalParent, parentReadable = F.safeGet(object, "Parent")
        if parentReadable and finalParent ~= expectedParent then
            F.recordWarning(
                "ParentChangedDuringVisit",
                object,
                "Instance changed parent while it was being dumped; the node keeps its first-seen snapshot location"
            )
        end
    end

    return node
end

function F.makeTree(node)
    local output = {}
    local nodeStack = { node }
    local depthStack = { 0 }
    local processed = 0

    while #nodeStack > 0 do
        local stackIndex = #nodeStack
        local current = nodeStack[stackIndex]
        local depth = depthStack[stackIndex]
        nodeStack[stackIndex] = nil
        depthStack[stackIndex] = nil

        local prefix = string.rep("    ", depth)
        local suffix = current.DumpError and " [dump error]" or ""

        output[#output + 1] = string.format(
            "%s%s [%s] (#%s)%s",
            prefix,
            F.escapeText(current.Name),
            F.escapeText(current.ClassName),
            tostring(current.Id),
            suffix
        )

        for index = #current.Children, 1, -1 do
            nodeStack[#nodeStack + 1] = current.Children[index]
            depthStack[#depthStack + 1] = depth + 1
        end

        processed = processed + 1
        if processed % 2000 == 0 then
            task.wait()
        end
    end

    return output
end

function F.sortRecordsByPath(records)
    table.sort(records, function(a, b)
        if a.Path ~= b.Path then
            return a.Path < b.Path
        end

        return a.Id < b.Id
    end)
end

function F.tokenizeText(value)
    local text = F.sanitizeString(value or "")
    text = string.gsub(text, "([a-z0-9])([A-Z])", "%1 %2")
    text = string.gsub(text, "[^%w]+", " ")

    local tokens = {}
    local seen = {}

    for token in string.gmatch(text, "%w+") do
        local lowered = string.lower(token)
        if not seen[lowered] then
            seen[lowered] = true
            table.insert(tokens, token)
        end
    end

    return tokens
end

function F.buildAncestorNames(parentId)
    local reverse = {}
    local currentId = parentId
    local guard = 0

    while currentId and guard < 128 do
        guard = guard + 1
        local meta = instanceMetaById[currentId]
        if not meta then
            break
        end

        table.insert(reverse, meta.Name)
        currentId = meta.ParentId
    end

    local result = {}
    for index = #reverse, 1, -1 do
        table.insert(result, reverse[index])
    end

    return result
end

function F.enrichRemoteRecords()
    for _, bucket in pairs(remoteIndex) do
        for _, record in ipairs(bucket) do
            record.Ancestors = F.buildAncestorNames(record.ParentId)

            local tokenMap = {}
            local tokens = {}

            local function addTokens(value)
                for _, token in ipairs(F.tokenizeText(value)) do
                    local lowered = string.lower(token)
                    if not tokenMap[lowered] then
                        tokenMap[lowered] = true
                        table.insert(tokens, token)
                    end
                end
            end

            addTokens(record.Name)
            for _, ancestorName in ipairs(record.Ancestors) do
                addTokens(ancestorName)
            end

            table.sort(tokens, function(a, b)
                return string.lower(a) < string.lower(b)
            end)

            record.Tokens = tokens
        end
    end
end

function F.buildPathStats(instanceIndex)
    local counts = {}

    for _, meta in ipairs(instanceIndex) do
        counts[meta.Path] = (counts[meta.Path] or 0) + 1
    end

    local collisions = {}
    local groups = 0
    local affected = 0

    for path, count in pairs(counts) do
        if count > 1 then
            groups = groups + 1
            affected = affected + count
            table.insert(collisions, {
                Path = path,
                Count = count
            })
        end
    end

    table.sort(collisions, function(a, b)
        if a.Count ~= b.Count then
            return a.Count > b.Count
        end

        return a.Path < b.Path
    end)

    local top = {}
    for index = 1, math.min(50, #collisions) do
        top[index] = collisions[index]
    end

    return {
        DuplicatePathGroups = groups,
        InstancesInDuplicatePaths = affected,
        TopCollisions = top
    }
end

function F.buildPlayerIndex()
    local referenceCounts = {}
    for _, reference in ipairs(playerReferences) do
        referenceCounts[reference.UserId] = (referenceCounts[reference.UserId] or 0) + 1
    end

    local records = {}

    for _, descriptor in ipairs(playerDescriptors) do
        local player = descriptor.Player
        local team, teamReadable = F.safeGet(player, "Team")
        local teamColor, teamColorReadable = F.safeGet(player, "TeamColor")
        local neutral, neutralReadable = F.safeGet(player, "Neutral")

        local record = {
            Name = F.sanitizeString(descriptor.Name),
            DisplayName = F.sanitizeString(descriptor.DisplayName),
            UserId = descriptor.UserId,
            PlayerId = instanceIds[player],
            CharacterId = descriptor.Character and instanceIds[descriptor.Character] or nil,
            BackpackId = descriptor.Backpack and instanceIds[descriptor.Backpack] or nil,
            PlayerGuiId = descriptor.PlayerGui and instanceIds[descriptor.PlayerGui] or nil,
            StarterGearId = descriptor.StarterGear and instanceIds[descriptor.StarterGear] or nil,
            ReferenceCount = referenceCounts[descriptor.UserId] or 0
        }

        if teamReadable and team then
            record.NativeTeam = F.makeInstanceReference(team)
        end

        if teamColorReadable and teamColor ~= nil then
            record.TeamColor = serializeValue(teamColor)
        end

        if neutralReadable and neutral ~= nil then
            record.Neutral = neutral
        end

        table.insert(records, record)
    end

    return {
        Total = #records,
        Players = records
    }
end

local STATE_BUCKETS = {
    Players = function(meta) return meta.ClassName == "Player" end,
    Values = function(meta) return meta.IsValueBase == true end,
    Attributes = function(meta) return meta.HasAttributes == true end,
    Tools = function(meta) return meta.ClassName == "Tool" end,
    Remotes = function(meta) return REMOTE_BUCKETS[meta.ClassName] ~= nil end,
    Interfaces = function(meta) return F.GUI_CLASSES[meta.ClassName] == true end,
    Humanoids = function(meta) return meta.ClassName == "Humanoid" end
}

function F.stateRecordFromMeta(meta, valueById)
    local record = {
        Id = meta.Id, Name = meta.Name, ClassName = meta.ClassName,
        Path = meta.Path, ParentId = meta.ParentId
    }
    local valueRecord = valueById[meta.Id]
    if valueRecord then record.Value = valueRecord.Value end
    return record
end

function F.buildStateIndex(instanceIndex)
    local buckets, counts, valueById, attributeIds = {}, {}, {}, {}
    for _, valueRecord in ipairs(valueRecords) do valueById[valueRecord.Id] = valueRecord end
    for _, row in ipairs(attributeIndex) do attributeIds[row.Id] = true end
    for bucketName in pairs(STATE_BUCKETS) do
        buckets[bucketName] = {}
        counts[bucketName] = 0
    end
    for _, meta in ipairs(instanceIndex) do
        local className = meta.ClassName
        for bucketName, predicate in pairs(STATE_BUCKETS) do
            local matched
            if bucketName == "Values" then
                matched = predicate(meta) or valueById[meta.Id] ~= nil
            elseif bucketName == "Attributes" then
                matched = predicate(meta) or attributeIds[meta.Id] == true
            else
                matched = predicate(meta)
            end
            if matched then
                counts[bucketName] = counts[bucketName] + 1
                if #buckets[bucketName] < CONFIG.StateIndexMaxPerBucket then
                    buckets[bucketName][#buckets[bucketName] + 1] =
                        F.stateRecordFromMeta(meta, valueById)
                end
            end
        end
    end
    return { Counts = counts, Buckets = buckets }
end

function F.finalizeIndexes()
    F.sortRecordsByPath(attributeIndex)
    F.sortRecordsByPath(toolRecords)
    F.sortRecordsByPath(valueRecords)

    table.sort(playerReferences, function(a, b)
        if a.UserId ~= b.UserId then
            return a.UserId < b.UserId
        end

        if a.ObjectId ~= b.ObjectId then
            return a.ObjectId < b.ObjectId
        end

        if a.Field ~= b.Field then
            return a.Field < b.Field
        end

        return a.MatchKind < b.MatchKind
    end)

    for _, bucket in pairs(remoteIndex) do
        F.sortRecordsByPath(bucket)
    end

    for _, bucket in pairs(scriptIndex) do
        F.sortRecordsByPath(bucket)
    end

    for _, record in ipairs(toolRecords) do
        table.sort(record.AnimationIds)
        table.sort(record.SoundIds)
        table.sort(record.ValueIds)
        table.sort(record.DescendantIds)
    end

    for _, ids in pairs(inventoryToolIds) do
        table.sort(ids)
    end

    F.enrichRemoteRecords()
end

function F.buildInstanceIndex()
    local list = {}

    for id = 1, nextInstanceId do
        local meta = instanceMetaById[id]
        if meta then
            table.insert(list, meta)
        end
    end

    return list
end

function F.buildInventory()
    return {
        Player = LocalPlayer and F.makeInstanceReference(LocalPlayer) or nil,
        Backpack = F.makeInstanceReference(backpack),
        Character = F.makeInstanceReference(character),
        StarterGear = F.makeInstanceReference(starterGear),
        ToolIds = inventoryToolIds
    }
end

function F.totalBucketCount(index)
    local total = 0
    for _, bucket in pairs(index) do
        total = total + #bucket
    end
    return total
end

function F.totalRemoteCount()
    return F.totalBucketCount(remoteIndex)
end

function F.totalScriptCount()
    return F.totalBucketCount(scriptIndex)
end

function F.buildSummary(elapsed, pathStats)
    local classes = {}

    for className, count in pairs(classCounts) do
        table.insert(classes, {
            ClassName = className,
            Count = count
        })
    end

    table.sort(classes, function(a, b)
        if a.Count ~= b.Count then
            return a.Count > b.Count
        end

        return a.ClassName < b.ClassName
    end)

    local lines = {
        "Schema: " .. SCHEMA_NAME,
        "Schema Version: " .. tostring(SCHEMA_VERSION),
        "Game: " .. F.sanitizeString(game.Name),
        "PlaceId: " .. tostring(game.PlaceId),
        "GameId: " .. tostring(game.GameId),
        "JobId: " .. F.sanitizeString(game.JobId),
        "Serialized Instance Records: " .. tostring(nextInstanceId),
        "Traversed Descendants: " .. tostring(nodeCount),
        "Registered IDs: " .. tostring(nextInstanceId),
        "Remotes / Bindables: " .. tostring(F.totalRemoteCount()),
        "Scripts: " .. tostring(F.totalScriptCount()),
        "Interaction Research: " .. tostring(SELECTION.InteractionResearch),
        "Outgoing Hook (opt-in): " .. tostring(CONFIG.RuntimeTraceOutgoingRemotes),
        "LocalScripts queued for decompile: " .. tostring(clientDecompileStats.Queued),
        "LocalScripts decompiled: " .. tostring(clientDecompileStats.Succeeded),
        "LocalScripts decompile failed: " .. tostring(clientDecompileStats.Failed),
        "LocalScripts decompile skipped: " .. tostring(clientDecompileStats.Skipped),
        "ModuleScripts queued for decompile: " .. tostring(moduleDecompileStats.Queued),
        "ModuleScripts decompiled: " .. tostring(moduleDecompileStats.Succeeded),
        "ModuleScripts decompile failed: " .. tostring(moduleDecompileStats.Failed),
        "ModuleScripts decompile timed out: " .. tostring(moduleDecompileStats.TimedOut),
        "ModuleScripts ignored by DecompileIgnore: " .. tostring(moduleDecompileStats.Ignored),
        "ModuleScripts decompile skipped: " .. tostring(moduleDecompileStats.Skipped),
        "Objects With Attributes: " .. tostring(#attributeIndex),
        "ValueBase Records: " .. tostring(#valueRecords),
        "GUI Elements: " .. tostring(guiCapture.SnapshotSaved),
        "GUI Snapshot Omitted: " .. tostring(guiCapture.SnapshotOmitted),
        "Player References: " .. tostring(#playerReferences),
        "Tools: " .. tostring(#toolRecords),
        "Duplicate Path Groups: " .. tostring(pathStats.DuplicatePathGroups),
        "Instances In Duplicate Paths: " .. tostring(pathStats.InstancesInDuplicatePaths),
        "Errors: " .. tostring(#errors),
        "Warnings: " .. tostring(#warnings),
        "Sanitized invalid UTF-8 unique strings: " .. tostring(invalidUtf8StringCount),
        "Invalid / empty class names: " .. tostring(invalidClassNameCount),
        "Time: " .. string.format("%.2fs", elapsed),
        "Runtime Trace: " .. tostring(CONFIG.RuntimeTrace),
        "Runtime Trace Frozen: " .. tostring(runtimeHookState.Frozen),
        "Runtime Ring Window: " .. tostring(CONFIG.RuntimeRingWindowSeconds) .. "s",
        "Runtime Remote Events: " .. tostring(#runtimeEventRecords),
        "  RemoteEvent: " .. tostring(#runtimeEventCategoryRecords.RemoteEvent),
        "  UnreliableRemoteEvent: " .. tostring(#runtimeEventCategoryRecords.UnreliableRemoteEvent),
        "  RemoteFunction: " .. tostring(#runtimeEventCategoryRecords.RemoteFunction),
        "  Other: " .. tostring(#runtimeEventCategoryRecords.Other),
        "Runtime Value Changes: " .. tostring(#runtimeValueRecords),
        "Runtime Attribute Changes: " .. tostring(#runtimeAttributeRecords),
        "Runtime GUI Changes: " .. tostring(#guiCapture.Records),
        "Runtime Character Records: " .. tostring(#runtimeCharacterRecords),
        "Runtime Log Records: " .. tostring(#runtimeLogRecords),
        "Runtime Timeline Records: " .. tostring(#runtimeTimelineRecords),
        "Runtime Error Messages: " .. tostring(#runtimeErrorRecords),
        "Runtime Hook Observations: " .. tostring(#runtimeHookState.HookRecords),
        "Runtime Hook Integrity Records: " .. tostring(#runtimeHookState.HookIntegrityRecords),
        "Buffer Capture: " .. tostring(CONFIG.RuntimeCaptureBuffers and capabilities.buffer_len),
        "Outgoing Remote Hook: " .. tostring(CONFIG.RuntimeTraceOutgoingRemotes and capabilities.hookmetamethod and capabilities.getnamecallmethod),
        "",
        "Top Duplicate Paths:"
    }

    if #pathStats.TopCollisions == 0 then
        table.insert(lines, "(none)")
    else
        for index = 1, math.min(10, #pathStats.TopCollisions) do
            local collision = pathStats.TopCollisions[index]
            table.insert(
                lines,
                string.format("%dx %s", collision.Count, F.escapeText(collision.Path))
            )
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Class Counts:")

    for _, entry in ipairs(classes) do
        table.insert(
            lines,
            string.format("%s: %d", entry.ClassName, entry.Count)
        )
    end

    return table.concat(lines, "\n")
end

function F.encodeJSON(data, label)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if ok then
        return result, true
    end

    F.recordError("JSONEncode", nil, result, label)

    local fallbackOk, fallback = pcall(function()
        return HttpService:JSONEncode({
            Error = F.sanitizeString(result),
            Message = F.sanitizeString(label .. " export failed")
        })
    end)

    if fallbackOk then
        return fallback, false
    end

    return "{}", false
end

function F.ensureFolder(path)
    if capabilities.isfolder then
        local ok, exists = pcall(isfolder, path)
        if ok and exists then
            return true
        end
    end

    if capabilities.makefolder then
        local ok = pcall(makefolder, path)
        if ok then
            return true
        end

        if capabilities.isfolder then
            local checkOk, exists = pcall(isfolder, path)
            if checkOk and exists then
                return true
            end
        end

        if not capabilities.isfolder then
            return true
        end
    end

    return false
end

function F.selectOutputFolder()
    local base = "GameStructureDump"
    local chosen = base
    if capabilities.isfolder then
        local count = 1
        while count <= 100000 do
            local ok, exists = pcall(isfolder, chosen)
            if not ok then
                return false, "isfolder failed: " .. tostring(exists)
            end
            if not exists then break end
            count = count + 1
            chosen = base .. tostring(count)
        end
        if count > 100000 then
            return false, "unable to find an unused dump folder"
        end
    else
        -- Without isfolder, never risk silently overwriting an existing dump.
        local ok, guid = pcall(function() return HttpService:GenerateGUID(false) end)
        if not ok then return false, "isfolder unavailable and could not generate a unique fallback name" end
        chosen = base .. "_" .. tostring(guid):gsub("%-", "")
    end

    local old = OUTPUT_FOLDER
    local function move(path)
        if type(path) == "string" and path:sub(1, #old + 1) == old .. "/" then
            return chosen .. path:sub(#old + 1)
        end
        return path
    end
    META_FILE = move(META_FILE)
    TREE_FILE = move(TREE_FILE)
    STRUCTURE_FILE = move(STRUCTURE_FILE)
    INSTANCES_FILE = move(INSTANCES_FILE)
    VISUAL_ASSETS_FILE = move(VISUAL_ASSETS_FILE)
    GUI_FILE = move(GUI_FILE)
    RUNTIME_VISUAL_ASSETS_FILE = move(RUNTIME_VISUAL_ASSETS_FILE)
    REMOTES_FILE = move(REMOTES_FILE)
    SCRIPTS_FILE = move(SCRIPTS_FILE)
    SUMMARY_FILE = move(SUMMARY_FILE)
    INVENTORY_FILE = move(INVENTORY_FILE)
    ATTRIBUTES_FILE = move(ATTRIBUTES_FILE)
    TOOLS_FILE = move(TOOLS_FILE)
    VALUES_FILE = move(VALUES_FILE)
    PLAYERS_FILE = move(PLAYERS_FILE)
    AVATAR_INSPECTION_FILE = move(AVATAR_INSPECTION_FILE)
    PLAYER_REFERENCES_FILE = move(PLAYER_REFERENCES_FILE)
    STATE_FILE = move(STATE_FILE)
    MANIFEST_FILE = move(MANIFEST_FILE)
    ERRORS_FILE = move(ERRORS_FILE)
    WARNINGS_FILE = move(WARNINGS_FILE)
    DIAGNOSTICS_FILE = move(DIAGNOSTICS_FILE)
    CRASH_FILE = move(CRASH_FILE)
    PREVIOUS_RUN_FILE = move(PREVIOUS_RUN_FILE)
    RECOVERY_FOLDER = move(RECOVERY_FOLDER)
    TAGS_FILE = move(TAGS_FILE)
    INTERACTIONS_FILE = move(INTERACTIONS_FILE)
    PHYSICS_FILE = move(PHYSICS_FILE)
    REMOTE_USAGE_FILE = move(REMOTE_USAGE_FILE)
    INTERACTION_RESEARCH_FILE = move(INTERACTION_RESEARCH_FILE)
    INTERACTION_EVENTS_FILE = move(INTERACTION_EVENTS_FILE)
    SOURCE_REFERENCES_FILE = move(SOURCE_REFERENCES_FILE)
    CONNECTION_RESEARCH_FILE = move(CONNECTION_RESEARCH_FILE)
    MODULE_SOURCES_FOLDER = move(MODULE_SOURCES_FOLDER)
    CLIENT_SOURCES_FOLDER = move(CLIENT_SOURCES_FOLDER)
    for kind, path in pairs(RUNTIME_FILES) do
        RUNTIME_FILES[kind] = move(path)
    end
    OUTPUT_FOLDER = chosen
    if not F.ensureOutputFolder() then
        return false, "failed to create: " .. chosen
    end
    return true
end

function F.ensureOutputFolder()
    return F.ensureFolder(OUTPUT_FOLDER)
end

function F.writeSafe(path, contents)
    local ok, writeError = pcall(writefile, path, contents)
    if not ok then
        F.recordError("WriteFile", nil, writeError, path)
        return false
    end

    return true
end


F.avatarInspection = {
    Active = false, Records = {}, LastSignatures = {}, LastSavedAt = 0,
    Connections = {}, WatchedPlayers = {}, Descriptions = setmetatable({}, { __mode = "k" }),
    CapturedPlayerIds = {}, UniquePlayers = 0, Errors = {}, Skipped = 0,
    StartedAt = nil, MaxRecords = 480, MaxAccessories = 48
}

F.AVATAR_DESCRIPTION_PROPERTIES = {
    "RightLeg", "LeftLeg", "RightArm", "LeftArm", "Torso", "Head", "Face",
    "Shirt", "Pants", "GraphicTShirt", "HairAccessory", "HatAccessory",
    "FaceAccessory", "NeckAccessory", "ShouldersAccessory", "FrontAccessory",
    "BackAccessory", "WaistAccessory", "EyebrowAccessory", "EyelashAccessory",
    "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale",
    "ProportionScale", "RightLegColor", "LeftLegColor", "LeftArmColor",
    "RightArmColor", "HeadColor", "TorsoColor", "IdleAnimation",
    "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation",
    "ClimbAnimation", "SwimAnimation", "MoodAnimation"
}
F.AVATAR_PART_PROPERTIES = {
    "Size", "MeshSize", "MeshId", "TextureID", "Color", "Transparency",
    "Material", "Reflectance", "CastShadow", "CFrame", "PivotOffset", "LocalTransparencyModifier"
}
F.AVATAR_JOINT_CLASSES = {
    Motor6D = true, AnimationConstraint = true, Weld = true, ManualWeld = true,
    WeldConstraint = true, RigidConstraint = true
}

function F.avatarRead(object, property)
    if not object then return nil end
    local ok, value = pcall(function() return object[property] end)
    if not ok or value == nil then return nil end
    local typ = typeof(value)
    if typ == "Instance" then
        local fullPathOk, fullPath = pcall(function() return value:GetFullName() end)
        return {
            Name = F.safeName(value), ClassName = F.safeClassName(value),
            Path = fullPathOk and F.sanitizeString(fullPath) or nil
        }
    end
    local converted, result = pcall(serializeValue, value, {
        seen = {}, depth = 0, noAssignInstanceId = true
    })
    return converted and result or F.sanitizeString(tostring(value))
end

function F.avatarProps(object, keys)
    local result = {}
    for _, key in ipairs(keys) do
        local value = F.avatarRead(object, key)
        if value ~= nil then result[key] = value end
    end
    return result
end

function F.avatarChildNames(parent, classFilter, limit)
    local result = {}
    local ok, children = pcall(function() return parent:GetChildren() end)
    if not ok then return result end
    for _, child in ipairs(children) do
        if not classFilter or classFilter[F.safeClassName(child)] then
            local info = {
                Name = F.safeName(child), ClassName = F.safeClassName(child)
            }
            if child:IsA("Attachment") then
                info.Properties = F.avatarProps(child, { "CFrame", "Position", "Orientation", "Axis", "SecondaryAxis" })
            elseif child:IsA("SpecialMesh") then
                info.Properties = F.avatarProps(child, { "MeshId", "TextureId", "Scale", "Offset", "MeshType" })
            elseif child:IsA("Vector3Value") then
                info.Properties = F.avatarProps(child, { "Value" })
            elseif child:IsA("SurfaceAppearance") then
                info.Properties = F.avatarProps(child, { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" })
            elseif child:IsA("WrapLayer") then
                info.Properties = F.avatarProps(child, { "ReferenceMeshId", "CageMeshId", "Order", "Puffiness", "AutoSkin" })
            elseif child:IsA("WrapTarget") then
                info.Properties = F.avatarProps(child, { "CageMeshId", "Stiffness" })
            end
            result[#result + 1] = info
            if #result >= limit then break end
        end
    end
    return result
end

function F.avatarGetDescription(humanoid, character)
    local cache = F.avatarInspection.Descriptions[character]
    if cache and os.clock() - cache.At < 15 then
        return cache.Properties, cache.Accessories, cache.Error
    end
    local ok, description = pcall(function() return humanoid:GetAppliedDescription() end)
    local result, accessories, err = nil, nil, nil
    if ok and description then
        result = F.avatarProps(description, F.AVATAR_DESCRIPTION_PROPERTIES)
        local accOk, acc = pcall(function() return description:GetAccessories(true) end)
        if accOk and type(acc) == "table" then
            accessories = {}
            for i, value in ipairs(acc) do
                if i > 80 then break end
                accessories[#accessories + 1] = {
                    AssetId = value.AssetId, AccessoryType = tostring(value.AccessoryType),
                    IsLayered = value.IsLayered, Order = value.Order, Puffiness = value.Puffiness
                }
            end
        end
    else
        err = F.sanitizeString(tostring(description))
    end
    F.avatarInspection.Descriptions[character] = {
        At = os.clock(), Properties = result, Accessories = accessories, Error = err
    }
    return result, accessories, err
end

function F.avatarCapturePlayer(player, reason, force)
    if not F.avatarInspection.Active then return end
    local ok, err = pcall(function()
        local character = player.Character
        local record = {
            TimeSeconds = math.floor((os.clock() - F.avatarInspection.StartedAt) * 100) / 100,
            Reason = reason, Name = F.safeName(player), UserId = player.UserId,
            DisplayName = F.avatarRead(player, "DisplayName"),
            HasCharacter = character ~= nil, RigType = nil,
            Description = nil, DescriptionAccessories = nil,
            BodyParts = {}, BodyJoints = {}, LegParts = {}, LegJoints = {}, Accessories = {}, ScaleValues = {}, RigHierarchy = nil, AppearanceDiscrepancies = {}
        }
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                record.RigType = F.avatarRead(humanoid, "RigType")
                record.Description, record.DescriptionAccessories, record.DescriptionError =
                    F.avatarGetDescription(humanoid, character)
                record.Humanoid = F.avatarProps(humanoid, { "HipHeight", "AutoRotate" })
                F.V38.trackAssets(player, record.Description, "AvatarDescription")
                for _, scaleName in ipairs({
                    "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale",
                    "BodyTypeScale", "BodyProportionScale"
                }) do
                    local scale = humanoid:FindFirstChild(scaleName)
                    if scale and scale:IsA("NumberValue") then
                        record.ScaleValues[scaleName] = F.avatarRead(scale, "Value")
                    end
                end
            else
                record.DescriptionError = "Humanoid missing at capture"
            end

            local legParts, bodyParts = {}, {}
            local rigRoot = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
            record.RootPart = rigRoot and F.safeFullName(rigRoot) or nil
            local descendantsOk, descendants = pcall(function() return character:GetDescendants() end)
            if descendantsOk then
                for _, part in ipairs(descendants) do
                    if F.safeIsA(part, "BasePart")
                        and not part:FindFirstAncestorOfClass("Accessory")
                        and not part:FindFirstAncestorOfClass("Tool") then
                        if #record.BodyParts >= 180 then
                            record.BodyPartsOmitted = (record.BodyPartsOmitted or 0) + 1
                        else
                            bodyParts[part] = true
                            local name = F.safeName(part)
                            local lowerName = string.lower(name)
                            local isLeg = lowerName:find("leg", 1, true) ~= nil
                                or lowerName:find("foot", 1, true) ~= nil
                            if isLeg then legParts[part] = true end
                            local fields = F.avatarProps(part, F.AVATAR_PART_PROPERTIES)
                            F.V38.trackAssets(part, fields, "AvatarBody")
                            local extra = F.avatarChildNames(part, {
                                Attachment = true, SpecialMesh = true, Vector3Value = true,
                                SurfaceAppearance = true, WrapLayer = true, WrapTarget = true
                            }, 30)
                            local item = {
                                Name = name, Path = F.safeFullName(part), ClassName = part.ClassName,
                                Properties = fields, Children = extra,
                                RelativeToRoot = rigRoot and F.V38.relativeFrame(rigRoot, part) or nil,
                                OriginalSize = (part:FindFirstChild("OriginalSize") and
                                    F.avatarRead(part:FindFirstChild("OriginalSize"), "Value")) or nil
                            }
                            record.BodyParts[#record.BodyParts + 1] = item
                            if isLeg then record.LegParts[#record.LegParts + 1] = item end
                        end
                    end
                end
            end
            if descendantsOk then
                for _, item in ipairs(descendants) do
                    local class = F.safeClassName(item)
                    if F.AVATAR_JOINT_CLASSES[class] then
                        local part0Ok, part0 = pcall(function() return item.Part0 end)
                        local part1Ok, part1 = pcall(function() return item.Part1 end)
                        local a0Ok, a0 = pcall(function() return item.Attachment0 end)
                        local a1Ok, a1 = pcall(function() return item.Attachment1 end)
                        local relevant = (part0Ok and bodyParts[part0]) or (part1Ok and bodyParts[part1])
                        if not relevant then
                            if a0Ok and a0 and bodyParts[a0.Parent] then relevant = true end
                            if a1Ok and a1 and bodyParts[a1.Parent] then relevant = true end
                        end
                        if relevant and #record.BodyJoints < 100 then
                            local joint = F.V38.captureJoint(item, character)
                            record.BodyJoints[#record.BodyJoints + 1] = joint
                            if (part0Ok and legParts[part0]) or (part1Ok and legParts[part1])
                                or (a0Ok and a0 and legParts[a0.Parent])
                                or (a1Ok and a1 and legParts[a1.Parent]) then
                                record.LegJoints[#record.LegJoints + 1] = joint
                            end
                        end
                    elseif class == "Accessory" and #record.Accessories < F.avatarInspection.MaxAccessories then
                        local handle = item:FindFirstChild("Handle")
                        local handleInfo = nil
                        if handle and handle:IsA("BasePart") then
                            handleInfo = {
                                ClassName = handle.ClassName,
                                Properties = F.avatarProps(handle, F.AVATAR_PART_PROPERTIES),
                                Children = F.avatarChildNames(handle, {
                                    SpecialMesh = true, Attachment = true, SurfaceAppearance = true
                                }, 12)
                            }
                        end
                        local accessoryInfo = F.V38.captureAccessory(item, handle, character)
                        accessoryInfo.Handle = handleInfo
                        if handleInfo then F.V38.trackAssets(handle, handleInfo.Properties, "AvatarAccessory") end
                        record.Accessories[#record.Accessories + 1] = accessoryInfo
                    end
                end
            end
        end

        table.sort(record.BodyParts, function(a, b) return a.Name < b.Name end)
        table.sort(record.BodyJoints, function(a, b) return a.Name < b.Name end)
        table.sort(record.LegParts, function(a, b) return a.Name < b.Name end)
        table.sort(record.LegJoints, function(a, b) return a.Name < b.Name end)
        table.sort(record.Accessories, function(a, b) return a.Name < b.Name end)
        record.RigHierarchy = F.V38.buildRigHierarchy(record)
        record.AppearanceDiscrepancies, record.AssetIdentityComparisons = F.V38.compareAppearance(record)
        local signatureData = {
            HasCharacter = record.HasCharacter, RigType = record.RigType,
            Description = record.Description, DescriptionAccessories = record.DescriptionAccessories,
            ScaleValues = record.ScaleValues, Accessories = {}, BodyParts = {}, JointConfiguration = {}
        }
        for _, part in ipairs(record.BodyParts) do
            signatureData.BodyParts[#signatureData.BodyParts + 1] = {
                Name = part.Name, ClassName = part.ClassName,
                MeshId = part.Properties.MeshId, TextureID = part.Properties.TextureID,
                Size = part.Properties.Size, MeshSize = part.Properties.MeshSize,
                OriginalSize = part.OriginalSize, Children = part.Children
            }
        end
        for _, joint in ipairs(record.BodyJoints) do
            signatureData.JointConfiguration[#signatureData.JointConfiguration + 1] = {
                Name = joint.Name, ClassName = joint.ClassName, Part0 = joint.Properties.Part0,
                Part1 = joint.Properties.Part1, C0 = joint.QuantizedC0, C1 = joint.QuantizedC1,
                Enabled = joint.Properties.Enabled
            }
        end
        for _, accessory in ipairs(record.Accessories) do
            signatureData.Accessories[#signatureData.Accessories + 1] = {
                Name = accessory.Name,
                AccessoryType = accessory.AccessoryType,
                MeshId = accessory.Handle and accessory.Handle.Properties.MeshId,
                TextureID = accessory.Handle and accessory.Handle.Properties.TextureID
            }
        end
        local sigOk, signature = pcall(function() return HttpService:JSONEncode(signatureData) end)
        signature = sigOk and signature or tostring(character)
        local previous = F.avatarInspection.LastSignatures[player.UserId]
        if previous and previous.SignatureData then
            record.JointChanges = F.V38.diffJoints(previous.SignatureData.JointConfiguration, signatureData.JointConfiguration)
        end
        local changed = not previous or previous.Character ~= character or previous.Signature ~= signature
        local checkpoint = not previous or os.clock() - previous.At >= 30
        if not changed and not checkpoint and not force then return end
        F.avatarInspection.LastSignatures[player.UserId] = {
            At = os.clock(), Character = character, Signature = signature, SignatureData = signatureData
        }
        if #F.avatarInspection.Records >= F.avatarInspection.MaxRecords then
            F.avatarInspection.Skipped = F.avatarInspection.Skipped + 1
            return
        end
        record.Changed = changed
        F.avatarInspection.Records[#F.avatarInspection.Records + 1] = record
        if not F.avatarInspection.CapturedPlayerIds[player.UserId] then
            F.avatarInspection.CapturedPlayerIds[player.UserId] = true
            F.avatarInspection.UniquePlayers = F.avatarInspection.UniquePlayers + 1
        end
    end)
    if not ok then
        if #F.avatarInspection.Errors < 45 then
            F.avatarInspection.Errors[#F.avatarInspection.Errors + 1] =
                { Player = F.safeName(player), Error = F.sanitizeString(tostring(err)) }
        end
    end
end

function F.avatarInspectionDocument()
    return {
        Schema = "Averyn.AvatarInspection", Version = 2, DumpId = currentDumpId,
        GeneratedAtUnix = os.time(), GameId = game.GameId, PlaceId = game.PlaceId,
        JobId = tostring(game.JobId), ReadOnly = true,
        Notes = {
            "RightLeg / LeftLeg in Description are body part asset IDs, not bundle IDs.",
            "MeshId and TextureID identify rendered meshes when client security permits reads.",
            "A player must have a streamed-in character for physical MeshPart measurements.",
            "This does not contain downloadable mesh binary geometry."
        },
        UniquePlayers = F.avatarInspection.UniquePlayers, Total = #F.avatarInspection.Records,
        Skipped = F.avatarInspection.Skipped, Errors = F.avatarInspection.Errors,
        Records = F.avatarInspection.Records
    }
end

function F.avatarWriteProgress(force)
    if not SELECTION.AvatarInspection then return end
    if not force and os.clock() - F.avatarInspection.LastSavedAt < 12 then return end
    F.avatarInspection.LastSavedAt = os.clock()
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(F.avatarInspectionDocument())
    end)
    if ok then F.writeSafe(AVATAR_INSPECTION_FILE, encoded) end
end

function F.avatarWatchPlayer(player)
    if F.avatarInspection.WatchedPlayers[player] then return end
    F.avatarInspection.WatchedPlayers[player] = true
    F.avatarInspection.Connections[#F.avatarInspection.Connections + 1] =
        player.CharacterAdded:Connect(function()
            task.delay(1, function() F.avatarCapturePlayer(player, "CharacterAdded", true) end)
            task.delay(4, function() F.avatarCapturePlayer(player, "CharacterReady", false) end)
        end)
    local appearanceOk, appearanceConnection = pcall(function()
        return player.CharacterAppearanceLoaded:Connect(function()
            local character = player.Character
            if character then F.avatarInspection.Descriptions[character] = nil end
            task.defer(function() F.avatarCapturePlayer(player, "AppearanceLoaded", true) end)
        end)
    end)
    if appearanceOk then
        F.avatarInspection.Connections[#F.avatarInspection.Connections + 1] = appearanceConnection
    end
    F.avatarCapturePlayer(player, "Initial", true)
end

function F.startAvatarInspection()
    if F.avatarInspection.Active then return end
    F.avatarInspection.Active = true
    F.avatarInspection.StartedAt = os.clock()
    for _, player in ipairs(Players:GetPlayers()) do
        F.avatarWatchPlayer(player)
    end
    F.avatarInspection.Connections[#F.avatarInspection.Connections + 1] =
        Players.PlayerAdded:Connect(F.avatarWatchPlayer)
    task.spawn(function()
        while F.avatarInspection.Active do
            task.wait(3)
            if not F.avatarInspection.Active then break end
            for _, player in ipairs(Players:GetPlayers()) do
                F.avatarWatchPlayer(player)
                F.avatarCapturePlayer(player, "Periodic", false)
            end
            F.avatarWriteProgress(false)
        end
    end)
    F.avatarWriteProgress(true)
    F.log("Avatar inspection v3.8 enabled | full body, joints, wraps, accessories, pose")
end

function F.finishAvatarInspection()
    if not F.avatarInspection.Active then return end
    for _, player in ipairs(Players:GetPlayers()) do
        F.avatarCapturePlayer(player, "Final", false)
    end
    F.avatarInspection.Active = false
    for _, connection in ipairs(F.avatarInspection.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(F.avatarInspection.Connections)
    F.avatarWriteProgress(true)
end

F.V38 = {
    SchemaVersion = 3.9,
    Events = {}, EventOmitted = 0, Connections = {},
    Observed = setmetatable({}, { __mode = "k" }), ObservedCount = 0,
    TagWatch = {}, TagEventCount = 0,
    AssetIndex = {}, AssetList = {}, AssetOmitted = 0,
    DependencyEdges = {}, DependencyOmitted = 0,
    RemoteStats = {}, RecentInputs = {}, RecentRemotes = {}, RecentEffects = {},
    SampledCamera = nil, LastCameraSample = 0,
    PlayerCharacters = setmetatable({}, { __mode = "k" }),
    CharacterSnapshots = {}, CharacterDeaths = {},
    BaselinePose = setmetatable({}, { __mode = "k" }),
    ToolSnapshots = {}, ToolOmitted = 0,
    ListenerMarkers = 0,
    CallbacksWrapped = setmetatable({}, { __mode = "k" }),
    CallbackCoverage = { NamecallHook = false, DirectCalls = "NotIntercepted", CallbackWrappingOptIn = false },
    Missing = {}, MissingCounts = {},
    Coverage = { TrackedObjects = 0, ObserversOmitted = 0, EventRecordsOmitted = 0, UnknownUnreplicatedObjects = true },
    MaxTrackedPlayerCharacters = 150
}

function F.V38.digest(value)
    if type(value) == "string" then return F.comparisonDigest(value) end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(value) end)
    if ok and type(encoded) == "string" then return F.comparisonDigest(encoded) end
    return F.comparisonDigest(F.sanitizeString(tostring(value)))
end

function F.V38.addEvent(kind, object, details)
    if not runtimeTraceActive then return end
    local r = F.V38
    if #r.Events >= CONFIG.V38MaxEvents then
        r.EventOmitted = r.EventOmitted + 1
        return
    end
    local row = {
        Time = os.clock() - runtimeStartedAt, Kind = kind,
        Object = object and F.safeFullName(object) or nil,
        ClassName = object and F.safeClassName(object) or nil,
        Details = details
    }
    r.Events[#r.Events + 1] = row
    if kind == "SoundPlayed" or kind == "ParticleEnabled" or kind == "ParticleEmitted"
        or kind == "BeamEnabled" or kind == "TrailEnabled" or kind == "VisualCreated" then
        r.RecentEffects[#r.RecentEffects + 1] = row
        if #r.RecentEffects > 150 then table.remove(r.RecentEffects, 1) end
        F.V38.trackEffectCorrelation(row)
    end
    if journalRecord then journalRecord("Runtime", { Kind = "V38:" .. kind, Data = row }) end
end

function F.V38.connect(signal, callback)
    if not signal then return false end
    local ok, connection = pcall(function() return signal:Connect(callback) end)
    if ok and connection then
        F.V38.Connections[#F.V38.Connections + 1] = connection
        return true
    end
    return false
end

function F.V38.signal(object, eventName, callback)
    local ok, signal = pcall(function() return object[eventName] end)
    return ok and F.V38.connect(signal, callback) or false
end

function F.V38.propertySignal(object, key, callback)
    local ok, signal = pcall(function() return object:GetPropertyChangedSignal(key) end)
    return ok and F.V38.connect(signal, callback) or false
end

function F.V38.relativeFrame(root, part)
    local ok, value = pcall(function() return root.CFrame:ToObjectSpace(part.CFrame) end)
    if not ok then return nil end
    local components = { value:GetComponents() }
    for i = 1, #components do components[i] = math.floor(components[i] * 1000 + 0.5) / 1000 end
    return components
end

function F.V38.frameKey(value)
    if typeof(value) ~= "CFrame" then return nil end
    local raw = { value:GetComponents() }
    local out = {}
    for i, n in ipairs(raw) do out[i] = (n >= 0 and math.floor(n * 100 + 0.5) or math.ceil(n * 100 - 0.5)) / 100 end
    return out
end

function F.V38.captureJoint(joint, character)
    local props = F.avatarProps(joint, {
        "Part0", "Part1", "Attachment0", "Attachment1", "C0", "C1", "Enabled", "Transform", "Active"
    })
    local row = {
        Name = F.safeName(joint), Path = F.safeFullName(joint), ClassName = F.safeClassName(joint),
        Properties = props
    }
    local ok0, c0 = pcall(function() return joint.C0 end)
    local ok1, c1 = pcall(function() return joint.C1 end)
    if ok0 then row.QuantizedC0 = F.V38.frameKey(c0) end
    if ok1 then row.QuantizedC1 = F.V38.frameKey(c1) end
    if row.ClassName == "Motor6D" then
        local ok, transform = pcall(function() return joint.Transform end)
        if ok and typeof(transform) == "CFrame" then
            local position = transform.Position.Magnitude
            local axis, angle = transform:ToAxisAngle()
            if position >= CONFIG.V38PoseTranslationTolerance
                or math.abs(angle) >= CONFIG.V38PoseRotationTolerance then
                row.PoseDifferenceFromRest = {
                    TranslationStuds = math.floor(position * 1000 + 0.5) / 1000,
                    RotationRadians = math.floor(math.abs(angle) * 1000 + 0.5) / 1000,
                    Observation = "May be normal animation; not an avatar mismatch"
                }
            end
            if not F.V38.BaselinePose[joint] then
                F.V38.BaselinePose[joint] = F.V38.frameKey(transform)
            end
            row.FirstObservedTransform = F.V38.BaselinePose[joint]
        end
    end
    return row
end

function F.V38.diffJoints(previous, current)
    local old = {}
    for _, joint in ipairs(previous or {}) do old[tostring(joint.Path or joint.Name) .. "|" .. tostring(joint.ClassName)] = joint end
    local changes = {}
    for _, joint in ipairs(current or {}) do
        local key = tostring(joint.Path or joint.Name) .. "|" .. tostring(joint.ClassName)
        local prior = old[key]
        if prior then
            local before = F.V38.digest(prior)
            local after = F.V38.digest(joint)
            if before ~= after then
                changes[#changes + 1] = { Joint = key, Before = prior, After = joint }
            end
            old[key] = nil
        else
            changes[#changes + 1] = { Joint = key, Change = "Added" }
        end
        if #changes >= 60 then break end
    end
    for key in pairs(old) do
        if #changes >= 60 then break end
        changes[#changes + 1] = { Joint = key, Change = "Removed" }
    end
    return changes
end

function F.V38.captureAccessory(accessory, handle, character)
    local row = {
        Name = F.safeName(accessory), Path = F.safeFullName(accessory),
        AccessoryType = F.avatarRead(accessory, "AccessoryType"),
        AttachmentPoint = F.avatarRead(accessory, "AttachmentPoint"),
        Welds = {}, Attachments = {}, Wraps = {}, LinkedBodyParts = {}, LinkingMethod = nil
    }
    local found = {}
    local descendantsOk, descendants = pcall(function() return accessory:GetDescendants() end)
    if not descendantsOk then return row end
    local bodyAttachments = {}
    for _, body in ipairs(character:GetChildren()) do
        if body:IsA("BasePart") then
            for _, attachment in ipairs(body:GetChildren()) do
                if attachment:IsA("Attachment") then
                    local name = F.safeName(attachment)
                    bodyAttachments[name] = bodyAttachments[name] or {}
                    bodyAttachments[name][#bodyAttachments[name] + 1] = body
                end
            end
        end
    end
    for _, item in ipairs(descendants) do
        local class = F.safeClassName(item)
        if F.AVATAR_JOINT_CLASSES[class] and #row.Welds < 30 then
            local info = F.V38.captureJoint(item, character)
            row.Welds[#row.Welds + 1] = info
            for _, field in ipairs({ "Part0", "Part1", "Attachment0", "Attachment1" }) do
                local ok, ref = pcall(function() return item[field] end)
                if ok and typeof(ref) == "Instance" then
                    local bodyPart = ref:IsA("Attachment") and ref.Parent or ref
                    if bodyPart and bodyPart.Parent == character and not found[bodyPart] then
                        found[bodyPart] = true
                        row.LinkedBodyParts[#row.LinkedBodyParts + 1] = F.safeName(bodyPart)
                        row.LinkingMethod = "JointReference"
                    end
                end
            end
        elseif class == "Attachment" and #row.Attachments < 30 then
            local attachmentName = F.safeName(item)
            row.Attachments[#row.Attachments + 1] = {
                Name = attachmentName, Path = F.safeFullName(item),
                Properties = F.avatarProps(item, { "CFrame", "Position", "Orientation", "Axis", "SecondaryAxis" })
            }
            for _, body in ipairs(bodyAttachments[attachmentName] or {}) do
                if not found[body] then
                    found[body] = true
                    row.LinkedBodyParts[#row.LinkedBodyParts + 1] = F.safeName(body)
                    if not row.LinkingMethod then row.LinkingMethod = "MatchingAttachmentName (inferred)" end
                end
            end
        elseif (class == "WrapLayer" or class == "WrapTarget") and #row.Wraps < 24 then
            row.Wraps[#row.Wraps + 1] = {
                Name = F.safeName(item), ClassName = class,
                Properties = F.avatarProps(item, class == "WrapLayer"
                    and { "ReferenceMeshId", "CageMeshId", "Order", "Puffiness", "AutoSkin" }
                    or { "CageMeshId", "Stiffness" })
            }
        end
    end
    table.sort(row.LinkedBodyParts)
    return row
end

function F.V38.buildRigHierarchy(record)
    local result = {
        RigType = record.RigType, Parts = {}, Joints = record.BodyJoints,
        Accessories = {}, RootPart = record.RootPart,
        PoseExplanation = "PoseDifferenceFromRest is an observation, not evidence of tampering"
    }
    for _, part in ipairs(record.BodyParts) do
        result.Parts[#result.Parts + 1] = {
            Name = part.Name, Path = part.Path, ClassName = part.ClassName,
            Properties = part.Properties, RelativeToRoot = part.RelativeToRoot,
            AttachmentsAndWraps = part.Children, OriginalSize = part.OriginalSize
        }
    end
    for _, accessory in ipairs(record.Accessories) do
        result.Accessories[#result.Accessories + 1] = {
            Name = accessory.Name, Path = accessory.Path,
            LinkedBodyParts = accessory.LinkedBodyParts, LinkingMethod = accessory.LinkingMethod,
            Attachments = accessory.Attachments, Welds = accessory.Welds, Wraps = accessory.Wraps,
            Handle = accessory.Handle
        }
    end
    return result
end

function F.V38.compareAppearance(record)
    local result, comparisons = {}, {}
    local descriptions = record.Description or {}
    local bodyAssetKeys = {
        Head = "Head", Torso = "Torso", UpperTorso = "Torso", LowerTorso = "Torso",
        ["Left Arm"] = "LeftArm", ["Right Arm"] = "RightArm",
        LeftUpperArm = "LeftArm", LeftLowerArm = "LeftArm", LeftHand = "LeftArm",
        RightUpperArm = "RightArm", RightLowerArm = "RightArm", RightHand = "RightArm",
        ["Left Leg"] = "LeftLeg", ["Right Leg"] = "RightLeg",
        LeftUpperLeg = "LeftLeg", LeftLowerLeg = "LeftLeg", LeftFoot = "LeftLeg",
        RightUpperLeg = "RightLeg", RightLowerLeg = "RightLeg", RightFoot = "RightLeg"
    }
    local pairsOfColors = {
        Head = "HeadColor", Torso = "TorsoColor", UpperTorso = "TorsoColor",
        LowerTorso = "TorsoColor", ["Left Arm"] = "LeftArmColor", ["Right Arm"] = "RightArmColor",
        ["Left Leg"] = "LeftLegColor", ["Right Leg"] = "RightLegColor",
        LeftUpperArm = "LeftArmColor", RightUpperArm = "RightArmColor",
        LeftUpperLeg = "LeftLegColor", RightUpperLeg = "RightLegColor"
    }
    for _, part in ipairs(record.BodyParts) do
        local key = pairsOfColors[part.Name]
        local expected = key and descriptions[key]
        local actual = part.Properties.Color
        if type(actual) == "table" and type(expected) == "table"
            and expected.__type == "Color3" and actual.__type == "Color3" then
            local distance = math.abs((actual.r or 0) - (expected.r or 0))
                + math.abs((actual.g or 0) - (expected.g or 0))
                + math.abs((actual.b or 0) - (expected.b or 0))
            if distance > 0.08 then
                result[#result + 1] = { BodyPart = part.Name, Property = "Color", Expected = expected,
                    Observed = actual, Reason = "Description and locally rendered color differ" }
            end
        end
        local bodyId = descriptions[bodyAssetKeys[part.Name]]
        if part.Properties.MeshId and tonumber(bodyId) and tonumber(bodyId) > 0 then
            comparisons[#comparisons + 1] = {
                BodyPart = part.Name, DescriptionAssetId = bodyId,
                RenderedMeshId = part.Properties.MeshId, TextureId = part.Properties.TextureID,
                Status = "Different asset identifier namespaces; cannot assert mismatch from ID comparison alone"
            }
        end
    end
    for name, descriptionKey in pairs({
        BodyHeightScale = "HeightScale", BodyWidthScale = "WidthScale", BodyDepthScale = "DepthScale",
        HeadScale = "HeadScale", BodyTypeScale = "BodyTypeScale", BodyProportionScale = "ProportionScale"
    }) do
        local actual = record.ScaleValues[name]
        local expected = descriptions[descriptionKey]
        if type(actual) == "number" and type(expected) == "number"
            and math.abs(actual - expected) > 0.03 then
            result[#result + 1] = { Property = name, Expected = expected, Observed = actual,
                Reason = "AppliedDescription and replicated humanoid scale value differ" }
        end
    end
    return result, comparisons
end

function F.V38.makeRigDocument()
    local byId = {}
    for _, row in ipairs(F.avatarInspection.Records) do
        if row.RigHierarchy then byId[tostring(row.UserId)] = {
            UserId = row.UserId, Name = row.Name, TimeSeconds = row.TimeSeconds,
            Hierarchy = row.RigHierarchy, JointChanges = row.JointChanges,
            AppearanceDiscrepancies = row.AppearanceDiscrepancies,
            AssetIdentityComparisons = row.AssetIdentityComparisons
        } end
    end
    local rigs = {}
    for _, row in pairs(byId) do rigs[#rigs + 1] = row end
    table.sort(rigs, function(a, b) return a.UserId < b.UserId end)
    return { Schema = "Averyn.RigHierarchy", Version = 1, DumpId = currentDumpId,
        TotalPlayers = #rigs, Note = "Best-effort client-replicated rig, not mesh binary data", Players = rigs }
end

function F.V38.trackAssets(object, properties, source)
    if type(properties) ~= "table" then return end
    local r = F.V38
    for property, value in pairs(properties) do
        if (type(value) == "string" or type(value) == "number") and type(property) == "string" then
            value = tostring(value)
            local k = string.lower(property)
            if k:find("id", 1, true) or k:find("texture", 1, true)
                or k == "head" or k == "torso" or k == "leftarm" or k == "rightarm"
                or k == "leftleg" or k == "rightleg" or k == "face"
                or k == "shirt" or k == "pants" or k == "graphictshirt"
                or k:find("animation", 1, true) or k:find("accessory", 1, true)
                or k:find("map", 1, true) or k:find("image", 1, true)
                or k:find("asset", 1, true) or k:find("graphic", 1, true)
                or k:find("template", 1, true) or k == "video" then
                local id = value:match("[?&]id=(%d+)") or value:match("rbxassetid://(%d+)")
                    or value:match("^%s*(%d+)%s*$")
                if id and id ~= "0" then
                    local entry = r.AssetIndex[id]
                    if not entry then
                        if #r.AssetList >= CONFIG.V38MaxAssetIds then
                            r.AssetOmitted = r.AssetOmitted + 1
                        else
                            entry = { Id = id, TotalReferences = 0, Properties = {}, References = {}, ReferenceOmitted = 0, _Seen = {} }
                            r.AssetIndex[id] = entry
                            r.AssetList[#r.AssetList + 1] = entry
                        end
                    end
                    if entry then
                        local path = F.safeFullName(object)
                        local key = path .. "|" .. property
                        if not entry._Seen[key] then
                            entry.TotalReferences = entry.TotalReferences + 1
                            entry.Properties[property] = (entry.Properties[property] or 0) + 1
                            if #entry.References < CONFIG.V38MaxReferencesPerAsset then
                                entry.References[#entry.References + 1] = {
                                    Path = path, ClassName = F.safeClassName(object),
                                    Property = property, Source = source
                                }
                            else
                                entry.ReferenceOmitted = entry.ReferenceOmitted + 1
                            end
                            entry._Seen[key] = true
                        end
                    end
                end
            end
        end
    end
end

function F.V38.visualEvent(kind, object, details)
    F.V38.addEvent(kind, object, details)
end

function F.V38.watchMarker(track, marker, log)
    if type(marker) ~= "string" or #marker == 0 or #marker > 80 then return end
    local r = F.V38
    if not r.TrackMarkerNames then r.TrackMarkerNames = setmetatable({}, { __mode = "k" }) end
    local names = r.TrackMarkerNames[track]
    if not names then names = {} r.TrackMarkerNames[track] = names end
    if names[marker] or r.ListenerMarkers >= CONFIG.V38MaxMarkerListeners then return end
    local ok, signal = pcall(function() return track:GetMarkerReachedSignal(marker) end)
    if ok and F.V38.connect(signal, function(value)
        log("AnimationMarkerReached", { Marker = marker, Value = F.sanitizeString(tostring(value)) })
    end) then
        names[marker] = true
        r.ListenerMarkers = r.ListenerMarkers + 1
    end
end

function F.V38.discoverAnimationMarkers(track, log)
    if not CONFIG.V38DiscoverAnimationMarkers then return end
    local r = F.V38
    local ok, assetId = pcall(function() return track.Animation.AnimationId end)
    if not ok or type(assetId) ~= "string" or assetId == "" then return end
    r.MarkerLookupCache = r.MarkerLookupCache or {}
    local cached = r.MarkerLookupCache[assetId]
    if type(cached) == "table" then
        for _, name in ipairs(cached) do F.V38.watchMarker(track, name, log) end
        return
    end
    if cached == false or (r.MarkerLookupsRequested or 0) >= CONFIG.V38MaxMarkerAssetLookups then return end
    r.MarkerLookupsRequested = (r.MarkerLookupsRequested or 0) + 1
    r.MarkerLookupCache[assetId] = false
    task.spawn(function()
        r.MarkerLookupsActive = r.MarkerLookupsActive or 0
        local startedWait = os.clock()
        while r.MarkerLookupsActive >= CONFIG.V38MaxMarkerLookupConcurrent
            and runtimeTraceActive and os.clock() - startedWait < 6 do
            task.wait(0.2)
        end
        if not runtimeTraceActive then return end
        r.MarkerLookupsActive = r.MarkerLookupsActive + 1
        local loaded, sequence = pcall(function()
            return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync(assetId)
        end)
        local discovered, seen = {}, {}
        if loaded and sequence then
            local framesOk, frames = pcall(function() return sequence:GetKeyframes() end)
            if framesOk then
                for _, frame in ipairs(frames) do
                    local markersOk, markers = pcall(function() return frame:GetMarkers() end)
                    if markersOk then
                        for _, marker in ipairs(markers) do
                            local name = F.safeName(marker)
                            if not seen[name] and #discovered < 40 then
                                seen[name] = true
                                discovered[#discovered + 1] = name
                            end
                        end
                    end
                end
            end
            pcall(function() sequence:Destroy() end)
        else
            F.V38.markMissing("AnimationMarkerAssetUnavailable", assetId)
        end
        r.MarkerLookupsActive = math.max(0, r.MarkerLookupsActive - 1)
        r.MarkerLookupCache[assetId] = discovered
        if runtimeTraceActive then
            for _, name in ipairs(discovered) do F.V38.watchMarker(track, name, log) end
        end
    end)
end

function F.V38.watchAnimationTrack(track, animator, alreadyPlaying)
    local r = F.V38
    if not r.Active or not track then return end
    if not r.Tracks then r.Tracks = setmetatable({}, { __mode = "k" }) end
    if r.Tracks[track] then return end
    r.Tracks[track] = true
    local function log(event, details)
        F.V38.addEvent(event, animator, {
            Track = F.avatarRead(track, "Name"), Animation = F.avatarRead(track, "Animation"),
            AnimationId = (function()
                local ok, id = pcall(function() return track.Animation.AnimationId end)
                return ok and id or nil
            end)(),
            Properties = F.avatarProps(track, { "TimePosition", "Priority", "Speed", "WeightCurrent", "WeightTarget" }),
            Details = details
        })
    end
    log(alreadyPlaying and "AnimationObservedPlaying" or "AnimationStarted", nil)
    F.V38.signal(track, "Stopped", function() log("AnimationStopped", nil) end)
    F.V38.signal(track, "Ended", function() log("AnimationEnded", nil) end)
    F.V38.signal(track, "DidLoop", function() log("AnimationLooped", nil) end)
    F.V38.signal(track, "KeyframeReached", function(name)
        log("AnimationKeyframeReached", { Keyframe = F.sanitizeString(tostring(name)) })
    end)
    F.V38.discoverAnimationMarkers(track, log)
end

function F.V38.watchAnimator(animator)
    F.V38.signal(animator, "AnimationPlayed", function(track)
        F.V38.watchAnimationTrack(track, animator)
    end)
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if ok and type(tracks) == "table" then
        for _, track in ipairs(tracks) do F.V38.watchAnimationTrack(track, animator, true) end
    end
end

function F.V38.watchVisual(object, className)
    if className == "Animator" then
        F.V38.watchAnimator(object)
    elseif className == "Sound" then
        for _, event in ipairs({ "Played", "Paused", "Resumed", "Stopped", "Ended", "DidLoop" }) do
            F.V38.signal(object, event, function()
                F.V38.visualEvent("Sound" .. event, object, F.avatarProps(object,
                    { "SoundId", "TimePosition", "Volume", "PlaybackSpeed", "Playing" }))
            end)
        end
        F.V38.propertySignal(object, "SoundId", function()
            F.V38.visualEvent("SoundIdChanged", object, { SoundId = F.avatarRead(object, "SoundId") })
        end)
    elseif className == "ParticleEmitter" then
        for _, prop in ipairs({ "Enabled", "Rate", "Texture", "Color", "Transparency", "Size", "Speed" }) do
            F.V38.propertySignal(object, prop, function()
                local value = F.avatarRead(object, prop)
                F.V38.visualEvent((prop == "Enabled" and value == true) and "ParticleEnabled"
                    or "ParticlePropertyChanged", object, { Property = prop, Value = value })
            end)
        end
        -- ParticleEmitter:Emit(count) has no passive event; do not falsely report emitted particles.
    elseif className == "Beam" or className == "Trail" then
        F.V38.propertySignal(object, "Enabled", function()
            local active = F.avatarRead(object, "Enabled")
            F.V38.visualEvent(className .. (active and "Enabled" or "Disabled"), object,
                { Enabled = active })
        end)
    end
    local visualFields = {
        BasePart = { "Color", "Material", "MaterialVariant", "Transparency", "Size" },
        MeshPart = { "MeshId", "TextureID" },
        SpecialMesh = { "MeshId", "TextureId", "Scale" },
        Decal = { "Texture", "Transparency" }, Texture = { "Texture", "Transparency" },
        SurfaceAppearance = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" },
        MaterialVariant = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap", "BaseMaterial" },
        AudioPlayer = { "AssetId", "Playing", "Volume", "TimePosition" }
    }
    local fields = visualFields[className]
    if not fields and F.safeIsA(object, "BasePart") then fields = visualFields.BasePart end
    local merged, seen = {}, {}
    if F.safeIsA(object, "BasePart") then
        for _, property in ipairs(visualFields.BasePart) do
            if not seen[property] then seen[property] = true merged[#merged + 1] = property end
        end
    end
    if fields then
        for _, property in ipairs(fields) do
            if not seen[property] then seen[property] = true merged[#merged + 1] = property end
        end
    end
    for _, property in ipairs(merged) do
        F.V38.propertySignal(object, property, function()
            F.V38.visualEvent("VisualPropertyChanged", object, {
                Property = property, Value = F.avatarRead(object, property)
            })
        end)
    end
end

function F.V38.toolAppearance(tool, phase)
    local items, truncated = {}, false
    local ok, descendants = pcall(function() return tool:GetDescendants() end)
    if not ok then return { Phase = phase, Error = "DescendantsInaccessible" } end
    for index, item in ipairs(descendants) do
        if index > 140 then truncated = true break end
        local class = F.safeClassName(item)
        if F.safeIsA(item, "BasePart") or class == "SpecialMesh" or class == "Decal"
            or class == "Texture" or class == "SurfaceAppearance" or class == "MaterialVariant" then
            items[#items + 1] = { Path = F.safeFullName(item), ClassName = class,
                Properties = F.avatarProps(item, {
                    "MeshId", "TextureID", "TextureId", "Texture", "Color", "Material",
                    "MaterialVariant", "Transparency", "Size", "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap"
                }) }
        end
    end
    return { Phase = phase, Time = os.clock() - runtimeStartedAt, Tool = F.safeFullName(tool),
        ToolProperties = F.avatarProps(tool, { "Grip", "GripForward", "GripRight", "GripUp",
            "GripPos", "RequiresHandle", "TextureId", "Enabled" }),
        Items = items, Truncated = truncated }
end

function F.V38.captureRigAndCameraState(tool, event)
    local camera = workspace.CurrentCamera
    local row = {
        Event = event, Camera = camera and F.avatarProps(camera,
            { "CFrame", "Focus", "CameraType", "CameraSubject", "FieldOfView" }) or nil,
        Tool = tool and F.safeFullName(tool) or nil, Parts = {}, Joints = {}, Tracks = {}
    }
    local character = LocalPlayer and LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if F.safeIsA(part, "BasePart") and #row.Parts < 60
                and not part:FindFirstAncestorOfClass("Accessory")
                and not part:FindFirstAncestorOfClass("Tool") then
                row.Parts[#row.Parts + 1] = {
                    Path = F.safeFullName(part), ClassName = F.safeClassName(part),
                    Properties = F.avatarProps(part, { "CFrame", "Size", "LocalTransparencyModifier" }) }
            elseif F.safeClassName(part) == "Motor6D" and #row.Joints < 70 then
                row.Joints[#row.Joints + 1] = F.V38.captureJoint(part, character)
            elseif F.safeClassName(part) == "Animator" then
                row.Tracks = F.getAnimatorPlaybackTracks(part) or {}
            end
        end
    end
    return row
end

function F.V38.watchTool(tool)
    if not LocalPlayer then return end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    if not ((backpack and F.safeIsDescendantOf(tool, backpack))
        or (character and F.safeIsDescendantOf(tool, character))) then return end
    local r = F.V38
    if not r.Tools then r.Tools = setmetatable({}, { __mode = "k" }) end
    if r.Tools[tool] then return end
    r.Tools[tool] = true
    local function snapshot(phase)
        if not runtimeTraceActive then return end
        if #r.ToolSnapshots >= 350 then r.ToolOmitted = r.ToolOmitted + 1 return end
        local record = F.V38.toolAppearance(tool, phase)
        record.CharacterRigAndCamera = F.V38.captureRigAndCameraState(tool, phase)
        r.ToolSnapshots[#r.ToolSnapshots + 1] = record
        F.V38.addEvent("Tool" .. phase, tool, { AppearanceSnapshot = #r.ToolSnapshots })
    end
    snapshot("Observed")
    F.V38.signal(tool, "Equipped", function()
        snapshot("Equipped")
        task.delay(0.12, function()
            if runtimeTraceActive then snapshot("EquippedSettled") end
        end)
    end)
    F.V38.signal(tool, "Unequipped", function() snapshot("Unequipped") end)
    F.V38.signal(tool, "Activated", function() snapshot("Activated") end)
    F.V38.signal(tool, "Deactivated", function() snapshot("Deactivated") end)
end

function F.V38.watchConstraint(object, className)
    local fields = {
        "Enabled", "Active", "Part0", "Part1", "Attachment0", "Attachment1",
        "C0", "C1", "LimitsEnabled", "TargetAngle", "AngularVelocity", "Length"
    }
    for _, property in ipairs(fields) do
        F.V38.propertySignal(object, property, function()
            F.V38.addEvent("PhysicsPropertyChanged", object,
                { Property = property, Value = F.avatarRead(object, property) })
        end)
    end
end

function F.V38.watchTags(tag)
    local r = F.V38
    if r.TagWatch[tag] then return end
    local count = 0
    for _ in pairs(r.TagWatch) do count = count + 1 end
    if count >= CONFIG.V38MaxTags then
        F.V38.markMissing("LimitReached", "TagWatcherCap")
        return
    end
    r.TagWatch[tag] = true
    for _, action in ipairs({ "Added", "Removed" }) do
        local ok, signal = pcall(function()
            return action == "Added" and CollectionService:GetInstanceAddedSignal(tag)
                or CollectionService:GetInstanceRemovedSignal(tag)
        end)
        if ok then
            F.V38.connect(signal, function(object)
                r.TagEventCount = r.TagEventCount + 1
                F.V38.addEvent("Tag" .. action, object, { Tag = tag })
            end)
        end
    end
end

function F.V38.observeInstance(object, className)
    local r = F.V38
    if not runtimeTraceActive or r.Observed[object] then return end
    className = className or F.safeClassName(object)
    local isVisual = SELECTION.Visuals and (F.safeIsA(object, "BasePart")
        or className == "Animator" or className == "Sound" or className == "ParticleEmitter"
        or className == "Beam" or className == "Trail" or className == "AudioPlayer"
        or className == "MeshPart" or className == "Part" or className == "SpecialMesh"
        or className == "Decal" or className == "Texture" or className == "MaterialVariant"
        or className == "SurfaceAppearance")
    local isPhysics = SELECTION.Structure and PHYSICS_CLASSES[className]
        and className ~= "Attachment" and className ~= "Bone"
    local isTool = className == "Tool"
    local isBindable = (className == "BindableEvent"
        or className == "BindableFunction" or className == "RemoteFunction")
    if not isVisual and not isPhysics and not isTool and not isBindable then return end
    if r.ObservedCount >= CONFIG.V38MaxObserved then
        r.Coverage.ObserversOmitted = r.Coverage.ObserversOmitted + 1
        return
    end
    local commonPart = F.safeIsA(object, "BasePart") and not isTool
    if commonPart then
        r.LowPriorityObserved = r.LowPriorityObserved or 0
        local parent = object.Parent
        local isEquipment = parent and (F.safeIsA(parent, "Tool") or F.safeIsA(parent, "Accessory"))
        local isCharacter = parent and F.safeIsA(parent, "Model")
            and parent:FindFirstChildOfClass("Humanoid") ~= nil
        if not isEquipment and not isCharacter then
            if r.LowPriorityObserved >= 500 then
                r.Coverage.ObserversOmitted = r.Coverage.ObserversOmitted + 1
                return
            end
            r.LowPriorityObserved = r.LowPriorityObserved + 1
        end
    end
    r.Observed[object] = true
    r.ObservedCount = r.ObservedCount + 1
    if isVisual then F.V38.watchVisual(object, className) end
    if isPhysics then F.V38.watchConstraint(object, className) end
    if isTool then F.V38.watchTool(object) end
    if isBindable then F.V38.watchBindable(object, className) end
end

function F.V38.markMissing(category, detail)
    local r = F.V38
    local key = tostring(category) .. "|" .. tostring(detail)
    r.MissingCounts[key] = (r.MissingCounts[key] or 0) + 1
    if not r.Missing[key] then
        local count = 0
        for _ in pairs(r.Missing) do count = count + 1 end
        if count < 120 then r.Missing[key] = true end
    end
end

function F.V38.inferValue(value, depth, seen)
    local kind = typeof(value)
    if kind == "buffer" then
        local size = nil
        if type(buffer) == "table" and type(buffer.len) == "function" then
            local ok, result = pcall(buffer.len, value)
            if ok then size = result end
        end
        return { Type = "buffer", Length = size }
    end
    if kind ~= "table" then
        return { Type = kind, InstanceClass = kind == "Instance" and F.safeClassName(value) or nil }
    end
    if seen[value] then return { Type = "table", Circular = true } end
    if depth >= CONFIG.V38MaxNestedDepth then return { Type = "table", DepthLimit = true } end
    seen[value] = true
    local entries, n, omitted = {}, 0, 0
    for key, child in pairs(value) do
        n = n + 1
        if n <= CONFIG.V38MaxNestedItems then
            entries[#entries + 1] = {
                KeyType = typeof(key), Key = F.sanitizeString(tostring(key)):sub(1, 80),
                Shape = F.V38.inferValue(child, depth + 1, seen)
            }
        else
            omitted = omitted + 1
        end
    end
    seen[value] = nil
    table.sort(entries, function(a, b)
        return a.KeyType == b.KeyType and a.Key < b.Key or a.KeyType < b.KeyType
    end)
    return { Type = "table", Size = n, Entries = entries, Omitted = omitted,
        Note = "Observed client-side schema; not a definitive remote contract" }
end

function F.V38.inferPacked(packed)
    local results = {}
    if type(packed) ~= "table" then return results end
    for index = 1, math.min(packed.n or #packed, 24) do
        local ok, shape = pcall(F.V38.inferValue, packed[index], 0, {})
        results[index] = ok and shape or { Type = typeof(packed[index]), AnalysisError = true }
    end
    return results
end

function F.V38.onRemoteRecord(record)
    local r = F.V38
    local key = tostring(record.Path) .. "|" .. tostring(record.Method) .. "|" .. tostring(record.Direction)
    local stats = r.RemoteStats[key]
    if not stats then
        r.RemoteStatsCount = r.RemoteStatsCount or 0
        if r.RemoteStatsCount >= 5000 then
            r.RemoteStatsOmitted = (r.RemoteStatsOmitted or 0) + 1
            return
        end
        r.RemoteStatsCount = r.RemoteStatsCount + 1
        stats = { Path = record.Path, Method = record.Method, Direction = record.Direction,
            Calls = 0, FirstTime = record.Time, LastTime = nil, PeakCallsPerSecond = 0,
            MinInterval = nil, MaxInterval = nil, Seconds = {}, Samples = {} }
        r.RemoteStats[key] = stats
    end
    stats.Calls = stats.Calls + 1
    local second = math.floor(record.Time)
    stats.Seconds[second] = (stats.Seconds[second] or 0) + 1
    stats.PeakCallsPerSecond = math.max(stats.PeakCallsPerSecond, stats.Seconds[second])
    if stats.LastTime then
        local delta = math.max(0, record.Time - stats.LastTime)
        stats.MinInterval = math.min(stats.MinInterval or delta, delta)
        stats.MaxInterval = math.max(stats.MaxInterval or delta, delta)
    end
    stats.LastTime = record.Time
    if #stats.Samples < 12 then
        stats.Samples[#stats.Samples + 1] = { Time = record.Time, Shape = record.ArgumentShape }
    end
    local recent = { Time = record.Time, Path = record.Path, Method = record.Method }
    r.RecentRemotes[#r.RecentRemotes + 1] = recent
    if #r.RecentRemotes > 150 then table.remove(r.RecentRemotes, 1) end
    for i = #r.RecentInputs, 1, -1 do
        local input = r.RecentInputs[i]
        if record.Time - input.Time > 1.2 then break end
        if input.Time <= record.Time then
            F.V38.addCorrelation(input, recent, nil)
            break
        end
    end
end

function F.V38.addCorrelation(input, remote, effect)
    local r = F.V38
    if not r.Correlations then r.Correlations = {} end
    if #r.Correlations >= 1500 then return end
    r.Correlations[#r.Correlations + 1] = {
        Input = input, Remote = remote,
        Effect = effect and { Kind = effect.Kind, Time = effect.Time, Object = effect.Object } or nil,
        Analysis = "Temporal proximity only; causality is not established"
    }
end

function F.V38.trackEffectCorrelation(row)
    if not row or not row.Time then return end
    for i = #F.V38.RecentRemotes, 1, -1 do
        local remote = F.V38.RecentRemotes[i]
        if row.Time - remote.Time > 0.9 then break end
        if remote.Time <= row.Time then
            F.V38.addCorrelation(nil, remote, row)
            return
        end
    end
end

function F.V38.scanSource(source, record, path)
    if type(source) ~= "string" or not record then return end
    local r = F.V38
    local n = 0
    local aliases = {}
    for lineNumber, line in ipairs(string.split(source, "\n")) do
        local alias, expression = line:match("local%s+([%w_]+)%s*=%s*(.+)")
        if alias and expression and #expression < 220 and
            (expression:find("GetService", 1, true) or expression:find("WaitForChild", 1, true)
                or expression:find("FindFirstChild", 1, true)) then
            aliases[alias] = expression
        end
        local edges = {}
        local requireExpr = line:match("require%s*%(%s*([^%)]+)")
        if requireExpr then
            edges[#edges + 1] = { Kind = "Require", TargetExpression = requireExpr:sub(1, 170),
                Confidence = requireExpr:find("script.", 1, true) and "Medium" or "Low" }
        end
        for _, method in ipairs({ "FireServer", "InvokeServer", "OnClientEvent", "OnClientInvoke",
            "Fire", "Invoke" }) do
            local pos = line:find(method, 1, true)
            if pos then
                local prefix = line:sub(1, pos - 1)
                local expr = prefix:match("([%w_%.%[%]\"']+):?$") or "Unknown"
                local alias = expr:match("^([%w_]+)$")
                local probablePath = alias and aliases[alias]
                edges[#edges + 1] = { Kind = "RemoteOrBindableReference", Method = method,
                    TargetExpression = expr:sub(1, 170),
                    ProbableSourceExpression = probablePath,
                    Confidence = probablePath and "Medium" or "Low",
                    DirectCallCandidate = (method == "FireServer" or method == "InvokeServer")
                        and prefix:match("%.$") ~= nil or nil }
            end
        end
        for _, edge in ipairs(edges) do
            if #r.DependencyEdges >= CONFIG.V38MaxDependencyEdges then
                r.DependencyOmitted = r.DependencyOmitted + 1
                return
            end
            edge.ScriptPath = record.Path
            edge.ScriptClass = record.ClassName
            edge.File = path
            edge.Line = lineNumber
            edge.Text = line:sub(1, 240)
            r.DependencyEdges[#r.DependencyEdges + 1] = edge
        end
        if #edges > 0 then n = n + #edges end
        if n >= 150 then break end
    end
end

function F.V38.watchCallbacks(object, className)
    if not CONFIG.V38CaptureCallbackCalls then return end
    if className ~= "RemoteFunction" and className ~= "BindableFunction" then return end
    local property = className == "RemoteFunction" and "OnClientInvoke" or "OnInvoke"
    local existing = F.V38.CallbacksWrapped[object]
    if existing then
        local readOk, current = pcall(function() return object[property] end)
        if readOk and current == existing.Wrapper then return end
        F.V38.CallbacksWrapped[object] = nil
    end
    local ok, original = pcall(function() return object[property] end)
    if not ok then
        if not F.V38.CallbackDenied then F.V38.CallbackDenied = setmetatable({}, { __mode = "k" }) end
        if not F.V38.CallbackDenied[object] then
            F.V38.CallbackDenied[object] = true
            F.V38.markMissing("CallbackReadDenied", F.safeFullName(object))
        end
        return
    end
    if type(original) ~= "function" then return end
    local function wrapper(...)
        local args = table.pack(...)
        F.V38.addEvent("CallbackInvoked", object, {
            CallbackProperty = property, ArgumentShape = F.V38.inferPacked(args),
            Arguments = F.serializePackedRuntimeValues(args)
        })
        -- Calling original directly preserves errors and yielding behavior of its callback.
        local returns = table.pack(original(...))
        F.V38.addEvent("CallbackReturned", object, {
            CallbackProperty = property, Returns = F.serializePackedRuntimeValues(returns)
        })
        return table.unpack(returns, 1, returns.n)
    end
    local installed = pcall(function() object[property] = wrapper end)
    if installed then
        F.V38.CallbacksWrapped[object] = { Property = property, Original = original, Wrapper = wrapper }
        F.V38.addEvent("CallbackWrapperInstalled", object, { Property = property })
    else
        F.V38.markMissing("CallbackWriteDenied", F.safeFullName(object))
    end
end

function F.V38.watchBindable(object, className)
    if className == "BindableEvent" then
        F.V38.signal(object, "Event", function(...)
            local args = table.pack(...)
            F.V38.addEvent("BindableEventFired", object, {
                Arguments = F.serializePackedRuntimeValues(args), ArgumentShape = F.V38.inferPacked(args)
            })
        end)
    elseif className == "BindableFunction" or className == "RemoteFunction" then
        if not F.V38.CallbackCandidates then
            F.V38.CallbackCandidates = setmetatable({}, { __mode = "k" })
        end
        F.V38.CallbackCandidates[object] = className
        F.V38.watchCallbacks(object, className)
    end
end

function F.V38.collisionMatrix()
    local physics = game:GetService("PhysicsService")
    local ok, groups = pcall(function() return physics:GetRegisteredCollisionGroups() end)
    if not ok then
        ok, groups = pcall(function() return physics:GetCollisionGroups() end)
    end
    if not ok or type(groups) ~= "table" then
        F.V38.markMissing("ApiUnavailable", "CollisionGroups")
        return { Available = false, Groups = {}, Matrix = {} }
    end
    local names = {}
    for _, entry in ipairs(groups) do
        local name = entry.name or entry.Name
        if type(name) == "string" then names[#names + 1] = name end
    end
    table.sort(names)
    local matrix = {}
    for _, a in ipairs(names) do
        local row = {}
        for _, b in ipairs(names) do
            local works, collides = pcall(function() return physics:CollisionGroupsAreCollidable(a, b) end)
            row[b] = works and collides or "Unavailable"
        end
        matrix[a] = row
    end
    return { Available = true, Groups = names, Matrix = matrix }
end

function F.V38.characterSnapshot(player, character, cause)
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChildOfClass("Backpack")
    local snapshot = {
        UserId = player.UserId, Name = F.safeName(player), Event = cause,
        Time = os.clock() - runtimeStartedAt, Attributes = F.getAttributes(character),
        CharacterParts = {}, Inventory = {}, Humanoid = humanoid and F.avatarProps(humanoid,
            { "RigType", "MaxHealth", "HipHeight", "WalkSpeed", "JumpPower" }) or nil
    }
    for _, child in ipairs(character:GetChildren()) do
        if #snapshot.CharacterParts >= 100 then break end
        snapshot.CharacterParts[#snapshot.CharacterParts + 1] = {
            Name = F.safeName(child), ClassName = F.safeClassName(child),
            Attributes = F.optionalMap(F.getAttributes(child)),
            Size = F.safeIsA(child, "BasePart") and F.avatarRead(child, "Size") or nil
        }
    end
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and #snapshot.Inventory < 60 then
                snapshot.Inventory[#snapshot.Inventory + 1] = F.safeName(tool)
            end
        end
    end
    table.sort(snapshot.Inventory)
    table.sort(snapshot.CharacterParts, function(a, b) return a.Name < b.Name end)
    return snapshot
end

function F.V38.diffCharacterSnapshots(previous, current)
    local result = {
        AddedParts = {}, RemovedParts = {}, ChangedParts = {},
        AddedTools = {}, RemovedTools = {}, ChangedAttributes = {},
        HumanoidChanged = F.V38.digest(previous.Humanoid) ~= F.V38.digest(current.Humanoid),
        PreviousHumanoid = previous.Humanoid, CurrentHumanoid = current.Humanoid
    }
    local oldParts, newParts = {}, {}
    for _, item in ipairs(previous.CharacterParts or {}) do
        oldParts[item.Name .. "|" .. item.ClassName] = item
    end
    for _, item in ipairs(current.CharacterParts or {}) do
        local key = item.Name .. "|" .. item.ClassName
        newParts[key] = true
        if not oldParts[key] then
            if #result.AddedParts < 40 then result.AddedParts[#result.AddedParts + 1] = key end
        elseif F.V38.digest(oldParts[key]) ~= F.V38.digest(item) then
            if #result.ChangedParts < 40 then result.ChangedParts[#result.ChangedParts + 1] = {
                Key = key, Before = oldParts[key], After = item } end
        end
    end
    for key in pairs(oldParts) do
        if not newParts[key] and #result.RemovedParts < 40 then
            result.RemovedParts[#result.RemovedParts + 1] = key
        end
    end
    local oldTools, newTools = {}, {}
    for _, name in ipairs(previous.Inventory or {}) do oldTools[name] = true end
    for _, name in ipairs(current.Inventory or {}) do
        newTools[name] = true
        if not oldTools[name] and #result.AddedTools < 50 then
            result.AddedTools[#result.AddedTools + 1] = name
        end
    end
    for name in pairs(oldTools) do
        if not newTools[name] and #result.RemovedTools < 50 then
            result.RemovedTools[#result.RemovedTools + 1] = name
        end
    end
    local attrNames = {}
    for key in pairs(previous.Attributes or {}) do attrNames[key] = true end
    for key in pairs(current.Attributes or {}) do attrNames[key] = true end
    for key in pairs(attrNames) do
        local before = previous.Attributes and previous.Attributes[key]
        local after = current.Attributes and current.Attributes[key]
        if F.V38.digest(before) ~= F.V38.digest(after) and #result.ChangedAttributes < 50 then
            result.ChangedAttributes[#result.ChangedAttributes + 1] = {
                Name = key, Before = before, After = after }
        end
    end
    return result
end

function F.V38.watchCharacter(player, character)
    if not character or not runtimeTraceActive then return end
    local r = F.V38
    if r.PlayerCharacters[character] then return end
    r.PlayerCharacters[character] = true
    local snapshot = F.V38.characterSnapshot(player, character, "Spawn")
    local previous = r.CharacterSnapshots[player.UserId]
    local difference = nil
    if previous then difference = F.V38.diffCharacterSnapshots(previous, snapshot) end
    r.CharacterSnapshots[player.UserId] = snapshot
    F.V38.addEvent("CharacterSpawned", character, { Player = player.UserId,
        RespawnDifferences = difference, Snapshot = snapshot })
    local function watchHumanoid(humanoid)
        if not humanoid or not humanoid:IsA("Humanoid") then return end
        if not r.Humanoids then r.Humanoids = setmetatable({}, { __mode = "k" }) end
        if r.Humanoids[humanoid] then return end
        r.Humanoids[humanoid] = true
        F.V38.signal(humanoid, "Died", function()
            if not runtimeTraceActive then return end
            local row = { Time = os.clock() - runtimeStartedAt,
                PlayerUserId = player.UserId, Name = F.safeName(player),
                Character = F.safeFullName(character),
                LastPosition = F.avatarRead(character:FindFirstChild("HumanoidRootPart"), "Position"),
                Humanoid = F.avatarProps(humanoid, { "Health", "MaxHealth" }) }
            if #r.CharacterDeaths < 700 then r.CharacterDeaths[#r.CharacterDeaths + 1] = row end
            F.V38.addEvent("PlayerDied", character, row)
        end)
    end
    watchHumanoid(character:FindFirstChildOfClass("Humanoid"))
    F.V38.connect(character.ChildAdded, function(child)
        if child:IsA("Humanoid") then watchHumanoid(child) end
    end)
end

function F.V38.watchPlayer(player)
    local r = F.V38
    if not r.Players then r.Players = setmetatable({}, { __mode = "k" }) end
    if r.Players[player] then return end
    r.Players[player] = true
    F.V38.signal(player, "CharacterAdded", function(char)
        F.V38.watchCharacter(player, char)
        task.delay(1, function()
            if runtimeTraceActive then
                local snap = F.V38.characterSnapshot(player, char, "CharacterReady")
                if snap then r.CharacterSnapshots[player.UserId] = snap end
            end
        end)
    end)
    F.V38.signal(player, "CharacterRemoving", function(char)
        F.V38.addEvent("CharacterRemoving", char, { PlayerUserId = player.UserId })
    end)
    F.V38.watchCharacter(player, player.Character)
end

function F.V38.startRuntime()
    local r = F.V38
    if r.Active or not runtimeTraceActive then return end
    r.Active = true
    r.CallbackCoverage = {
        NamecallHook = CONFIG.RuntimeTraceOutgoingRemotes and capabilities.hookmetamethod or false,
        DirectCalls = "NotIntercepted: direct method calls may bypass __namecall",
        CallbackWrappingOptIn = CONFIG.V38CaptureCallbackCalls,
        CallbackLimitations = "Existing readable callback only; later replacements not reliably observable"
    }
    if CONFIG.V38CaptureCallbackCalls then
        task.spawn(function()
            while runtimeTraceActive and r.Active do
                task.wait(1)
                if not runtimeTraceActive or not r.Active then break end
                for candidate, className in pairs(r.CallbackCandidates or {}) do
                    if candidate.Parent then F.V38.watchCallbacks(candidate, className) end
                end
            end
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do F.V38.watchPlayer(player) end
    F.V38.connect(Players.PlayerAdded, function(player)
        F.V38.watchPlayer(player)
        F.V38.addEvent("PlayerJoined", player, { UserId = player.UserId })
    end)
    F.V38.connect(Players.PlayerRemoving, function(player)
        F.V38.addEvent("PlayerLeft", player, {
            UserId = player.UserId, LastCharacter = r.CharacterSnapshots[player.UserId]
        })
    end)
    local inputService = game:GetService("UserInputService")
    F.V38.connect(inputService.InputBegan, function(input, consumed)
        if consumed or not runtimeTraceActive then return end
        local kind = input.UserInputType
        local key = input.KeyCode
        local allowedActionKey = kind == Enum.UserInputType.Keyboard and (
            key == Enum.KeyCode.E or key == Enum.KeyCode.R or key == Enum.KeyCode.F
            or key == Enum.KeyCode.Q or key == Enum.KeyCode.Space)
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch
            and kind ~= Enum.UserInputType.Gamepad1 and not allowedActionKey then return end
        local item = { Time = os.clock() - runtimeStartedAt, Type = tostring(kind),
            KeyCode = tostring(input.KeyCode), ScreenPosition = F.serializeRuntimeValue(input.Position) }
        r.RecentInputs[#r.RecentInputs + 1] = item
        if #r.RecentInputs > 100 then table.remove(r.RecentInputs, 1) end
        F.V38.addEvent("UserInput", nil, item)
    end)
    local ok, allTags = pcall(function() return CollectionService:GetAllTags() end)
    if ok and type(allTags) == "table" then
        for _, tag in ipairs(allTags) do F.V38.watchTags(tag) end
    end
    task.spawn(function()
        while runtimeTraceActive and r.Active do
            task.wait(3)
            if not runtimeTraceActive or not r.Active then break end
            local success, tags = pcall(function() return CollectionService:GetAllTags() end)
            if success and type(tags) == "table" then
                for _, tag in ipairs(tags) do F.V38.watchTags(tag) end
            end
        end
    end)
    F.V38.connect(game.DescendantAdded, function(object)
        if not runtimeTraceActive then return end
        local className = F.safeClassName(object)
        F.V38.observeInstance(object, className)
        for _, tag in ipairs(F.getTags(object)) do F.V38.watchTags(tag) end
        if SELECTION.Visuals and (className == "ParticleEmitter" or className == "Sound"
            or className == "Beam" or className == "Trail" or className == "Fire"
            or className == "Smoke" or className == "Sparkles") then
            F.V38.addEvent("VisualCreated", object, { ClassName = className })
        end
    end)
    local okCamera, runService = pcall(function() return game:GetService("RunService") end)
    if okCamera then
        F.V38.connect(runService.Heartbeat, function()
            if not runtimeTraceActive then return end
            local now = os.clock()
            if now - r.LastCameraSample < CONFIG.V38CameraSampleSeconds then return end
            r.LastCameraSample = now
            local camera = workspace.CurrentCamera
            if not camera then return end
            local state = F.avatarProps(camera, { "CFrame", "FieldOfView", "CameraType", "CameraSubject" })
            local key = F.V38.digest(state)
            if r.SampledCamera == key then return end
            r.SampledCamera = key
            F.V38.addEvent("CameraChanged", camera, state)
        end)
    end
end

function F.V38.stopRuntime()
    local r = F.V38
    r.Active = false
    for object, values in pairs(r.CallbacksWrapped) do
        pcall(function()
            if object[values.Property] == values.Wrapper then
                object[values.Property] = values.Original
            end
        end)
        r.CallbacksWrapped[object] = nil
    end
    for _, connection in ipairs(r.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(r.Connections)
end

function F.V38.buildEffectGroups()
    local rows = {}
    for _, event in ipairs(F.V38.Events) do
        if event.Kind == "SoundPlayed" or event.Kind == "ParticleEnabled"
            or event.Kind == "BeamEnabled" or event.Kind == "TrailEnabled"
            or event.Kind == "VisualCreated" then
            rows[#rows + 1] = event
        end
    end
    table.sort(rows, function(a, b) return a.Time < b.Time end)
    local groups, current = {}, nil
    for _, row in ipairs(rows) do
        if not current or row.Time - current.StartSeconds > CONFIG.V38EffectGroupWindow then
            if #groups >= 2500 then break end
            current = { StartSeconds = row.Time, EndSeconds = row.Time, Events = {} }
            groups[#groups + 1] = current
        end
        current.EndSeconds = row.Time
        if #current.Events < 50 then
            current.Events[#current.Events + 1] = { Time = row.Time, Kind = row.Kind, Path = row.Object }
        end
    end
    return { WindowSeconds = CONFIG.V38EffectGroupWindow, Groups = groups,
        Caveat = "Temporal clustering only. Emit(count) and non-replicated effects cannot be observed passively." }
end

function F.V38.makeCoverage()
    local r = F.V38
    local unavailable = {}
    for key in pairs(r.Missing) do unavailable[#unavailable + 1] = {
        Category = key, Count = r.MissingCounts[key] } end
    table.sort(unavailable, function(a, b) return a.Category < b.Category end)
    local issueCategories = {}
    local issueSamples = {}
    for _, issue in ipairs(errors) do
        local stage = tostring(issue.Stage or "Unknown")
        local reason = tostring(issue.Error or "")
        local kind = "UnknownCause"
        if stage == "ReadProperty" or stage == "SerializeProperty" then
            kind = "PropertyInaccessibleOrSerializationFailed"
        elseif stage:find("Decompile") or reason:lower():find("decompil") then
            kind = "DecompilationFailed"
        elseif reason:lower():find("destroy") or reason:lower():find("parent") then
            kind = "PossiblyRemovedObject"
        elseif reason:lower():find("limit") or reason:lower():find("maximum") then
            kind = "LimitReached"
        end
        issueCategories[kind] = (issueCategories[kind] or 0) + 1
        if #issueSamples < 40 then issueSamples[#issueSamples + 1] = {
            Kind = kind, Stage = stage, Path = issue.Path, Property = issue.Property,
            Message = reason:sub(1, 160) } end
    end
    local caps = {
        VisualSnapshot = visualSnapshotOmitted, VisualRuntime = visualDynamicOmitted,
        VisualAnimation = visualAnimationPlaybackOmitted, GUI = guiCapture.SnapshotOmitted,
        RuntimeEvents = r.EventOmitted, RemoteUsage = remoteUsageOverflow,
        Tags = tagOmitted, Physics = physicsOmitted, Interactions = interactionOmitted,
        AvatarRecords = F.avatarInspection.Skipped, ToolSnapshots = r.ToolOmitted,
        AssetIds = r.AssetOmitted, DependencyEdges = r.DependencyOmitted,
        RemoteStats = r.RemoteStatsOmitted or 0,
        Observers = r.Coverage.ObserversOmitted,
        LocalDecompilerSkipped = clientDecompileStats.Skipped,
        ModuleDecompilerSkipped = moduleDecompileStats.Skipped
    }
    local partial = #errors > 0 or clientDecompileStats.Failed > 0 or moduleDecompileStats.Failed > 0
    for name, count in pairs(caps) do
        if count > 0 then
            partial = true
            unavailable[#unavailable + 1] = { Category = "LimitReached:" .. name, Count = count }
        end
    end
    return {
        Schema = "Averyn.CaptureCoverage", Version = 1, DumpId = currentDumpId,
        Selection = SELECTION,
        Totals = {
            TraversedNodes = nodeCount, RegisteredIds = nextInstanceId,
            Remotes = F.totalRemoteCount(), Scripts = F.totalScriptCount(),
            VisualSnapshot = visualSnapshotSaved, VisualRuntime = #visualDynamicRecords,
            AvatarRecords = #F.avatarInspection.Records, RuntimeEvents = #runtimeEventRecords,
            V38Events = #r.Events, Observers = r.ObservedCount, Assets = #r.AssetList,
            LocalDecompilerSucceeded = clientDecompileStats.Succeeded,
            LocalDecompilerFailed = clientDecompileStats.Failed,
            ModuleDecompilerSucceeded = moduleDecompileStats.Succeeded,
            ModuleDecompilerFailed = moduleDecompileStats.Failed
        },
        Limits = caps, IncompleteCategories = unavailable,
        ErrorClassification = issueCategories, ErrorSamples = issueSamples,
        Partial = partial,
        Limitations = {
            "Inaccessible properties may be security-restricted; no server-side access is implied.",
            "Unreplicated/streamed-out objects cannot be enumerated or counted reliably.",
            "Callback wrapping requires opt-in and an existing readable callback.",
            "Direct remote calls can bypass __namecall; coverage cannot be measured fully.",
            "Animation marker listeners support named candidates, not every unknown name.",
            "Failed decompilation cannot distinguish server-only source from network failure.",
            "A full client-side view is not evidence of complete game replication."
        }
    }
end

function F.V38.export(writtenFiles)
    local r = F.V38
    r.CallbackCoverage.NamecallHook = runtimeOutgoingHookInstalled == true
    local function write(name, document)
        F.writeJSONDocument(OUTPUT_FOLDER .. "/" .. name, document, name, writtenFiles, false)
    end
    write("coverage.json", F.V38.makeCoverage())
    if SELECTION.AvatarInspection then write("rig_hierarchy.json", F.V38.makeRigDocument()) end
    if SELECTION.Visuals or SELECTION.AvatarInspection then
        table.sort(r.AssetList, function(a, b) return a.Id < b.Id end)
        for _, asset in ipairs(r.AssetList) do asset._Seen = nil end
        write("asset_catalogue.json", { DumpId = currentDumpId, UniqueAssets = #r.AssetList,
            Omitted = r.AssetOmitted, Assets = r.AssetList })
    end
    if SELECTION.Structure then write("collision_matrix.json", F.V38.collisionMatrix()) end
    if SELECTION.LocalSources or SELECTION.ModuleSources then
        write("source_dependency_graph.json", { DumpId = currentDumpId,
            Edges = r.DependencyEdges, Total = #r.DependencyEdges, Omitted = r.DependencyOmitted,
            Caveat = "Static source heuristics; dynamic requires and remote bindings may be unresolved" })
    end
    if SELECTION.Runtime then
        local bursts = {}
        for _, stat in pairs(r.RemoteStats) do
            local seconds = {}
            for second, count in pairs(stat.Seconds) do
                seconds[#seconds + 1] = { Second = second, Calls = count }
            end
            table.sort(seconds, function(a, b) return a.Second < b.Second end)
            stat.Seconds = seconds
            bursts[#bursts + 1] = stat
        end
        table.sort(bursts, function(a, b) return a.Path < b.Path end)
        write("runtime_v38_events.json", {
            DumpId = currentDumpId, Total = #r.Events,
            OmittedByCap = r.EventOmitted, Events = r.Events,
            MarkerCoverage = "KeyframeReached and best-effort discovery of markers from animation assets",
            MarkerLookupsRequested = r.MarkerLookupsRequested or 0,
            MarkerListenerCount = r.ListenerMarkers
        })
        write("runtime_traffic_analysis.json", {
            DumpId = currentDumpId, RemoteStats = bursts,
            RemoteStatsOmitted = r.RemoteStatsOmitted or 0,
            Correlations = r.Correlations or {}, CallbackCoverage = r.CallbackCoverage,
            EffectGroups = F.V38.buildEffectGroups(),
            Limitations = "Direct calls and server-only interactions cannot be measured conclusively"
        })
        write("runtime_tool_visual_state.json", { DumpId = currentDumpId,
            Snapshots = r.ToolSnapshots, Omitted = r.ToolOmitted,
            PlayerDeaths = r.CharacterDeaths, LastCharacterSnapshots = r.CharacterSnapshots })
    end
end


initRecovery = function()
    if not CONFIG.RecoveryEnabled or not capabilities.writefile then return end
    if not F.ensureFolder(RECOVERY_FOLDER) then
        F.recordWarning("RecoveryInit", nil, "Recovery folder unavailable")
        return
    end
    local leaf = string.gsub(tostring(currentDumpId or os.time()), "[^%w%-_]", "_")
    local folder = RECOVERY_FOLDER .. "/" .. leaf
    if not F.ensureFolder(folder) then
        F.recordWarning("RecoveryInit", nil, "Recovery run folder unavailable: " .. folder)
        return
    end
    recoveryState.Folder = folder
    recoveryLastFlush = os.clock()
    recoveryLastDiagnostics = 0
end

journalRecord = function(stream, entry)
    if not recoveryState.Folder then return end
    local bufferEntries = recoveryState.Buffers[stream]
    if bufferEntries then bufferEntries[#bufferEntries + 1] = entry end
end

writeDiagnostics = function(status, extra)
    if not currentDumpId or not capabilities.writefile then return end
    local now = os.clock()
    local memoryOk, memoryKb = pcall(collectgarbage, "count")
    local payload = {
        Schema = SCHEMA_NAME,
        SchemaVersion = SCHEMA_VERSION,
        DumpId = currentDumpId,
        Status = status or "InProgress",
        Stage = currentStage,
        LastObjectPath = recoveryLastPath,
        LastObjectClass = recoveryLastClass,
        LastError = recoveryLastError,
        SnapshotBusy = snapshotBusy,
        RuntimeTraceActive = runtimeTraceActive,
        ElapsedSeconds = now - started,
        UpdatedAtUnix = os.time(),
        MemoryKilobytes = memoryOk and memoryKb or nil,
        Counts = { Traversed = nodeCount, RegisteredIds = nextInstanceId,
            Errors = #errors, Warnings = #warnings,
            RemoteEvents = #runtimeEventRecords,
            RuntimeValues = #runtimeValueRecords,
            RuntimeAttributes = #runtimeAttributeRecords,
            LocalDecompiled = clientDecompileStats.Succeeded,
            ModuleDecompiled = moduleDecompileStats.Succeeded },
        Recovery = { Folder = recoveryState.Folder, Sequences = recoveryState.Sequences,
            SavedRecords = recoveryState.Saved, FailedWrites = recoveryState.FailedWrites,
            LastWriteFailure = recoveryState.LastFailure },
        Details = extra
    }
    local encodedOk, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
    if encodedOk then
        local savedOk = pcall(writefile, DIAGNOSTICS_FILE, encoded)
        if savedOk then recoveryLastDiagnostics = now end
    end
end

flushRecovery = function(force)
    if not recoveryState.Folder or recoveryFlushBusy then return end
    local now = os.clock()
    local interval = math.max(0.2, tonumber(CONFIG.RecoveryFlushSeconds) or 2)
    if not force and now - recoveryLastFlush < interval then return end
    recoveryLastFlush = now
    recoveryFlushBusy = true
    local flushOk, flushError = pcall(function()
    for _, stream in ipairs({ "Snapshot", "Runtime", "Issues" }) do
        local bufferEntries = recoveryState.Buffers[stream]
        if #bufferEntries > 0 then
            local batchSize = stream == "Snapshot" and CONFIG.RecoverySnapshotBatch
                or (stream == "Runtime" and CONFIG.RecoveryRuntimeBatch or CONFIG.RecoveryIssueBatch)
            batchSize = math.max(1, math.floor(tonumber(batchSize) or 100))
            local entryIndex = 1
            local written = 0
            while entryIndex <= #bufferEntries do
                local stopIndex = math.min(#bufferEntries, entryIndex + batchSize - 1)
                local batch = {}
                for index = entryIndex, stopIndex do
                    batch[#batch + 1] = bufferEntries[index]
                end
                local sequence = recoveryState.Sequences[stream] + 1
                local path = string.format("%s/%s_%06d.json", recoveryState.Folder,
                    string.lower(stream), sequence)
                local encodedOk, encoded = pcall(HttpService.JSONEncode, HttpService, {
                    DumpId = currentDumpId, Stream = stream, Sequence = sequence,
                    SavedAtUnix = os.time(), Count = #batch, Entries = batch
                })
                local savedOk, saveError = false, nil
                if encodedOk then savedOk, saveError = pcall(writefile, path, encoded) end
                if not encodedOk or not savedOk then
                    recoveryState.FailedWrites = recoveryState.FailedWrites + 1
                    recoveryState.LastFailure = tostring(encodedOk and saveError or encoded)
                    break
                end
                recoveryState.Sequences[stream] = sequence
                recoveryState.Saved[stream] = recoveryState.Saved[stream] + #batch
                written = stopIndex
                entryIndex = stopIndex + 1
            end
            if written > 0 then
                local remaining = {}
                for index = written + 1, #bufferEntries do
                    remaining[#remaining + 1] = bufferEntries[index]
                end
                recoveryState.Buffers[stream] = remaining
            end
        end
    end
    local indexOk, indexJson = pcall(HttpService.JSONEncode, HttpService, {
        DumpId = currentDumpId, Stage = currentStage,
        Status = currentStage == "complete" and "Complete" or "InProgress",
        Sequences = recoveryState.Sequences, Saved = recoveryState.Saved,
        FailedWrites = recoveryState.FailedWrites, LastFailure = recoveryState.LastFailure,
        LastObjectPath = recoveryLastPath, LastObjectClass = recoveryLastClass,
        UpdatedAtUnix = os.time()
    })
    if indexOk then
        pcall(writefile, recoveryState.Folder .. "/index.json", indexJson)
    end
    end)
    recoveryFlushBusy = false
    if not flushOk then
        recoveryState.FailedWrites = recoveryState.FailedWrites + 1
        recoveryState.LastFailure = tostring(flushError)
    end
end

function F.base64Encode(data)
    if type(nativeBase64Encoder) == "function" then
        local ok, encoded = pcall(nativeBase64Encoder, data)
        if ok and type(encoded) == "string" and encoded ~= "" then
            return encoded
        end
    end

    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return ((data:gsub(".", function(char)
        local bits = ""
        local byte = string.byte(char)
        for bit = 8, 1, -1 do
            bits = bits .. (byte % 2 ^ bit - byte % 2 ^ (bit - 1) > 0 and "1" or "0")
        end
        return bits
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
        if #bits < 6 then
            return ""
        end

        local value = 0
        for index = 1, 6 do
            if bits:sub(index, index) == "1" then
                value = value + 2 ^ (6 - index)
            end
        end

        return alphabet:sub(value + 1, value + 1)
    end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

function F.sanitizeFileComponent(value)
    local text = F.sanitizeString(value or "ModuleScript")
    text = text:gsub("%c", "_")
    text = text:gsub('[/:*?"<>|]', "_")
    text = text:gsub("\\", "_")
    text = text:gsub("%s+$", "")
    text = text:gsub("^%s+", "")

    if text == "" or text == "." or text == ".." then
        text = "ModuleScript"
    end

    if #text > 96 then
        text = text:sub(1, 96)
    end

    return text
end

function F.moduleSourcePath(record)
    local safeName = F.sanitizeFileComponent(record and record.Name or "ModuleScript")
    local id = record and record.Id or 0
    local folder = currentModuleSourcesFolder or MODULE_SOURCES_FOLDER
    return string.format("%s/%06d_%s.luau", folder, id, safeName)
end

function F.compactDecompilerError(value)
    local text = F.sanitizeString(value or "unknown decompiler error")
    if #text > 2048 then
        return text:sub(1, 2048) .. "..."
    end
    return text
end

function F.requestByteFall(bytecode)
    if type(executorRequest) ~= "function" then
        return false, nil, 0, "no HTTP request function available", 0
    end

    local encodeOk, encodedBytecode = pcall(F.base64Encode, bytecode)
    if not encodeOk or type(encodedBytecode) ~= "string" or encodedBytecode == "" then
        return false, nil, 0, "failed to base64 encode bytecode: " .. tostring(encodedBytecode), 0
    end

    local jsonOk, body = pcall(HttpService.JSONEncode, HttpService, {
        script = encodedBytecode
    })
    encodedBytecode = nil

    if not jsonOk then
        return false, nil, 0, "failed to encode ByteFall request body: " .. tostring(body), 0
    end

    local maxAttempts = math.max(1, math.floor(tonumber(CONFIG.ModuleDecompilerRetryCount) or 0) + 1)
    local lastError = "request failed"
    local lastStatus = 0

    for attempt = 1, maxAttempts do
        local requestOk, result = pcall(executorRequest, {
            Url = CONFIG.ModuleDecompilerEndpoint,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = body
        })

        if requestOk and type(result) == "table" then
            local statusCode = tonumber(result.StatusCode or result.Status) or 0
            local responseBody = tostring(result.Body or "")
            lastStatus = statusCode

            if statusCode == 200 then
                if responseBody ~= "" then
                    return true, responseBody, statusCode, nil, attempt
                end
                lastError = "ByteFall returned an empty 200 response"
            elseif statusCode == 400 then
                lastError = "ByteFall 400 bad request: " .. responseBody
            elseif statusCode == 404 then
                lastError = "ByteFall 404 not found: wrong endpoint?"
            elseif statusCode == 500 then
                lastError = "ByteFall 500 decompilation failed: " .. responseBody
            else
                lastError = "ByteFall HTTP " .. tostring(statusCode) .. ": " .. responseBody
            end

            local retryable = statusCode == 0
                or statusCode == 408
                or statusCode == 425
                or statusCode == 429
                or statusCode >= 500

            if not retryable then
                return false, nil, statusCode, lastError, attempt
            end
        elseif requestOk then
            lastError = "ByteFall returned an invalid response"
        else
            lastError = "ByteFall request failed: " .. tostring(result)
        end

        if attempt < maxAttempts then
            task.wait(math.max(0, tonumber(CONFIG.ModuleDecompilerRetryDelay) or 0) * attempt)
        end
    end

    return false, nil, lastStatus, lastError, maxAttempts
end

function F.buildModuleDecompileResult(entry, guard)
    local object = entry and entry.Object or nil
    local record = entry and entry.Record or nil
    if not record then
        return {
            Status = "Failed",
            Reason = "module record is unavailable"
        }
    end

    local bytecodeOk, bytecode = pcall(getscriptbytecode, object)
    if guard and guard.Cancelled then
        return nil
    end

    if not bytecodeOk or type(bytecode) ~= "string" or bytecode == "" then
        local reason = bytecodeOk
            and "getscriptbytecode returned empty or non-string data"
            or ("getscriptbytecode failed: " .. tostring(bytecode))
        return {
            Status = "Failed",
            Reason = F.compactDecompilerError(reason)
        }
    end

    local bytecodeBytes = #bytecode
    local bytecodeDigest = SELECTION.InteractionResearch and F.comparisonDigest(bytecode) or nil
    local success, source, statusCode, requestError, attempts = F.requestByteFall(bytecode)
    bytecode = nil

    if guard and guard.Cancelled then
        source = nil
        return nil
    end

    if not success then
        return {
            Status = "Failed",
            HttpStatus = statusCode,
            Attempts = attempts,
            BytecodeBytes = bytecodeBytes,
            BytecodeDigest = bytecodeDigest,
            Reason = F.compactDecompilerError(requestError)
        }
    end

    return {
        Status = "Success",
        Source = source,
        HttpStatus = statusCode,
        Attempts = attempts,
        BytecodeBytes = bytecodeBytes,
        BytecodeDigest = bytecodeDigest,
        SourceDigest = SELECTION.InteractionResearch and F.comparisonDigest(source) or nil,
        SourceBytes = #source
    }
end

function F.applyModuleDecompileResult(entry, result)
    local object = entry and entry.Object or nil
    local record = entry and entry.Record or nil
    if not record then
        return
    end

    if type(result) ~= "table" then
        local reason = "module decompiler returned no result"
        record.Decompile = {
            Status = "Failed",
            Reason = reason
        }
        moduleDecompileStats.Failed = moduleDecompileStats.Failed + 1
        F.recordWarning("ModuleDecompile", object, reason)
        return
    end

    local bytecodeBytes = tonumber(result.BytecodeBytes) or 0
    moduleDecompileStats.BytecodeBytes = moduleDecompileStats.BytecodeBytes + bytecodeBytes

    if result.Status ~= "Success" then
        record.Decompile = {
            Status = result.Status or "Failed",
            HttpStatus = result.HttpStatus,
            Attempts = result.Attempts,
            BytecodeBytes = result.BytecodeBytes,
            BytecodeDigest = result.BytecodeDigest,
            Reason = result.Reason
        }
        moduleDecompileStats.Failed = moduleDecompileStats.Failed + 1
        F.recordWarning("ModuleDecompile", object, result.Reason or "module decompilation failed")
        return
    end

    local source = result.Source
    local path = F.moduleSourcePath(record)
    local writeOk = type(source) == "string" and F.writeSafe(path, source)
    if not writeOk then
        record.Decompile = {
            Status = "Failed",
            HttpStatus = result.HttpStatus,
            Attempts = result.Attempts,
            BytecodeBytes = result.BytecodeBytes,
            SourceBytes = result.SourceBytes,
            Reason = "decompiled source could not be written"
        }
        moduleDecompileStats.Failed = moduleDecompileStats.Failed + 1
        return
    end

    record.Decompile = {
        Status = "Success",
        File = path,
        HttpStatus = result.HttpStatus,
        Attempts = result.Attempts,
        BytecodeBytes = result.BytecodeBytes,
        BytecodeDigest = result.BytecodeDigest,
        SourceDigest = result.SourceDigest,
        SourceBytes = result.SourceBytes
    }
    F.scanSourceReferences(source, record, path)
    F.V38.scanSource(source, record, path)

    moduleDecompileStats.Succeeded = moduleDecompileStats.Succeeded + 1
    moduleDecompileStats.Written = moduleDecompileStats.Written + 1
    moduleDecompileStats.SourceBytes = moduleDecompileStats.SourceBytes + (tonumber(result.SourceBytes) or 0)
    result.Source = nil
end

function F.runModuleDecompileWithTimeout(entry, timeoutSeconds)
    local guard = {
        Cancelled = false,
        Done = false,
        Ok = false,
        Result = nil,
        Error = nil
    }

    task.spawn(function()
        local ok, result = pcall(F.buildModuleDecompileResult, entry, guard)
        if guard.Cancelled then
            return
        end
        guard.Ok = ok
        if ok then
            guard.Result = result
        else
            guard.Error = result
        end
        guard.Done = true
    end)

    local startedAt = os.clock()
    local timeout = math.max(0.1, tonumber(timeoutSeconds) or 10)
    while not guard.Done and os.clock() - startedAt < timeout do
        task.wait(0.05)
    end

    if not guard.Done then
        guard.Cancelled = true
        return false, nil, "decompile timed out after " .. tostring(timeout) .. "s"
    end

    if not guard.Ok then
        return true, nil, "unexpected module decompiler error: " .. tostring(guard.Error)
    end

    return true, guard.Result, nil
end

function F.clientScriptSourcePath(record)
    local safeName = F.sanitizeFileComponent(record and record.Name or "LocalScript")
    local id = record and record.Id or 0
    local folder = currentClientSourcesFolder or CLIENT_SOURCES_FOLDER
    return string.format("%s/%06d_%s.luau", folder, id, safeName)
end

function F.applyClientDecompileResult(entry, result)
    local record = entry and entry.Record
    local object = entry and entry.Object
    if not record then
        return
    end
    if type(result) ~= "table" then
        result = {Status = "Failed", Reason = "client decompiler returned no result"}
    end

    local bytecodeBytes = tonumber(result.BytecodeBytes) or 0
    clientDecompileStats.BytecodeBytes = clientDecompileStats.BytecodeBytes + bytecodeBytes

    if result.Status ~= "Success" then
        record.Decompile = {
            Status = result.Status or "Failed",
            HttpStatus = result.HttpStatus,
            Attempts = result.Attempts,
            BytecodeBytes = result.BytecodeBytes,
            BytecodeDigest = result.BytecodeDigest,
            Reason = result.Reason or "client decompilation failed"
        }
        clientDecompileStats.Failed = clientDecompileStats.Failed + 1
        F.recordWarning("LocalScriptDecompile", object, record.Decompile.Reason)
        return
    end

    local path = F.clientScriptSourcePath(record)
    local ok = type(result.Source) == "string" and F.writeSafe(path, result.Source)
    if not ok then
        record.Decompile = {
            Status = "Failed",
            BytecodeBytes = result.BytecodeBytes,
            SourceBytes = result.SourceBytes,
            Reason = "failed to write decompiled client source"
        }
        clientDecompileStats.Failed = clientDecompileStats.Failed + 1
        F.recordWarning("LocalScriptDecompileWrite", object, record.Decompile.Reason)
        return
    end

    record.Decompile = {
        Status = "Success",
        File = path,
        HttpStatus = result.HttpStatus,
        Attempts = result.Attempts,
        BytecodeBytes = result.BytecodeBytes,
        BytecodeDigest = result.BytecodeDigest,
        SourceDigest = result.SourceDigest,
        SourceBytes = result.SourceBytes
    }
    F.scanSourceReferences(result.Source, record, path)
    F.V38.scanSource(result.Source, record, path)
    clientDecompileStats.Succeeded = clientDecompileStats.Succeeded + 1
    clientDecompileStats.Written = clientDecompileStats.Written + 1
    clientDecompileStats.SourceBytes = clientDecompileStats.SourceBytes + (tonumber(result.SourceBytes) or 0)
    result.Source = nil
end

function F.markClientScriptsSkipped(reason, startIndex, countAsAborted)
    for i = math.max(1, tonumber(startIndex) or 1), #clientScriptQueue do
        local entry = clientScriptQueue[i]
        local record = entry and entry.Record
        if record and not record.Decompile then
            record.Decompile = {Status = "Skipped", Reason = reason}
            clientDecompileStats.Skipped = clientDecompileStats.Skipped + 1
            if countAsAborted then
                clientDecompileStats.Aborted = clientDecompileStats.Aborted + 1
            end
        end
    end
end

function F.decompileQueuedClientScripts(scriptsDocument)
    local started = os.clock()
    if not CONFIG.DecompileLocalScripts or #clientScriptQueue == 0 then
        clientDecompileStats.ElapsedSeconds = os.clock() - started
        return
    end
    if not capabilities.getscriptbytecode or not capabilities.http_request then
        F.markClientScriptsSkipped("getscriptbytecode or HTTP API unavailable")
        clientDecompileStats.ElapsedSeconds = os.clock() - started
        table.clear(clientScriptQueue)
        return
    end

    currentClientSourcesFolder = CLIENT_SOURCES_FOLDER .. "/" .. F.sanitizeFileComponent(currentDumpId or "dump")
    clientDecompileStats.OutputFolder = currentClientSourcesFolder
    if not F.ensureFolder(CLIENT_SOURCES_FOLDER) or not F.ensureFolder(currentClientSourcesFolder) then
        F.markClientScriptsSkipped("client scripts output folder could not be created")
        clientDecompileStats.ElapsedSeconds = os.clock() - started
        table.clear(clientScriptQueue)
        return
    end

    table.sort(clientScriptQueue, function(a, b)
        local pathA = a.Record.Path or ""
        local pathB = b.Record.Path or ""
        local _, depthA = pathA:gsub("%.", "")
        local _, depthB = pathB:gsub("%.", "")
        if depthA ~= depthB then return depthA < depthB end
        if pathA ~= pathB then return pathA < pathB end
        return (a.Record.Id or 0) < (b.Record.Id or 0)
    end)

    local maxScripts = math.max(0, math.floor(tonumber(CONFIG.LocalDecompilerMaxScripts) or 0))
    local total = math.min(#clientScriptQueue, maxScripts)
    if total < #clientScriptQueue then
        F.markClientScriptsSkipped("LocalDecompilerMaxScripts limit reached", total + 1)
    end
    if total == 0 then
        clientDecompileStats.ElapsedSeconds = os.clock() - started
        table.clear(clientScriptQueue)
        return
    end

    local nextIndex, completed, activeWorkers = 0, 0, 0
    local timeouts, abortRequested = 0, false
    local workerCount = math.max(1, math.min(total, math.floor(tonumber(CONFIG.LocalDecompilerWorkers) or 2)))
    local timeoutSeconds = math.max(0.1, tonumber(CONFIG.LocalDecompilerTimeout) or 10)
    local abortAfter = math.max(1, math.floor(tonumber(CONFIG.LocalDecompilerAbortAfterTimeouts) or 4))
    F.log("LocalScript decompile candidates:", total, "workers:", workerCount)

    for _ = 1, workerCount do
        activeWorkers = activeWorkers + 1
        task.spawn(function()
            local ok, err = pcall(function()
                while not abortRequested do
                    nextIndex = nextIndex + 1
                    local index = nextIndex
                    if index > total then
                        break
                    end
                    local entry = clientScriptQueue[index]
                    clientDecompileStats.Attempted = clientDecompileStats.Attempted + 1
                    local finished, result, errorText = F.runModuleDecompileWithTimeout(entry, timeoutSeconds)
                    if not finished then
                        local record = entry.Record
                        record.Decompile = {Status = "TimedOut", Reason = F.compactDecompilerError(errorText)}
                        clientDecompileStats.Failed = clientDecompileStats.Failed + 1
                        clientDecompileStats.TimedOut = clientDecompileStats.TimedOut + 1
                        timeouts = timeouts + 1
                        F.recordWarning("LocalScriptDecompileTimeout", entry.Object, errorText)
                        if timeouts >= abortAfter then
                            abortRequested = true
                        end
                    elseif errorText then
                        F.applyClientDecompileResult(entry, {
                            Status = "Failed",
                            Reason = F.compactDecompilerError(errorText)
                        })
                    else
                        F.applyClientDecompileResult(entry, result)
                    end
                    completed = completed + 1
                    if completed % 10 == 0 or completed == total then
                        F.log("LocalScripts decompiled:", completed, "/", total,
                            "success:", clientDecompileStats.Succeeded, "failed:", clientDecompileStats.Failed)
                    end
                    if scriptsDocument and completed % 75 == 0 then
                        pcall(function()
                            F.writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts_local_checkpoint.json", nil, false)
                            checkpointStage("decompile_localscripts")
                        end)
                    end
                    task.wait()
                end
            end)
            if not ok then
                F.recordWarning("LocalScriptDecompileWorker", nil, tostring(err))
                abortRequested = true
            end
            activeWorkers = activeWorkers - 1
        end)
    end
    while activeWorkers > 0 do
        task.wait(0.05)
    end
    if abortRequested then
        local reason = "client decompilation aborted after " .. tostring(timeouts) .. " timeout(s)"
        for i = nextIndex + 1, total do
            local record = clientScriptQueue[i] and clientScriptQueue[i].Record
            if record and not record.Decompile then
                record.Decompile = {Status = "Skipped", Reason = reason}
                clientDecompileStats.Skipped = clientDecompileStats.Skipped + 1
                clientDecompileStats.Aborted = clientDecompileStats.Aborted + 1
            end
        end
        F.recordWarning("LocalScriptDecompileCircuitBreaker", nil, reason)
    end
    clientDecompileStats.ElapsedSeconds = os.clock() - started
    table.clear(clientScriptQueue)
    F.releaseTemporaryMemory()
end

function F.markQueuedModulesSkipped(reason, startIndex, countAsAborted)
    local first = math.max(1, tonumber(startIndex) or 1)
    for index = first, #moduleScriptQueue do
        local entry = moduleScriptQueue[index]
        local record = entry and entry.Record or nil
        if record and record.Decompile == nil then
            record.Decompile = {
                Status = "Skipped",
                Reason = reason
            }
            moduleDecompileStats.Skipped = moduleDecompileStats.Skipped + 1
            if countAsAborted then
                moduleDecompileStats.Aborted = moduleDecompileStats.Aborted + 1
            end
        end
    end
end

function F.decompileQueuedModules(scriptsDocument)
    local decompileStartedAt = os.clock()

    if not CONFIG.DecompileModuleScripts then
        F.markQueuedModulesSkipped("module decompilation disabled by configuration")
        moduleDecompileStats.ElapsedSeconds = os.clock() - decompileStartedAt
        table.clear(moduleScriptQueue)
        return
    end

    if #moduleScriptQueue == 0 then
        moduleDecompileStats.ElapsedSeconds = os.clock() - decompileStartedAt
        return
    end

    if not capabilities.getscriptbytecode then
        F.markQueuedModulesSkipped("getscriptbytecode is unavailable")
        moduleDecompileStats.ElapsedSeconds = os.clock() - decompileStartedAt
        table.clear(moduleScriptQueue)
        return
    end

    if not capabilities.http_request then
        F.markQueuedModulesSkipped("executor HTTP request API is unavailable")
        moduleDecompileStats.ElapsedSeconds = os.clock() - decompileStartedAt
        table.clear(moduleScriptQueue)
        return
    end

    currentModuleSourcesFolder = MODULE_SOURCES_FOLDER .. "/" .. F.sanitizeFileComponent(currentDumpId or "dump")
    moduleDecompileStats.OutputFolder = currentModuleSourcesFolder

    if not F.ensureFolder(MODULE_SOURCES_FOLDER) or not F.ensureFolder(currentModuleSourcesFolder) then
        F.markQueuedModulesSkipped("modules output folder could not be created")
        moduleDecompileStats.ElapsedSeconds = os.clock() - decompileStartedAt
        table.clear(moduleScriptQueue)
        return
    end

    local total = #moduleScriptQueue
    local nextIndex = 0
    local completed = 0
    local activeWorkers = 0
    local timeoutCount = 0
    local abortRequested = false
    local workerCount = math.max(1, math.min(total, math.floor(tonumber(CONFIG.ModuleDecompilerWorkers) or 1)))
    local progressEvery = math.max(1, math.floor(tonumber(CONFIG.ModuleDecompilerProgressEvery) or 10))
    local checkpointEvery = math.max(1, math.floor(tonumber(CONFIG.ModuleDecompilerCheckpointEvery) or 25))
    local timeoutSeconds = math.max(0.1, tonumber(CONFIG.ModuleDecompilerTimeout) or 10)
    local abortAfterTimeouts = math.max(1, math.floor(tonumber(CONFIG.ModuleDecompilerAbortAfterTimeouts) or workerCount))

    F.log("ModuleScript decompile candidates:", total, "workers:", workerCount, "timeout:", timeoutSeconds)

    for _ = 1, workerCount do
        activeWorkers = activeWorkers + 1
        task.spawn(function()
            local workerOk, workerError = pcall(function()
                while not abortRequested do
                    nextIndex = nextIndex + 1
                    local index = nextIndex
                    if index > total then
                        break
                    end

                    local entry = moduleScriptQueue[index]
                    moduleDecompileStats.Attempted = moduleDecompileStats.Attempted + 1
                    local finished, result, err = F.runModuleDecompileWithTimeout(entry, timeoutSeconds)

                    if not finished then
                        local record = entry and entry.Record or nil
                        local object = entry and entry.Object or nil
                        if record then
                            record.Decompile = {
                                Status = "TimedOut",
                                Reason = F.compactDecompilerError(err)
                            }
                        end
                        moduleDecompileStats.Failed = moduleDecompileStats.Failed + 1
                        moduleDecompileStats.TimedOut = moduleDecompileStats.TimedOut + 1
                        timeoutCount = timeoutCount + 1
                        F.recordWarning("ModuleDecompileTimeout", object, err)
                        if timeoutCount >= abortAfterTimeouts then
                            abortRequested = true
                        end
                    elseif err then
                        F.applyModuleDecompileResult(entry, {
                            Status = "Failed",
                            Reason = F.compactDecompilerError(err)
                        })
                    else
                        F.applyModuleDecompileResult(entry, result)
                    end

                    completed = completed + 1
                    if completed % progressEvery == 0 or completed == total then
                        F.log("ModuleScripts decompiled:", completed, "/", total,
                            "success:", moduleDecompileStats.Succeeded, "failed:", moduleDecompileStats.Failed)
                    end

                    if scriptsDocument and completed % checkpointEvery == 0 then
                        pcall(function()
                            F.writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts_checkpoint.json", nil, false)
                            checkpointStage("decompile_modules")
                        end)
                    end

                    task.wait()
                end
            end)

            if not workerOk then
                F.recordWarning("ModuleDecompileWorker", nil, "worker crashed: " .. tostring(workerError))
                abortRequested = true
            end
            activeWorkers = activeWorkers - 1
        end)
    end

    while activeWorkers > 0 do
        task.wait(0.05)
    end

    if abortRequested then
        local reason = "module decompilation aborted after " .. tostring(timeoutCount) .. " timeout(s); remaining modules skipped"
        F.markQueuedModulesSkipped(reason, nextIndex + 1, true)
        F.recordWarning("ModuleDecompileCircuitBreaker", nil, reason)
    end

    moduleDecompileStats.ElapsedSeconds = os.clock() - decompileStartedAt
    table.clear(moduleScriptQueue)
    F.releaseTemporaryMemory()
end

checkpointStage = function(stage)
    local changed = currentStage ~= stage
    if changed then
        local elapsed = os.clock() - started
        if progressLastStage then
            F.log(string.format("Stage %s completed after %.1fs (%d nodes)", progressLastStage, elapsed, nodeCount))
        end
        F.log(string.format("Stage: %s | %.1fs | %d nodes", tostring(stage), elapsed, nodeCount))
        progressLastStage = stage
    end
    currentStage = stage
    if selectionStatus and selectionStatus.Parent then
        selectionStatus.Text = "Stage: " .. tostring(stage) .. " · " .. OUTPUT_FOLDER
    end

    if not currentDumpId or not capabilities.writefile then
        return
    end

    local checkpoint = {
        Schema = SCHEMA_NAME,
        SchemaVersion = SCHEMA_VERSION,
        DumpId = currentDumpId,
        Complete = false,
        Status = "InProgress",
        Stage = currentStage,
        GeneratedAtUnix = os.time(),
        Stats = {
            TraversedDescendants = nodeCount,
            RegisteredIds = nextInstanceId,
            Errors = #errors,
            Warnings = #warnings,
            ModuleDecompileQueued = moduleDecompileStats.Queued,
            ModuleDecompileAttempted = moduleDecompileStats.Attempted,
            ModuleDecompileSucceeded = moduleDecompileStats.Succeeded,
            ModuleDecompileFailed = moduleDecompileStats.Failed,
            ModuleDecompileTimedOut = moduleDecompileStats.TimedOut,
            ModuleDecompileIgnored = moduleDecompileStats.Ignored
        }
    }

    local encoded = F.encodeJSON(checkpoint, "manifest_checkpoint.json")
    F.writeSafe(MANIFEST_FILE, encoded)
    if flushRecovery then flushRecovery(true) end
    if writeDiagnostics then writeDiagnostics("InProgress") end
end

function F.fileNameFromPath(path)
    return string.match(path, "[^/]+$") or path
end

function F.writeJSONDocument(path, data, label, writtenFiles, required)
    local encoded, encodeSuccess = F.encodeJSON(data, label)
    local bytes = #encoded
    local writeSuccess = F.writeSafe(path, encoded)
    local success = encodeSuccess and writeSuccess

    F.log(string.format("File: %s | %.1f KB | %s", F.fileNameFromPath(path), bytes / 1024,
        success and "OK" or "FAILED"))
    if writtenFiles then
        table.insert(writtenFiles, {
            File = F.fileNameFromPath(path),
            Bytes = bytes,
            Encoded = encodeSuccess,
            Written = writeSuccess,
            Success = success,
            Required = required ~= false
        })
    end

    return success, bytes
end

function F.releaseTemporaryMemory()
    if type(collectgarbage) == "function" then
        pcall(collectgarbage, "collect")
    end
end

function F.writeTextDocument(path, contents, writtenFiles, required)
    local bytes = #contents
    local success = F.writeSafe(path, contents)

    F.log(string.format("File: %s | %.1f KB | %s", F.fileNameFromPath(path), bytes / 1024,
        success and "OK" or "FAILED"))
    if writtenFiles then
        table.insert(writtenFiles, {
            File = F.fileNameFromPath(path),
            Bytes = bytes,
            Success = success,
            Required = required ~= false
        })
    end

    return success, bytes
end

function F.backfillRuntimeIds()
    if not snapshotFinalized then
        return
    end

    local pathToId = {}
    local duplicatePaths = {}

    for id, meta in pairs(instanceMetaById) do
        local path = meta and meta.Path
        if path then
            if pathToId[path] ~= nil then
                duplicatePaths[path] = true
                pathToId[path] = nil
            elseif not duplicatePaths[path] then
                pathToId[path] = id
            end
        end
    end

    local function backfillReference(reference)
        if type(reference) ~= "table" or reference.Id ~= nil then
            return
        end

        local path = reference.Path
        if path and not duplicatePaths[path] then
            reference.Id = pathToId[path]
        end
    end

    for _, record in ipairs(runtimeEventRecords) do
        if record.RemoteId == nil then
            local path = record.Path or record.SnapshotPath
            if path and not duplicatePaths[path] then
                record.RemoteId = pathToId[path]
            end
        end

        backfillReference(record.Caller)
    end

    for _, record in ipairs(runtimeAttributeRecords) do
        if record.Id == nil then
            local path = record.Path or record.SnapshotPath
            if path and not duplicatePaths[path] then
                record.Id = pathToId[path]
            end
        end
    end

    for _, record in ipairs(guiCapture.Records) do
        if record.Id == nil then
            local path = record.Path
            if path and not duplicatePaths[path] then record.Id = pathToId[path] end
        end
    end

    for _, record in ipairs(runtimeValueRecords) do
        if record.Id == nil then
            local path = record.Path or record.SnapshotPath
            if path and not duplicatePaths[path] then
                record.Id = pathToId[path]
            end
        end
    end

    for _, record in ipairs(runtimeCharacterRecords) do
        backfillReference(record.Object)
        backfillReference(record.Character)

        if record.Humanoid and record.Humanoid.Id == nil then
            local path = record.Humanoid.Path
            if path and not duplicatePaths[path] then
                record.Humanoid.Id = pathToId[path]
            end
        end

        if record.Root and record.Root.Id == nil then
            local path = record.Root.Path
            if path and not duplicatePaths[path] then
                record.Root.Id = pathToId[path]
            end
        end
    end
end

function F.makeRuntimeEventDocument(records, category)
    return {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTrace,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        Category = category,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #records,
        DroppedDueToCategoryCap = category
            and runtimeEventCategoryDropped[category]
            or nil,
        Events = records
    }
end

flushRuntimeTrace = function()
    if not capabilities.writefile then
        return
    end

    F.pruneRuntimeCaches(true)
    F.backfillRuntimeIds()

    local eventsDocument = F.makeRuntimeEventDocument(runtimeEventRecords, nil)
    eventsDocument.CategoryTotals = {
        RemoteEvent = #runtimeEventCategoryRecords.RemoteEvent,
        UnreliableRemoteEvent = #runtimeEventCategoryRecords.UnreliableRemoteEvent,
        RemoteFunction = #runtimeEventCategoryRecords.RemoteFunction,
        Other = #runtimeEventCategoryRecords.Other
    }
    eventsDocument.CategoryDroppedDueToCap = runtimeEventCategoryDropped

    local valuesDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTrace,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeValueRecords,
        Changes = runtimeValueRecords
    }

    local attributesDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTrace,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeAttributeRecords,
        Changes = runtimeAttributeRecords
    }

    local characterDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTraceCharacter,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        SampleInterval = CONFIG.RuntimeCharacterSampleInterval,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeCharacterRecords,
        Records = runtimeCharacterRecords
    }

    local logsDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeCaptureLogs,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeLogRecords,
        Records = runtimeLogRecords
    }

    local timelineDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTrace,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeTimelineRecords,
        Timeline = runtimeTimelineRecords
    }

    local disconnectDocument = {
        DumpId = currentDumpId,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        ErrorMessages = runtimeErrorRecords
    }

    local hooksDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTraceHookDiagnostics,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeHookState.HookRecords,
        Records = runtimeHookState.HookRecords
    }

    local hookIntegrityDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTraceHookDiagnostics,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Baseline = runtimeHookState.HookIntegrityBaseline,
        LastSnapshot = runtimeHookState.HookIntegrityLast,
        Total = #runtimeHookState.HookIntegrityRecords,
        Records = runtimeHookState.HookIntegrityRecords
    }

    F.writeSafe(RUNTIME_FILES.Events, F.encodeJSON(eventsDocument, "runtime_events.json"))
    F.writeSafe(
        RUNTIME_FILES.EventsRemoteEvent,
        F.encodeJSON(
            F.makeRuntimeEventDocument(runtimeEventCategoryRecords.RemoteEvent, "RemoteEvent"),
            "runtime_events_remote_event.json"
        )
    )
    F.writeSafe(
        RUNTIME_FILES.EventsUnreliableRemoteEvent,
        F.encodeJSON(
            F.makeRuntimeEventDocument(runtimeEventCategoryRecords.UnreliableRemoteEvent, "UnreliableRemoteEvent"),
            "runtime_events_unreliable_remote_event.json"
        )
    )
    F.writeSafe(
        RUNTIME_FILES.EventsRemoteFunction,
        F.encodeJSON(
            F.makeRuntimeEventDocument(runtimeEventCategoryRecords.RemoteFunction, "RemoteFunction"),
            "runtime_events_remote_function.json"
        )
    )
    F.writeSafe(
        RUNTIME_FILES.EventsOther,
        F.encodeJSON(
            F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Other, "Other"),
            "runtime_events_other.json"
        )
    )
    if CONFIG.VisualCapture then
        F.writeSafe(
            RUNTIME_VISUAL_ASSETS_FILE,
            F.encodeJSON(F.buildVisualDocument(visualDynamicRecords, true), "runtime_visual_assets.json")
        )
    end
    F.writeSafe(RUNTIME_FILES.Gui, F.encodeJSON({
        DumpId = currentDumpId, Enabled = CONFIG.RuntimeTraceGui,
        RollingWindow = true, WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        Total = #guiCapture.Records, Changes = guiCapture.Records
    }, "runtime_gui.json"))
    F.writeSafe(RUNTIME_FILES.Values, F.encodeJSON(valuesDocument, "runtime_values.json"))
    F.writeSafe(RUNTIME_FILES.Attributes, F.encodeJSON(attributesDocument, "runtime_attributes.json"))
    F.writeSafe(RUNTIME_FILES.Character, F.encodeJSON(characterDocument, "runtime_character.json"))
    F.writeSafe(RUNTIME_FILES.Logs, F.encodeJSON(logsDocument, "runtime_logs.json"))
    F.writeSafe(RUNTIME_FILES.Timeline, F.encodeJSON(timelineDocument, "runtime_timeline.json"))
    F.writeSafe(RUNTIME_FILES.Disconnect, F.encodeJSON(disconnectDocument, "runtime_disconnect.json"))
    F.writeSafe(RUNTIME_FILES.Hooks, F.encodeJSON(hooksDocument, "runtime_hooks.json"))
    F.writeSafe(
        RUNTIME_FILES.HookIntegrity,
        F.encodeJSON(hookIntegrityDocument, "runtime_hook_integrity.json")
    )

    runtimeHookState.LastFlushAt = os.clock()
    runtimeHookState.MutationsSinceFlush = 0
end

function F.stopRuntimeTrace()
    runtimeTraceActive = false
    F.V38.stopRuntime()
    runtimeHookState.Active = false

    F.disconnectConnections(runtimeCharacterConnections)
    F.disconnectConnections(runtimeConnections)

    flushRuntimeTrace()
end

function F.finishRuntimeTraceAfterSnapshot()
    if not CONFIG.RuntimeTrace then
        return
    end

    flushRuntimeTrace()

    local postSeconds = math.max(0, tonumber(CONFIG.RuntimeTracePostSeconds) or 0)
    if postSeconds > 0 and not runtimeHookState.Frozen then
        F.log(string.format("Runtime capture: %gs remaining after snapshot", postSeconds))
        local waitStarted = os.clock()
        local nextReportAt = 0
        while runtimeTraceActive
            and not runtimeHookState.Frozen
            and os.clock() - waitStarted < postSeconds
        do
            local elapsed = os.clock() - waitStarted
            if elapsed >= nextReportAt then
                local remain = math.max(0, math.ceil(postSeconds - elapsed))
                F.log(string.format("Runtime: %ds left | %d events | %d value changes | %d attribute changes",
                    remain, #runtimeEventRecords, #runtimeValueRecords, #runtimeAttributeRecords))
                if selectionStatus and selectionStatus.Parent then
                    selectionStatus.Text = string.format("Runtime: %ds left (%d events)", remain, #runtimeEventRecords)
                end
                nextReportAt = elapsed + 10
            end
            task.wait(0.1)
        end
    end

    F.stopRuntimeTrace()

    if runtimeHookState.Frozen then
        print(
            "runtime trace frozen:",
            runtimeHookState.FreezeInfo and runtimeHookState.FreezeInfo.Reason or "unknown reason"
        )
    end

    print(
        "runtime trace finished:",
        #runtimeEventRecords,
        "remote calls/events,",
        #runtimeValueRecords,
        "value changes,",
        #runtimeAttributeRecords,
        "attribute changes,",
        #runtimeCharacterRecords,
        "character records,",
        #runtimeHookState.HookRecords,
        "hook observations,",
        #runtimeHookState.HookIntegrityRecords,
        "hook integrity records"
    )
end

function F.prepareSelectedSnapshotNodes()
    selectedSnapshotNodes = nil
    if SELECTION.Structure then return end
    local allowed = setmetatable({ [game] = true }, { __mode = "k" })
    local function hasAttributes(object)
        local ok, attrs = pcall(function() return object:GetAttributes() end)
        if not ok then
            F.recordError("GetAttributes", object, attrs)
            return false
        end
        return next(attrs) ~= nil
    end
    local childrenOk, children = pcall(function() return game:GetChildren() end)
    if not childrenOk then error("Cannot scan game children: " .. tostring(children)) end
    local stack = children
    local seen = setmetatable({}, { __mode = "k" })
    local visited = 0
    while #stack > 0 do
        local object = stack[#stack]
        stack[#stack] = nil
        if not seen[object] then
            seen[object] = true
            local className = F.safeClassName(object)
            local parentOk, parent = pcall(function() return object.Parent end)
            local isIgnored = (object == selectionGui)
                or (CONFIG.SkipEngineInternals and parentOk and parent == game
                    and (F.safeName(object) == "CoreGui" or F.safeName(object) == "CorePackages"))
            if not isIgnored then
                local matched = (SELECTION.GUI and F.GUI_CLASSES[className])
                    or (SELECTION.Remotes and REMOTE_BUCKETS[className])
                    or ((SELECTION.Scripts or SELECTION.LocalSources or SELECTION.ModuleSources)
                        and SCRIPT_BUCKETS[className])
                    or (SELECTION.Values and (F.classIsA(object, className, "ValueBase")
                        or hasAttributes(object)))
                    or (SELECTION.PlayersTools and
                        (className == "Player" or className == "PlayerGui" or className == "Backpack"
                        or className == "Tool" or className == "Humanoid" or className == "StarterGear"))
                    or (SELECTION.Visuals and F.isVisualAsset(object, className))
                if matched then
                    local ancestor = object
                    while ancestor and ancestor ~= game and not allowed[ancestor] do
                        allowed[ancestor] = true
                        local ok, parent = pcall(function() return ancestor.Parent end)
                        ancestor = ok and parent or nil
                    end
                end
                local ok, descendants = pcall(function() return object:GetChildren() end)
                if ok then
                    for i = 1, #descendants do stack[#stack + 1] = descendants[i] end
                end
            end
        end
        visited = visited + 1
        if visited % 256 == 0 then
            local now = os.clock()
            if now - lastSelectionYield >= (CONFIG.MaxSelectionSliceSeconds or 0.013) then
                if now - progressLastLoggedAt >= (CONFIG.ProgressLogEverySeconds or 2) then
                    F.log(string.format("Selecting nodes: %d scanned | %.1fs", visited, now - started))
                    progressLastLoggedAt = now
                    if selectionStatus and selectionStatus.Parent then
                        selectionStatus.Text = string.format("Selecting: %d inspected", visited)
                    end
                end
                task.wait()
                lastSelectionYield = os.clock()
            end
        end
    end
    selectedSnapshotNodes = allowed
end

local activeRegistry
local activeRegistryToken

function F.run()
    if type(shared) == "table" then
        activeRegistry = shared
        if type(activeRegistry.__AverynDumperActive) == "table"
            and activeRegistry.__AverynDumperActive.JobId == tostring(game.JobId)
        then
            warn("GameStructureDump: a dump is already running in this server; duplicate execution ignored.")
            return
        end
        activeRegistryToken = { JobId = tostring(game.JobId), StartedAt = os.clock() }
        activeRegistry.__AverynDumperActive = activeRegistryToken
    end
    if SELECTION.ClosureResearch then SELECTION.InteractionResearch = true end
    if SELECTION.InteractionResearch then
        for _, key in ipairs({ "Remotes", "Scripts", "PlayersTools", "Runtime", "LocalSources", "ModuleSources" }) do
            SELECTION[key] = true
        end
    end
    if SELECTION.OutgoingHook or SELECTION.CallbackTrace then SELECTION.Runtime = true end
    local chosen = {}
    for name, enabled in pairs(SELECTION) do
        if enabled then chosen[#chosen + 1] = name end
    end
    table.sort(chosen)
    F.log("Starting dump | " .. table.concat(chosen, ", "))
    F.log("Adaptive frame yielding enabled; recovery checkpoints and full final exports remain active")
    CONFIG.GuiCapture = SELECTION.GUI
    CONFIG.VisualCapture = SELECTION.Visuals
    CONFIG.RuntimeTrace = SELECTION.Runtime
    CONFIG.RuntimeTraceOutgoingRemotes = SELECTION.Runtime and SELECTION.OutgoingHook
    CONFIG.V38CaptureCallbackCalls = SELECTION.Runtime and SELECTION.CallbackTrace
    CONFIG.RuntimeTraceGui = SELECTION.Runtime and SELECTION.GUI
    CONFIG.DecompileLocalScripts = SELECTION.LocalSources
    CONFIG.DecompileModuleScripts = SELECTION.ModuleSources
    CONFIG.RuntimePrimeBeforeSnapshot = SELECTION.Runtime and not SELECTION.Structure
    clientDecompileStats.Enabled = CONFIG.DecompileLocalScripts
    moduleDecompileStats.Enabled = CONFIG.DecompileModuleScripts
    if not capabilities.writefile then
        warn("GameStructureDump: writefile is unavailable; dump aborted.")
        return
    end
    local folderOk, folderError = F.selectOutputFolder()
    if not folderOk then
        warn("GameStructureDump: " .. tostring(folderError))
        return
    end
    F.log("Output folder: " .. OUTPUT_FOLDER)

    local guidOk, guid = pcall(function()
        return HttpService:GenerateGUID(false)
    end)

    currentDumpId = guidOk and guid or string.format("%d-%d", os.time(), math.floor(os.clock() * 1000))
    if type(readfile) == "function" then
        F.ensureFolder(RECOVERY_FOLDER)
        local oldCrashOk, oldCrashText = pcall(readfile, CRASH_FILE)
        if oldCrashOk and type(oldCrashText) == "string" then
            local decodeOk, oldCrash = pcall(HttpService.JSONDecode, HttpService, oldCrashText)
            if decodeOk and type(oldCrash) == "table" and oldCrash.Status == "LuaException" then
                local archiveName = F.sanitizeFileComponent(oldCrash.DumpId or tostring(os.time()))
                F.writeSafe(RECOVERY_FOLDER .. "/crash_" .. archiveName .. ".json", oldCrashText)
            end
        end
        local previousOk, previousText = pcall(readfile, MANIFEST_FILE)
        if previousOk and type(previousText) == "string" then
            local decodedOk, previous = pcall(HttpService.JSONDecode, HttpService, previousText)
            if decodedOk and type(previous) == "table" and previous.Status == "InProgress" then
                local detailsOk, detailsText = pcall(readfile, DIAGNOSTICS_FILE)
                local details = nil
                if detailsOk and type(detailsText) == "string" then
                    local parsedOk, parsed = pcall(HttpService.JSONDecode, HttpService, detailsText)
                    if parsedOk then details = parsed end
                end
                local previousId = F.sanitizeFileComponent(previous.DumpId or tostring(os.time()))
                local previousReport = F.encodeJSON({
                    Status = "PreviousRunInterrupted",
                    Note = "An unfinished run was found; a native crash, teleport or manual stop cannot be distinguished here.",
                    DetectedAtUnix = os.time(),
                    PreviousManifest = previous, PreviousDiagnostics = details
                }, "previous_run_interrupted.json")
                F.writeSafe(RECOVERY_FOLDER .. "/previous_" .. previousId .. ".json", previousReport)
                F.writeSafe(PREVIOUS_RUN_FILE, previousReport)
            end
        end
    end
    initRecovery()
    F.writeSafe(CRASH_FILE, F.encodeJSON({
        DumpId = currentDumpId, Status = "NoLuaCrashRecorded",
        Note = "A native client crash cannot be caught by Luau; consult diagnostics.json and recovery/ if the run is interrupted."
    }, "crash_report.json"))
    snapshotBusy = true
    checkpointStage("runtime_start")
    runtimeStartedAt = os.clock()
    F.startRuntimeTrace()
    if SELECTION.AvatarInspection then F.startAvatarInspection() end

    if SELECTION.AvatarInspection and not SELECTION.Structure and not SELECTION.GUI
        and not SELECTION.Remotes and not SELECTION.Scripts and not SELECTION.Values
        and not SELECTION.PlayersTools and not SELECTION.Visuals and not SELECTION.Runtime
        and not SELECTION.LocalSources and not SELECTION.ModuleSources then
        checkpointStage("avatar_inspection_only")
        local endsAt = os.clock() + CONFIG.RuntimeTracePostSeconds
        while os.clock() < endsAt do
            task.wait(math.min(1, math.max(0.03, endsAt - os.clock())))
        end
        F.finishAvatarInspection()
        F.V38.export(nil)
        snapshotBusy = false
        snapshotFinalized = true
        F.writeSafe(ERRORS_FILE, F.encodeJSON(errors, "errors.json"))
        F.writeSafe(WARNINGS_FILE, F.encodeJSON(warnings, "warnings.json"))
        F.writeSafe(META_FILE, F.encodeJSON({
            Schema = SCHEMA_NAME, SchemaVersion = SCHEMA_VERSION,
            DumpId = currentDumpId, Mode = "AvatarInspectionOnly", Selection = SELECTION,
            GeneratedAtUnix = os.time(), ElapsedSeconds = os.clock() - started,
            AvatarInspectionFile = AVATAR_INSPECTION_FILE,
            AvatarRecords = #F.avatarInspection.Records, AvatarPlayers = F.avatarInspection.UniquePlayers,
            Errors = #errors, Warnings = #warnings
        }, "meta.json"))
        F.writeSafe(MANIFEST_FILE, F.encodeJSON({
            Schema = SCHEMA_NAME, SchemaVersion = SCHEMA_VERSION,
            DumpId = currentDumpId, Complete = true, Status = "Complete",
            Stage = "complete", Mode = "AvatarInspectionOnly", Selection = SELECTION,
            Folder = OUTPUT_FOLDER, Files = { "avatar_inspection.json", "meta.json", "manifest.json" },
            GeneratedAtUnix = os.time()
        }, "manifest.json"))
        currentStage = "complete"
        if flushRecovery then flushRecovery(true) end
        if writeDiagnostics then writeDiagnostics("Complete") end
        F.log("Avatar inspection finished:", AVATAR_INSPECTION_FILE)
        print("dump finished")
        return
    end

    if not SELECTION.Structure and not SELECTION.GUI and not SELECTION.Remotes
        and not SELECTION.Scripts and not SELECTION.Values and not SELECTION.PlayersTools
        and not SELECTION.Visuals and not SELECTION.LocalSources and not SELECTION.ModuleSources then
        snapshotBusy = false
        snapshotFinalized = true
        checkpointStage("runtime_only")
        F.finishRuntimeTraceAfterSnapshot()
        if SELECTION.AvatarInspection then
            F.finishAvatarInspection()
        end
        F.writeSafe(ERRORS_FILE, F.encodeJSON(errors, "errors.json"))
        F.writeSafe(WARNINGS_FILE, F.encodeJSON(warnings, "warnings.json"))
        F.writeSafe(META_FILE, F.encodeJSON({
            Schema = SCHEMA_NAME, SchemaVersion = SCHEMA_VERSION,
            DumpId = currentDumpId, Mode = "RuntimeOnly", Selection = SELECTION,
            GeneratedAtUnix = os.time(), ElapsedSeconds = os.clock() - started,
            Events = #runtimeEventRecords, GuiChanges = #guiCapture.Records,
            RecoveryFolder = recoveryState.Folder, Errors = #errors, Warnings = #warnings,
            AvatarInspectionFile = SELECTION.AvatarInspection and AVATAR_INSPECTION_FILE or nil,
            AvatarRecords = SELECTION.AvatarInspection and #F.avatarInspection.Records or nil
        }, "meta.json"))
        F.writeSafe(MANIFEST_FILE, F.encodeJSON({
            Schema = SCHEMA_NAME, SchemaVersion = SCHEMA_VERSION,
            DumpId = currentDumpId, Complete = true, Status = "Complete",
            Stage = "complete", Mode = "RuntimeOnly", Selection = SELECTION,
            Folder = OUTPUT_FOLDER, GeneratedAtUnix = os.time()
        }, "manifest.json"))
        currentStage = "complete"
        if flushRecovery then flushRecovery(true) end
        if recoveryState.Folder then
            F.writeSafe(recoveryState.Folder .. "/status.json", F.encodeJSON({
                DumpId = currentDumpId, Status = "Complete", Stage = currentStage,
                Saved = recoveryState.Saved
            }, "recovery_status.json"))
        end
        if writeDiagnostics then writeDiagnostics("Complete") end
        F.log("Runtime-only dump finished:", OUTPUT_FOLDER)
        return
    end

    checkpointStage("prepare_players")
    if SELECTION.PlayersTools then F.preparePlayerDescriptors() end
    checkpointStage("select_snapshot_nodes")
    F.prepareSelectedSnapshotNodes()

    checkpointStage("snapshot_traversal")
    local rootId = F.assignInstanceId(game)
    F.updateInstanceMeta(game, rootId, nil, "game", "DataModel", "game")

    local root = {
        Id = rootId,
        Name = "game",
        ClassName = "DataModel",
        Path = "game",
        Attributes = F.optionalMap(F.getAttributes(game)),
        Tags = F.getTags(game),
        Properties = {
            Name = F.sanitizeString(game.Name),
            PlaceId = game.PlaceId,
            GameId = game.GameId,
            JobId = F.sanitizeString(game.JobId)
        },
        Children = {}
    }

    if journalRecord then
        journalRecord("Snapshot", { Id = rootId, ParentId = nil, Name = "game",
            ClassName = "DataModel", Path = "game", Properties = root.Properties,
            Attributes = root.Attributes, Tags = root.Tags })
    end
    if flushRecovery then flushRecovery(true) end
    for _, service in ipairs(F.getSortedChildren(game)) do
        if selectedSnapshotNodes and not selectedSnapshotNodes[service] then continue end
        local serviceName = F.safeName(service)
        if CONFIG.SkipEngineInternals and (serviceName == "CorePackages" or serviceName == "CoreGui") then
            root.SkippedEngineServices = root.SkippedEngineServices or {}
            root.SkippedEngineServices[#root.SkippedEngineServices + 1] = serviceName
            continue
        end
        local ok, result, status = pcall(
            dumpNode,
            service,
            rootId,
            {
                InventorySource = nil,
                ToolState = nil,
                ParentObject = game
            }
        )

        if ok then
            if result then
                table.insert(root.Children, result)
            elseif status == nil then
                F.recordError("DumpRootChild", service, "dumpNode returned no data")
            end
        else
            F.recordError("DumpRootChild", service, result)
            table.insert(root.Children, F.makeFailedNode(service, rootId, result))
        end
    end

    F.logProgress(true, "snapshot complete")
    snapshotFinalized = true
    checkpointStage("finalize_indexes")
    F.finalizeIndexes()

    table.clear(traversedInstances)

    local snapshotElapsed = os.clock() - started
    local writtenFiles = {}

    checkpointStage("write_structure_text")
    if SELECTION.Structure then
        local treeLines = F.makeTree(root)
        F.writeTextDocument(TREE_FILE, table.concat(treeLines, "\n"), writtenFiles, true)
    end
    F.releaseTemporaryMemory()

    checkpointStage("write_visual_assets")
    if SELECTION.Visuals then
        F.writeJSONDocument(VISUAL_ASSETS_FILE,
            F.buildVisualDocument(visualSnapshotRecords, false),
            "visual_assets.json", writtenFiles, false)
    end
    table.clear(visualSnapshotRecords)

    checkpointStage("write_gui_index")
    if SELECTION.GUI then
        F.writeJSONDocument(GUI_FILE, {
            Total = #guiCapture.Snapshot,
            Omitted = guiCapture.SnapshotOmitted,
            Elements = guiCapture.Snapshot,
            IndexedPropertiesSource = SELECTION.Structure and CONFIG.CompactSecondaryIndexes and "structure.json" or nil
        }, "gui.json", writtenFiles, true)
    end
    table.clear(guiCapture.Snapshot)

    checkpointStage("write_structure_json")
    if SELECTION.Structure then
        F.writeJSONDocument(STRUCTURE_FILE, root, "structure.json", writtenFiles, true)
    end
    root = nil
    F.releaseTemporaryMemory()

    checkpointStage("build_instance_index")
    local instanceIndex = F.buildInstanceIndex()
    local instanceCount = #instanceIndex
    local pathStats = F.buildPathStats(instanceIndex)

    checkpointStage("write_instances")
    if SELECTION.Structure then
        F.writeJSONDocument(INSTANCES_FILE, instanceIndex, "instances.json", writtenFiles, true)
    end

    checkpointStage("build_state_index")
    local stateDocument = F.buildStateIndex(instanceIndex)
    stateDocument.PathCollisions = pathStats
    stateDocument.PlayerReferenceCount = #playerReferences
    stateDocument.ValueRecordCount = #valueRecords

    checkpointStage("write_state")
    if SELECTION.Structure then
        F.writeJSONDocument(STATE_FILE, stateDocument, "state.json", writtenFiles, true)
    end
    stateDocument = nil
    instanceIndex = nil

    -- Resolve any early runtime references while snapshot metadata still exists,
    -- then release the largest metadata table before the post-snapshot trace window.
    F.backfillRuntimeIds()
    table.clear(instanceMetaById)
    F.releaseTemporaryMemory()

    checkpointStage("write_static_indexes")
    local inventory = F.buildInventory()
    local playerIndex = F.buildPlayerIndex()

    local remotesDocument = {
        Total = F.totalRemoteCount(),
        RemoteEvents = remoteIndex.RemoteEvents,
        UnreliableRemoteEvents = remoteIndex.UnreliableRemoteEvents,
        RemoteFunctions = remoteIndex.RemoteFunctions,
        BindableEvents = remoteIndex.BindableEvents,
        BindableFunctions = remoteIndex.BindableFunctions
    }

    local scriptsDocument = {
        Total = F.totalScriptCount(),
        LocalScripts = scriptIndex.LocalScripts,
        ModuleScripts = scriptIndex.ModuleScripts,
        Scripts = scriptIndex.Scripts,
        CoreScripts = scriptIndex.CoreScripts
    }

    local valuesDocument = {
        Total = #valueRecords,
        Values = valueRecords
    }

    local playerReferencesDocument = {
        Total = #playerReferences,
        References = playerReferences
    }

    if SELECTION.Structure then
    F.writeJSONDocument(TAGS_FILE, { Total = #tagRecords, Omitted = tagOmitted,
            Counts = tagCounts, TaggedInstances = tagRecords }, "tags.json", writtenFiles, false)
        F.writeJSONDocument(INTERACTIONS_FILE, { Total = #interactionRecords,
            Omitted = interactionOmitted, Interactions = interactionRecords,
            IndexedPropertiesSource = CONFIG.CompactSecondaryIndexes and "structure.json" or nil },
            "interactions.json", writtenFiles, false)
        F.writeJSONDocument(PHYSICS_FILE, { Total = #physicsRecords,
            Omitted = physicsOmitted, JointsAndConstraints = physicsRecords,
            IndexedPropertiesSource = CONFIG.CompactSecondaryIndexes and "structure.json" or nil },
            "physics.json", writtenFiles, false)
    end
    if SELECTION.Remotes then F.writeJSONDocument(REMOTES_FILE, remotesDocument, "remotes.json", writtenFiles, true) end
    if SELECTION.PlayersTools then
        F.writeJSONDocument(INVENTORY_FILE, inventory, "inventory.json", writtenFiles, true)
        F.writeJSONDocument(TOOLS_FILE, toolRecords, "tools.json", writtenFiles, true)
        F.writeJSONDocument(PLAYERS_FILE, playerIndex, "players.json", writtenFiles, true)
        F.writeJSONDocument(PLAYER_REFERENCES_FILE, playerReferencesDocument,
            "player_references.json", writtenFiles, true)
    end
    if SELECTION.Values then
        F.writeJSONDocument(ATTRIBUTES_FILE, attributeIndex, "attributes.json", writtenFiles, true)
        F.writeJSONDocument(VALUES_FILE, valuesDocument, "values.json", writtenFiles, true)
    end
    inventory = nil
    playerIndex = nil
    playerDescriptors = {}

    F.releaseTemporaryMemory()
    selectedSnapshotNodes = nil
    snapshotBusy = false

    checkpointStage("runtime_post_capture")
    F.finishRuntimeTraceAfterSnapshot()

    if SELECTION.Scripts or SELECTION.LocalSources or SELECTION.ModuleSources then
        F.writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts_pre_decompile.json", nil, false)
    end
    checkpointStage("decompile_localscripts")
    F.decompileQueuedClientScripts(scriptsDocument)
    checkpointStage("decompile_modules")
    F.decompileQueuedModules(scriptsDocument)
    if SELECTION.Scripts or SELECTION.LocalSources or SELECTION.ModuleSources then
        F.writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts.json", writtenFiles, true)
    end
    if SELECTION.InteractionResearch then
        checkpointStage("interaction_research_export")
        local candidates = {}
        local normalizedCounts = {}
        for _, bucket in pairs(remoteIndex) do
            for _, entry in ipairs(bucket) do
                local normalized = F.normalizeComparisonPath(entry.Path)
                local key = entry.ClassName .. "|" .. normalized
                normalizedCounts[key] = (normalizedCounts[key] or 0) + 1
                candidates[#candidates + 1] = {
                    Path = entry.Path, NormalizedPath = normalized,
                    StableKey = key, Name = entry.Name, ClassName = entry.ClassName,
                    ParentId = entry.ParentId, Attributes = entry.Attributes,
                    Tags = entry.Tags, Client = entry.Client,
                    LooksSessionGenerated = normalized ~= entry.Path
                }
            end
        end
        table.sort(candidates, function(a, b)
            return a.StableKey < b.StableKey or
                (a.StableKey == b.StableKey and a.Path < b.Path)
        end)
        for _, entry in ipairs(candidates) do
            entry.NormalizedPathGroupCount = normalizedCounts[entry.StableKey]
            entry.NormalizedPathAmbiguous = normalizedCounts[entry.StableKey] > 1
        end
        local scripts = {}
        for _, bucket in pairs(scriptIndex) do
            for _, entry in ipairs(bucket) do
                scripts[#scripts + 1] = {
                    ClassName = entry.ClassName, Path = entry.Path,
                    StableKey = entry.ClassName .. "|" .. F.normalizeComparisonPath(entry.Path),
                    Decompile = entry.Decompile
                }
            end
        end
        table.sort(scripts, function(a, b) return a.StableKey < b.StableKey end)
        local tools = {}
        for _, entry in ipairs(toolRecords) do
            tools[#tools + 1] = {
                Name = entry.Name, Path = entry.Path,
                NormalizedPath = F.normalizeComparisonPath(entry.Path),
                InventorySource = entry.Source,
                Location = entry.Location,
                IsLocalPlayer = entry.IsLocalPlayer,
                Attributes = entry.Attributes, Properties = entry.Properties
            }
        end
        F.writeJSONDocument(INTERACTION_RESEARCH_FILE, {
            Schema = "Averyn.InteractionResearch", Version = 1,
            DumpId = currentDumpId,
            PlaceId = game.PlaceId, GameId = game.GameId, JobId = F.sanitizeString(game.JobId),
            Method = "Passive enumeration, script source analysis and optional outbound trace",
            Caveats = {
                "Client observation cannot reveal server-only source or authoritative validation.",
                "Normalized high-entropy path components are patterns, not guaranteed identities.",
                "Instance IDs are dump-local, not stable across servers.",
                "A matching remote path does not prove identical argument schemas.",
                "Outgoing FireServer/InvokeServer activity requires the opt-in hook; without it, it is unobserved."
            },
            OutgoingHookEnabled = CONFIG.RuntimeTraceOutgoingRemotes,
            OutgoingHookInstalled = runtimeOutgoingHookInstalled,
            SourcesSucceeded = clientDecompileStats.Succeeded + moduleDecompileStats.Succeeded,
            SourceReferenceCount = #interactionSourceReferences,
            SourceReferenceRecordsDropped = interactionSourceRefsDropped,
            RemoteCount = #candidates, Remotes = candidates,
            Scripts = scripts, Tools = tools,
            RemoteUsageFile = REMOTE_USAGE_FILE,
            ToolObservations = interactionToolCounts,
            RemoteLifecycle = interactionRemoteLifecycleCounts,
            EventsSaved = #interactionEvents, EventsDropped = interactionDropped
        }, "interaction_research.json", writtenFiles, true)
        F.writeJSONDocument(INTERACTION_EVENTS_FILE, {
            DumpId = currentDumpId, Total = #interactionEvents, Dropped = interactionDropped,
            Description = "Client-observed tool and interaction events and remote lifecycle; server activity is not fully visible",
            Events = interactionEvents
        }, "interaction_events.json", writtenFiles, false)
        F.writeJSONDocument(SOURCE_REFERENCES_FILE, {
            DumpId = currentDumpId, Total = #interactionSourceReferences,
            Dropped = interactionSourceRefsDropped, Records = interactionSourceReferences
        }, "source_references.json", writtenFiles, false)
        F.writeJSONDocument(CONNECTION_RESEARCH_FILE, {
            DumpId = currentDumpId,
            Enabled = SELECTION.ClosureResearch,
            Total = #interactionConnectionRecords,
            Dropped = interactionConnectionDropped,
            Description = "Best-effort callback and upvalue inspection for supported native interaction signals. Snapshot-only evidence.",
            Records = interactionConnectionRecords
        }, "connection_research.json", writtenFiles, false)
    end
    if SELECTION.Runtime then F.writeJSONDocument(REMOTE_USAGE_FILE, {
        DumpId = currentDumpId, TotalUniqueRemotes = #remoteUsageRecords,
        OmittedRemotesDueToCap = remoteUsageOverflow,
        Coverage = "Observed incoming and outgoing calls for this run, cumulative (not just rolling window)",
        Remotes = remoteUsageRecords
    }, "remote_usage.json", writtenFiles, false) end

    if SELECTION.Runtime and SELECTION.Visuals then F.writeJSONDocument(
        RUNTIME_VISUAL_ASSETS_FILE,
        F.buildVisualDocument(visualDynamicRecords, true),
        "runtime_visual_assets.json", writtenFiles, false
    ) end

    if SELECTION.Runtime then
    local runtimeEventsDocument = F.makeRuntimeEventDocument(runtimeEventRecords, nil)
    runtimeEventsDocument.CategoryTotals = {
        RemoteEvent = #runtimeEventCategoryRecords.RemoteEvent,
        UnreliableRemoteEvent = #runtimeEventCategoryRecords.UnreliableRemoteEvent,
        RemoteFunction = #runtimeEventCategoryRecords.RemoteFunction,
        Other = #runtimeEventCategoryRecords.Other
    }
    runtimeEventsDocument.CategoryDroppedDueToCap = runtimeEventCategoryDropped

    F.writeJSONDocument(RUNTIME_FILES.Gui, {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTraceGui,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Observed = guiCapture.ObservedCount,
        ObserverOmissions = guiCapture.OmittedObservers,
        Total = #guiCapture.Records,
        Changes = guiCapture.Records
    }, "runtime_gui.json", writtenFiles, false)

    local runtimeValuesDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTrace,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeValueRecords,
        Changes = runtimeValueRecords
    }

    local runtimeAttributesDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTrace,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeAttributeRecords,
        Changes = runtimeAttributeRecords
    }

    local runtimeCharacterDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTraceCharacter,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        SampleInterval = CONFIG.RuntimeCharacterSampleInterval,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeCharacterRecords,
        Records = runtimeCharacterRecords
    }

    local runtimeLogsDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeCaptureLogs,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeLogRecords,
        Records = runtimeLogRecords
    }

    local runtimeTimelineDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTrace,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeTimelineRecords,
        Timeline = runtimeTimelineRecords
    }

    local runtimeDisconnectDocument = {
        DumpId = currentDumpId,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        ErrorMessages = runtimeErrorRecords
    }

    local runtimeHooksDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTraceHookDiagnostics,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Total = #runtimeHookState.HookRecords,
        Records = runtimeHookState.HookRecords
    }

    local runtimeHookIntegrityDocument = {
        DumpId = currentDumpId,
        Enabled = CONFIG.RuntimeTraceHookDiagnostics,
        Active = runtimeTraceActive,
        Frozen = runtimeHookState.Frozen,
        FreezeInfo = runtimeHookState.FreezeInfo,
        RollingWindow = true,
        WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
        ElapsedSeconds = os.clock() - runtimeStartedAt,
        Baseline = runtimeHookState.HookIntegrityBaseline,
        LastSnapshot = runtimeHookState.HookIntegrityLast,
        Total = #runtimeHookState.HookIntegrityRecords,
        Records = runtimeHookState.HookIntegrityRecords
    }

    F.writeJSONDocument(
        RUNTIME_FILES.Events,
        runtimeEventsDocument,
        "runtime_events.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.EventsRemoteEvent,
        F.makeRuntimeEventDocument(runtimeEventCategoryRecords.RemoteEvent, "RemoteEvent"),
        "runtime_events_remote_event.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.EventsUnreliableRemoteEvent,
        F.makeRuntimeEventDocument(runtimeEventCategoryRecords.UnreliableRemoteEvent, "UnreliableRemoteEvent"),
        "runtime_events_unreliable_remote_event.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.EventsRemoteFunction,
        F.makeRuntimeEventDocument(runtimeEventCategoryRecords.RemoteFunction, "RemoteFunction"),
        "runtime_events_remote_function.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.EventsOther,
        F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Other, "Other"),
        "runtime_events_other.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.Values,
        runtimeValuesDocument,
        "runtime_values.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.Attributes,
        runtimeAttributesDocument,
        "runtime_attributes.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.Character,
        runtimeCharacterDocument,
        "runtime_character.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.Logs,
        runtimeLogsDocument,
        "runtime_logs.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.Timeline,
        runtimeTimelineDocument,
        "runtime_timeline.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.Disconnect,
        runtimeDisconnectDocument,
        "runtime_disconnect.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.Hooks,
        runtimeHooksDocument,
        "runtime_hooks.json",
        writtenFiles,
        false
    )
    F.writeJSONDocument(
        RUNTIME_FILES.HookIntegrity,
        runtimeHookIntegrityDocument,
        "runtime_hook_integrity.json",
        writtenFiles,
        false
    )

    end
    if SELECTION.AvatarInspection then
        F.finishAvatarInspection()
        F.writeJSONDocument(AVATAR_INSPECTION_FILE, F.avatarInspectionDocument(),
            "avatar_inspection.json", writtenFiles, true)
    end
    F.V38.export(writtenFiles)
    F.writeJSONDocument(WARNINGS_FILE, warnings, "warnings.json", writtenFiles, true)

    local totalElapsed = os.clock() - started
    local meta = {
        Schema = SCHEMA_NAME,
        SchemaVersion = SCHEMA_VERSION,
        DumpId = currentDumpId,
        GeneratedAtUnix = os.time(),
        Recovery = { Folder = recoveryState.Folder, Sequences = recoveryState.Sequences,
            Saved = recoveryState.Saved, FailedWrites = recoveryState.FailedWrites },
        Selection = SELECTION,
        OutputFolder = OUTPUT_FOLDER,
        AvatarInspection = SELECTION.AvatarInspection and {
            File = AVATAR_INSPECTION_FILE,
            Records = #F.avatarInspection.Records,
            UniquePlayers = F.avatarInspection.UniquePlayers,
            CapturePeriodSeconds = CONFIG.RuntimeTracePostSeconds,
            ReadOnly = true
        } or nil,
        AdditionalIndexes = SELECTION.Structure and { TAGS_FILE, INTERACTIONS_FILE, PHYSICS_FILE } or {},
        IdSemantics = "Snapshot-local. IDs are stable only inside this dump.",
        PathSemantics = "Human-readable path. Paths are not guaranteed to be unique.",
        Game = {
            Name = F.sanitizeString(game.Name),
            PlaceId = game.PlaceId,
            GameId = game.GameId,
            JobId = F.sanitizeString(game.JobId),
            CreatorId = F.avatarRead(game, "CreatorId"),
            CreatorType = F.avatarRead(game, "CreatorType"),
            PlaceVersion = F.avatarRead(game, "PlaceVersion")
        },
        V38 = {
            CoverageFile = OUTPUT_FOLDER .. "/coverage.json",
            RigHierarchyFile = SELECTION.AvatarInspection and OUTPUT_FOLDER .. "/rig_hierarchy.json" or nil,
            RuntimeEventsFile = SELECTION.Runtime and OUTPUT_FOLDER .. "/runtime_v38_events.json" or nil,
            AssetCatalogueFile = (SELECTION.Visuals or SELECTION.AvatarInspection) and OUTPUT_FOLDER .. "/asset_catalogue.json" or nil,
            SourceGraphFile = (SELECTION.LocalSources or SELECTION.ModuleSources) and OUTPUT_FOLDER .. "/source_dependency_graph.json" or nil,
            Observers = F.V38.ObservedCount, RuntimeEvents = #F.V38.Events,
            EventsOmitted = F.V38.EventOmitted
        },
        Player = LocalPlayer and {
            Name = F.safeName(LocalPlayer),
            UserId = LocalPlayer.UserId
        } or nil,
        Stats = {
            Instances = instanceCount,
            DescendantInstances = nodeCount,
            RegisteredIds = nextInstanceId,
            RemotesAndBindables = F.totalRemoteCount(),
            Scripts = F.totalScriptCount(),
            LocalScriptsQueuedForDecompile = clientDecompileStats.Queued,
            LocalScriptsDecompiled = clientDecompileStats.Succeeded,
            LocalScriptsDecompileFailed = clientDecompileStats.Failed,
            LocalScriptsDecompileSkipped = clientDecompileStats.Skipped,
            ModuleScriptsQueuedForDecompile = moduleDecompileStats.Queued,
            ModuleScriptsDecompiled = moduleDecompileStats.Succeeded,
            ModuleScriptsDecompileFailed = moduleDecompileStats.Failed,
            ModuleScriptsDecompileSkipped = moduleDecompileStats.Skipped,
            ObjectsWithAttributes = #attributeIndex,
            ValueBaseRecords = #valueRecords,
            GuiElements = guiCapture.SnapshotSaved,
            GuiSnapshotOmitted = guiCapture.SnapshotOmitted,
            PlayerReferences = #playerReferences,
            Tools = #toolRecords,
            TaggedInstances = #tagRecords,
            Interactions = #interactionRecords,
            Physics = #physicsRecords,
            RemotesObservedWithCalls = #remoteUsageRecords,
            DuplicatePathGroups = pathStats.DuplicatePathGroups,
            InstancesInDuplicatePaths = pathStats.InstancesInDuplicatePaths,
            Errors = #errors,
            Warnings = #warnings,
            SanitizedInvalidUtf8UniqueStrings = invalidUtf8StringCount,
            InvalidClassNames = invalidClassNameCount,
            SnapshotSeconds = snapshotElapsed,
            ElapsedSeconds = totalElapsed
        },
        LocalScriptDecompiler = {
            Enabled = CONFIG.DecompileLocalScripts,
            Endpoint = CONFIG.ModuleDecompilerEndpoint,
            MaxScripts = CONFIG.LocalDecompilerMaxScripts,
            Workers = CONFIG.LocalDecompilerWorkers,
            TimeoutSeconds = CONFIG.LocalDecompilerTimeout,
            OutputFolder = currentClientSourcesFolder or CLIENT_SOURCES_FOLDER,
            Stats = clientDecompileStats
        },
        ModuleDecompiler = {
            Enabled = CONFIG.DecompileModuleScripts,
            Endpoint = CONFIG.ModuleDecompilerEndpoint,
            Workers = CONFIG.ModuleDecompilerWorkers,
            TimeoutSeconds = CONFIG.ModuleDecompilerTimeout,
            Ignore = CONFIG.ModuleDecompilerIgnore,
            RetryCount = CONFIG.ModuleDecompilerRetryCount,
            AbortAfterTimeouts = CONFIG.ModuleDecompilerAbortAfterTimeouts,
            OutputFolder = currentModuleSourcesFolder or MODULE_SOURCES_FOLDER,
            Stats = moduleDecompileStats
        },
        GuiCapture = {
            Enabled = CONFIG.GuiCapture,
            SnapshotCount = guiCapture.SnapshotSaved,
            SnapshotOmitted = guiCapture.SnapshotOmitted,
            RuntimeTraceEnabled = CONFIG.RuntimeTraceGui,
            ObservedObjects = guiCapture.ObservedCount,
            ObserverOmissions = guiCapture.OmittedObservers,
            RuntimeChanges = #guiCapture.Records,
            Files = { GUI_FILE, RUNTIME_FILES.Gui }
        },
        VisualCapture = {
            Enabled = CONFIG.VisualCapture,
            SnapshotCount = visualSnapshotSaved,
            DynamicCount = #visualDynamicRecords,
            SnapshotOmitted = visualSnapshotOmitted,
            DynamicOmitted = visualDynamicOmitted,
            EssentialOverflowSaved = visualEssentialOverflowSaved,
            AnimationPlaybackCount = #visualAnimationPlaybackRecords,
            AnimationPlaybackOmitted = visualAnimationPlaybackOmitted,
            TrackedAnimators = visualTrackedAnimatorCount,
            Files = { VISUAL_ASSETS_FILE, RUNTIME_VISUAL_ASSETS_FILE }
        },
        RuntimeTrace = {
            Enabled = CONFIG.RuntimeTrace,
            Frozen = runtimeHookState.Frozen,
            FreezeInfo = runtimeHookState.FreezeInfo,
            PostSeconds = CONFIG.RuntimeTracePostSeconds,
            RingWindowSeconds = CONFIG.RuntimeRingWindowSeconds,
            IncomingRemotes = CONFIG.RuntimeTraceIncomingRemotes,
            OutgoingRemotes = CONFIG.RuntimeTraceOutgoingRemotes,
            OutgoingRemoteObservationMode = "PostCallPassive",
            DynamicRemotes = CONFIG.RuntimeTraceDynamicRemotes,
            ToolAttributes = CONFIG.RuntimeTraceToolAttributes,
            AllAttributes = CONFIG.RuntimeTraceAllAttributes,
            AllValues = CONFIG.RuntimeTraceAllValues,
            CaptureCaller = CONFIG.RuntimeCaptureCaller,
            CaptureCallerStack = CONFIG.RuntimeCaptureCallerStack,
            CallerStackDepth = CONFIG.RuntimeCallerStackDepth,
            CaptureInvokeReturns = CONFIG.RuntimeCaptureInvokeReturns,
            CaptureBuffers = CONFIG.RuntimeCaptureBuffers,
            MaxBufferBytes = CONFIG.RuntimeMaxBufferBytes,
            MaxSerializedTableItems = CONFIG.RuntimeMaxSerializedTableItems,
            MaxSerializedStringBytes = CONFIG.RuntimeMaxSerializedStringBytes,
            TraceCharacter = CONFIG.RuntimeTraceCharacter,
            CharacterSampleInterval = CONFIG.RuntimeCharacterSampleInterval,
            CaptureLogs = CONFIG.RuntimeCaptureLogs,
            TraceGui = CONFIG.RuntimeTraceGui,
            MaxObservedGui = CONFIG.RuntimeMaxObservedGui,
            MaxGuiChanges = CONFIG.RuntimeMaxGuiChanges,
            MaxLogRecords = CONFIG.RuntimeMaxLogRecords,
            TraceHookDiagnostics = CONFIG.RuntimeTraceHookDiagnostics,
            HookIntegrityInterval = CONFIG.RuntimeHookIntegrityInterval,
            MaxHookRecords = CONFIG.RuntimeMaxHookRecords,
            MaxHookIntegrityRecords = CONFIG.RuntimeMaxHookIntegrityRecords,
            FreezeOnDisconnectError = CONFIG.RuntimeFreezeOnDisconnectError,
            MaxEvents = CONFIG.RuntimeMaxEvents,
            MaxEventsPerCategory = CONFIG.RuntimeMaxEventsPerCategory,
            MaxValueChanges = CONFIG.RuntimeMaxValueChanges,
            MaxAttributeChanges = CONFIG.RuntimeMaxAttributeChanges,
            ObserverCaps = {
                Remotes = CONFIG.RuntimeMaxObservedRemotes,
                Attributes = CONFIG.RuntimeMaxObservedAttributes,
                Values = CONFIG.RuntimeMaxObservedValues
            },
            ObservedObjects = runtimeObserverCounts,
            MaxCharacterRecords = CONFIG.RuntimeMaxCharacterRecords,
            MaxTimelineRecords = CONFIG.RuntimeMaxTimelineRecords,
            Recorded = {
                Events = #runtimeEventRecords,
                RemoteEventEvents = #runtimeEventCategoryRecords.RemoteEvent,
                UnreliableRemoteEventEvents = #runtimeEventCategoryRecords.UnreliableRemoteEvent,
                RemoteFunctionEvents = #runtimeEventCategoryRecords.RemoteFunction,
                OtherEvents = #runtimeEventCategoryRecords.Other,
                ValueChanges = #runtimeValueRecords,
                AttributeChanges = #runtimeAttributeRecords,
                CharacterRecords = #runtimeCharacterRecords,
                GuiChanges = #guiCapture.Records,
                LogRecords = #runtimeLogRecords,
                TimelineRecords = #runtimeTimelineRecords,
                ErrorMessages = #runtimeErrorRecords,
                HookObservations = #runtimeHookState.HookRecords,
                HookIntegrityRecords = #runtimeHookState.HookIntegrityRecords
            },
            CategoryDroppedDueToCap = runtimeEventCategoryDropped
        },
        InteractionResearch = {
            Enabled = SELECTION.InteractionResearch,
            RemoteCount = F.totalRemoteCount(),
            ToolEvents = #interactionEvents,
            ToolEventsDropped = interactionDropped,
            SourceReferences = #interactionSourceReferences,
            SourceReferencesDropped = interactionSourceRefsDropped,
            ClosureResearchEnabled = SELECTION.ClosureResearch,
            ClosureSnapshots = #interactionConnectionRecords,
            Files = SELECTION.InteractionResearch and {
                INTERACTION_RESEARCH_FILE, INTERACTION_EVENTS_FILE, SOURCE_REFERENCES_FILE,
                CONNECTION_RESEARCH_FILE
            } or nil
        },
        Capabilities = capabilities
    }

    F.writeTextDocument(
        SUMMARY_FILE,
        F.buildSummary(totalElapsed, pathStats),
        writtenFiles,
        true
    )

    meta.Stats.Errors = #errors
    meta.Stats.Warnings = #warnings
    meta.Stats.ElapsedSeconds = os.clock() - started
    F.writeJSONDocument(META_FILE, meta, "meta.json", writtenFiles, true)

    F.writeJSONDocument(ERRORS_FILE, errors, "errors.json", writtenFiles, true)

    local complete = true
    for _, file in ipairs(writtenFiles) do
        if file.Required and not file.Success then
            complete = false
            break
        end
    end

    local manifest = {
        Schema = SCHEMA_NAME,
        SchemaVersion = SCHEMA_VERSION,
        DumpId = currentDumpId,
        Selection = SELECTION,
        OutputFolder = OUTPUT_FOLDER,
        Complete = complete,
        Status = complete and "Complete" or "Incomplete",
        Stage = "complete",
        HasErrors = #errors > 0,
        HasWarnings = #warnings > 0,
        GeneratedAtUnix = os.time(),
        IdSemantics = "Snapshot-local",
        Files = writtenFiles,
        Stats = {
            Instances = instanceCount,
            DescendantInstances = nodeCount,
            RegisteredIds = nextInstanceId,
            GuiElements = guiCapture.SnapshotSaved,
            GuiChanges = #guiCapture.Records,
            LocalScriptsQueuedForDecompile = clientDecompileStats.Queued,
            LocalScriptsDecompiled = clientDecompileStats.Succeeded,
            LocalScriptsDecompileFailed = clientDecompileStats.Failed,
            LocalScriptsDecompileSkipped = clientDecompileStats.Skipped,
            ModuleScriptsQueuedForDecompile = moduleDecompileStats.Queued,
            ModuleScriptsDecompiled = moduleDecompileStats.Succeeded,
            ModuleScriptsDecompileFailed = moduleDecompileStats.Failed,
            ModuleScriptsDecompileSkipped = moduleDecompileStats.Skipped,
            Errors = #errors,
            Warnings = #warnings
        },
        RuntimeTrace = {
            Enabled = CONFIG.RuntimeTrace,
            FilesAreAuxiliary = true,
            RollingWindow = true,
            WindowSeconds = CONFIG.RuntimeRingWindowSeconds,
            Frozen = runtimeHookState.Frozen,
            FreezeInfo = runtimeHookState.FreezeInfo,
            Events = #runtimeEventRecords,
            RemoteEventEvents = #runtimeEventCategoryRecords.RemoteEvent,
            UnreliableRemoteEventEvents = #runtimeEventCategoryRecords.UnreliableRemoteEvent,
            RemoteFunctionEvents = #runtimeEventCategoryRecords.RemoteFunction,
            OtherEvents = #runtimeEventCategoryRecords.Other,
            ValueChanges = #runtimeValueRecords,
            AttributeChanges = #runtimeAttributeRecords,
            CharacterRecords = #runtimeCharacterRecords,
            GuiChanges = #guiCapture.Records,
            LogRecords = #runtimeLogRecords,
            TimelineRecords = #runtimeTimelineRecords,
            ErrorMessages = #runtimeErrorRecords,
            HookObservations = #runtimeHookState.HookRecords,
            HookIntegrityRecords = #runtimeHookState.HookIntegrityRecords,
            CategoryDroppedDueToCap = runtimeEventCategoryDropped
        }
    }

    local manifestEncoded, manifestEncodeOk = F.encodeJSON(manifest, "manifest.json")
    local manifestWriteOk = F.writeSafe(MANIFEST_FILE, manifestEncoded)
    if not manifestEncodeOk or not manifestWriteOk then
        warn("GameStructureDump: manifest.json could not be completed.")
    end

    currentStage = "complete"
    if flushRecovery then flushRecovery(true) end
    if recoveryState.Folder then
        F.writeSafe(recoveryState.Folder .. "/status.json", F.encodeJSON({
            DumpId = currentDumpId, Status = "Complete", Stage = currentStage,
            Saved = recoveryState.Saved
        }, "recovery_status.json"))
    end
    if writeDiagnostics then writeDiagnostics("Complete") end
    F.log("All exports finished, finalizing statistics")
    print("dump finished")
    print("DumpId:", currentDumpId)
    print("Serialized instance records:", instanceCount)
    print("Traversed descendants:", nodeCount)
    print("Registered IDs:", nextInstanceId)
    print("Remotes / Bindables:", F.totalRemoteCount())
    print("Scripts:", F.totalScriptCount())
    print("LocalScripts queued for decompile:", clientDecompileStats.Queued)
    print("LocalScripts decompiled:", clientDecompileStats.Succeeded)
    print("LocalScripts decompile failed:", clientDecompileStats.Failed)
    print("ModuleScripts queued for decompile:", moduleDecompileStats.Queued)
    print("ModuleScripts decompiled:", moduleDecompileStats.Succeeded)
    print("ModuleScripts decompile failed:", moduleDecompileStats.Failed)
    print("ModuleScripts decompile skipped:", moduleDecompileStats.Skipped)
    print("Module decompile time:", string.format("%.2fs", moduleDecompileStats.ElapsedSeconds))
    print("Attributes:", #attributeIndex)
    print("Values:", #valueRecords)
    print("GUI elements captured:", guiCapture.SnapshotSaved)
    print("GUI entries omitted by snapshot cap:", guiCapture.SnapshotOmitted)
    print("GUI dynamic changes:", #guiCapture.Records)
    print("Player references:", #playerReferences)
    print("Visual assets in snapshot:", visualSnapshotSaved)
    print("Visual assets seen during runtime:", #visualDynamicRecords)
    print("Visual assets omitted by cap:", visualSnapshotOmitted + visualDynamicOmitted)
    print("Tools:", #toolRecords)
    print("Duplicate path groups:", pathStats.DuplicatePathGroups)
    print("Errors:", #errors)
    print("Warnings:", #warnings)
    print("Hook observations:", #runtimeHookState.HookRecords)
    print("Hook integrity records:", #runtimeHookState.HookIntegrityRecords)
    print("Sanitized invalid UTF-8 unique strings:", invalidUtf8StringCount)
    print("Time:", string.format("%.2fs", totalElapsed))
    print("Folder:", OUTPUT_FOLDER)

end

function F.formatFatalError(err)
    local message = F.sanitizeString(err)
    if debug and type(debug.traceback) == "function" then
        local ok, trace = pcall(debug.traceback, message, 2)
        if ok and type(trace) == "string" then
            return F.sanitizeString(trace)
        end
    end
    return message
end

function F.executeDump()
    local runOk, runError = xpcall(F.run, F.formatFatalError)
if activeRegistry and activeRegistryToken
    and activeRegistry.__AverynDumperActive == activeRegistryToken
then
    activeRegistry.__AverynDumperActive = nil
end
if not runOk then
    snapshotBusy = false
    F.recordError("FatalRun", nil, runError, currentStage)
    pcall(function()
        if flushRecovery then flushRecovery(true) end
        if writeDiagnostics then writeDiagnostics("Crashed", { StackTrace = runError }) end
        if recoveryState.Folder then
            F.writeSafe(recoveryState.Folder .. "/status.json", F.encodeJSON({
                DumpId = currentDumpId, Status = "LuaException", Stage = currentStage,
                LastObjectPath = recoveryLastPath, Error = F.sanitizeString(runError)
            }, "recovery_status.json"))
        end
        F.writeSafe(CRASH_FILE, F.encodeJSON({
            DumpId = currentDumpId, Status = "LuaException", Stage = currentStage,
            LastObjectPath = recoveryLastPath, LastObjectClass = recoveryLastClass,
            StackTrace = F.sanitizeString(runError),
            NodeCount = nodeCount, Memory = collectgarbage("count"),
            GeneratedAtUnix = os.time(), RecoveryFolder = recoveryState.Folder
        }, "crash_report.json"))
    end)

    pcall(function()
        if runtimeTraceActive then
            F.stopRuntimeTrace()
        end
    end)

    pcall(function()
        F.writeSafe(ERRORS_FILE, F.encodeJSON(errors, "errors.json"))
        F.writeSafe(WARNINGS_FILE, F.encodeJSON(warnings, "warnings.json"))

        local crashManifest = {
            Schema = SCHEMA_NAME,
            SchemaVersion = SCHEMA_VERSION,
            DumpId = currentDumpId,
            Complete = false,
            Status = "Crashed",
            Stage = currentStage,
            GeneratedAtUnix = os.time(),
            Stats = {
                TraversedDescendants = nodeCount,
                RegisteredIds = nextInstanceId,
                Errors = #errors,
                Warnings = #warnings
            },
            FatalError = F.sanitizeString(runError)
        }

        F.writeSafe(MANIFEST_FILE, F.encodeJSON(crashManifest, "manifest.json"))
    end)

    F.log("Crash report saved, last object:", recoveryLastPath)
    warn("GameStructureDump crashed during stage:", currentStage)
    warn(runError)
end


    F.log("Dump finished with status:", runOk and currentStage == "complete" and "COMPLETE" or "FAILED",
        "elapsed:", string.format("%.2fs", os.clock() - started), "folder:", OUTPUT_FOLDER)
    dumpRunning = false
    if selectionStartButton and selectionStartButton.Parent then
        selectionStartButton.Text = runOk and currentStage == "complete" and "CAPTURE COMPLETE" or "CAPTURE FAILED"
    end
    if selectionStatus and selectionStatus.Parent then
        selectionStatus.Text = runOk and currentStage == "complete"
            and ("Saved to " .. OUTPUT_FOLDER)
            or ("Failed: " .. tostring(runError or currentStage))
        selectionStatus.TextColor3 = runOk and currentStage == "complete"
            and Color3.fromRGB(215, 215, 215) or Color3.fromRGB(176, 176, 176)
    end
end

function F.showSelectionWindow()
    local UserInputService = game:GetService("UserInputService")
    local accent = Color3.fromRGB(205, 205, 205)
    local mainColor = Color3.fromRGB(13, 13, 13)
    local surfaceColor = Color3.fromRGB(29, 29, 29)
    local subtleColor = Color3.fromRGB(158, 158, 158)
    local lightText = Color3.fromRGB(241, 241, 241)
    local darkBorder = Color3.fromRGB(67, 67, 67)
    local selectedSurfaceColor = Color3.fromRGB(45, 45, 45)

    local function create(class, props, parent)
        local object = Instance.new(class)
        for name, value in pairs(props or {}) do object[name] = value end
        if parent then object.Parent = parent end
        return object
    end
    local function round(object, radius)
        create("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
        return object
    end
    local function stroke(object, color, thickness)
        create("UIStroke", { Color = color or darkBorder, Thickness = thickness or 1,
            Transparency = 0.34 }, object)
    end
    local function label(parent, text, size, color, font)
        return create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Text = text, Font = font or Enum.Font.Gotham,
            TextColor3 = color or lightText, TextSize = size or 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, parent)
    end

    local root = create("ScreenGui", {
        Name = "AverynDumperPicker", ResetOnSpawn = false,
        IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 2147483000
    })
    local parent
    if type(gethui) == "function" then
        local ok, gui = pcall(gethui)
        if ok and typeof(gui) == "Instance" then parent = gui end
    end
    if not parent then
        local ok, core = pcall(game.GetService, game, "CoreGui")
        if ok then parent = core end
    end
    if not parent and LocalPlayer then
        parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            or LocalPlayer:WaitForChild("PlayerGui", 10)
    end
    if not parent then
        warn("GameStructureDump: cannot attach the configuration UI (no GUI parent).")
        root:Destroy()
        return
    end
    local previous = parent:FindFirstChild("AverynDumperPicker")
    if previous then previous:Destroy() end
    root.Parent = parent
    selectionGui = root

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(420, 700)
    local width = math.min(414, math.max(250, viewport.X - 24))
    local height = math.min(610, math.max(290, viewport.Y - 24))

    local panel = create("Frame", {
        Name = "Panel", BackgroundColor3 = mainColor, BorderSizePixel = 0,
        Size = UDim2.fromOffset(width, height), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Active = true
    }, root)
    round(panel, 15)
    stroke(panel)

    local header = create("Frame", {
        Name = "Header", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 9), Size = UDim2.new(1, -36, 0, 55), Active = true
    }, panel)
    local heading = label(header, "Averyn Dumper", 18, lightText, Enum.Font.GothamBold)
    heading.Size = UDim2.new(1, -40, 0, 26)
    local subheading = label(header, "Select the data and activity to export", 12, subtleColor)
    subheading.Position = UDim2.fromOffset(0, 28)
    subheading.Size = UDim2.new(1, -20, 0, 20)
    local closeButton = create("TextButton", {
        Text = "×", Font = Enum.Font.GothamMedium, TextSize = 24,
        TextColor3 = subtleColor, BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(30, 30)
    }, header)
    closeButton.MouseButton1Click:Connect(function() root:Destroy() end)

    local body = create("ScrollingFrame", {
        Name = "Options", BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        Position = UDim2.fromOffset(18, 70),
        Size = UDim2.new(1, -36, 1, -196)
    }, panel)
    create("UIListLayout", { Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder }, body)

    local rows = {}
    local compactLayout = width < 340
    local optionRowHeight = compactLayout and 104 or 78
    local optionTitleHeight = compactLayout and 36 or 21
    local optionDescriptionHeight = compactLayout and 52 or 39
    local definitions = {
        { "Structure", "Instance & World Snapshot", "Export hierarchy, instance properties, tags, physics and interaction data." },
        { "GUI", "Interface Hierarchy", "Capture GUI objects, layouts, text, input controls and visual properties." },
        { "Remotes", "Remote & Bindable Registry", "Index RemoteEvents, RemoteFunctions and Bindables with their paths." },
        { "Scripts", "Script Location Index", "Locate LocalScripts, ModuleScripts and Scripts in the instance tree." },
        { "Values", "Values & Attribute Index", "Record ValueBase contents and attributes attached to instances." },
        { "PlayersTools", "Players & Tool Inventories", "Record players, their inventories, tools and ownership references." },
        { "AvatarInspection", "Character & Rig Inspection", "Inspect standard and custom rigs, accessories, joints and poses." },
        { "Visuals", "Animation, Audio & Effects", "Catalogue animation IDs, sounds, particles, meshes and effect assets." },
        { "Runtime", "Live Activity Recorder", "Track remote activity, value changes, GUI events and character state." },
        { "LocalSources", "LocalScript Source Export", "Reconstruct and save readable source files from client LocalScripts." },
        { "ModuleSources", "ModuleScript Source Export", "Decompile ModuleScript bytecode and save the recovered Luau sources." },
        { "InteractionResearch", "Interactions & Remote Analysis", "Inspect tools, prompts, clicks, remote lifecycles and script references." },
        { "ClosureResearch", "Callback & Upvalue Analysis", "Inspect native interaction callbacks, connected functions and upvalues." },
        { "OutgoingHook", "Outgoing Remote Interception", "Trace FireServer and InvokeServer calls; alters the namecall hook." },
        { "CallbackTrace", "Invoke Callback Monitoring", "Observe OnInvoke and OnClientInvoke calls by wrapping handlers." },
    }
    local function updateRow(key)
        local elements = rows[key]
        if not elements then return end
        local on = SELECTION[key]
        elements.Check.BackgroundColor3 = on and accent or surfaceColor
        elements.Tick.Visible = on
        elements.Row.BackgroundColor3 = on and selectedSurfaceColor or surfaceColor
    end
    for order, item in ipairs(definitions) do
        local key, title, subtitle = item[1], item[2], item[3]
        local row = create("TextButton", {
            Name = key, Text = "", BackgroundColor3 = surfaceColor,
            AutoButtonColor = false, Size = UDim2.new(1, -6, 0, optionRowHeight),
            LayoutOrder = order
        }, body)
        round(row, 9)
        local check = create("Frame", {
            BackgroundColor3 = accent, Size = UDim2.fromOffset(21, 21),
            Position = UDim2.new(0, 13, 0.5, -10), BorderSizePixel = 0
        }, row)
        round(check, 6)
        local tick = label(check, "✓", 15, Color3.fromRGB(17, 17, 17), Enum.Font.GothamBold)
        tick.TextXAlignment = Enum.TextXAlignment.Center
        local name = label(row, title, compactLayout and 12 or 13, lightText, Enum.Font.GothamMedium)
        name.Position = UDim2.fromOffset(45, compactLayout and 9 or 11)
        name.Size = UDim2.new(1, -55, 0, optionTitleHeight)
        name.TextWrapped = true
        name.TextYAlignment = Enum.TextYAlignment.Top
        local description = label(row, subtitle, 11, subtleColor)
        description.Position = UDim2.fromOffset(45, compactLayout and 46 or 35)
        description.Size = UDim2.new(1, -55, 0, optionDescriptionHeight)
        description.TextWrapped = true
        description.TextYAlignment = Enum.TextYAlignment.Top
        rows[key] = { Row = row, Check = check, Tick = tick }
        row.MouseButton1Click:Connect(function()
            if dumpRunning then return end
            SELECTION[key] = not SELECTION[key]
            if key == "InteractionResearch" and SELECTION.InteractionResearch then
                for _, dependency in ipairs({ "Remotes", "Scripts", "PlayersTools", "Runtime", "LocalSources", "ModuleSources" }) do
                    SELECTION[dependency] = true
                    updateRow(dependency)
                end
            elseif key == "ClosureResearch" and SELECTION.ClosureResearch then
                SELECTION.InteractionResearch = true
                updateRow("InteractionResearch")
                for _, dependency in ipairs({ "Remotes", "Scripts", "PlayersTools", "Runtime", "LocalSources", "ModuleSources" }) do
                    SELECTION[dependency] = true
                    updateRow(dependency)
                end
            elseif (key == "OutgoingHook" or key == "CallbackTrace") and SELECTION[key] then
                SELECTION.Runtime = true
                updateRow("Runtime")
            end
            updateRow(key)
        end)
        updateRow(key)
    end

    local footer = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 1, -118),
        Size = UDim2.new(1, -36, 0, 108)
    }, panel)
    local runtimeTitle = label(footer, "Extra live capture (seconds)", 12, subtleColor)
    runtimeTitle.Size = UDim2.new(1, -70, 0, 26)
    local runtimeBox = create("TextBox", {
        Text = tostring(CONFIG.RuntimeTracePostSeconds),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = lightText,
        BackgroundColor3 = surfaceColor, ClearTextOnFocus = false,
        Size = UDim2.fromOffset(62, 28), Position = UDim2.new(1, -62, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    }, footer)
    round(runtimeBox, 7)
    local start = create("TextButton", {
        Text = "START CAPTURE", Font = Enum.Font.GothamBold,
        TextSize = 14, TextColor3 = Color3.fromRGB(17, 17, 17),
        BackgroundColor3 = accent,
        Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 43),
        AutoButtonColor = true
    }, footer)
    round(start, 10)
    selectionStartButton = start
    local status = label(footer, "", 11, subtleColor)
    status.Position = UDim2.fromOffset(0, 82)
    status.Size = UDim2.new(1, 0, 0, 23)
    status.TextTruncate = Enum.TextTruncate.AtEnd
    selectionStatus = status

    start.MouseButton1Click:Connect(function()
        if dumpRunning then return end
        local any = false
        for _, enabled in pairs(SELECTION) do if enabled then any = true break end end
        if not any then
            status.Text = "Select at least one capture category."
            status.TextColor3 = Color3.fromRGB(202, 202, 202)
            return
        end
        if SELECTION.Runtime or SELECTION.AvatarInspection then
            local seconds = tonumber(runtimeBox.Text)
            if not seconds or seconds < 0 or seconds > 600 then
                status.Text = "Set a capture time between 0 and 600 seconds."
                status.TextColor3 = Color3.fromRGB(202, 202, 202)
                return
            end
            CONFIG.RuntimeTracePostSeconds = seconds
        end
        dumpRunning = true
        started = os.clock()
        start.Text = "CAPTURING..."
        start.AutoButtonColor = false
        status.TextColor3 = subtleColor
        status.Text = "Preparing output folder..."
        progressLastLoggedAt = os.clock()
        progressLastCount = 0
        progressLastStage = nil
        lastTraversalYield = os.clock()
        lastSelectionYield = os.clock()
        F.log("Capture started. Check the console for progress.")
        task.spawn(F.executeDump)
    end)

    local dragging, dragOrigin, startPosition
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = input
            dragOrigin = input.Position
            startPosition = panel.Position
        end
    end)
    local moveConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input == dragging
            or (dragging.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseMovement)) then
            local delta = input.Position - dragOrigin
            panel.Position = UDim2.new(startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
    local endedConnection = UserInputService.InputEnded:Connect(function(input)
        if input == dragging then dragging = nil end
    end)
    root.Destroying:Connect(function()
        moveConnection:Disconnect()
        endedConnection:Disconnect()
    end)
end

F.showSelectionWindow()
