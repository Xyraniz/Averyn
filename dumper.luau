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
local ERRORS_FILE = OUTPUT_FOLDER .. "/errors.json"

local YIELD_EVERY = 250
local MAX_SERIALIZE_DEPTH = 32

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
local attributeIndex = {}
local toolRecords = {}
local instanceIds = setmetatable({}, { __mode = "k" })
local instanceMetaById = {}

local remoteIndex = {
	RemoteEvents = {},
	RemoteFunctions = {},
	BindableEvents = {},
	BindableFunctions = {}
}

local scriptIndex = {
	LocalScripts = {},
	ModuleScripts = {},
	Scripts = {}
}

local inventoryToolIds = {
	Backpack = {},
	Character = {},
	StarterGear = {}
}

local function safeName(object)
	local ok, value = pcall(function()
		return object.Name
	end)

	if ok then
		return value
	end

	return "<unknown>"
end

local function safeClassName(object)
	local ok, value = pcall(function()
		return object.ClassName
	end)

	if ok then
		return value
	end

	return "Instance"
end

local function safeFullName(object)
	local ok, result = pcall(function()
		return object:GetFullName()
	end)

	if ok then
		return result
	end

	return safeName(object)
end

local function recordError(stage, object, message, property)
	local entry = {
		Stage = stage,
		Error = tostring(message)
	}

	if object then
		entry.Id = instanceIds[object]
		entry.Name = safeName(object)
		entry.ClassName = safeClassName(object)
		entry.Path = safeFullName(object)
	end

	if property then
		entry.Property = property
	end

	table.insert(errors, entry)
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

local function updateInstanceMeta(object, id, parentId)
	local meta = instanceMetaById[id]
	if not meta then
		meta = { Id = id }
		instanceMetaById[id] = meta
	end

	meta.Name = safeName(object)
	meta.ClassName = safeClassName(object)
	meta.Path = safeFullName(object)
	meta.ParentId = parentId
	meta.ReferencedOnly = false
end

local function makeInstanceReference(object)
	if not object then
		return nil
	end

	local id = assignInstanceId(object)

	return {
		Id = id,
		Name = safeName(object),
		ClassName = safeClassName(object),
		Path = safeFullName(object)
	}
end

local function finiteNumber(value)
	if value ~= value then
		return false
	end

	return value ~= math.huge and value ~= -math.huge
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

	if valueType == "string" or valueType == "boolean" then
		return value
	end

	if valueType == "number" then
		if finiteNumber(value) then
			return value
		end

		return {
			__type = "Number",
			value = tostring(value)
		}
	end

	if valueType == "Vector3" then
		return {
			__type = "Vector3",
			x = value.X,
			y = value.Y,
			z = value.Z
		}
	end

	if valueType == "Vector2" then
		return {
			__type = "Vector2",
			x = value.X,
			y = value.Y
		}
	end

	if valueType == "Color3" then
		return {
			__type = "Color3",
			r = value.R,
			g = value.G,
			b = value.B
		}
	end

	if valueType == "CFrame" then
		return {
			__type = "CFrame",
			components = { value:GetComponents() }
		}
	end

	if valueType == "UDim" then
		return {
			__type = "UDim",
			scale = value.Scale,
			offset = value.Offset
		}
	end

	if valueType == "UDim2" then
		return {
			__type = "UDim2",
			xScale = value.X.Scale,
			xOffset = value.X.Offset,
			yScale = value.Y.Scale,
			yOffset = value.Y.Offset
		}
	end

	if valueType == "BrickColor" then
		return {
			__type = "BrickColor",
			name = value.Name,
			number = value.Number
		}
	end

	if valueType == "EnumItem" then
		return {
			__type = "EnumItem",
			value = tostring(value)
		}
	end

	if valueType == "NumberRange" then
		return {
			__type = "NumberRange",
			min = value.Min,
			max = value.Max
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
				time = keypoint.Time,
				value = keypoint.Value,
				envelope = keypoint.Envelope
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
				time = keypoint.Time,
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
		__type = valueType,
		value = tostring(value)
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
		local success, serialized = pcall(serializeValue, value)
		if success then
			output[name] = serialized
		else
			recordError("SerializeAttribute", object, serialized, name)
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
	RemoteFunction = "RemoteFunctions",
	BindableEvent = "BindableEvents",
	BindableFunction = "BindableFunctions"
}

