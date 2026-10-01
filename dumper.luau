local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local OUTPUT_FOLDER = "GameStructureDump"

local TREE_FILE = OUTPUT_FOLDER .. "/structure.txt"
local JSON_FILE = OUTPUT_FOLDER .. "/structure.json"
local REMOTES_FILE = OUTPUT_FOLDER .. "/remotes.txt"
local SCRIPTS_FILE = OUTPUT_FOLDER .. "/scripts.txt"
local SUMMARY_FILE = OUTPUT_FOLDER .. "/summary.txt"

local INVENTORY_FILE = OUTPUT_FOLDER .. "/inventory.json"
local ATTRIBUTES_FILE = OUTPUT_FOLDER .. "/attributes.json"
local TOOLS_FILE = OUTPUT_FOLDER .. "/tools.json"

local YIELD_EVERY = 250

if makefolder and not isfolder(OUTPUT_FOLDER) then
	makefolder(OUTPUT_FOLDER)
end

local nodeCount = 0

local classCounts = {}
local remoteLines = {}
local scriptLines = {}

local attributeIndex = {}

local function safeGet(object, property)
	local ok, value = pcall(function()
		return object[property]
	end)

	if ok then
		return value
	end

	return nil
end

local function safeFullName(object)
	local ok, result = pcall(function()
		return object:GetFullName()
	end)

	if ok then
		return result
	end

	return object.Name
end

local function serializeValue(value)
	if value == nil then
		return nil
	end

	local valueType = typeof(value)

	if valueType == "string"
		or valueType == "number"
		or valueType == "boolean" then

		return value
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
			components = {
				value:GetComponents()
			}
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
		return tostring(value)
	end

	if valueType == "Instance" then
		return {
			__type = "Instance",
			name = value.Name,
			path = safeFullName(value),
			className = value.ClassName
		}
	end

	if valueType == "table" then
		local output = {}

		for key, item in pairs(value) do
			output[tostring(key)] = serializeValue(item)
		end

		return output
	end

	return tostring(value)
end

local function getAttributes(object)
	local ok, attributes = pcall(function()
		return object:GetAttributes()
	end)

	if not ok then
		return {}
	end

	local output = {}

	for name, value in pairs(attributes) do
		output[name] = serializeValue(value)
	end

	return output
end

local function getTags(object)
	local ok, tags = pcall(function()
		return CollectionService:GetTags(object)
	end)

	if ok then
		return tags
	end

	return {}
end

