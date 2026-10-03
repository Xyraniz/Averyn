local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local OUTPUT_FOLDER = "GameStructureDump"
local SCHEMA_NAME = "Averyn.GameStructureDump"
local SCHEMA_VERSION = 3.2

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

local YIELD_EVERY = 100
local MAX_SERIALIZE_DEPTH = 32

local CONFIG = {
	-- Runtime tracing starts before the snapshot walk, so calls that happen while
	-- the dump is taking its normal ~seconds-long snapshot are captured too.
	RuntimeTrace = true,

	-- Keep the tracer alive long enough to reproduce a suspicious kick after the
	-- normal structure snapshot has finished.
	RuntimeTracePostSeconds = 45,

	-- Runtime records are kept as a rolling window. This prevents noisy remotes
	-- from consuming the whole capture before the interesting event happens.
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

	-- Capture real Luau buffer contents when possible. Small buffers are stored
	-- completely; large buffers keep a prefix + suffix so a single huge payload
	-- cannot explode the dump size.
	RuntimeCaptureBuffers = true,
	RuntimeMaxBufferBytes = 4096,

	-- Character telemetry is intentionally separated from remote traffic.
	RuntimeTraceCharacter = true,
	RuntimeCharacterSampleInterval = 0.15,
	RuntimeMaxCharacterRecords = 10000,

	-- Console output can expose local detector warnings or errors immediately
	-- before a disconnect. It is stored separately to keep the remote trace clean.
	RuntimeCaptureLogs = true,
	RuntimeMaxLogRecords = 5000,

	-- Hook diagnostics are passive where possible. The dumper already needs one
	-- __namecall hook for outgoing remote tracing, so that same hook also observes
	-- Workspace ray calls. It intentionally does NOT install an __index hook,
	-- because doing so would contaminate a test whose purpose is to discover
	-- whether another script's __index hook is what triggers a detector.
	RuntimeTraceHookDiagnostics = true,
	RuntimeHookIntegrityInterval = 0.20,
	RuntimeMaxHookRecords = 12000,
	RuntimeMaxHookIntegrityRecords = 4000,
	RuntimeHookRaySignatureMagnitude = 5000,
	RuntimeHookRaySignatureTolerance = 3,
	RuntimeHookTargetMaxMissStuds = 12,

	-- Suspicious rays that match the configured signature are recorded every time.
	-- Ordinary rays are sampled so diagnostics do not add hundreds of heavy
	-- observations per second to camera code.
	RuntimeHookNormalRaySampleInterval = 0.25,

	-- Error/disconnect capture. Error 267 is normally visible through game:GetService("GuiService").
	-- The trace freezes immediately when a kick/disconnect-like message appears,
	-- preserving the rolling window that led up to it.
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

	-- Disk flushing is throttled because high-frequency replication traffic can
	-- otherwise trigger hundreds of writefile calls per second.
	RuntimeFlushEvery = 250,
	RuntimeFlushMinSeconds = 1.0,

	-- Stability only: observer priming still scans every existing Instance, but
	-- yields cooperatively instead of materializing game:GetDescendants() at once.
	RuntimePrimeYieldEvery = 150,

	-- The combined timeline also behaves as a ring. Remote categories have
	-- independent caps, so internal replication cannot starve ordinary game
	-- remotes from the capture.
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

	StateIndexMaxPerBucket = 1500
}

local capabilities = {
	writefile = type(writefile) == "function",
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
local currentDumpId = nil

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

local inventoryToolIds = {
	Backpack = {},
	Character = {},
	StarterGear = {}
}

local function isContinuationByte(value)
	return value ~= nil and value >= 0x80 and value <= 0xBF
end

local function sanitizeString(value)
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
			if isContinuationByte(b2) then
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
				secondValid = isContinuationByte(b2)
			end

			if secondValid and isContinuationByte(b3) then
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
				secondValid = isContinuationByte(b2)
			end

			if secondValid and isContinuationByte(b3) and isContinuationByte(b4) then
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

local function escapeText(value)
	value = sanitizeString(value)
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

local function safeName(object)
	local ok, value = pcall(function()
		return object.Name
	end)

	if ok then
		return sanitizeString(value)
	end

	return "<unknown>"
end

local function safeClassName(object)
	local ok, value = pcall(function()
		return object.ClassName
	end)

	if ok and type(value) == "string" then
		value = sanitizeString(value)
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

local function safeFullName(object)
	local ok, result = pcall(function()
		return object:GetFullName()
	end)

	if ok then
		return sanitizeString(result)
	end

	return safeName(object)
end

local function makeIssue(stage, object, message, property)
	local entry = {
		Stage = sanitizeString(stage),
		Error = sanitizeString(message)
	}

	if object then
		entry.Id = instanceIds[object]
		entry.Name = safeName(object)
		entry.ClassName = safeClassName(object)
		entry.Path = safeFullName(object)
	end

	if property then
		entry.Property = sanitizeString(property)
	end

	return entry
end

local function recordError(stage, object, message, property)
	table.insert(errors, makeIssue(stage, object, message, property))
end

local function recordWarning(stage, object, message, property)
	table.insert(warnings, makeIssue(stage, object, message, property))
end

local function safeGet(object, property)
	local ok, value = pcall(function()
		return object[property]
	end)

	if ok then
		return value, true, nil
	end

	return nil, false, value
end

local function safeIsA(object, className)
	local ok, result = pcall(function()
		return object:IsA(className)
	end)

	return ok and result or false
end

local function safeIsDescendantOf(object, ancestor)
	if not object or not ancestor then
		return false
	end

	local ok, result = pcall(function()
		return object:IsDescendantOf(ancestor)
	end)

	return ok and result or false
end

local function assignInstanceId(object)
	local existing = instanceIds[object]
	if existing then
		return existing
	end

	nextInstanceId = nextInstanceId + 1
	local id = nextInstanceId
	instanceIds[object] = id

	instanceMetaById[id] = {
		Id = id,
		Name = safeName(object),
		ClassName = safeClassName(object),
		Path = safeFullName(object),
		ReferencedOnly = true
	}

	return id
end

local function updateInstanceMeta(object, id, parentId, name, className, path)
	local meta = instanceMetaById[id]
	if not meta then
		meta = { Id = id }
		instanceMetaById[id] = meta
	end

	meta.Name = name or safeName(object)
	meta.ClassName = className or safeClassName(object)
	meta.Path = path or safeFullName(object)
	meta.ParentId = parentId
	meta.ReferencedOnly = false
end

local function makeInstanceReference(object, allowAssign)
	if not object then
		return nil
	end

	if allowAssign == nil then
		allowAssign = true
	end

	local id = instanceIds[object]
	if not id and not snapshotFinalized and allowAssign then
		id = assignInstanceId(object)
	end

	local reference = {
		Name = safeName(object),
		ClassName = safeClassName(object),
		Path = safeFullName(object)
	}

	if id then
		reference.Id = id
	end

	return reference
end

local function finiteNumber(value)
	if value ~= value then
		return false
	end

	return value ~= math.huge and value ~= -math.huge
end

local function serializeComponentNumber(value)
	if finiteNumber(value) then
		return value
	end

	return {
		__type = "NonFiniteNumber",
		value = sanitizeString(tostring(value))
	}
end

local function optionalMap(value)
	if next(value) == nil then
		return nil
	end

	return value
end

local function isArrayTable(value)
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

local function stableKey(value)
	local valueType = typeof(value)

	if valueType == "string" or valueType == "number" or valueType == "boolean" then
		return valueType .. ":" .. tostring(value)
	end

	if valueType == "EnumItem" then
		return valueType .. ":" .. tostring(value)
	end

	return valueType .. ":" .. tostring(value)
end

local function bytesToHex(value)
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

local function readBufferRange(value, offset, length)
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

local function serializeBufferValue(value)
	local result = {
		__type = "buffer"
	}

	if not CONFIG.RuntimeCaptureBuffers then
		result.Captured = false
		result.Value = sanitizeString(tostring(value))
		return result
	end

	if not capabilities.buffer_len then
		result.Captured = false
		result.Error = "buffer.len unavailable"
		result.Value = sanitizeString(tostring(value))
		return result
	end

	local lengthOk, length = pcall(buffer.len, value)
	if not lengthOk or type(length) ~= "number" then
		result.Captured = false
		result.Error = sanitizeString(length)
		result.Value = sanitizeString(tostring(value))
		return result
	end

	result.Length = length

	local maxBytes = math.max(0, tonumber(CONFIG.RuntimeMaxBufferBytes) or 0)
	if maxBytes == 0 then
		result.Captured = false
		return result
	end

	if length <= maxBytes then
		local raw = readBufferRange(value, 0, length)
		if raw then
			result.Captured = true
			result.CapturedBytes = length
			result.Truncated = false
			result.Hex = bytesToHex(raw)
		else
			result.Captured = false
			result.Error = "buffer bytes could not be read"
		end

		return result
	end

	local prefixLength = math.floor(maxBytes / 2)
	local suffixLength = maxBytes - prefixLength
	local prefix = readBufferRange(value, 0, prefixLength)
	local suffix = readBufferRange(value, math.max(0, length - suffixLength), suffixLength)

	if prefix and suffix then
		result.Captured = true
		result.CapturedBytes = prefixLength + suffixLength
		result.Truncated = true
		result.HexPrefix = bytesToHex(prefix)
		result.HexSuffix = bytesToHex(suffix)
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
		return sanitizeString(value)
	end

	if valueType == "buffer" then
		return serializeBufferValue(value)
	end

	if valueType == "boolean" then
		return value
	end

	if valueType == "number" then
		if finiteNumber(value) then
			return value
		end

		return {
			__type = "Number",
			value = sanitizeString(tostring(value))
		}
	end

	if valueType == "Vector3" then
		return {
			__type = "Vector3",
			x = serializeComponentNumber(value.X),
			y = serializeComponentNumber(value.Y),
			z = serializeComponentNumber(value.Z)
		}
	end

	if valueType == "Vector2" then
		return {
			__type = "Vector2",
			x = serializeComponentNumber(value.X),
			y = serializeComponentNumber(value.Y)
		}
	end

	if valueType == "Color3" then
		return {
			__type = "Color3",
			r = serializeComponentNumber(value.R),
			g = serializeComponentNumber(value.G),
			b = serializeComponentNumber(value.B)
		}
	end

	if valueType == "CFrame" then
		local rawComponents = { value:GetComponents() }
		local components = {}
		for index, component in ipairs(rawComponents) do
			components[index] = serializeComponentNumber(component)
		end

		return {
			__type = "CFrame",
			components = components
		}
	end

	if valueType == "UDim" then
		return {
			__type = "UDim",
			scale = serializeComponentNumber(value.Scale),
			offset = serializeComponentNumber(value.Offset)
		}
	end

	if valueType == "UDim2" then
		return {
			__type = "UDim2",
			xScale = serializeComponentNumber(value.X.Scale),
			xOffset = serializeComponentNumber(value.X.Offset),
			yScale = serializeComponentNumber(value.Y.Scale),
			yOffset = serializeComponentNumber(value.Y.Offset)
		}
	end

	if valueType == "BrickColor" then
		return {
			__type = "BrickColor",
			name = sanitizeString(value.Name),
			number = value.Number
		}
	end

	if valueType == "EnumItem" then
		return {
			__type = "EnumItem",
			value = sanitizeString(tostring(value))
		}
	end

	if valueType == "Font" then
		return {
			__type = "Font",
			family = sanitizeString(value.Family),
			weight = serializeValue(value.Weight),
			style = serializeValue(value.Style)
		}
	end

	if valueType == "NumberRange" then
		return {
			__type = "NumberRange",
			min = serializeComponentNumber(value.Min),
			max = serializeComponentNumber(value.Max)
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
				time = serializeComponentNumber(keypoint.Time),
				value = serializeComponentNumber(keypoint.Value),
				envelope = serializeComponentNumber(keypoint.Envelope)
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
				time = serializeComponentNumber(keypoint.Time),
				value = serializeValue(keypoint.Value)
			})
		end

		return {
			__type = "ColorSequence",
			keypoints = keypoints
		}
	end

	if valueType == "Instance" then
		local reference = makeInstanceReference(value, not state.noAssignInstanceId)
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
			noAssignInstanceId = state.noAssignInstanceId
		}

		local result

		if isArrayTable(value) then
			result = {}
			for index = 1, #value do
				result[index] = serializeValue(value[index], childState)
			end
		else
			local entries = {}

			for key, item in pairs(value) do
				table.insert(entries, {
					_sort = stableKey(key),
					key = serializeValue(key, childState),
					value = serializeValue(item, childState)
				})
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
		end

		state.seen[value] = nil
		return result
	end

	return {
		__type = sanitizeString(valueType),
		value = sanitizeString(tostring(value))
	}
