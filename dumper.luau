local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local OUTPUT_FOLDER = "GameStructureDump"
local SCHEMA_NAME = "Averyn.GameStructureDump"
local SCHEMA_VERSION = 3.3

local META_FILE = OUTPUT_FOLDER .. "/meta.json"
local TREE_FILE = OUTPUT_FOLDER .. "/structure.txt"
local STRUCTURE_FILE = OUTPUT_FOLDER .. "/structure.json"
local INSTANCES_FILE = OUTPUT_FOLDER .. "/instances.json"
local REMOTES_FILE = OUTPUT_FOLDER .. "/remotes.json"
local SCRIPTS_FILE = OUTPUT_FOLDER .. "/scripts.json"
local SUMMARY_FILE = OUTPUT_FOLDER .. "/summary.txt"
local INVENTORY_FILE = OUTPUT_FOLDER .. "/inventory.json"
local ATTRIBUTES_FILE = OUTPUT_FOLDER .. "/attributes.json"
local TOOLS_FILE = OUTPUT_FOLDER .. "/tools.json"
local VALUES_FILE = OUTPUT_FOLDER .. "/values.json"
local PLAYERS_FILE = OUTPUT_FOLDER .. "/players.json"
local PLAYER_REFERENCES_FILE = OUTPUT_FOLDER .. "/player_references.json"
local STATE_FILE = OUTPUT_FOLDER .. "/state.json"
local RUNTIME_FILES = {
	Events = OUTPUT_FOLDER .. "/runtime_events.json",
	EventsGame = OUTPUT_FOLDER .. "/runtime_events_game.json",
	EventsReplicator = OUTPUT_FOLDER .. "/runtime_events_replicator.json",
	EventsAnalytics = OUTPUT_FOLDER .. "/runtime_events_analytics.json",
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
local MODULE_SOURCES_FOLDER = OUTPUT_FOLDER .. "/modules"

local YIELD_EVERY = 100
local MAX_SERIALIZE_DEPTH = 32

local CONFIG = {
	RuntimeTrace = true,
	RuntimeTracePostSeconds = 45,
	RuntimeRingWindowSeconds = 30,
	RuntimeTraceIncomingRemotes = true,
	RuntimeTraceOutgoingRemotes = true,
	RuntimeTraceDynamicRemotes = true,
	RuntimeTraceToolAttributes = true,
	RuntimeTraceInterestingAttributes = true,
	RuntimeTraceAllValues = true,
	RuntimeCaptureCaller = true,
	RuntimeCaptureCallerStack = true,
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
	RuntimeTraceHookDiagnostics = true,
	RuntimeHookIntegrityInterval = 0.20,
	RuntimeMaxHookRecords = 12000,
	RuntimeMaxHookIntegrityRecords = 4000,
	RuntimeHookRaySignatureMagnitude = 5000,
	RuntimeHookRaySignatureTolerance = 3,
	RuntimeHookTargetMaxMissStuds = 12,
	RuntimeHookNormalRaySampleInterval = 0.25,
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
		Game = 16000,
		Replicator = 16000,
		Analytics = 4000,
		Other = 8000
	},
	RuntimeMaxTimelineRecords = 40000,
	RuntimeMaxValueChanges = 16000,
	RuntimeMaxAttributeChanges = 16000,
	RuntimeMaxObservedRemotes = 5000,
	RuntimeMaxObservedAttributes = 6000,
	RuntimeMaxObservedValues = 10000,
	ProgressCheckpointEvery = 5000,
	StateIndexMaxPerBucket = 1500,
	DecompileModuleScripts = true,
	ModuleDecompilerEndpoint = "https://decompiler.bytefall.dev/decompile",
	ModuleDecompilerWorkers = 3,
	ModuleDecompilerTimeout = 10,
	ModuleDecompilerIgnore = { "Chat", "CoreGui", "CorePackages" },
	ModuleDecompilerRetryCount = 0,
	ModuleDecompilerRetryDelay = 0.35,
	ModuleDecompilerAbortAfterTimeouts = 3,
	ModuleDecompilerProgressEvery = 10,
	ModuleDecompilerCheckpointEvery = 25
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
	debug_info = debug ~= nil and type(debug.info) == "function",
	buffer = type(buffer) == "table",
	buffer_len = type(buffer) == "table" and type(buffer.len) == "function",
	buffer_readu8 = type(buffer) == "table" and type(buffer.readu8) == "function",
	buffer_tostring = type(buffer) == "table" and type(buffer.tostring) == "function",
	getrawmetatable = type(getrawmetatable) == "function",
	isreadonly = type(isreadonly) == "function",
	getgenv = type(getgenv) == "function",
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
	Game = {},
	Replicator = {},
	Analytics = {},
	Other = {}
}
local runtimeEventCategoryDropped = {
	Game = 0,
	Replicator = 0,
	Analytics = 0,
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
	LastNormalRayObservationAt = 0,
	FlushScheduled = false
}
local runtimeOutgoingHookInstalled = false
local runtimeStartedAt = os.clock()
local snapshotFinalized = false
local snapshotBusy = false
local currentStage = "init"
local currentDumpId = nil
local currentModuleSourcesFolder = nil
local checkpointStage

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
	table.insert(errors, F.makeIssue(stage, object, message, property))