local SCRIPT_BUCKETS = {
	LocalScript = "LocalScripts",
	ModuleScript = "ModuleScripts",
	Script = "Scripts"
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

local function getUsefulProperties(object)
	local data = {}
	local className = safeClassName(object)

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

local function registerAttributes(object, id, path, attributes)
	if next(attributes) == nil then
		return
	end

	table.insert(attributeIndex, {
		Id = id,
		Name = safeName(object),
		ClassName = safeClassName(object),
		Path = path,
		Attributes = attributes
	})
end

local function registerRemote(object, id, parentId, path, attributes, tags)
	local className = safeClassName(object)
	local bucket = REMOTE_BUCKETS[className]
	if not bucket then
		return
	end

	table.insert(remoteIndex[bucket], {
		Id = id,
		Name = safeName(object),
		ClassName = className,
		Path = path,
		ParentId = parentId,
		Attributes = attributes,
		Tags = tags
	})
end

local function registerScript(object, id, parentId, path, properties)
	local className = safeClassName(object)
	local bucket = SCRIPT_BUCKETS[className]
	if not bucket then
		return
	end

	local record = {
		Id = id,
		Name = safeName(object),
		ClassName = className,
		Path = path,
		ParentId = parentId
	}

	if properties.Disabled ~= nil then
		record.Disabled = properties.Disabled
	end

	table.insert(scriptIndex[bucket], record)
end

local backpack = LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack") or nil
local character = LocalPlayer and LocalPlayer.Character or nil
local starterGear = LocalPlayer and LocalPlayer:FindFirstChild("StarterGear") or nil

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

local function createToolRecord(object, id, path, source, attributes, properties)
	local record = {
		Id = id,
		Name = safeName(object),
		ClassName = safeClassName(object),
		Path = path,
		Source = source,
		Attributes = attributes,
		Properties = properties,
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

local function registerToolDescendant(toolState, object, id, className)
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
	if parentReadable and parent == toolState.Instance and safeName(object) == "Handle" and record.HandleId == nil then
		record.HandleId = id
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
	updateInstanceMeta(object, id, parentId)

	return {
		Id = id,
		Name = safeName(object),
		ClassName = safeClassName(object),
		Path = safeFullName(object),
		ParentId = parentId,
		DumpError = tostring(dumpError),
		Attributes = {},
		Tags = {},
		Properties = {},
		Children = {}
	}
end

local dumpNode

dumpNode = function(object, parentId, context)
	local id = assignInstanceId(object)
	updateInstanceMeta(object, id, parentId)

	nodeCount = nodeCount + 1
	if nodeCount % YIELD_EVERY == 0 then
		task.wait()
	end

	local name = safeName(object)
	local className = safeClassName(object)
	local path = safeFullName(object)
	local source = resolveInventorySource(object, context and context.InventorySource or nil)
	local parentToolState = context and context.ToolState or nil

	classCounts[className] = (classCounts[className] or 0) + 1

	local attributes = getAttributes(object)
	local tags = getTags(object)
	local properties = getUsefulProperties(object)

	registerAttributes(object, id, path, attributes)
	registerRemote(object, id, parentId, path, attributes, tags)
	registerScript(object, id, parentId, path, properties)
	registerToolDescendant(parentToolState, object, id, className)

	local currentToolState = parentToolState
	if className == "Tool" or safeIsA(object, "Tool") then
		currentToolState = createToolRecord(
			object,
			id,
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
		Attributes = attributes,
		Tags = tags,
		Properties = properties,
		Children = {}
	}

	for _, child in ipairs(getSortedChildren(object)) do
		local ok, childData = pcall(
			dumpNode,
			child,
			id,
			{
				InventorySource = source,
				ToolState = currentToolState
			}
		)

		if ok and childData then
			table.insert(node.Children, childData)
		else
			recordError("DumpNode", child, childData)
			table.insert(node.Children, makeFailedNode(child, id, childData))
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
			node.Name,
			node.ClassName,
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

local function finalizeIndexes()
	sortRecordsByPath(attributeIndex)
	sortRecordsByPath(toolRecords)

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

local function totalRemoteCount()
	return #remoteIndex.RemoteEvents
		+ #remoteIndex.RemoteFunctions
		+ #remoteIndex.BindableEvents
		+ #remoteIndex.BindableFunctions
end

local function totalScriptCount()
	return #scriptIndex.LocalScripts
		+ #scriptIndex.ModuleScripts
		+ #scriptIndex.Scripts
end

local function buildSummary(elapsed)
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
		"Game: " .. tostring(game.Name),
		"PlaceId: " .. tostring(game.PlaceId),
		"GameId: " .. tostring(game.GameId),
		"JobId: " .. tostring(game.JobId),
		"Total Instances: " .. tostring(nodeCount),
		"Registered IDs: " .. tostring(nextInstanceId),
		"Remotes / Bindables: " .. tostring(totalRemoteCount()),
		"Scripts: " .. tostring(totalScriptCount()),
		"Objects With Attributes: " .. tostring(#attributeIndex),
		"Tools: " .. tostring(#toolRecords),
		"Errors: " .. tostring(#errors),
		"Time: " .. string.format("%.2fs", elapsed),
		"",
		"Class Counts:"
	}

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
		return result
	end

	recordError("JSONEncode", nil, result, label)

	local fallbackOk, fallback = pcall(function()
		return HttpService:JSONEncode({
			Error = tostring(result),
			Message = label .. " export failed"
		})
	end)

	if fallbackOk then
		return fallback
	end

	return "{}"
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

local function run()
	if not capabilities.writefile then
		warn("GameStructureDump: writefile is unavailable; dump aborted.")
		return
	end

	if not ensureOutputFolder() then
		warn("GameStructureDump: output folder could not be created or verified; dump aborted.")
		return
	end

	local rootId = assignInstanceId(game)
	updateInstanceMeta(game, rootId, nil)

	local root = {
		Id = rootId,
		Name = "game",
		ClassName = "DataModel",
		Path = "game",
		Attributes = getAttributes(game),
		Tags = getTags(game),
		Properties = {
			Name = game.Name,
			PlaceId = game.PlaceId,
			GameId = game.GameId,
			JobId = game.JobId
		},
		Children = {}
	}

	for _, service in ipairs(getSortedChildren(game)) do
		local ok, result = pcall(
			dumpNode,
			service,
			rootId,
			{
				InventorySource = nil,
				ToolState = nil
			}
		)

		if ok and result then
			table.insert(root.Children, result)
		else
			recordError("DumpRootChild", service, result)
			table.insert(root.Children, makeFailedNode(service, rootId, result))
		end
	end

	finalizeIndexes()

	local inventory = buildInventory()
	local instanceIndex = buildInstanceIndex()
	local treeLines = makeTree(root)
	local elapsed = os.clock() - started

	local remotesDocument = {
		Total = totalRemoteCount(),
		RemoteEvents = remoteIndex.RemoteEvents,
		RemoteFunctions = remoteIndex.RemoteFunctions,
		BindableEvents = remoteIndex.BindableEvents,
		BindableFunctions = remoteIndex.BindableFunctions
	}

	local scriptsDocument = {
		Total = totalScriptCount(),
		LocalScripts = scriptIndex.LocalScripts,
		ModuleScripts = scriptIndex.ModuleScripts,
		Scripts = scriptIndex.Scripts
	}

	local meta = {
		Schema = SCHEMA_NAME,
		SchemaVersion = SCHEMA_VERSION,
		GeneratedAtUnix = os.time(),
		Game = {
			Name = game.Name,
			PlaceId = game.PlaceId,
			GameId = game.GameId,
			JobId = game.JobId
		},
		Player = LocalPlayer and {
			Name = LocalPlayer.Name,
			UserId = LocalPlayer.UserId
		} or nil,
		Stats = {
			Instances = nodeCount,
			RegisteredIds = nextInstanceId,
			RemotesAndBindables = totalRemoteCount(),
			Scripts = totalScriptCount(),
			ObjectsWithAttributes = #attributeIndex,
			Tools = #toolRecords,
			Errors = #errors,
			ElapsedSeconds = elapsed
		},
		Capabilities = capabilities
	}

	local encoded = {
		Structure = encodeJSON(root, "structure.json"),
		Instances = encodeJSON(instanceIndex, "instances.json"),
		Remotes = encodeJSON(remotesDocument, "remotes.json"),
		Scripts = encodeJSON(scriptsDocument, "scripts.json"),
		Inventory = encodeJSON(inventory, "inventory.json"),
		Attributes = encodeJSON(attributeIndex, "attributes.json"),
		Tools = encodeJSON(toolRecords, "tools.json")
	}

	writeSafe(TREE_FILE, table.concat(treeLines, "\n"))
	writeSafe(STRUCTURE_FILE, encoded.Structure)
	writeSafe(INSTANCES_FILE, encoded.Instances)
	writeSafe(REMOTES_FILE, encoded.Remotes)
	writeSafe(SCRIPTS_FILE, encoded.Scripts)
	writeSafe(INVENTORY_FILE, encoded.Inventory)
	writeSafe(ATTRIBUTES_FILE, encoded.Attributes)
	writeSafe(TOOLS_FILE, encoded.Tools)

	meta.Stats.Errors = #errors
	writeSafe(SUMMARY_FILE, buildSummary(elapsed))
	writeSafe(META_FILE, encodeJSON(meta, "meta.json"))

	local errorJSON = encodeJSON(errors, "errors.json")
	writeSafe(ERRORS_FILE, errorJSON)

	print("dump finished")
	print("Instances:", nodeCount)
	print("Registered IDs:", nextInstanceId)
	print("Remotes / Bindables:", totalRemoteCount())
	print("Scripts:", totalScriptCount())
	print("Attributes:", #attributeIndex)
	print("Tools:", #toolRecords)
	print("Errors:", #errors)
	print("Time:", string.format("%.2fs", elapsed))
	print("Folder:", OUTPUT_FOLDER)
end

run()