end

local function serializeRuntimeValue(value)
	local ok, result = pcall(serializeValue, value, {
		seen = {},
		depth = 0,
		noAssignInstanceId = true
	})

	if ok then
		return result
	end

	return {
		__type = "SerializationError",
		value = sanitizeString(result)
	}
end

local function serializePackedRuntimeValues(packed)
	local output = {}
	for index = 1, packed.n do
		local value = packed[index]
		if value == nil then
			output[index] = { __type = "Nil" }
		else
			output[index] = serializeRuntimeValue(value)
		end
	end
	return output
end

local function getAttributes(object)
	local ok, attributes = pcall(function()
		return object:GetAttributes()
	end)

	if not ok then
		recordError("GetAttributes", object, attributes)
		return {}
	end

	local output = {}

	for name, value in pairs(attributes) do
		local safeAttributeName = sanitizeString(name)
		local success, serialized = pcall(serializeValue, value)
		if success then
			output[safeAttributeName] = serialized
		else
			recordError("SerializeAttribute", object, serialized, safeAttributeName)
		end
	end

	return output
end

local function getTags(object)
	local ok, tags = pcall(function()
		return CollectionService:GetTags(object)
	end)

	if not ok then
		recordError("GetTags", object, tags)
		return {}
	end

	for index, tag in ipairs(tags) do
		tags[index] = sanitizeString(tag)
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

local function captureProperty(object, output, property)
	local value, readable, readError = safeGet(object, property)

	if not readable then
		recordError("ReadProperty", object, readError, property)
		return
	end

	if value == nil then
		return
	end

	local ok, serialized = pcall(serializeValue, value)
	if ok then
		output[property] = serialized
	else
		recordError("SerializeProperty", object, serialized, property)
	end
end

local function getUsefulProperties(object, className)
	local data = {}
	className = className or safeClassName(object)

	for _, group in ipairs(PROPERTY_GROUPS) do
		if safeIsA(object, group.Class) then
			for _, property in ipairs(group.Properties) do
				captureProperty(object, data, property)
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

local function registerAttributes(id, name, className, path, attributes)
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

local function getRemoteClientMetadata(object, className)
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
						Source = source and sanitizeString(source) or nil,
						Line = line,
						Name = name and sanitizeString(name) or nil
					}
				end
			end
		end
	end

	return optionalMap(metadata)
end

local function registerRemote(object, id, name, className, parentId, path, attributes, tags)
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
		Attributes = optionalMap(attributes),
		Tags = tags
	}

	local clientMetadata = getRemoteClientMetadata(object, className)
	if clientMetadata then
		record.Client = clientMetadata
	end

	table.insert(remoteIndex[bucket], record)
end

local function registerScript(id, name, className, parentId, path, properties)
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
end

local function registerValue(object, id, name, className, parentId, path, attributes, tags)
	if not safeIsA(object, "ValueBase") then
		return
	end

	local rawValue, readable, readError = safeGet(object, "Value")
	local record = {
		Id = id,
		Name = name,
		ClassName = className,
		Path = path,
		ParentId = parentId,
		Attributes = optionalMap(attributes),
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
		record.ReadError = sanitizeString(readError)
	end

	table.insert(valueRecords, record)
end

local backpack = LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack") or nil
local character = LocalPlayer and LocalPlayer.Character or nil
local starterGear = LocalPlayer and LocalPlayer:FindFirstChild("StarterGear") or nil

local playerDescriptors = {}
local playerReferenceKeys = {}

local function preparePlayerDescriptors()
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

local function addPlayerReference(descriptor, objectId, field, matchKind, value)
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
		PlayerName = sanitizeString(descriptor.Name),
		DisplayName = sanitizeString(descriptor.DisplayName),
		UserId = descriptor.UserId,
		ObjectId = objectId,
		Field = sanitizeString(field),
		MatchKind = sanitizeString(matchKind),
		Value = serializeValue(value)
	})
end

local function scanValueForPlayerReferences(objectId, field, value)
	local valueType = typeof(value)

	for _, descriptor in ipairs(playerDescriptors) do
		if valueType == "string" then
			if value == descriptor.Name then
				addPlayerReference(descriptor, objectId, field, "Username", value)
			elseif descriptor.DisplayName ~= descriptor.Name and value == descriptor.DisplayName then
				addPlayerReference(descriptor, objectId, field, "DisplayName", value)
			elseif value == tostring(descriptor.UserId) then
				addPlayerReference(descriptor, objectId, field, "UserIdString", value)
			end
		elseif valueType == "number" and value == descriptor.UserId then
			addPlayerReference(descriptor, objectId, field, "UserIdNumber", value)
		elseif valueType == "Instance" then
			if value == descriptor.Player then
				addPlayerReference(descriptor, objectId, field, "PlayerInstance", value)
			elseif descriptor.Character and value == descriptor.Character then
				addPlayerReference(descriptor, objectId, field, "CharacterInstance", value)
			elseif descriptor.Backpack and value == descriptor.Backpack then
				addPlayerReference(descriptor, objectId, field, "BackpackInstance", value)
			elseif descriptor.PlayerGui and value == descriptor.PlayerGui then
				addPlayerReference(descriptor, objectId, field, "PlayerGuiInstance", value)
			end
		end
	end
