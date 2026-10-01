local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local OUTPUT_FOLDER = "GameStructureDump"
local SCHEMA_NAME = "Averyn.GameStructureDump"
local SCHEMA_VERSION = 2

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
local RUNTIME_EVENTS_FILE = OUTPUT_FOLDER .. "/runtime_events.json"
local RUNTIME_VALUES_FILE = OUTPUT_FOLDER .. "/runtime_values.json"
local MANIFEST_FILE = OUTPUT_FOLDER .. "/manifest.json"
local ERRORS_FILE = OUTPUT_FOLDER .. "/errors.json"
local WARNINGS_FILE = OUTPUT_FOLDER .. "/warnings.json"

local YIELD_EVERY = 250
local MAX_SERIALIZE_DEPTH = 32

local CONFIG = {
	RuntimeTrace = false,
	RuntimeTraceSeconds = 30,
	RuntimeTraceAllValues = false,
	RuntimeFlushEvery = 25,
	RuntimeMaxEvents = 3000,
	RuntimeMaxValueChanges = 3000,
	StateIndexMaxPerBucket = 1500
}

local capabilities = {
	writefile = type(writefile) == "function",
	makefolder = type(makefolder) == "function",
	isfolder = type(isfolder) == "function"
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
local runtimeValueRecords = {}
local runtimeConnections = {}
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

local function makeInstanceReference(object)
	if not object then
		return nil
	end

	local id = instanceIds[object]
	if not id and not snapshotFinalized then
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
		local reference = makeInstanceReference(value)
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
			depth = state.depth + 1
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

local function registerRemote(id, name, className, parentId, path, attributes, tags)
	local bucket = REMOTE_BUCKETS[className]
	if not bucket then
		return
	end

	table.insert(remoteIndex[bucket], {
		Id = id,
		Name = name,
		ClassName = className,
		Path = path,
		ParentId = parentId,
		Attributes = optionalMap(attributes),
		Tags = tags
	})
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
	"dead"
}

local flushRuntimeTrace

local function isRuntimeInteresting(name, path)
	local haystack = string.lower((name or "") .. " " .. (path or ""))

	for _, keyword in ipairs(RUNTIME_KEYWORDS) do
		if string.find(haystack, keyword, 1, true) then
			return true
		end
	end

	return false
end

local function maybeFlushRuntimeTrace()
	if not flushRuntimeTrace then
		return
	end

	local total = #runtimeEventRecords + #runtimeValueRecords
	if total > 0 and total % CONFIG.RuntimeFlushEvery == 0 then
		flushRuntimeTrace()
	end
end

local function watchRuntimeRemote(object, id, name, className, path)
	if not CONFIG.RuntimeTrace then
		return
	end

	if className ~= "RemoteEvent" and className ~= "UnreliableRemoteEvent" then
		return
	end

	local ok, signal = pcall(function()
		return object.OnClientEvent
	end)

	if not ok or not signal then
		return
	end

	local connectionOk, connection = pcall(function()
		return signal:Connect(function(...)
			if #runtimeEventRecords >= CONFIG.RuntimeMaxEvents then
				return
			end

			local packed = table.pack(...)
			local arguments = {}

			for index = 1, packed.n do
				local serializeOk, serialized = pcall(serializeValue, packed[index])
				if serializeOk then
					arguments[index] = serialized
				else
					arguments[index] = {
						__type = "SerializationError",
						value = sanitizeString(serialized)
					}
				end
			end

			table.insert(runtimeEventRecords, {
				Time = os.clock() - runtimeStartedAt,
				RemoteId = id,
				Name = name,
				ClassName = className,
				Path = path,
				ArgumentCount = packed.n,
				Arguments = arguments
			})

			maybeFlushRuntimeTrace()
		end)
	end)

	if connectionOk and connection then
		table.insert(runtimeConnections, connection)
	else
		recordWarning("RuntimeRemoteTrace", object, connection)
	end
end