end

function F.recordWarning(stage, object, message, property)
	table.insert(warnings, F.makeIssue(stage, object, message, property))
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

local PROPERTY_GROUPS = {
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
		Properties = { "Disabled" }
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

	for _, group in ipairs(PROPERTY_GROUPS) do
		if F.safeIsA(object, group.Class) then
			for _, property in ipairs(group.Properties) do
				F.captureProperty(object, data, property)
			end
		end
	end

	if REMOTE_BUCKETS[className] then
		data.RemoteType = className
	end

	if SCRIPT_BUCKETS[className] then
		data.ScriptType = className
	end

	return data
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

	if className == "ModuleScript" then
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
			if value == descriptor.Name then
				F.addPlayerReference(descriptor, objectId, field, "Username", value)
			elseif descriptor.DisplayName ~= descriptor.Name and value == descriptor.DisplayName then
				F.addPlayerReference(descriptor, objectId, field, "DisplayName", value)
			elseif value == tostring(descriptor.UserId) then
				F.addPlayerReference(descriptor, objectId, field, "UserIdString", value)
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

local RUNTIME_KEYWORDS = {
	"team",
	"red",
	"blue",
	"match",
	"round",
	"player",
	"owner",
	"enemy",
	"ally",
	"score",
	"state",
	"teleport",
	"spawn",
	"respawn",
	"winner",
	"dead",
	"ammo",
	"reload",
	"fire",
	"shoot",
	"gun",
	"weapon",
	"tool",
	"damage",
	"projectile",
	"velocity",
	"speed",
	"position",
	"movement",
	"security",
	"detect",
	"kick",
	"ban"
}

local flushRuntimeTrace
local freezeRuntimeTrace

function F.isRuntimeInteresting(name, path)
	local haystack = string.lower((name or "") .. " " .. (path or ""))

	for _, keyword in ipairs(RUNTIME_KEYWORDS) do
		if string.find(haystack, keyword, 1, true) then
			return true
		end
	end

	return false
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
	local text = string.lower(
		(path or F.safeFullName(remote) or "")
			.. " "
			.. F.safeName(remote)
	)

	if string.find(text, "__replicatorinternal", 1, true)
		or string.find(text, "replicatorclient", 1, true)
		or string.find(text, "replicator", 1, true)
	then
		return "Replicator"
	end

	if string.find(text, "analytics", 1, true)
		or string.find(text, "telemetry", 1, true)
		or string.find(text, "metrics", 1, true)
	then
		return "Analytics"
	end

	if string.find(text, "robloxreplicatedstorage", 1, true)
		or string.find(text, "coregui", 1, true)
	then
		return "Other"
	end

	return "Game"
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

	if capabilities.getgenv then
		local envOk, environment = pcall(getgenv)
		if envOk and type(environment) == "table" then
			local target = rawget(environment, "AimTarget")
			if typeof(target) == "Instance" then
				snapshot.AimTarget = F.makeInstanceReference(target, false)
				snapshot.AimTargetFingerprint =
					F.safeFullName(target) .. "|" .. F.sanitizeString(tostring(target))
			elseif target == nil then
				snapshot.AimTargetFingerprint = "nil"
			else
				snapshot.AimTarget = F.serializeRuntimeValue(target)
				snapshot.AimTargetFingerprint =
					typeof(target) .. "|" .. F.sanitizeString(tostring(target))
			end
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
		DirectionMagnitude = record.Ray and record.Ray.DirectionMagnitude or nil,
		Matches5000MagnitudeSignature = record.Matches5000MagnitudeSignature,
		CandidatePath = record.TargetCandidate
			and record.TargetCandidate.Part
			and record.TargetCandidate.Part.Path
			or nil,
		AimTargetPath = record.GlobalAimTarget
			and record.GlobalAimTarget.Path
			or nil
	})

	F.maybeFlushRuntimeTrace()
	return record
end