end

local function scanAttributesForPlayerReferences(objectId, attributes)
	for name, value in pairs(attributes) do
		scanValueForPlayerReferences(objectId, "Attribute:" .. sanitizeString(name), value)
	end
end

local function findTopServiceName(object)
	local current = object
	local previous = object

	while current do
		previous = current
		local parent, readable = safeGet(current, "Parent")
		if not readable or parent == nil then
			break
		end

		if parent == game then
			return safeName(current)
		end

		current = parent
	end

	return safeName(previous)
end

local function describeToolLocation(object, source)
	local result = {
		Location = source or findTopServiceName(object)
	}

	for _, descriptor in ipairs(playerDescriptors) do
		local ownerLocation

		if descriptor.Backpack and safeIsDescendantOf(object, descriptor.Backpack) then
			ownerLocation = "PlayerBackpack"
		elseif descriptor.Character and safeIsDescendantOf(object, descriptor.Character) then
			ownerLocation = "PlayerCharacter"
		elseif descriptor.StarterGear and safeIsDescendantOf(object, descriptor.StarterGear) then
			ownerLocation = "PlayerStarterGear"
		end

		if ownerLocation then
			result.Location = ownerLocation
			result.OwnerName = sanitizeString(descriptor.Name)
			result.OwnerUserId = descriptor.UserId
			result.IsLocalPlayer = descriptor.Player == LocalPlayer
			break
		end
	end

	return result
end

local function resolveInventorySource(object, inheritedSource)
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

local function createToolRecord(object, id, name, className, path, source, attributes, properties)
	local location = describeToolLocation(object, source)
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
		Attributes = optionalMap(attributes),
		Properties = optionalMap(properties),
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

local function registerToolDescendant(toolState, object, id, className, name)
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

	if safeIsA(object, "ValueBase") then
		table.insert(record.ValueIds, id)
	end

	local parent, parentReadable = safeGet(object, "Parent")
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

local function isRuntimeInteresting(name, path)
	local haystack = string.lower((name or "") .. " " .. (path or ""))

	for _, keyword in ipairs(RUNTIME_KEYWORDS) do
		if string.find(haystack, keyword, 1, true) then
			return true
		end
	end

	return false
end

local function trimRuntimeArray(records, maxCount, cutoffTime)
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

local function pruneRuntimeCaches(force)
	local now = os.clock()

	if not force and now - runtimeHookState.LastPruneAt < 1 then
		return
	end

	runtimeHookState.LastPruneAt = now

	local elapsed = now - runtimeStartedAt
	local window = math.max(0, tonumber(CONFIG.RuntimeRingWindowSeconds) or 0)
	local cutoff = window > 0 and math.max(0, elapsed - window) or nil

	trimRuntimeArray(runtimeEventRecords, CONFIG.RuntimeMaxEvents, cutoff)
	trimRuntimeArray(runtimeValueRecords, CONFIG.RuntimeMaxValueChanges, cutoff)
	trimRuntimeArray(runtimeAttributeRecords, CONFIG.RuntimeMaxAttributeChanges, cutoff)
	trimRuntimeArray(runtimeCharacterRecords, CONFIG.RuntimeMaxCharacterRecords, cutoff)
	trimRuntimeArray(runtimeLogRecords, CONFIG.RuntimeMaxLogRecords, cutoff)
	trimRuntimeArray(runtimeTimelineRecords, CONFIG.RuntimeMaxTimelineRecords, cutoff)
	trimRuntimeArray(runtimeErrorRecords, 256, cutoff)
	trimRuntimeArray(
		runtimeHookState.HookRecords,
		CONFIG.RuntimeMaxHookRecords,
		cutoff
	)
	trimRuntimeArray(
		runtimeHookState.HookIntegrityRecords,
		CONFIG.RuntimeMaxHookIntegrityRecords,
		cutoff
	)

	for category, records in pairs(runtimeEventCategoryRecords) do
		local maxCount = CONFIG.RuntimeMaxEventsPerCategory
			and CONFIG.RuntimeMaxEventsPerCategory[category]
			or CONFIG.RuntimeMaxEvents

		local _, overflow = trimRuntimeArray(records, maxCount, cutoff)
		if overflow > 0 then
			runtimeEventCategoryDropped[category] =
				(runtimeEventCategoryDropped[category] or 0) + overflow
		end
	end
end

local function scheduleRuntimeFlush()
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
			recordError("RuntimeFlush", nil, flushError)
		end
	end)
end

local function maybeFlushRuntimeTrace()
	runtimeHookState.MutationsSinceFlush = runtimeHookState.MutationsSinceFlush + 1
	pruneRuntimeCaches(false)

	if not flushRuntimeTrace then
		return
	end

	local every = math.max(1, tonumber(CONFIG.RuntimeFlushEvery) or 250)
	local minSeconds = math.max(0, tonumber(CONFIG.RuntimeFlushMinSeconds) or 0)
	local now = os.clock()

	if runtimeHookState.MutationsSinceFlush >= every
		and now - runtimeHookState.LastFlushAt >= minSeconds
	then
		runtimeHookState.MutationsSinceFlush = 0
		runtimeHookState.LastFlushAt = now
		scheduleRuntimeFlush()
	end
end

local function appendRuntimeTimeline(record)
	if type(record) ~= "table" then
		return
	end

	if record.Time == nil then
		record.Time = os.clock() - runtimeStartedAt
	end

	table.insert(runtimeTimelineRecords, record)
end

local function classifyRuntimeRemote(remote, path)
	local text = string.lower(
		(path or safeFullName(remote) or "")
			.. " "
			.. safeName(remote)
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

local function captureRuntimeCallerStack()
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
			Source = sanitizeString(source),
			Line = line,
			Name = name and sanitizeString(name) or nil
		})
	end

	return #frames > 0 and frames or nil
end

local function getRuntimeCallerInfo()
	local callerInfo = nil
	local callerScript = nil

	if CONFIG.RuntimeCaptureCaller and capabilities.getcallingscript then
		local ok, result = pcall(getcallingscript)
		if ok and typeof(result) == "Instance" then
			callerScript = result
			callerInfo = makeInstanceReference(result, false)

			if callerInfo then
				if not callerInfo.Name or callerInfo.Name == "" then
					callerInfo.Name = safeName(result)
				end
				if not callerInfo.Path or callerInfo.Path == "" then
					callerInfo.Path = safeFullName(result)
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

	local stack = captureRuntimeCallerStack()
	if callerInfo and stack and stack[1] then
		callerInfo.DebugSource = stack[1].Source
		callerInfo.DebugLine = stack[1].Line
		callerInfo.DebugName = stack[1].Name
	end

	return callerInfo, callerScript, isExecutor, stack
end

local function describeRuntimeHookValue(value)
	local description = {
		Type = typeof(value),
		Text = sanitizeString(tostring(value))
	}

	local fingerprintParts = {
		description.Type,
		description.Text
	}

	if type(value) == "function" and capabilities.debug_info then
		local ok, source, line, name = pcall(debug.info, value, "sln")
		if ok then
			description.Source = source and sanitizeString(source) or nil
			description.Line = line
			description.Name = name and sanitizeString(name) or nil

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

local function getRuntimeHookSnapshot(source)
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
				Error = not ok and sanitizeString(metatableValue) or "not a table"
			}
		end

		local result = {
			Available = true,
			Index = describeRuntimeHookValue(rawget(metatableValue, "__index")),
			Namecall = describeRuntimeHookValue(rawget(metatableValue, "__namecall")),
			NewIndex = describeRuntimeHookValue(rawget(metatableValue, "__newindex"))
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
				Error = sanitizeString(mouseObject)
			}
		end
	end

	if capabilities.getgenv then
		local envOk, environment = pcall(getgenv)
		if envOk and type(environment) == "table" then
			local target = rawget(environment, "AimTarget")
			if typeof(target) == "Instance" then
				snapshot.AimTarget = makeInstanceReference(target, false)
				snapshot.AimTargetFingerprint =
					safeFullName(target) .. "|" .. sanitizeString(tostring(target))
			elseif target == nil then
				snapshot.AimTargetFingerprint = "nil"
			else
				snapshot.AimTarget = serializeRuntimeValue(target)
				snapshot.AimTargetFingerprint =
					typeof(target) .. "|" .. sanitizeString(tostring(target))
			end
		end
	end

	return snapshot
end