local function getUsefulProperties(object)
	local data = {}
	local className = object.ClassName

	if object:IsA("ValueBase") then
		data.Value = serializeValue(
			safeGet(object, "Value")
		)
	end

	if object:IsA("ObjectValue") then
		data.Value = serializeValue(
			safeGet(object, "Value")
		)
	end

	if object:IsA("BasePart") then
		data.Position = serializeValue(
			safeGet(object, "Position")
		)

		data.Size = serializeValue(
			safeGet(object, "Size")
		)

		data.CFrame = serializeValue(
			safeGet(object, "CFrame")
		)

		data.Anchored = safeGet(
			object,
			"Anchored"
		)

		data.CanCollide = safeGet(
			object,
			"CanCollide"
		)

		data.CanTouch = safeGet(
			object,
			"CanTouch"
		)

		data.CanQuery = safeGet(
			object,
			"CanQuery"
		)

		data.Transparency = safeGet(
			object,
			"Transparency"
		)

		data.Material = serializeValue(
			safeGet(object, "Material")
		)

		data.Color = serializeValue(
			safeGet(object, "Color")
		)
	end

	if className == "Animation" then
		data.AnimationId = safeGet(
			object,
			"AnimationId"
		)
	end

	if object:IsA("Sound") then
		data.SoundId = safeGet(
			object,
			"SoundId"
		)

		data.Volume = safeGet(
			object,
			"Volume"
		)

		data.Looped = safeGet(
			object,
			"Looped"
		)

		data.PlaybackSpeed = safeGet(
			object,
			"PlaybackSpeed"
		)
	end

	if object:IsA("Decal")
		or object:IsA("Texture") then

		data.Texture = safeGet(
			object,
			"Texture"
		)

		data.Transparency = safeGet(
			object,
			"Transparency"
		)
	end

	if object:IsA("MeshPart") then
		data.MeshId = safeGet(
			object,
			"MeshId"
		)

		data.TextureID = safeGet(
			object,
			"TextureID"
		)
	end

	if object:IsA("SpecialMesh") then
		data.MeshId = safeGet(
			object,
			"MeshId"
		)

		data.TextureId = safeGet(
			object,
			"TextureId"
		)

		data.MeshType = serializeValue(
			safeGet(object, "MeshType")
		)

		data.Scale = serializeValue(
			safeGet(object, "Scale")
		)
	end

	if object:IsA("Humanoid") then
		data.Health = safeGet(
			object,
			"Health"
		)

		data.MaxHealth = safeGet(
			object,
			"MaxHealth"
		)

		data.WalkSpeed = safeGet(
			object,
			"WalkSpeed"
		)

		data.JumpPower = safeGet(
			object,
			"JumpPower"
		)

		data.RigType = serializeValue(
			safeGet(object, "RigType")
		)
	end

	if object:IsA("Tool") then
		data.ToolTip = safeGet(
			object,
			"ToolTip"
		)

		data.CanBeDropped = safeGet(
			object,
			"CanBeDropped"
		)

		data.RequiresHandle = safeGet(
			object,
			"RequiresHandle"
		)

		data.Enabled = safeGet(
			object,
			"Enabled"
		)

		data.Grip = serializeValue(
			safeGet(object, "Grip")
		)

		data.TextureId = safeGet(
			object,
			"TextureId"
		)
	end

	if object:IsA("RemoteEvent") then
		data.RemoteType = "RemoteEvent"
	end

	if object:IsA("RemoteFunction") then
		data.RemoteType = "RemoteFunction"
	end

	if object:IsA("BindableEvent") then
		data.RemoteType = "BindableEvent"
	end

	if object:IsA("BindableFunction") then
		data.RemoteType = "BindableFunction"
	end

	if object:IsA("LocalScript")
		or object:IsA("ModuleScript")
		or object:IsA("Script") then

		data.ScriptType = className
		data.Disabled = safeGet(
			object,
			"Disabled"
		)
	end

	if object:IsA("ProximityPrompt") then
		data.ActionText = safeGet(
			object,
			"ActionText"
		)

		data.ObjectText = safeGet(
			object,
			"ObjectText"
		)

		data.HoldDuration = safeGet(
			object,
			"HoldDuration"
		)

		data.MaxActivationDistance = safeGet(
			object,
			"MaxActivationDistance"
		)

		data.KeyboardKeyCode = serializeValue(
			safeGet(object, "KeyboardKeyCode")
		)
	end

	return data
end

local function registerAttributes(object, attributes)
	if next(attributes) == nil then
		return
	end

	table.insert(attributeIndex, {
		Name = object.Name,
		ClassName = object.ClassName,
		Path = safeFullName(object),
		Attributes = attributes
	})
end

local function dumpNode(object)
	nodeCount += 1

	if nodeCount % YIELD_EVERY == 0 then
		task.wait()
	end

	classCounts[object.ClassName] =
		(classCounts[object.ClassName] or 0) + 1

	local path = safeFullName(object)
	local attributes = getAttributes(object)

	registerAttributes(
		object,
		attributes
	)

	if object:IsA("RemoteEvent")
		or object:IsA("RemoteFunction") then

		table.insert(
			remoteLines,
			string.format(
				"[%s] %s",
				object.ClassName,
				path
			)
		)
	end

	if object:IsA("LocalScript")
		or object:IsA("ModuleScript")
		or object:IsA("Script") then

		table.insert(
			scriptLines,
			string.format(
				"[%s] %s",
				object.ClassName,
				path
			)
		)
	end

	local node = {
		Name = object.Name,
		ClassName = object.ClassName,
		Path = path,
		Attributes = attributes,
		Tags = getTags(object),
		Properties = getUsefulProperties(object),
		Children = {}
	}

	local ok, children = pcall(function()
		return object:GetChildren()
	end)

	if ok then
		for _, child in ipairs(children) do
			local success, childData =
				pcall(dumpNode, child)

			if success and childData then
				table.insert(
					node.Children,
					childData
				)
			end
		end
	end

	return node
end

