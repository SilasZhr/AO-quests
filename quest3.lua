-- A BOT TO AUTO-PLAYING GAME BASED ON AMOUNT YOU HAVE SET (DEFAULT IS 2)

-- Number of rounds to play automatically
NumAutoPlay  = NumAutoPlay or 2
CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
BlackJack = "Vo7O7WJ2OPlKBtudjfeOdzjcjpi_-V_RLE27VpZP8jA"

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

-- A table of basic strategy
local basic_strategy = {
  [21] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [20] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [19] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [18] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [17] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [16] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [15] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [14] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [13] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [12] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [11] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [10] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [9] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [8] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [7] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [6] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [5] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [4] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [3] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [2] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"}
}

-- get the point of a card
local function pointOfCard(card)
  local point
  if (card == "J" or card == "Q" or card == "K") then
    point = 10
  elseif card == "A" then
    point = 11
  else
    point = tonumber(card)
  end

  return point
end

-- extract the card from game response message
local function extractCards(input_str)
  local chars = {}
  for char in input_str:gmatch("%d+%s*of") do
    table.insert(chars, char:sub(1, char:find("%s") - 1))
  end
  for char in input_str:gmatch("%a%s*of") do
    table.insert(chars, char:sub(1, 1))
  end
  return chars
end

-- get the best decision based on a table of basic strategy
local function getBestDecision(player_hand_value, dealer_upcard_value)
  if not basic_strategy[player_hand_value] then
    return "S"
  end

  local decision = basic_strategy[player_hand_value][dealer_upcard_value] or "S"
  return decision
end

-- decide to the next action
local function decideNextAction(str)
  local strPlayer
  local strDealer
  local index = string.find(str, "And the dealer is showing")

  if index ~= nil then -- in a game round
    strPlayer = string.sub(str, 1, index - 2)
    strDealer = string.sub(str, index)
  else                 -- game over
    if NumAutoPlay > 1 then
      index = string.find(str, "You have no active game")
      if index == nil then
        ao.send({ Target = ao.id, Action = "AutoPay" })
      end
    end
    return
  end

  -- Calc the value of player hand
  local points = 0
  local amtOfA = 0
  local result = extractCards(strPlayer)

  for i = 1, #result do
    if result[i] == "A" then
      amtOfA = amtOfA + 1
      if amtOfA > 1 then
        points = points + 1
      else
        points = points + 11
      end
    else
      points = points + pointOfCard(result[i])
    end
  end

  print('Your points: ' .. points)

  -- Calc the value of dealer upcard
  result = extractCards(strDealer)
  local dealerUpCard = pointOfCard(result[1])

  -- if points > 16 then -- this is a simple playing strategy
  -- this is a playing strategy from a table of basic strategy
  local decision = getBestDecision(points, dealerUpCard)

  if decision == "H" then
    print(colors.red .. 'Hit!' .. colors.reset)
    ao.send({ Target = BlackJack, Action = "Hit" })
  else
    print(colors.red .. 'Stay!' .. colors.reset)
    ao.send({ Target = BlackJack, Action = "Stay" })
  end
end

-- Handler to process the message from the game and decide the next action
Handlers.add(
  "BlackJackReader",
  Handlers.utils.hasMatchingTag("Action", "BlackJackMessage"),
  function(msg)
    print(msg.Data)
    decideNextAction(msg.Data)
  end
)

-- Handler to automate payment when a round end.
Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function(msg)
    if msg.From == ao.id then
      NumAutoPlay = NumAutoPlay - 1
      print(colors.red .. "Auto-paying confirmation fees." .. colors.reset)
      ao.send({ Target = CRED, Action = "Transfer", Recipient = BlackJack, Quantity = "1000" })
    end
  end
)

-- Handler to set the number of automate playing
Handlers.add(
  "SetAutoPlay",
  Handlers.utils.hasMatchingTag("Action", "SetAutoPlay"),
  function(msg)
    if msg.From == ao.id then
      print("You set the amount of auto-playing: " .. msg.Tags.Amount)
      NumAutoPlay = tonumber(msg.Tags.Amount)
    end
  end
)

-- Debug: Handler for testing
-- Handlers.add("testAutoNextAction", Handlers.utils.hasMatchingTag("Action", "TestAutoNextAction"), decideNextAction)