local function appendRuntimeHookRecord(record)
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

	appendRuntimeTimeline({
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

	maybeFlushRuntimeTrace()
	return record
end

local function findRuntimeRayCandidate(origin, direction)
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
				and safeIsA(part, "BasePart")
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
		Player = makeInstanceReference(bestPlayer, false),
		Part = makeInstanceReference(bestPart, false),
		MissDistance = bestMiss,
		DistanceAlongRay = bestAlong
	}
end

local function appendRuntimeRayObservation(self, method, packedArguments)
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

	-- Keep every suspicious ray, but sample ordinary camera/game rays. This
	-- makes hook diagnostics much less invasive while preserving the signal we
	-- care about for this capture.
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

	local callerInfo, _, callerIsExecutor, callerStack = getRuntimeCallerInfo()

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
				globalAimTarget = makeInstanceReference(target, false)
			end
		end
	end

	appendRuntimeHookRecord({
		HookKind = "NamecallRayObservation",
		Metamethod = "__namecall",
		Method = method,
		Object = makeInstanceReference(self, false),
		Arguments = serializePackedRuntimeValues(packedArguments),
		Caller = callerInfo,
		CallerIsExecutor = callerIsExecutor,
		CallerStack = callerStack,
		Ray = {
			Origin = serializeRuntimeValue(origin),
			Direction = serializeRuntimeValue(direction),
			DirectionMagnitude = magnitude,
			EndPoint = serializeRuntimeValue(origin + direction),
			CameraOrigin = cameraOrigin and serializeRuntimeValue(cameraOrigin) or nil,
			OriginDistanceFromCamera = cameraDistance
		},
		Matches5000MagnitudeSignature = matchesSignature,
		TargetCandidate = findRuntimeRayCandidate(origin, direction),
		GlobalAimTarget = globalAimTarget
	})
end

local function checkRuntimeHookIntegrity(force, source)
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

	local current = getRuntimeHookSnapshot(source)
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

		appendRuntimeTimeline({
			Time = current.Time,
			Kind = "HookIntegrity",
			Source = source,
			Event = record.Event,
			ChangedFields = #fields > 0 and fields or nil
		})

		maybeFlushRuntimeTrace()
	end

	if runtimeHookState.HookIntegrityBaseline == nil then
		runtimeHookState.HookIntegrityBaseline = current
	end

	runtimeHookState.HookIntegrityLast = current
end

local function appendRuntimeRemoteRecord(remote, direction, method, packedArguments, extra)
	if not runtimeTraceActive then
		return nil
	end

	extra = extra or {}
	local className = safeClassName(remote)
	local path = safeFullName(remote)
	local category = extra.Category or classifyRuntimeRemote(remote, path)
	local callerInfo = extra.Caller

	local record = {
		Time = os.clock() - runtimeStartedAt,
		Direction = direction,
		Method = method,
		Category = category,
		Phase = extra.Phase,
		RemoteId = instanceIds[remote],
		Name = safeName(remote),
		ClassName = className,
		Path = path,
		SnapshotPath = extra.SnapshotPath,
		ArgumentCount = packedArguments.n,
		Arguments = serializePackedRuntimeValues(packedArguments),
		Caller = callerInfo,
		CallerIsExecutor = direction == "ClientToServer" and extra.CallerIsExecutor or nil,
		CallerStack = extra.CallerStack,
		ObservedByExecutor = extra.ObservedByExecutor,
		Observer = extra.Observer,
		DurationSeconds = extra.DurationSeconds
	}

	if extra.Returns then
		record.ReturnCount = extra.Returns.n
		record.Returns = serializePackedRuntimeValues(extra.Returns)
	end

	table.insert(runtimeEventRecords, record)

	local categoryRecords = runtimeEventCategoryRecords[category]
	if not categoryRecords then
		category = "Other"
		record.Category = category
		categoryRecords = runtimeEventCategoryRecords.Other
	end

	table.insert(categoryRecords, record)

	appendRuntimeTimeline({
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

	maybeFlushRuntimeTrace()
	return record
end

local function watchRuntimeRemote(object, id, name, className, path)
	if not CONFIG.RuntimeTrace or not runtimeTraceActive or not CONFIG.RuntimeTraceIncomingRemotes then
		return
	end

	if className ~= "RemoteEvent" and className ~= "UnreliableRemoteEvent" then
		return
	end

	if runtimeObservedRemotes[object] then
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

			appendRuntimeRemoteRecord(
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
		recordWarning("RuntimeRemoteTrace", object, connection)
	end
end

local function installOutgoingRemoteHook()
	if not CONFIG.RuntimeTrace or not CONFIG.RuntimeTraceOutgoingRemotes then
		return false
	end

	if runtimeOutgoingHookInstalled then
		runtimeHookState.Active = true
		return true
	end

	if not capabilities.hookmetamethod or not capabilities.getnamecallmethod then
		recordWarning(
			"RuntimeOutgoingRemoteTrace",
			nil,
			"hookmetamethod/getnamecallmethod unavailable; outgoing FireServer/InvokeServer calls cannot be observed"
		)
		return false
	end

	local oldNamecall

	local function handler(self, ...)
		-- getnamecallmethod() must be read before anything else. More importantly,
		-- no diagnostic code is allowed to perform another namecall before the
		-- original call is dispatched. Doing that can overwrite the active method
		-- and accidentally turn Workspace:Raycast(...) into Workspace:<other>(...).
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

		-- Only pure Lua/executor-safe work happens before oldNamecall. In
		-- particular: no GetFullName, FindFirstChild, IsA, Vector3:Dot, logging,
		-- serialization, or other ':' calls are made here.
		local packedArguments = table.pack(...)
		local callStarted = os.clock()

		-- PASSIVE DISPATCH: run the real call first. All heavy inspection happens
		-- only after it has completed, so the dumper cannot change which namecall
		-- method Roblox receives.
		local returns = table.pack(oldNamecall(self, ...))
		local duration = os.clock() - callStarted

		if observeRay then
			pcall(
				appendRuntimeRayObservation,
				self,
				method,
				packedArguments
			)
		end

		if observeRemote then
			-- Validate the object only now, after the original namecall has already
			-- completed. Property/method reads in the logger therefore cannot corrupt
			-- the call we are observing.
			local className = typeof(self) == "Instance" and safeClassName(self) or nil
			local isFireServer = method == "FireServer"
				and (className == "RemoteEvent" or className == "UnreliableRemoteEvent")
			local isInvokeServer = method == "InvokeServer"
				and className == "RemoteFunction"

			if isFireServer or isInvokeServer then
				local callerInfo, _, callerIsExecutor, callerStack = getRuntimeCallerInfo()
				local snapshotPath = safeFullName(self)
				local record = appendRuntimeRemoteRecord(
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
					appendRuntimeTimeline({
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
					maybeFlushRuntimeTrace()
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
		recordWarning("RuntimeOutgoingRemoteTrace", nil, hookResult or "failed to install __namecall hook")
		return false
	end

	runtimeOutgoingHookInstalled = true
	runtimeHookState.Active = true
	return true
end

local function shouldWatchRuntimeAttributes(object, name, path, attributes)
	if not runtimeTraceActive then
		return false
	end

	if CONFIG.RuntimeTraceToolAttributes and safeIsA(object, "Tool") then
		return true
	end

	if not CONFIG.RuntimeTraceInterestingAttributes or next(attributes or {}) == nil then
		return false
	end

	if safeIsA(object, "Player")
		or safeIsA(object, "Humanoid")
		or safeIsA(object, "BasePart")
	then
		return true
	end

	return isRuntimeInteresting(name, path)
end

local function watchRuntimeAttributes(object, id, name, className, path, attributes)
	if not CONFIG.RuntimeTrace or not runtimeTraceActive then
		return
	end

	if runtimeObservedAttributes[object] then
		return
	end

	if not shouldWatchRuntimeAttributes(object, name, path, attributes) then
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
				previousSerialized = serializeRuntimeValue(oldValue)
			end

			local newSerialized = nil
			if newValue ~= nil then
				newSerialized = serializeRuntimeValue(newValue)
			end

			local record = {
				Time = os.clock() - runtimeStartedAt,
				Id = instanceIds[object] or id,
				Name = safeName(object),
				ClassName = safeClassName(object),
				Path = safeFullName(object),
				SnapshotPath = path,
				Attribute = sanitizeString(attributeName),
				PreviousIsNil = oldValue == nil,
				PreviousValue = previousSerialized,
				ValueIsNil = newValue == nil,
				Value = newSerialized
			}

			table.insert(runtimeAttributeRecords, record)

			appendRuntimeTimeline({
				Time = record.Time,
				Kind = "Attribute",
				Name = record.Name,
				Path = record.Path,
				Field = record.Attribute
			})

			maybeFlushRuntimeTrace()
		end)
	end)

	if connectionOk and connection then
		table.insert(runtimeConnections, connection)
	else
		recordWarning("RuntimeAttributeTrace", object, connection)
	end
end

local function watchRuntimeValue(object, id, name, className, path)
	if not CONFIG.RuntimeTrace or not runtimeTraceActive or not safeIsA(object, "ValueBase") then
		return
	end

	if not CONFIG.RuntimeTraceAllValues and not isRuntimeInteresting(name, path) then
		return
	end

	if runtimeObservedValues[object] then
		return
	end
	runtimeObservedValues[object] = true

	if runtimeValueLastValues[object] == nil then
		local initialValue, initialReadable = safeGet(object, "Value")
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
			local value, readable, readError = safeGet(object, "Value")
			local serialized
			local previousSerialized = previousState.HasValue
				and serializeRuntimeValue(previousState.Value)
				or nil

			if readable then
				serialized = value == nil
					and { __type = "Nil" }
					or serializeRuntimeValue(value)

				runtimeValueLastValues[object] = {
					HasValue = value ~= nil,
					Value = value
				}
			else
				serialized = {
					__type = "ReadError",
					value = sanitizeString(readError)
				}
			end

			local record = {
				Time = os.clock() - runtimeStartedAt,
				Id = instanceIds[object] or id,
				Name = name,
				ClassName = className,
				Path = safeFullName(object),
				SnapshotPath = path,
				PreviousIsNil = not previousState.HasValue,
				PreviousValue = previousSerialized,
				ValueIsNil = readable and value == nil or nil,
				Value = serialized
			}

			table.insert(runtimeValueRecords, record)

			appendRuntimeTimeline({
				Time = record.Time,
				Kind = "Value",
				Name = record.Name,
				Path = record.Path
			})

			maybeFlushRuntimeTrace()
		end)
	end)

	if connectionOk and connection then
		table.insert(runtimeConnections, connection)
	else
		recordWarning("RuntimeValueTrace", object, connection)
	end
end

local function disconnectConnections(connections)
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(connections)
end

local function appendRuntimeCharacterRecord(eventName, object, details)
	if not runtimeTraceActive then
		return nil
	end

	local record = {
		Time = os.clock() - runtimeStartedAt,
		Event = eventName,
		Object = object and makeInstanceReference(object, false) or nil,
		Details = details
	}

	table.insert(runtimeCharacterRecords, record)

	appendRuntimeTimeline({
		Time = record.Time,
		Kind = "Character",
		Event = eventName,
		Name = record.Object and record.Object.Name or nil,
		Path = record.Object and record.Object.Path or nil
	})

	maybeFlushRuntimeTrace()
	return record
end

local function readRuntimeProperty(object, property)
	local value, readable, readError = safeGet(object, property)

	if not readable then
		return {
			__type = "ReadError",
			value = sanitizeString(readError)
		}
	end

	if value == nil then
		return {
			__type = "Nil"
		}
	end

	return serializeRuntimeValue(value)
end

local function watchCharacterObject(object)
	if not object or not runtimeTraceActive then
		return
	end

	if safeIsA(object, "Humanoid") then
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

						appendRuntimeCharacterRecord(
							"HumanoidPropertyChanged",
							object,
							{
								Property = property,
								Value = readRuntimeProperty(object, property)
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

				appendRuntimeCharacterRecord(
					"HumanoidStateChanged",
					object,
					{
						OldState = serializeRuntimeValue(oldState),
						NewState = serializeRuntimeValue(newState)
					}
				)
			end)
		end)

		if stateOk and stateConnection then
			table.insert(runtimeCharacterConnections, stateConnection)
		end
	elseif safeIsA(object, "BasePart") and safeName(object) == "HumanoidRootPart" then
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

						appendRuntimeCharacterRecord(
							"RootPropertyChanged",
							object,
							{
								Property = property,
								Value = readRuntimeProperty(object, property)
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

local function watchLocalCharacter(character)
	if not CONFIG.RuntimeTraceCharacter then
		return
	end

	disconnectConnections(runtimeCharacterConnections)

	if not character then
		appendRuntimeCharacterRecord("CharacterMissing", nil, nil)
		return
	end

	appendRuntimeCharacterRecord(
		"CharacterAttached",
		character,
		{
			CharacterId = instanceIds[character]
		}
	)

	for _, descendant in ipairs(character:GetDescendants()) do
		if safeIsA(descendant, "Humanoid")
			or (safeIsA(descendant, "BasePart") and safeName(descendant) == "HumanoidRootPart")
		then
			watchCharacterObject(descendant)
		end
	end

	local addedOk, addedConnection = pcall(function()
		return character.DescendantAdded:Connect(function(object)
			if not runtimeTraceActive then
				return
			end

			appendRuntimeCharacterRecord(
				"DescendantAdded",
				object,
				{
					Parent = makeInstanceReference(object.Parent, false)
				}
			)

			if safeIsA(object, "Humanoid")
				or (safeIsA(object, "BasePart") and safeName(object) == "HumanoidRootPart")
			then
				watchCharacterObject(object)
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

			appendRuntimeCharacterRecord(
				"DescendantRemoving",
				object,
				{
					Parent = makeInstanceReference(object.Parent, false)
				}
			)
		end)
	end)

	if removingOk and removingConnection then
		table.insert(runtimeCharacterConnections, removingConnection)
	end
end

local function sampleLocalCharacter()
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
		Character = makeInstanceReference(character, false)
	}

	if humanoid then
		local stateOk, humanoidState = pcall(function()
			return humanoid:GetState()
		end)

		record.Humanoid = {
			Id = instanceIds[humanoid],
			Path = safeFullName(humanoid),
			Health = readRuntimeProperty(humanoid, "Health"),
			MaxHealth = readRuntimeProperty(humanoid, "MaxHealth"),
			WalkSpeed = readRuntimeProperty(humanoid, "WalkSpeed"),
			JumpPower = readRuntimeProperty(humanoid, "JumpPower"),
			JumpHeight = readRuntimeProperty(humanoid, "JumpHeight"),
			HipHeight = readRuntimeProperty(humanoid, "HipHeight"),
			MoveDirection = readRuntimeProperty(humanoid, "MoveDirection"),
			FloorMaterial = readRuntimeProperty(humanoid, "FloorMaterial"),
			State = stateOk and serializeRuntimeValue(humanoidState) or nil
		}
	end

	if root and safeIsA(root, "BasePart") then
		record.Root = {
			Id = instanceIds[root],
			Path = safeFullName(root),
			CFrame = readRuntimeProperty(root, "CFrame"),
			Position = readRuntimeProperty(root, "Position"),
			AssemblyLinearVelocity = readRuntimeProperty(root, "AssemblyLinearVelocity"),
			AssemblyAngularVelocity = readRuntimeProperty(root, "AssemblyAngularVelocity"),
			Anchored = readRuntimeProperty(root, "Anchored"),
			CanCollide = readRuntimeProperty(root, "CanCollide")
		}
	end

	table.insert(runtimeCharacterRecords, record)

	appendRuntimeTimeline({
		Time = record.Time,
		Kind = "CharacterSample",
		Path = record.Character and record.Character.Path or nil
	})

	maybeFlushRuntimeTrace()
end

local function appendRuntimeLog(message, messageType)
	if not runtimeTraceActive or not CONFIG.RuntimeCaptureLogs then
		return
	end

	local record = {
		Time = os.clock() - runtimeStartedAt,
		Message = sanitizeString(message),
		MessageType = serializeRuntimeValue(messageType)
	}

	table.insert(runtimeLogRecords, record)

	if isRuntimeInteresting(record.Message, "") then
		appendRuntimeTimeline({
			Time = record.Time,
			Kind = "Log",
			Message = record.Message,
			MessageType = record.MessageType
		})
	end

	maybeFlushRuntimeTrace()
end

local function getCurrentGuiErrorMessage()
	local ok, message = pcall(function()
		return game:GetService("GuiService"):GetErrorMessage()
	end)

	if ok and type(message) == "string" then
		return sanitizeString(message)
	end

	return nil
end

local function shouldFreezeForErrorMessage(message)
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

local function handleGuiErrorMessage(message, source)
	if type(message) ~= "string" or message == "" then
		return
	end

	message = sanitizeString(message)

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

	appendRuntimeTimeline({
		Time = record.Time,
		Kind = "GuiError",
		Source = source,
		Message = message,
		ErrorCode = code
	})

	maybeFlushRuntimeTrace()

	if shouldFreezeForErrorMessage(message) and freezeRuntimeTrace then
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
		pcall(checkRuntimeHookIntegrity, true, "BeforeFreeze")
	end

	local freezeTime = os.clock() - runtimeStartedAt

	runtimeHookState.Frozen = true
	runtimeTraceActive = false
	runtimeHookState.Active = false
	runtimeHookState.FreezeInfo = {
		Time = freezeTime,
		Reason = sanitizeString(reason or "Unknown"),
		Details = details
	}

	appendRuntimeTimeline({
		Time = freezeTime,
		Kind = "TraceFrozen",
		Reason = runtimeHookState.FreezeInfo.Reason
	})

	pruneRuntimeCaches(true)

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
		disconnectConnections(runtimeCharacterConnections)
		disconnectConnections(runtimeConnections)
	end)

	return true
end

local function primeRuntimeObservers()
	if not CONFIG.RuntimeTrace or not runtimeTraceActive then
		return
	end

	local childrenOk, rootChildren = pcall(function()
		return game:GetChildren()
	end)
	if not childrenOk then
		recordWarning("RuntimePrime", nil, rootChildren)
		return
	end

	-- DFS stack keeps memory proportional to the active frontier instead of
	-- retaining one giant GetDescendants() array for the entire DataModel.
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
			local className = safeClassName(object)
			local name = safeName(object)
			local path = safeFullName(object)

			if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
				watchRuntimeRemote(object, instanceIds[object], name, className, path)
			end

			if CONFIG.RuntimeTraceToolAttributes
				or CONFIG.RuntimeTraceInterestingAttributes
			then
				local shouldPrimeAttributes = safeIsA(object, "Tool")
					or safeIsA(object, "Player")
					or safeIsA(object, "Humanoid")
					or safeIsA(object, "BasePart")
					or isRuntimeInteresting(name, path)

				if shouldPrimeAttributes then
					local attributes = getAttributes(object)
					watchRuntimeAttributes(
						object,
						instanceIds[object],
						name,
						className,
						path,
						attributes
					)
				end
			end

			if safeIsA(object, "ValueBase") then
				watchRuntimeValue(object, instanceIds[object], name, className, path)
			end

			local descendantsOk, children = pcall(function()
				return object:GetChildren()
			end)

			if descendantsOk and type(children) == "table" then
				for index = #children, 1, -1 do
					stack[#stack + 1] = children[index]
				end
			elseif not descendantsOk then
				recordWarning("RuntimePrimeGetChildren", object, children)
			end
		end

		processed = processed + 1
		if processed % yieldEvery == 0 then
			task.wait()
		end
	end
end

local function startRuntimeTrace()
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
		checkRuntimeHookIntegrity(true, "BeforeDumperNamecallHook")
	end

	installOutgoingRemoteHook()

	if CONFIG.RuntimeTraceHookDiagnostics then
		checkRuntimeHookIntegrity(true, "AfterDumperNamecallHook")
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

					local className = safeClassName(object)
					local name = safeName(object)
					local path = safeFullName(object)

					if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
						watchRuntimeRemote(object, instanceIds[object], name, className, path)
					end

					if CONFIG.RuntimeTraceToolAttributes
						or CONFIG.RuntimeTraceInterestingAttributes
					then
						watchRuntimeAttributes(
							object,
							instanceIds[object],
							name,
							className,
							path,
							getAttributes(object)
						)
					end

					if safeIsA(object, "ValueBase") then
						watchRuntimeValue(object, instanceIds[object], name, className, path)
					end
				end)
			end)
		end)

		if ok and connection then
			table.insert(runtimeConnections, connection)
		else
			recordWarning("RuntimeDynamicTrace", nil, connection)
		end
	end

	primeRuntimeObservers()

	if LocalPlayer then
		watchLocalCharacter(LocalPlayer.Character)

		local addedOk, addedConnection = pcall(function()
			return LocalPlayer.CharacterAdded:Connect(function(newCharacter)
				if not runtimeTraceActive then
					return
				end

				watchLocalCharacter(newCharacter)
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

				appendRuntimeCharacterRecord(
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

				appendRuntimeLog(message, messageType)
			end)
		end)

		if logOk and logConnection then
			table.insert(runtimeConnections, logConnection)
		else
			recordWarning("RuntimeLogTrace", nil, logConnection)
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

				local current = getCurrentGuiErrorMessage()
				if (not current or current == "") and type(message) == "string" then
					current = message
				end

				handleGuiErrorMessage(current, "GuiService.ErrorMessageChanged")
			end)
		end)

		if connectionOk and connection then
			table.insert(runtimeConnections, connection)
		else
			recordWarning("RuntimeDisconnectTrace", nil, connection)
		end
	else
		recordWarning(
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
				sampleLocalCharacter()
			end

			if errorAccumulator >= 0.25 then
				errorAccumulator = 0
				local message = getCurrentGuiErrorMessage()
				if message and message ~= "" then
					handleGuiErrorMessage(message, "GuiServicePoll")
				end
			end

			local hookInterval =
				math.max(0.03, tonumber(CONFIG.RuntimeHookIntegrityInterval) or 0.20)
			if CONFIG.RuntimeTraceHookDiagnostics
				and hookIntegrityAccumulator >= hookInterval
			then
				hookIntegrityAccumulator = 0
				checkRuntimeHookIntegrity(false, "Heartbeat")
			end
		end)
	end)

	if heartbeatOk and heartbeatConnection then
		table.insert(runtimeConnections, heartbeatConnection)
	else
		recordWarning("RuntimeHeartbeatTrace", nil, heartbeatConnection)
	end