function F.findRuntimeRayCandidate(origin, direction)
	if typeof(origin) ~= "Vector3"
		or typeof(direction) ~= "Vector3"
		or direction.Magnitude <= 0
	then
		return nil
	end

	local directionUnit = direction.Unit
	local bestPart = nil
	local bestPlayer = nil
	local bestMiss = math.huge
	local bestAlong = nil

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= LocalPlayer then
			local otherCharacter = otherPlayer.Character
			local humanoid = otherCharacter
				and otherCharacter:FindFirstChildOfClass("Humanoid")
				or nil
			local part = otherCharacter
				and (
					otherCharacter:FindFirstChild("Head")
					or otherCharacter:FindFirstChild("HumanoidRootPart")
				)
				or nil

			if humanoid
				and humanoid.Health > 0
				and part
				and F.safeIsA(part, "BasePart")
			then
				local offset = part.Position - origin
				local along = offset.X * directionUnit.X
					+ offset.Y * directionUnit.Y
					+ offset.Z * directionUnit.Z

				if along > 0 then
					local nearestPoint = origin + directionUnit * along
					local miss = (part.Position - nearestPoint).Magnitude

					if miss < bestMiss then
						bestMiss = miss
						bestAlong = along
						bestPart = part
						bestPlayer = otherPlayer
					end
				end
			end
		end
	end

	if not bestPart
		or bestMiss > math.max(
			0,
			tonumber(CONFIG.RuntimeHookTargetMaxMissStuds) or 12
		)
	then
		return nil
	end

	return {
		Player = F.makeInstanceReference(bestPlayer, false),
		Part = F.makeInstanceReference(bestPart, false),
		MissDistance = bestMiss,
		DistanceAlongRay = bestAlong
	}
end

function F.appendRuntimeRayObservation(self, method, packedArguments)
	if not runtimeTraceActive
		or not CONFIG.RuntimeTraceHookDiagnostics
		or self ~= workspace
	then
		return
	end

	local origin = nil
	local direction = nil
	local ray = nil

	if method == "Raycast" then
		origin = packedArguments[1]
		direction = packedArguments[2]
	elseif string.find(method or "", "FindPartOnRay", 1, true) then
		ray = packedArguments[1]
		if typeof(ray) == "Ray" then
			origin = ray.Origin
			direction = ray.Direction
		end
	end

	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	local magnitude = direction.Magnitude
	local signatureMagnitude =
		tonumber(CONFIG.RuntimeHookRaySignatureMagnitude) or 5000
	local signatureTolerance =
		math.max(0, tonumber(CONFIG.RuntimeHookRaySignatureTolerance) or 3)
	local matchesSignature =
		math.abs(magnitude - signatureMagnitude) <= signatureTolerance

	if not matchesSignature then
		local now = os.clock()
		local sampleInterval = math.max(
			0,
			tonumber(CONFIG.RuntimeHookNormalRaySampleInterval) or 0.25
		)

		if sampleInterval > 0
			and now - (runtimeHookState.LastNormalRayObservationAt or 0) < sampleInterval
		then
			return
		end

		runtimeHookState.LastNormalRayObservationAt = now
	end

	local callerInfo, _, callerIsExecutor, callerStack = F.getRuntimeCallerInfo()

	local cameraOrigin = nil
	local cameraDistance = nil
	local camera = workspace.CurrentCamera

	if camera then
		local cameraOk, cameraCFrame = pcall(function()
			return camera.CFrame
		end)

		if cameraOk and typeof(cameraCFrame) == "CFrame" then
			cameraOrigin = cameraCFrame.Position
			cameraDistance = (origin - cameraOrigin).Magnitude
		end
	end

	local globalAimTarget = nil
	if capabilities.getgenv then
		local envOk, environment = pcall(getgenv)
		if envOk and type(environment) == "table" then
			local target = rawget(environment, "AimTarget")
			if typeof(target) == "Instance" then
				globalAimTarget = F.makeInstanceReference(target, false)
			end
		end
	end

	F.appendRuntimeHookRecord({
		HookKind = "NamecallRayObservation",
		Metamethod = "__namecall",
		Method = method,
		Object = F.makeInstanceReference(self, false),
		Arguments = F.serializePackedRuntimeValues(packedArguments),
		Caller = callerInfo,
		CallerIsExecutor = callerIsExecutor,
		CallerStack = callerStack,
		Ray = {
			Origin = F.serializeRuntimeValue(origin),
			Direction = F.serializeRuntimeValue(direction),
			DirectionMagnitude = magnitude,
			EndPoint = F.serializeRuntimeValue(origin + direction),
			CameraOrigin = cameraOrigin and F.serializeRuntimeValue(cameraOrigin) or nil,
			OriginDistanceFromCamera = cameraDistance
		},
		Matches5000MagnitudeSignature = matchesSignature,
		TargetCandidate = F.findRuntimeRayCandidate(origin, direction),
		GlobalAimTarget = globalAimTarget
	})
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

		if previous.AimTargetFingerprint ~= current.AimTargetFingerprint then
			table.insert(changes, {
				Field = "getgenv().AimTarget",
				Previous = previous.AimTarget,
				PreviousFingerprint = previous.AimTargetFingerprint,
				Current = current.AimTarget,
				CurrentFingerprint = current.AimTargetFingerprint
			})
		end
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