local function watchRuntimeValue(object, id, name, className, path)
	if not CONFIG.RuntimeTrace or not safeIsA(object, "ValueBase") then
		return
	end

	if not CONFIG.RuntimeTraceAllValues and not isRuntimeInteresting(name, path) then
		return
	end

	local signalOk, signal = pcall(function()
		return object:GetPropertyChangedSignal("Value")
	end)

	if not signalOk or not signal then
		return
	end

	local connectionOk, connection = pcall(function()
		return signal:Connect(function()
			if #runtimeValueRecords >= CONFIG.RuntimeMaxValueChanges then
				return
			end

			local value, readable, readError = safeGet(object, "Value")
			local serialized

			if readable then
				local serializeOk, result = pcall(serializeValue, value)
				serialized = serializeOk and result or {
					__type = "SerializationError",
					value = sanitizeString(result)
				}
			else
				serialized = {
					__type = "ReadError",
					value = sanitizeString(readError)
				}
			end

			table.insert(runtimeValueRecords, {
				Time = os.clock() - runtimeStartedAt,
				Id = id,
				Name = name,
				ClassName = className,
				Path = path,
				Value = serialized
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
	registerRemote(id, name, className, parentId, path, attributes, tags)
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
		"Total Instances: " .. tostring(nodeCount),
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

flushRuntimeTrace = function()
	if not capabilities.writefile then
		return
	end

	local eventsDocument = {
		DumpId = currentDumpId,
		Enabled = CONFIG.RuntimeTrace,
		Active = CONFIG.RuntimeTrace and #runtimeConnections > 0,
		ElapsedSeconds = os.clock() - runtimeStartedAt,
		Total = #runtimeEventRecords,
		Events = runtimeEventRecords
	}

	local valuesDocument = {
		DumpId = currentDumpId,
		Enabled = CONFIG.RuntimeTrace,
		Active = CONFIG.RuntimeTrace and #runtimeConnections > 0,
		ElapsedSeconds = os.clock() - runtimeStartedAt,
		Total = #runtimeValueRecords,
		Changes = runtimeValueRecords
	}

	writeSafe(RUNTIME_EVENTS_FILE, encodeJSON(eventsDocument, "runtime_events.json"))
	writeSafe(RUNTIME_VALUES_FILE, encodeJSON(valuesDocument, "runtime_values.json"))
end

local function stopRuntimeTrace()
	for _, connection in ipairs(runtimeConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	runtimeConnections = {}
	flushRuntimeTrace()
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

	local inventory = buildInventory()
	local instanceIndex = buildInstanceIndex()
	local playerIndex = buildPlayerIndex()
	local pathStats = buildPathStats(instanceIndex)
	local stateDocument = buildStateIndex(instanceIndex)
	local treeLines = makeTree(root)
	local snapshotElapsed = os.clock() - started

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
	writeJSONDocument(INSTANCES_FILE, instanceIndex, "instances.json", writtenFiles, true)
	writeJSONDocument(REMOTES_FILE, remotesDocument, "remotes.json", writtenFiles, true)
	writeJSONDocument(SCRIPTS_FILE, scriptsDocument, "scripts.json", writtenFiles, true)
	writeJSONDocument(INVENTORY_FILE, inventory, "inventory.json", writtenFiles, true)
	writeJSONDocument(ATTRIBUTES_FILE, attributeIndex, "attributes.json", writtenFiles, true)
	writeJSONDocument(TOOLS_FILE, toolRecords, "tools.json", writtenFiles, true)
	writeJSONDocument(VALUES_FILE, valuesDocument, "values.json", writtenFiles, true)
	writeJSONDocument(PLAYERS_FILE, playerIndex, "players.json", writtenFiles, true)
	writeJSONDocument(
		PLAYER_REFERENCES_FILE,
		playerReferencesDocument,
		"player_references.json",
		writtenFiles,
		true
	)
	writeJSONDocument(STATE_FILE, stateDocument, "state.json", writtenFiles, true)

	local runtimeEventsDocument = {
		DumpId = currentDumpId,
		Enabled = CONFIG.RuntimeTrace,
		Active = CONFIG.RuntimeTrace and #runtimeConnections > 0,
		ElapsedSeconds = os.clock() - runtimeStartedAt,
		Total = #runtimeEventRecords,
		Events = runtimeEventRecords
	}

	local runtimeValuesDocument = {
		DumpId = currentDumpId,
		Enabled = CONFIG.RuntimeTrace,
		Active = CONFIG.RuntimeTrace and #runtimeConnections > 0,
		ElapsedSeconds = os.clock() - runtimeStartedAt,
		Total = #runtimeValueRecords,
		Changes = runtimeValueRecords
	}

	writeJSONDocument(
		RUNTIME_EVENTS_FILE,
		runtimeEventsDocument,
		"runtime_events.json",
		writtenFiles,
		false
	)
	writeJSONDocument(
		RUNTIME_VALUES_FILE,
		runtimeValuesDocument,
		"runtime_values.json",
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
			Instances = nodeCount,
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
			Seconds = CONFIG.RuntimeTraceSeconds,
			AllValues = CONFIG.RuntimeTraceAllValues,
			MaxEvents = CONFIG.RuntimeMaxEvents,
			MaxValueChanges = CONFIG.RuntimeMaxValueChanges
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
			Instances = nodeCount,
			RegisteredIds = nextInstanceId,
			Errors = #errors,
			Warnings = #warnings
		},
		RuntimeTrace = {
			Enabled = CONFIG.RuntimeTrace,
			FilesAreAuxiliary = true
		}
	}

	local manifestEncoded, manifestEncodeOk = encodeJSON(manifest, "manifest.json")
	local manifestWriteOk = writeSafe(MANIFEST_FILE, manifestEncoded)
	if not manifestEncodeOk or not manifestWriteOk then
		warn("GameStructureDump: manifest.json could not be completed.")
	end

	print("dump finished")
	print("DumpId:", currentDumpId)
	print("Instances:", nodeCount)
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
	print("Sanitized invalid UTF-8 unique strings:", invalidUtf8StringCount)
	print("Time:", string.format("%.2fs", totalElapsed))
	print("Folder:", OUTPUT_FOLDER)

	if CONFIG.RuntimeTrace then
		flushRuntimeTrace()

		task.delay(CONFIG.RuntimeTraceSeconds, function()
			stopRuntimeTrace()
			print(
				"runtime trace finished:",
				#runtimeEventRecords,
				"remote events,",
				#runtimeValueRecords,
				"value changes"
			)
		end)
	end
end

run()