end

local function getSortedChildren(object)
	local ok, children = pcall(function()
		return object:GetChildren()
	end)

	if not ok then
		recordError("GetChildren", object, children)
		return {}
	end

	table.sort(children, function(a, b)
		local classA = safeClassName(a):lower()
		local classB = safeClassName(b):lower()

		if classA ~= classB then
			return classA < classB
		end

		local nameA = safeName(a):lower()
		local nameB = safeName(b):lower()

		if nameA ~= nameB then
			return nameA < nameB
		end

		return safeFullName(a) < safeFullName(b)
	end)

	return children
end

local function makeFailedNode(object, parentId, dumpError)
	local id = assignInstanceId(object)
	local name = safeName(object)
	local className = safeClassName(object)
	local path = safeFullName(object)
	updateInstanceMeta(object, id, parentId, name, className, path)

	return {
		Id = id,
		Name = name,
		ClassName = className,
		Path = path,
		ParentId = parentId,
		DumpError = sanitizeString(dumpError),
		Tags = {},
		Children = {}
	}
end

local dumpNode

dumpNode = function(object, parentId, context)
	local previousVisit = traversedInstances[object]
	if previousVisit then
		recordWarning(
			"RevisitedInstance",
			object,
			string.format(
				"Instance #%d was already traversed at %s and was skipped on a later encounter",
				previousVisit.Id,
				previousVisit.Path
			)
		)
		return nil, "revisited"
	end

	local id = assignInstanceId(object)
	local expectedParent = context and context.ParentObject or nil
	if expectedParent then
		local actualParent, parentReadable = safeGet(object, "Parent")
		if parentReadable and actualParent ~= expectedParent then
			recordWarning(
				"ParentChangedBeforeVisit",
				object,
				"Instance changed parent after GetChildren() and was skipped from the stale parent snapshot"
			)
			return nil, "parent_changed"
		end
	end

	local name = safeName(object)
	local className = safeClassName(object)
	local path = safeFullName(object)

	if invalidClassObjects[object] and not invalidClassWarned[object] then
		invalidClassWarned[object] = true
		recordWarning(
			"InvalidClassName",
			object,
			"ClassName was empty or unreadable and was replaced with Instance"
		)
	end

	traversedInstances[object] = {
		Id = id,
		ParentId = parentId,
		Path = path
	}
	updateInstanceMeta(object, id, parentId, name, className, path)

	nodeCount = nodeCount + 1
	if nodeCount % YIELD_EVERY == 0 then
		task.wait()
	end
	local source = resolveInventorySource(object, context and context.InventorySource or nil)
	local parentToolState = context and context.ToolState or nil

	classCounts[className] = (classCounts[className] or 0) + 1

	local attributes = getAttributes(object)
	local tags = getTags(object)
	local properties = getUsefulProperties(object, className)

	registerAttributes(id, name, className, path, attributes)
	registerRemote(object, id, name, className, parentId, path, attributes, tags)
	registerScript(id, name, className, parentId, path, properties)
	registerValue(object, id, name, className, parentId, path, attributes, tags)
	registerToolDescendant(parentToolState, object, id, className, name)

	scanAttributesForPlayerReferences(id, attributes)
	if safeIsA(object, "ValueBase") then
		local rawValue, readable = safeGet(object, "Value")
		if readable then
			scanValueForPlayerReferences(id, "Value", rawValue)
		end
	end

	watchRuntimeRemote(object, id, name, className, path)
	watchRuntimeAttributes(object, id, name, className, path, attributes)
	watchRuntimeValue(object, id, name, className, path)

	local currentToolState = parentToolState
	if className == "Tool" or safeIsA(object, "Tool") then
		currentToolState = createToolRecord(
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
		Attributes = optionalMap(attributes),
		Tags = tags,
		Properties = optionalMap(properties),
		Children = {}
	}

	for _, child in ipairs(getSortedChildren(object)) do
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
				recordError("DumpNode", child, "dumpNode returned no data")
			end
		else
			recordError("DumpNode", child, childData)
			table.insert(node.Children, makeFailedNode(child, id, childData))
		end
	end

	if expectedParent then
		local finalParent, parentReadable = safeGet(object, "Parent")
		if parentReadable and finalParent ~= expectedParent then
			recordWarning(
				"ParentChangedDuringVisit",
				object,
				"Instance changed parent while it was being dumped; the node keeps its first-seen snapshot location"
			)
		end
	end

	return node