function F.appendRuntimeRemoteRecord(remote, direction, method, packedArguments, extra)
	if not runtimeTraceActive then
		return nil
	end

	extra = extra or {}
	local className = F.safeClassName(remote)
	local path = F.safeFullName(remote)
	local category = extra.Category or F.classifyRuntimeRemote(remote, path)
	local callerInfo = extra.Caller

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
		SnapshotPath = extra.SnapshotPath,
		ArgumentCount = packedArguments.n,
		Arguments = F.serializePackedRuntimeValues(packedArguments),
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

function F.watchRuntimeRemote(object, id, name, className, path)
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
		local observeRay = traceActive
			and CONFIG.RuntimeTraceHookDiagnostics
			and self == workspace
			and (
				method == "Raycast"
				or string.find(method or "", "FindPartOnRay", 1, true) ~= nil
			)
		local observeRemote = traceActive
			and (method == "FireServer" or method == "InvokeServer")

		if not observeRay and not observeRemote then
			return oldNamecall(self, ...)
		end

		local packedArguments = table.pack(...)
		local callStarted = os.clock()

		local returns = table.pack(oldNamecall(self, ...))
		local duration = os.clock() - callStarted

		if observeRay then
			pcall(
				F.appendRuntimeRayObservation,
				self,
				method,
				packedArguments
			)
		end

		if observeRemote then
			local className = typeof(self) == "Instance" and F.safeClassName(self) or nil
			local isFireServer = method == "FireServer"
				and (className == "RemoteEvent" or className == "UnreliableRemoteEvent")
			local isInvokeServer = method == "InvokeServer"
				and className == "RemoteFunction"

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
	if not runtimeTraceActive then
		return false
	end

	if CONFIG.RuntimeTraceToolAttributes and F.safeIsA(object, "Tool") then
		return true
	end

	if not CONFIG.RuntimeTraceInterestingAttributes or next(attributes or {}) == nil then
		return false
	end

	if F.safeIsA(object, "Player")
		or F.safeIsA(object, "Humanoid")
		or F.safeIsA(object, "BasePart")
	then
		return true
	end

	return F.isRuntimeInteresting(name, path)
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

	if not CONFIG.RuntimeTraceAllValues and not F.isRuntimeInteresting(name, path) then
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

	if F.isRuntimeInteresting(record.Message, "") then
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

			if CONFIG.RuntimeTraceToolAttributes
				or CONFIG.RuntimeTraceInterestingAttributes
			then
				local shouldPrimeAttributes = F.safeIsA(object, "Tool")
					or F.safeIsA(object, "Player")
					or F.safeIsA(object, "Humanoid")
					or F.safeIsA(object, "BasePart")
					or F.isRuntimeInteresting(name, path)

				if shouldPrimeAttributes then
					local attributes = F.getAttributes(object)
					F.watchRuntimeAttributes(
						object,
						instanceIds[object],
						name,
						className,
						path,
						attributes
					)
				end
			end

			if F.safeIsA(object, "ValueBase") then
				F.watchRuntimeValue(object, instanceIds[object], name, className, path)
			end

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
	runtimeHookState.Frozen = false
	runtimeHookState.Active = true
	runtimeHookState.LastFlushAt = os.clock()
	runtimeHookState.MutationsSinceFlush = 0
	runtimeHookState.LastPruneAt = 0
	runtimeHookState.HookIntegrityLastCheckAt = 0
	runtimeHookState.HookIntegrityBaseline = nil
	runtimeHookState.HookIntegrityLast = nil
	runtimeHookState.LastNormalRayObservationAt = 0
	runtimeHookState.FlushScheduled = false

	if CONFIG.RuntimeTraceHookDiagnostics then
		F.checkRuntimeHookIntegrity(true, "BeforeDumperNamecallHook")
	end

	F.installOutgoingRemoteHook()

	if CONFIG.RuntimeTraceHookDiagnostics then
		F.checkRuntimeHookIntegrity(true, "AfterDumperNamecallHook")
	end

	if CONFIG.RuntimeTraceDynamicRemotes then
		local ok, connection = pcall(function()
			return game.DescendantAdded:Connect(function(object)
				if not runtimeTraceActive then
					return
				end

				task.defer(function()
					if not runtimeTraceActive or not object or not object.Parent then
						return
					end

					local className = F.safeClassName(object)
					local name = F.safeName(object)
					local path = F.safeFullName(object)

					if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
						F.watchRuntimeRemote(object, instanceIds[object], name, className, path)
					end

					if CONFIG.RuntimeTraceToolAttributes
						or CONFIG.RuntimeTraceInterestingAttributes
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

	if CONFIG.RuntimePrimeBeforeSnapshot then
		F.primeRuntimeObservers()
	end

	if LocalPlayer then
		F.watchLocalCharacter(LocalPlayer.Character)

		local addedOk, addedConnection = pcall(function()
			return LocalPlayer.CharacterAdded:Connect(function(newCharacter)
				if not runtimeTraceActive then
					return
				end

				F.watchLocalCharacter(newCharacter)
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

	local heartbeatOk, heartbeatConnection = pcall(function()
		return game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
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

	table.sort(children, function(a, b)
		local classA = F.safeClassName(a):lower()
		local classB = F.safeClassName(b):lower()

		if classA ~= classB then
			return classA < classB
		end

		local nameA = F.safeName(a):lower()
		local nameB = F.safeName(b):lower()

		if nameA ~= nameB then
			return nameA < nameB
		end

		return F.safeFullName(a) < F.safeFullName(b)
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
		task.wait()
	end
	local source = F.resolveInventorySource(object, context and context.InventorySource or nil)
	local parentToolState = context and context.ToolState or nil

	classCounts[className] = (classCounts[className] or 0) + 1

	local attributes = F.getAttributes(object)
	local tags = F.getTags(object)
	local properties = F.getUsefulProperties(object, className)

	F.registerAttributes(id, name, className, path, attributes)
	F.registerRemote(object, id, name, className, parentId, path, attributes, tags)
	F.registerScript(object, id, name, className, parentId, path, properties)
	F.registerValue(object, id, name, className, parentId, path, attributes, tags)
	F.registerToolDescendant(parentToolState, object, id, className, name)

	F.scanAttributesForPlayerReferences(id, attributes)
	if F.safeIsA(object, "ValueBase") then
		local rawValue, readable = F.safeGet(object, "Value")
		if readable then
			F.scanValueForPlayerReferences(id, "Value", rawValue)
		end
	end

	F.watchRuntimeRemote(object, id, name, className, path)
	F.watchRuntimeAttributes(object, id, name, className, path, attributes)
	F.watchRuntimeValue(object, id, name, className, path)

	local currentToolState = parentToolState
	if className == "Tool" or F.safeIsA(object, "Tool") then
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
	Team = { "team", "teams", "red", "blue", "ally", "allies", "enemy", "enemies" },
	Match = { "match", "round", "duel", "gamephase", "gamestate" },
	Player = { "player", "players", "owner", "userid", "username" },
	Teleport = { "teleport", "teleporting", "spawn", "respawn", "respawned" },
	Score = { "score", "kills", "kill", "deaths", "death", "winner", "win" }
}

function F.stateRecordFromMeta(meta, valueById)
	local record = {
		Id = meta.Id,
		Name = meta.Name,
		ClassName = meta.ClassName,
		Path = meta.Path,
		ParentId = meta.ParentId
	}

	local valueRecord = valueById[meta.Id]
	if valueRecord then
		record.Value = valueRecord.Value
	end

	return record
end

function F.buildStateIndex(instanceIndex)
	local buckets = {}
	local counts = {}
	local valueById = {}

	for _, valueRecord in ipairs(valueRecords) do
		valueById[valueRecord.Id] = valueRecord
	end

	for bucketName in pairs(STATE_BUCKETS) do
		buckets[bucketName] = {}
		counts[bucketName] = 0
	end

	for _, meta in ipairs(instanceIndex) do
		local tokenSet = {}
		local nameTokenSet = {}

		for _, token in ipairs(F.tokenizeText(meta.Name or "")) do
			local lowered = string.lower(token)
			tokenSet[lowered] = true
			nameTokenSet[lowered] = true
		end

		for _, token in ipairs(F.tokenizeText(meta.Path or "")) do
			tokenSet[string.lower(token)] = true
		end

		for bucketName, keywords in pairs(STATE_BUCKETS) do
			local matched = bucketName == "Player" and meta.ClassName == "Player"
			local searchSet = bucketName == "Player" and nameTokenSet or tokenSet

			if not matched then
				for _, keyword in ipairs(keywords) do
					if searchSet[keyword] then
						matched = true
						break
					end
				end
			end

			if matched then
				counts[bucketName] = counts[bucketName] + 1
				if #buckets[bucketName] < CONFIG.StateIndexMaxPerBucket then
					table.insert(buckets[bucketName], F.stateRecordFromMeta(meta, valueById))
				end
			end
		end
	end

	return {
		Counts = counts,
		Buckets = buckets
	}
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
		"ModuleScripts queued for decompile: " .. tostring(moduleDecompileStats.Queued),
		"ModuleScripts decompiled: " .. tostring(moduleDecompileStats.Succeeded),
		"ModuleScripts decompile failed: " .. tostring(moduleDecompileStats.Failed),
		"ModuleScripts decompile timed out: " .. tostring(moduleDecompileStats.TimedOut),
		"ModuleScripts ignored by DecompileIgnore: " .. tostring(moduleDecompileStats.Ignored),
		"ModuleScripts decompile skipped: " .. tostring(moduleDecompileStats.Skipped),
		"Objects With Attributes: " .. tostring(#attributeIndex),
		"ValueBase Records: " .. tostring(#valueRecords),
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
		"  Game: " .. tostring(#runtimeEventCategoryRecords.Game),
		"  Replicator: " .. tostring(#runtimeEventCategoryRecords.Replicator),
		"  Analytics: " .. tostring(#runtimeEventCategoryRecords.Analytics),
		"  Other: " .. tostring(#runtimeEventCategoryRecords.Other),
		"Runtime Value Changes: " .. tostring(#runtimeValueRecords),
		"Runtime Attribute Changes: " .. tostring(#runtimeAttributeRecords),
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
			Reason = F.compactDecompilerError(requestError)
		}
	end

	return {
		Status = "Success",
		Source = source,
		HttpStatus = statusCode,
		Attempts = attempts,
		BytecodeBytes = bytecodeBytes,
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
		SourceBytes = result.SourceBytes
	}

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

	print("module decompile candidates:", total, "workers:", workerCount, "timeout:", timeoutSeconds)

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
						print("module decompile:", completed, "/", total)
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
	currentStage = stage

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
end

function F.fileNameFromPath(path)
	return string.match(path, "[^/]+$") or path
end

function F.writeJSONDocument(path, data, label, writtenFiles, required)
	local encoded, encodeSuccess = F.encodeJSON(data, label)
	local bytes = #encoded
	local writeSuccess = F.writeSafe(path, encoded)
	local success = encodeSuccess and writeSuccess

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
		Game = #runtimeEventCategoryRecords.Game,
		Replicator = #runtimeEventCategoryRecords.Replicator,
		Analytics = #runtimeEventCategoryRecords.Analytics,
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
		RUNTIME_FILES.EventsGame,
		F.encodeJSON(
			F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Game, "Game"),
			"runtime_events_game.json"
		)
	)
	F.writeSafe(
		RUNTIME_FILES.EventsReplicator,
		F.encodeJSON(
			F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Replicator, "Replicator"),
			"runtime_events_replicator.json"
		)
	)
	F.writeSafe(
		RUNTIME_FILES.EventsAnalytics,
		F.encodeJSON(
			F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Analytics, "Analytics"),
			"runtime_events_analytics.json"
		)
	)
	F.writeSafe(
		RUNTIME_FILES.EventsOther,
		F.encodeJSON(
			F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Other, "Other"),
			"runtime_events_other.json"
		)
	)
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
		print(
			"snapshot finished; runtime trace remains active for up to",
			postSeconds,
			"more seconds"
		)

		local waitStarted = os.clock()
		while runtimeTraceActive
			and not runtimeHookState.Frozen
			and os.clock() - waitStarted < postSeconds
		do
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

function F.run()
	if not capabilities.writefile then
		warn("GameStructureDump: writefile is unavailable; dump aborted.")
		return
	end

	if not F.ensureOutputFolder() then
		warn("GameStructureDump: output folder could not be created or verified; dump aborted.")
		return
	end

	local guidOk, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)

	currentDumpId = guidOk and guid or string.format("%d-%d", os.time(), math.floor(os.clock() * 1000))
	snapshotBusy = true
	checkpointStage("runtime_start")
	runtimeStartedAt = os.clock()
	F.startRuntimeTrace()

	checkpointStage("prepare_players")
	F.preparePlayerDescriptors()

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

	for _, service in ipairs(F.getSortedChildren(game)) do
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

	snapshotFinalized = true
	checkpointStage("finalize_indexes")
	F.finalizeIndexes()

	table.clear(traversedInstances)

	local snapshotElapsed = os.clock() - started
	local writtenFiles = {}

	checkpointStage("write_structure_text")
	local treeLines = F.makeTree(root)
	local treeText = table.concat(treeLines, "\n")
	F.writeTextDocument(TREE_FILE, treeText, writtenFiles, true)
	treeText = nil
	treeLines = nil
	F.releaseTemporaryMemory()

	checkpointStage("write_structure_json")
	F.writeJSONDocument(STRUCTURE_FILE, root, "structure.json", writtenFiles, true)
	root = nil
	F.releaseTemporaryMemory()

	checkpointStage("build_instance_index")
	local instanceIndex = F.buildInstanceIndex()
	local instanceCount = #instanceIndex
	local pathStats = F.buildPathStats(instanceIndex)

	checkpointStage("write_instances")
	F.writeJSONDocument(INSTANCES_FILE, instanceIndex, "instances.json", writtenFiles, true)

	checkpointStage("build_state_index")
	local stateDocument = F.buildStateIndex(instanceIndex)
	stateDocument.PathCollisions = pathStats
	stateDocument.PlayerReferenceCount = #playerReferences
	stateDocument.ValueRecordCount = #valueRecords

	checkpointStage("write_state")
	F.writeJSONDocument(STATE_FILE, stateDocument, "state.json", writtenFiles, true)
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

	F.writeJSONDocument(REMOTES_FILE, remotesDocument, "remotes.json", writtenFiles, true)
	F.writeJSONDocument(INVENTORY_FILE, inventory, "inventory.json", writtenFiles, true)
	inventory = nil
	F.writeJSONDocument(ATTRIBUTES_FILE, attributeIndex, "attributes.json", writtenFiles, true)
	F.writeJSONDocument(TOOLS_FILE, toolRecords, "tools.json", writtenFiles, true)
	F.writeJSONDocument(VALUES_FILE, valuesDocument, "values.json", writtenFiles, true)
	F.writeJSONDocument(PLAYERS_FILE, playerIndex, "players.json", writtenFiles, true)
	playerIndex = nil
	playerDescriptors = {}
	F.writeJSONDocument(
		PLAYER_REFERENCES_FILE,
		playerReferencesDocument,
		"player_references.json",
		writtenFiles,
		true
	)

	F.releaseTemporaryMemory()
	snapshotBusy = false

	checkpointStage("runtime_post_capture")
	F.finishRuntimeTraceAfterSnapshot()

	F.writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts_pre_decompile.json", nil, false)
	checkpointStage("decompile_modules")
	F.decompileQueuedModules(scriptsDocument)
	F.writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts.json", writtenFiles, true)

	local runtimeEventsDocument = F.makeRuntimeEventDocument(runtimeEventRecords, nil)
	runtimeEventsDocument.CategoryTotals = {
		Game = #runtimeEventCategoryRecords.Game,
		Replicator = #runtimeEventCategoryRecords.Replicator,
		Analytics = #runtimeEventCategoryRecords.Analytics,
		Other = #runtimeEventCategoryRecords.Other
	}
	runtimeEventsDocument.CategoryDroppedDueToCap = runtimeEventCategoryDropped

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
		RUNTIME_FILES.EventsGame,
		F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Game, "Game"),
		"runtime_events_game.json",
		writtenFiles,
		false
	)
	F.writeJSONDocument(
		RUNTIME_FILES.EventsReplicator,
		F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Replicator, "Replicator"),
		"runtime_events_replicator.json",
		writtenFiles,
		false
	)
	F.writeJSONDocument(
		RUNTIME_FILES.EventsAnalytics,
		F.makeRuntimeEventDocument(runtimeEventCategoryRecords.Analytics, "Analytics"),
		"runtime_events_analytics.json",
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

	F.writeJSONDocument(WARNINGS_FILE, warnings, "warnings.json", writtenFiles, true)

	local totalElapsed = os.clock() - started
	local meta = {
		Schema = SCHEMA_NAME,
		SchemaVersion = SCHEMA_VERSION,
		DumpId = currentDumpId,
		GeneratedAtUnix = os.time(),
		IdSemantics = "Snapshot-local. IDs are stable only inside this dump.",
		PathSemantics = "Human-readable path. Paths are not guaranteed to be unique.",
		Game = {
			Name = F.sanitizeString(game.Name),
			PlaceId = game.PlaceId,
			GameId = game.GameId,
			JobId = F.sanitizeString(game.JobId)
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
			ModuleScriptsQueuedForDecompile = moduleDecompileStats.Queued,
			ModuleScriptsDecompiled = moduleDecompileStats.Succeeded,
			ModuleScriptsDecompileFailed = moduleDecompileStats.Failed,
			ModuleScriptsDecompileSkipped = moduleDecompileStats.Skipped,
			ObjectsWithAttributes = #attributeIndex,
			ValueBaseRecords = #valueRecords,
			PlayerReferences = #playerReferences,
			Tools = #toolRecords,
			DuplicatePathGroups = pathStats.DuplicatePathGroups,
			InstancesInDuplicatePaths = pathStats.InstancesInDuplicatePaths,
			Errors = #errors,
			Warnings = #warnings,
			SanitizedInvalidUtf8UniqueStrings = invalidUtf8StringCount,
			InvalidClassNames = invalidClassNameCount,
			SnapshotSeconds = snapshotElapsed,
			ElapsedSeconds = totalElapsed
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
			InterestingAttributes = CONFIG.RuntimeTraceInterestingAttributes,
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
			MaxLogRecords = CONFIG.RuntimeMaxLogRecords,
			TraceHookDiagnostics = CONFIG.RuntimeTraceHookDiagnostics,
			HookIntegrityInterval = CONFIG.RuntimeHookIntegrityInterval,
			MaxHookRecords = CONFIG.RuntimeMaxHookRecords,
			MaxHookIntegrityRecords = CONFIG.RuntimeMaxHookIntegrityRecords,
			HookRaySignatureMagnitude = CONFIG.RuntimeHookRaySignatureMagnitude,
			HookRaySignatureTolerance = CONFIG.RuntimeHookRaySignatureTolerance,
			HookTargetMaxMissStuds = CONFIG.RuntimeHookTargetMaxMissStuds,
			HookNormalRaySampleInterval = CONFIG.RuntimeHookNormalRaySampleInterval,
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
				GameEvents = #runtimeEventCategoryRecords.Game,
				ReplicatorEvents = #runtimeEventCategoryRecords.Replicator,
				AnalyticsEvents = #runtimeEventCategoryRecords.Analytics,
				OtherEvents = #runtimeEventCategoryRecords.Other,
				ValueChanges = #runtimeValueRecords,
				AttributeChanges = #runtimeAttributeRecords,
				CharacterRecords = #runtimeCharacterRecords,
				LogRecords = #runtimeLogRecords,
				TimelineRecords = #runtimeTimelineRecords,
				ErrorMessages = #runtimeErrorRecords,
				HookObservations = #runtimeHookState.HookRecords,
				HookIntegrityRecords = #runtimeHookState.HookIntegrityRecords
			},
			CategoryDroppedDueToCap = runtimeEventCategoryDropped
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
			GameEvents = #runtimeEventCategoryRecords.Game,
			ReplicatorEvents = #runtimeEventCategoryRecords.Replicator,
			AnalyticsEvents = #runtimeEventCategoryRecords.Analytics,
			OtherEvents = #runtimeEventCategoryRecords.Other,
			ValueChanges = #runtimeValueRecords,
			AttributeChanges = #runtimeAttributeRecords,
			CharacterRecords = #runtimeCharacterRecords,
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
	print("dump finished")
	print("DumpId:", currentDumpId)
	print("Serialized instance records:", instanceCount)
	print("Traversed descendants:", nodeCount)
	print("Registered IDs:", nextInstanceId)
	print("Remotes / Bindables:", F.totalRemoteCount())
	print("Scripts:", F.totalScriptCount())
	print("ModuleScripts queued for decompile:", moduleDecompileStats.Queued)
	print("ModuleScripts decompiled:", moduleDecompileStats.Succeeded)
	print("ModuleScripts decompile failed:", moduleDecompileStats.Failed)
	print("ModuleScripts decompile skipped:", moduleDecompileStats.Skipped)
	print("Module decompile time:", string.format("%.2fs", moduleDecompileStats.ElapsedSeconds))
	print("Attributes:", #attributeIndex)
	print("Values:", #valueRecords)
	print("Player references:", #playerReferences)
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

local runOk, runError = xpcall(F.run, F.formatFatalError)
if not runOk then
	snapshotBusy = false
	F.recordError("FatalRun", nil, runError, currentStage)

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

	warn("GameStructureDump crashed during stage:", currentStage)
	warn(runError)
end