local function dumpInventoryNode(object)
	local node = {
		Name = object.Name,
		ClassName = object.ClassName,
		Path = safeFullName(object),

		Attributes = getAttributes(object),
		Tags = getTags(object),

		Properties = getUsefulProperties(object),

		Children = {}
	}

	local ok, children = pcall(function()
		return object:GetChildren()
	end)

	if ok then
		for _, child in ipairs(children) do
			local success, childData =
				pcall(dumpInventoryNode, child)

			if success and childData then
				table.insert(
					node.Children,
					childData
				)
			end
		end
	end

	return node
end

local function dumpInventory()
	local inventory = {
		Player = {
			Name = LocalPlayer and LocalPlayer.Name or nil,
			UserId = LocalPlayer and LocalPlayer.UserId or nil
		},

		Backpack = nil,
		Character = nil,
		StarterGear = nil
	}

	if not LocalPlayer then
		return inventory
	end

	local backpack =
		LocalPlayer:FindFirstChildOfClass("Backpack")

	if backpack then
		inventory.Backpack =
			dumpInventoryNode(backpack)
	end

	local character =
		LocalPlayer.Character

	if character then
		inventory.Character =
			dumpInventoryNode(character)
	end

	local starterGear =
		LocalPlayer:FindFirstChild("StarterGear")

	if starterGear then
		inventory.StarterGear =
			dumpInventoryNode(starterGear)
	end

	return inventory
end

local function dumpHandle(handle)
	if not handle then
		return nil
	end

	return {
		Name = handle.Name,
		ClassName = handle.ClassName,
		Path = safeFullName(handle),

		Attributes = getAttributes(handle),

		Properties = getUsefulProperties(handle),

		Children = (function()
			local list = {}

			for _, descendant in ipairs(
				handle:GetDescendants()
			) do

				table.insert(list, {
					Name = descendant.Name,
					ClassName = descendant.ClassName,
					Path = safeFullName(descendant),

					Attributes =
						getAttributes(descendant),

					Properties =
						getUsefulProperties(descendant)
				})
			end

			return list
		end)()
	}
end

local function dumpTool(tool, source)
	local animations = {}
	local sounds = {}
	local values = {}
	local descendants = {}

	for _, object in ipairs(tool:GetDescendants()) do
		local entry = {
			Name = object.Name,
			ClassName = object.ClassName,
			Path = safeFullName(object),
			Attributes = getAttributes(object),
			Properties = getUsefulProperties(object)
		}

		table.insert(
			descendants,
			entry
		)

		if object:IsA("Animation") then
			table.insert(
				animations,
				{
					Name = object.Name,
					Path = safeFullName(object),
					AnimationId = safeGet(
						object,
						"AnimationId"
					),
					Attributes =
						getAttributes(object)
				}
			)
		end

		if object:IsA("Sound") then
			table.insert(
				sounds,
				{
					Name = object.Name,
					Path = safeFullName(object),

					SoundId = safeGet(
						object,
						"SoundId"
					),

					Volume = safeGet(
						object,
						"Volume"
					),

					PlaybackSpeed = safeGet(
						object,
						"PlaybackSpeed"
					),

					Looped = safeGet(
						object,
						"Looped"
					),

					Attributes =
						getAttributes(object)
				}
			)
		end

		if object:IsA("ValueBase") then
			table.insert(
				values,
				{
					Name = object.Name,
					ClassName = object.ClassName,
					Path = safeFullName(object),

					Value = serializeValue(
						safeGet(
							object,
							"Value"
						)
					),

					Attributes =
						getAttributes(object)
				}
			)
		end
	end

	local handle =
		tool:FindFirstChild("Handle")

	return {
		Name = tool.Name,
		ClassName = tool.ClassName,

		Path = safeFullName(tool),

		Source = source,

		Attributes = getAttributes(tool),

		Properties = getUsefulProperties(tool),

		Handle = dumpHandle(handle),

		Animations = animations,
		Sounds = sounds,
		Values = values,

		DescendantCount =
			#tool:GetDescendants(),

		Descendants = descendants
	}
end

local function dumpTools()
	local tools = {}
	local seen = {}

	if not LocalPlayer then
		return tools
	end

	local function scan(container, source)
		if not container then
			return
		end

		for _, object in ipairs(
			container:GetDescendants()
		) do

			if object:IsA("Tool")
				and not seen[object] then

				seen[object] = true

				local ok, result =
					pcall(
						dumpTool,
						object,
						source
					)

				if ok and result then
					table.insert(
						tools,
						result
					)
				end
			end
		end
	end

	local backpack =
		LocalPlayer:FindFirstChildOfClass("Backpack")

	local character =
		LocalPlayer.Character

	local starterGear =
		LocalPlayer:FindFirstChild("StarterGear")

	scan(
		backpack,
		"Backpack"
	)

	scan(
		character,
		"Character"
	)

	scan(
		starterGear,
		"StarterGear"
	)

	table.sort(
		tools,
		function(a, b)
			return a.Name:lower()
				< b.Name:lower()
		end
	)

	return tools