end

local function makeTree(node, depth, output)
	depth = depth or 0
	output = output or {}

	local prefix = string.rep("    ", depth)
	local suffix = ""
	if node.DumpError then
		suffix = " [dump error]"
	end

	table.insert(
		output,
		string.format(
			"%s%s [%s] (#%s)%s",
			prefix,
			escapeText(node.Name),
			escapeText(node.ClassName),
			tostring(node.Id),
			suffix
		)
	)

	for _, child in ipairs(node.Children) do
		makeTree(child, depth + 1, output)
	end

	return output
end

local function sortRecordsByPath(records)
	table.sort(records, function(a, b)
		if a.Path ~= b.Path then
			return a.Path < b.Path
		end

		return a.Id < b.Id
	end)
end

local function tokenizeText(value)
	local text = sanitizeString(value or "")
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

local function buildAncestorNames(parentId)
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

local function enrichRemoteRecords()
	for _, bucket in pairs(remoteIndex) do
		for _, record in ipairs(bucket) do
			record.Ancestors = buildAncestorNames(record.ParentId)

			local tokenMap = {}
			local tokens = {}

			local function addTokens(value)
				for _, token in ipairs(tokenizeText(value)) do
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

local function buildPathStats(instanceIndex)
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

local function buildPlayerIndex()
	local referenceCounts = {}
	for _, reference in ipairs(playerReferences) do
		referenceCounts[reference.UserId] = (referenceCounts[reference.UserId] or 0) + 1
	end

	local records = {}

	for _, descriptor in ipairs(playerDescriptors) do
		local player = descriptor.Player
		local team, teamReadable = safeGet(player, "Team")
		local teamColor, teamColorReadable = safeGet(player, "TeamColor")
		local neutral, neutralReadable = safeGet(player, "Neutral")

		local record = {
			Name = sanitizeString(descriptor.Name),
			DisplayName = sanitizeString(descriptor.DisplayName),
			UserId = descriptor.UserId,
			PlayerId = instanceIds[player],
			CharacterId = descriptor.Character and instanceIds[descriptor.Character] or nil,
			BackpackId = descriptor.Backpack and instanceIds[descriptor.Backpack] or nil,
			PlayerGuiId = descriptor.PlayerGui and instanceIds[descriptor.PlayerGui] or nil,
			StarterGearId = descriptor.StarterGear and instanceIds[descriptor.StarterGear] or nil,
			ReferenceCount = referenceCounts[descriptor.UserId] or 0
		}

		if teamReadable and team then
			record.NativeTeam = makeInstanceReference(team)
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

