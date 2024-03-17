LatestGameState = LatestGameState or nil
InAction = InAction or false
Logs = Logs or {}

local colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}


local directions = {
  { x = 0,  y = 1,  name = "Up" },
  { x = 0,  y = -1, name = "Down" },
  { x = -1, y = 0,  name = "Left" },
  { x = 1,  y = 0,  name = "Right" },
  { x = 1,  y = 1,  name = "UpRight" },
  { x = -1, y = 1,  name = "UpLeft" },
  { x = 1,  y = -1, name = "DownRight" },
  { x = -1, y = -1, name = "DownLeft" }
}

local function addLog(msg, text)
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

local function inRange(x1, y1, x2, y2, range)
  return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

local function findAvoidDirection()
  local me = LatestGameState.Players[ao.id]
  if not me then
    print("Error: Player with ao.id not found.")
    return "Stay"
  end

  local avoidVector = {x = 0, y = 0}
  local playerCount = 0

  for _, otherPlayer in pairs(LatestGameState.Players) do
    if otherPlayer.id ~= me.id then
      avoidVector.x = avoidVector.x + (me.x - otherPlayer.x)
      avoidVector.y = avoidVector.y + (me.y - otherPlayer.y)
      playerCount = playerCount + 1
    end
  end

  if playerCount == 0 then
    return "Stay"
  end

  avoidVector.x = avoidVector.x / playerCount
  avoidVector.y = avoidVector.y / playerCount
  avoidVector = normalizeDirection(avoidVector)

  local closestDirection = "Stay"
  local highestDot = -math.huge
  for _, dir in ipairs(directions) do
    local dotProduct = avoidVector.x * dir.x + avoidVector.y * dir.y
    if dotProduct > highestDot then
      highestDot = dotProduct
      closestDirection = dir.name
    end
  end

  return closestDirection
end

local function normalizeDirection(direction)
  local length = math.sqrt(direction.x * direction.x + direction.y * direction.y)
  if length == 0 then
    return { x = 0, y = 0 }
  end
  return { x = direction.x / length, y = direction.y / length }
end

local function decideNextAction()
  local me = LatestGameState.Players[ao.id]
  local tooClose = false
  for _, otherPlayer in pairs(LatestGameState.Players) do
    if otherPlayer.id ~= ao.id then
      local distance = math.sqrt((me.x - otherPlayer.x)^2 + (me.y - otherPlayer.y)^2)
      if distance < 2 then
        tooClose = true
        break
      end
    end
  end

  if tooClose then
    print(colors.red .. "Player too close, attacking!" .. colors.reset)
    ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(me.energy) })
  else
    local avoidDirection = findAvoidDirection()
    local energyStatus = "Energy sufficient."
    if me.energy < 50 then
      energyStatus = "Energy low. Prioritizing avoidance."
    end
    print(colors.blue .. energyStatus .. colors.reset)
    ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = avoidDirection })
  end

  InAction = false
end

local Handlers = {}

-- Print announcements and trigger game state updates
Handlers.PrintAnnouncements = function(msg)
  if msg.Event == "Started-Waiting-Period" then
    ao.send({ Target = ao.id, Action = "AutoPay" })
  elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
    InAction = true
    ao.send({ Target = Game, Action = "GetGameState" })
  elseif InAction then
    print("Previous action still in progress. Skipping.")
  end

  print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
end

Handlers.GetGameStateOnTick = function()
  if not InAction then
    InAction = true
    print(colors.gray .. "Getting game state..." .. colors.reset)
    ao.send({ Target = Game, Action = "GetGameState" })
  else
    print("Previous action still in progress. Skipping.")
  end
end

Handlers.AutoPay = function(msg)
  print("Auto-paying confirmation fees.")
  ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
end

Handlers.UpdateGameState = function(msg)
  local json = require("json")
  LatestGameState = json.decode(msg.Data)
  ao.send({ Target = ao.id, Action = "UpdatedGameState" })
  print("Game state updated. Print 'LatestGameState' for detailed view.")
  print("energy:" .. LatestGameState.Players[ao.id].energy)
end

-- Decide the next best action
Handlers.decideNextAction = function()
  if LatestGameState.GameMode ~= "Playing" then
    print("game not start")
    InAction = false
    return
  end
  print("Deciding next action.")
  decideNextAction()
  ao.send({ Target = ao.id, Action = "Tick" })
end

-- Automatically attack when hit by another player
Handlers.ReturnAttack = function(msg)
  if not InAction then
    InAction = true
    local playerEnergy = LatestGameState.Players[ao.id].energy
    if playerEnergy == undefined then
      print(colors.red .. "Unable to read energy." .. colors.reset)
      ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
    elseif playerEnergy == 0 then
      print(colors.red .. "Player has insufficient energy." .. colors.reset)
      ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
    else
      print(colors.red .. "Returning attack." .. colors.reset)
      print(colors.red .. "Player has insufficient energy." .. colors.reset)
      ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
    end
    InAction = false
    ao.send({ Target = ao.id, Action = "Tick" })
  else
    print("Previous action still in progress. Skipping.")
  end
end

-- Add handlers
for name, handler in pairs(Handlers) do
  Handlers.add(name, Handlers.utils.hasMatchingTag("Action", name), handler)
end