end

local function makeTree(node, depth, output)
	depth = depth or 0
	output = output or {}

	local prefix =
		string.rep(
			"    ",
			depth
		)

	table.insert(
		output,
		string.format(
			"%s%s [%s]",
			prefix,
			node.Name,
			node.ClassName
		)
	)

	for _, child in ipairs(node.Children) do
		makeTree(
			child,
			depth + 1,
			output
		)
	end

	return output
end

local function buildSummary()
	local list = {}

	for className, count in pairs(classCounts) do
		table.insert(
			list,
			{
				ClassName = className,
				Count = count
			}
		)
	end

	table.sort(
		list,
		function(a, b)
			return a.Count > b.Count
		end
	)

	local lines = {
		"Game: " .. tostring(game.Name),
		"PlaceId: " .. tostring(game.PlaceId),
		"GameId: " .. tostring(game.GameId),
		"JobId: " .. tostring(game.JobId),
		"Total Instances: " .. tostring(nodeCount),
		"Objects With Attributes: " .. tostring(#attributeIndex),
		"",
		"Class Counts:"
	}

	for _, entry in ipairs(list) do
		table.insert(
			lines,
			string.format(
				"%s: %d",
				entry.ClassName,
				entry.Count
			)
		)
	end

	return table.concat(
		lines,
		"\n"
	)
end

local function encodeJSON(data, fallbackMessage)
	local ok, result =
		pcall(function()
			return HttpService:JSONEncode(data)
		end)

	if ok then
		return result
	end

	return HttpService:JSONEncode({
		Error = tostring(result),
		Message = fallbackMessage
	})
end

local started = os.clock()

local root = {
	Name = "game",
	ClassName = "DataModel",
	Path = "game",

	Attributes = {},
	Tags = {},

	Properties = {
		Name = game.Name,
		PlaceId = game.PlaceId,
		GameId = game.GameId,
		JobId = game.JobId
	},

	Children = {}
}

for _, service in ipairs(game:GetChildren()) do
	local ok, result =
		pcall(
			dumpNode,
			service
		)

	if ok and result then
		table.insert(
			root.Children,
			result
		)
	end
end

local inventory =
	dumpInventory()

local tools =
	dumpTools()

local treeLines =
	makeTree(root)

table.sort(remoteLines)
table.sort(scriptLines)

table.sort(
	attributeIndex,
	function(a, b)
		return a.Path < b.Path
	end
)

local structureJSON =
	encodeJSON(
		root,
		"Full structure JSON export failed"
	)

local inventoryJSON =
	encodeJSON(
		inventory,
		"Inventory JSON export failed"
	)

local attributesJSON =
	encodeJSON(
		attributeIndex,
		"Attributes JSON export failed"
	)

local toolsJSON =
	encodeJSON(
		tools,
		"Tools JSON export failed"
	)

if writefile then
	writefile(
		TREE_FILE,
		table.concat(
			treeLines,
			"\n"
		)
	)

	writefile(
		JSON_FILE,
		structureJSON
	)

	writefile(
		REMOTES_FILE,
		table.concat(
			remoteLines,
			"\n"
		)
	)

	writefile(
		SCRIPTS_FILE,
		table.concat(
			scriptLines,
			"\n"
		)
	)

	writefile(
		SUMMARY_FILE,
		buildSummary()
	)

	writefile(
		INVENTORY_FILE,
		inventoryJSON
	)

	writefile(
		ATTRIBUTES_FILE,
		attributesJSON
	)

	writefile(
		TOOLS_FILE,
		toolsJSON
	)
end

local elapsed =
	os.clock() - started

print("dump finished")
print("Instances:", nodeCount)
print("Remotes:", #remoteLines)
print("Scripts:", #scriptLines)
print("Attributes:", #attributeIndex)
print("Tools:", #tools)

print(
	"Time:",
	string.format(
		"%.2fs",
		elapsed
	)
)

print(
	"Folder:",
	OUTPUT_FOLDER
)