local function stateRecordFromMeta(meta, valueById)
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

local function buildStateIndex(instanceIndex)
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

		for _, token in ipairs(tokenizeText(meta.Name or "")) do
			local lowered = string.lower(token)
			tokenSet[lowered] = true
			nameTokenSet[lowered] = true
		end

		for _, token in ipairs(tokenizeText(meta.Path or "")) do
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
					table.insert(buckets[bucketName], stateRecordFromMeta(meta, valueById))
				end
			end
		end
	end

	return {
		Counts = counts,
		Buckets = buckets
	}
end

local function finalizeIndexes()
	sortRecordsByPath(attributeIndex)
	sortRecordsByPath(toolRecords)
	sortRecordsByPath(valueRecords)

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
		sortRecordsByPath(bucket)
	end

	for _, bucket in pairs(scriptIndex) do
		sortRecordsByPath(bucket)
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

	enrichRemoteRecords()
end

local function buildInstanceIndex()
	local list = {}

	for id = 1, nextInstanceId do
		local meta = instanceMetaById[id]
		if meta then
			table.insert(list, meta)
		end
	end

	return list
end

local function buildInventory()
	return {
		Player = LocalPlayer and makeInstanceReference(LocalPlayer) or nil,
		Backpack = makeInstanceReference(backpack),
		Character = makeInstanceReference(character),
		StarterGear = makeInstanceReference(starterGear),
		ToolIds = inventoryToolIds
	}
end

local function totalBucketCount(index)
	local total = 0
	for _, bucket in pairs(index) do
		total = total + #bucket
	end
	return total
end

local function totalRemoteCount()
	return totalBucketCount(remoteIndex)
end

local function totalScriptCount()
	return totalBucketCount(scriptIndex)
end

local function buildSummary(elapsed, pathStats)
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
		"Game: " .. sanitizeString(game.Name),
		"PlaceId: " .. tostring(game.PlaceId),
		"GameId: " .. tostring(game.GameId),
		"JobId: " .. sanitizeString(game.JobId),
		"Serialized Instance Records: " .. tostring(nextInstanceId),
		"Traversed Descendants: " .. tostring(nodeCount),
		"Registered IDs: " .. tostring(nextInstanceId),
		"Remotes / Bindables: " .. tostring(totalRemoteCount()),
		"Scripts: " .. tostring(totalScriptCount()),
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
				string.format("%dx %s", collision.Count, escapeText(collision.Path))
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

local function encodeJSON(data, label)
	local ok, result = pcall(function()
		return HttpService:JSONEncode(data)
	end)

	if ok then
		return result, true
	end

	recordError("JSONEncode", nil, result, label)

	local fallbackOk, fallback = pcall(function()
		return HttpService:JSONEncode({
			Error = sanitizeString(result),
			Message = sanitizeString(label .. " export failed")
		})
	end)

	if fallbackOk then
		return fallback, false
	end

	return "{}", false
end

local function ensureOutputFolder()
	if capabilities.isfolder then
		local ok, exists = pcall(isfolder, OUTPUT_FOLDER)
		if ok and exists then
			return true
		end
	end

	if capabilities.makefolder then
		local ok = pcall(makefolder, OUTPUT_FOLDER)
		if ok then
			return true
		end

		if capabilities.isfolder then
			local checkOk, exists = pcall(isfolder, OUTPUT_FOLDER)
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

local function writeSafe(path, contents)
	local ok, writeError = pcall(writefile, path, contents)
	if not ok then
		recordError("WriteFile", nil, writeError, path)
		return false
	end

	return true
end

local function fileNameFromPath(path)
	return string.match(path, "[^/]+$") or path
end

local function writeJSONDocument(path, data, label, writtenFiles, required)
	local encoded, encodeSuccess = encodeJSON(data, label)
	local bytes = #encoded
	local writeSuccess = writeSafe(path, encoded)
	local success = encodeSuccess and writeSuccess

	if writtenFiles then
		table.insert(writtenFiles, {
			File = fileNameFromPath(path),
			Bytes = bytes,
			Encoded = encodeSuccess,
			Written = writeSuccess,
			Success = success,
			Required = required ~= false
		})
	end

	return success, bytes
end

local function releaseTemporaryMemory()
	if type(collectgarbage) == "function" then
		pcall(collectgarbage, "collect")
	end
end

local function writeTextDocument(path, contents, writtenFiles, required)
	local bytes = #contents
	local success = writeSafe(path, contents)

	if writtenFiles then
		table.insert(writtenFiles, {
			File = fileNameFromPath(path),
			Bytes = bytes,
			Success = success,
			Required = required ~= false
		})
	end

	return success, bytes
end

local function backfillRuntimeIds()
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

local function makeRuntimeEventDocument(records, category)
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

	pruneRuntimeCaches(true)
	backfillRuntimeIds()

	local eventsDocument = makeRuntimeEventDocument(runtimeEventRecords, nil)
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

	writeSafe(RUNTIME_FILES.Events, encodeJSON(eventsDocument, "runtime_events.json"))
	writeSafe(
		RUNTIME_FILES.EventsGame,
		encodeJSON(
			makeRuntimeEventDocument(runtimeEventCategoryRecords.Game, "Game"),
			"runtime_events_game.json"
		)
	)
	writeSafe(
		RUNTIME_FILES.EventsReplicator,
		encodeJSON(
			makeRuntimeEventDocument(runtimeEventCategoryRecords.Replicator, "Replicator"),
			"runtime_events_replicator.json"
		)
	)
	writeSafe(
		RUNTIME_FILES.EventsAnalytics,
		encodeJSON(
			makeRuntimeEventDocument(runtimeEventCategoryRecords.Analytics, "Analytics"),
			"runtime_events_analytics.json"
		)
	)
	writeSafe(
		RUNTIME_FILES.EventsOther,
		encodeJSON(
			makeRuntimeEventDocument(runtimeEventCategoryRecords.Other, "Other"),
			"runtime_events_other.json"
		)
	)
	writeSafe(RUNTIME_FILES.Values, encodeJSON(valuesDocument, "runtime_values.json"))
	writeSafe(RUNTIME_FILES.Attributes, encodeJSON(attributesDocument, "runtime_attributes.json"))
	writeSafe(RUNTIME_FILES.Character, encodeJSON(characterDocument, "runtime_character.json"))
	writeSafe(RUNTIME_FILES.Logs, encodeJSON(logsDocument, "runtime_logs.json"))
	writeSafe(RUNTIME_FILES.Timeline, encodeJSON(timelineDocument, "runtime_timeline.json"))
	writeSafe(RUNTIME_FILES.Disconnect, encodeJSON(disconnectDocument, "runtime_disconnect.json"))
	writeSafe(RUNTIME_FILES.Hooks, encodeJSON(hooksDocument, "runtime_hooks.json"))
	writeSafe(
		RUNTIME_FILES.HookIntegrity,
		encodeJSON(hookIntegrityDocument, "runtime_hook_integrity.json")
	)

	runtimeHookState.LastFlushAt = os.clock()
	runtimeHookState.MutationsSinceFlush = 0
end

local function stopRuntimeTrace()
	runtimeTraceActive = false
	runtimeHookState.Active = false

	disconnectConnections(runtimeCharacterConnections)
	disconnectConnections(runtimeConnections)

	flushRuntimeTrace()
end

local function finishRuntimeTraceAfterSnapshot()
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

	stopRuntimeTrace()

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

local function run()
	if not capabilities.writefile then
		warn("GameStructureDump: writefile is unavailable; dump aborted.")
		return
	end

	if not ensureOutputFolder() then
		warn("GameStructureDump: output folder could not be created or verified; dump aborted.")
		return
	end

	local guidOk, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)

	currentDumpId = guidOk and guid or string.format("%d-%d", os.time(), math.floor(os.clock() * 1000))
	runtimeStartedAt = os.clock()
	startRuntimeTrace()

	local initialManifest = {
		Schema = SCHEMA_NAME,
		SchemaVersion = SCHEMA_VERSION,
		DumpId = currentDumpId,
		Complete = false,
		Status = "InProgress",
		GeneratedAtUnix = os.time()
	}

	writeSafe(MANIFEST_FILE, encodeJSON(initialManifest, "manifest.json"))
	preparePlayerDescriptors()

	local rootId = assignInstanceId(game)
	updateInstanceMeta(game, rootId, nil, "game", "DataModel", "game")

	local root = {
		Id = rootId,
		Name = "game",
		ClassName = "DataModel",
		Path = "game",
		Attributes = optionalMap(getAttributes(game)),
		Tags = getTags(game),
		Properties = {
			Name = sanitizeString(game.Name),
			PlaceId = game.PlaceId,
			GameId = game.GameId,
			JobId = sanitizeString(game.JobId)
		},
		Children = {}
	}

	for _, service in ipairs(getSortedChildren(game)) do
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
				recordError("DumpRootChild", service, "dumpNode returned no data")
			end
		else
			recordError("DumpRootChild", service, result)
			table.insert(root.Children, makeFailedNode(service, rootId, result))
		end
	end

	snapshotFinalized = true
	finalizeIndexes()

	-- Traversal bookkeeping is no longer needed after the snapshot. Releasing it
	-- here lowers the peak during JSON encoding without dropping exported data.
	table.clear(traversedInstances)

	local snapshotElapsed = os.clock() - started
	finishRuntimeTraceAfterSnapshot()

	local inventory = buildInventory()
	local instanceIndex = buildInstanceIndex()
	local instanceCount = #instanceIndex
	local playerIndex = buildPlayerIndex()
	local pathStats = buildPathStats(instanceIndex)
	local stateDocument = buildStateIndex(instanceIndex)
	local treeLines = makeTree(root)

	stateDocument.PathCollisions = pathStats
	stateDocument.PlayerReferenceCount = #playerReferences
	stateDocument.ValueRecordCount = #valueRecords

	local remotesDocument = {
		Total = totalRemoteCount(),
		RemoteEvents = remoteIndex.RemoteEvents,
		UnreliableRemoteEvents = remoteIndex.UnreliableRemoteEvents,
		RemoteFunctions = remoteIndex.RemoteFunctions,
		BindableEvents = remoteIndex.BindableEvents,
		BindableFunctions = remoteIndex.BindableFunctions
	}

	local scriptsDocument = {
		Total = totalScriptCount(),
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

	local writtenFiles = {}

	local treeText = table.concat(treeLines, "\n")
	writeTextDocument(TREE_FILE, treeText, writtenFiles, true)
	treeText = nil
	treeLines = nil

	writeJSONDocument(STRUCTURE_FILE, root, "structure.json", writtenFiles, true)
	root = nil
	releaseTemporaryMemory()

	writeJSONDocument(INSTANCES_FILE, instanceIndex, "instances.json", writtenFiles, true)
	instanceIndex = nil
	table.clear(instanceMetaById)
	releaseTemporaryMemory()

	writeJSONDocument(REMOTES_FILE, remotesDocument, "remotes.json", writtenFiles, true)
	writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts.json", writtenFiles, true)
	writeJSONDocument(INVENTORY_FILE, inventory, "inventory.json", writtenFiles, true)
	inventory = nil
	writeJSONDocument(ATTRIBUTES_FILE, attributeIndex, "attributes.json", writtenFiles, true)
	writeJSONDocument(TOOLS_FILE, toolRecords, "tools.json", writtenFiles, true)
	writeJSONDocument(VALUES_FILE, valuesDocument, "values.json", writtenFiles, true)
	writeJSONDocument(PLAYERS_FILE, playerIndex, "players.json", writtenFiles, true)
	playerIndex = nil
	playerDescriptors = {}
	writeJSONDocument(
		PLAYER_REFERENCES_FILE,
		playerReferencesDocument,
		"player_references.json",
		writtenFiles,
		true
	)
	writeJSONDocument(STATE_FILE, stateDocument, "state.json", writtenFiles, true)
	stateDocument = nil

	local runtimeEventsDocument = makeRuntimeEventDocument(runtimeEventRecords, nil)
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

	writeJSONDocument(
		RUNTIME_FILES.Events,
		runtimeEventsDocument,
		"runtime_events.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.EventsGame,
		makeRuntimeEventDocument(runtimeEventCategoryRecords.Game, "Game"),
		"runtime_events_game.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.EventsReplicator,
		makeRuntimeEventDocument(runtimeEventCategoryRecords.Replicator, "Replicator"),
		"runtime_events_replicator.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.EventsAnalytics,
		makeRuntimeEventDocument(runtimeEventCategoryRecords.Analytics, "Analytics"),
		"runtime_events_analytics.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.EventsOther,
		makeRuntimeEventDocument(runtimeEventCategoryRecords.Other, "Other"),
		"runtime_events_other.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.Values,
		runtimeValuesDocument,
		"runtime_values.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.Attributes,
		runtimeAttributesDocument,
		"runtime_attributes.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.Character,
		runtimeCharacterDocument,
		"runtime_character.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.Logs,
		runtimeLogsDocument,
		"runtime_logs.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.Timeline,
		runtimeTimelineDocument,
		"runtime_timeline.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.Disconnect,
		runtimeDisconnectDocument,
		"runtime_disconnect.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.Hooks,
		runtimeHooksDocument,
		"runtime_hooks.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_FILES.HookIntegrity,
		runtimeHookIntegrityDocument,
		"runtime_hook_integrity.json",
		writtenFiles,
		false
	)

	writeJSONDocument(WARNINGS_FILE, warnings, "warnings.json", writtenFiles, true)

	local totalElapsed = os.clock() - started
	local meta = {
		Schema = SCHEMA_NAME,
		SchemaVersion = SCHEMA_VERSION,
		DumpId = currentDumpId,
		GeneratedAtUnix = os.time(),
		IdSemantics = "Snapshot-local. IDs are stable only inside this dump.",
		PathSemantics = "Human-readable path. Paths are not guaranteed to be unique.",
		Game = {
			Name = sanitizeString(game.Name),
			PlaceId = game.PlaceId,
			GameId = game.GameId,
			JobId = sanitizeString(game.JobId)
		},
		Player = LocalPlayer and {
			Name = safeName(LocalPlayer),
			UserId = LocalPlayer.UserId
		} or nil,
		Stats = {
			Instances = instanceCount,
			DescendantInstances = nodeCount,
			RegisteredIds = nextInstanceId,
			RemotesAndBindables = totalRemoteCount(),
			Scripts = totalScriptCount(),
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

	writeTextDocument(
		SUMMARY_FILE,
		buildSummary(totalElapsed, pathStats),
		writtenFiles,
		true
	)

	meta.Stats.Errors = #errors
	meta.Stats.Warnings = #warnings
	meta.Stats.ElapsedSeconds = os.clock() - started
	writeJSONDocument(META_FILE, meta, "meta.json", writtenFiles, true)

	writeJSONDocument(ERRORS_FILE, errors, "errors.json", writtenFiles, true)

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
		HasErrors = #errors > 0,
		HasWarnings = #warnings > 0,
		GeneratedAtUnix = os.time(),
		IdSemantics = "Snapshot-local",
		Files = writtenFiles,
		Stats = {
			Instances = instanceCount,
			DescendantInstances = nodeCount,
			RegisteredIds = nextInstanceId,
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

	local manifestEncoded, manifestEncodeOk = encodeJSON(manifest, "manifest.json")
	local manifestWriteOk = writeSafe(MANIFEST_FILE, manifestEncoded)
	if not manifestEncodeOk or not manifestWriteOk then
		warn("GameStructureDump: manifest.json could not be completed.")
	end

	print("dump finished")
	print("DumpId:", currentDumpId)
	print("Serialized instance records:", instanceCount)
	print("Traversed descendants:", nodeCount)
	print("Registered IDs:", nextInstanceId)
	print("Remotes / Bindables:", totalRemoteCount())
	print("Scripts:", totalScriptCount())
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

run()
