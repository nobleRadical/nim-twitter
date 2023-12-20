--twitter v0.9
--by nobleRadical

--colorPrint - a utility function that should be
-- part of the standard library. (nobleRadical)
function colorPrint(text, color)
local oldColor = term.getTextColor()
term.setTextColor(color)
print(text)
term.setTextColor(oldColor)
end


-- Connect to the internet.
peripheral.find("modem", rednet.open)

--for logging in a new user.
function verifyUser()
local man = peripheral.find("manipulator")
if man == nil then return nil end
local name = man.getName()
return name
end

-- Load twitter log, or an empty log.
function load()
local twitterLog = nil
local fileHnd = fs.open(".twitterlog", "r")
if fileHnd ~= nil then
twitterLog = textutils.unserialise(fileHnd.readAll())
fileHnd.close()
else
twitterLog = {["version"] = 0, ["posts"] = {}}
end
return twitterLog
end
-- save twitter log.
function save(twitterLog)
local fileHnd = fs.open(".twitterlog", "w")
fileHnd.write(textutils.serialise(twitterLog, { compact = true }))
fileHnd.close()
end

twitterLog = load()
--update the twitterlog against the network.
function updateTwitterLog()
local tempLog = network_GET()
if tempLog.version > twitterLog.version then
twitterLog = tempLog
save(twitterLog)
end

end
updateTwitterLog()

-- log file structure:
-- log.version :: number
-- log.posts :: array[posts]
--     post :: table
--     post.author :: string
--     post.contents :: string


--utility function
function addPost(log, post)
table.insert(log.posts, post)
log.version = log.version + 1
end
--utility function
function getLatestPost(log)
local pst = table.remove(log.posts)
if pst ~= nil then
table.insert(log.posts, pst)
return pst.author, pst.contents
else
return "None", "Nobody's posted yet. Change that!"
end
end


--coroutine of the main loop
--manages GET and POST requests from other computers
function recv_handler()
while true do
    local id, message = rednet.receive("twitter")
    if message.type == "GET" then
        rednet.send(id, twitterLog, "twitter")
    elseif message.type == "POST" then
        if twitterLog.version <= message.payload.version then
        twitterLog = message.payload
         save(twitterLog)
        end
    end
end
end
--Send a POST request.
function network_POST(log)
rednet.broadcast({ type="POST", payload=log}, "twitter")
end
--Send a GET request.
function network_GET()
rednet.broadcast({ type="GET" }, "twitter")
local messages = {}
while true do
local id, message = rednet.receive("twitter", 1)
if id == nil then break end
table.insert(messages, message)
end
table.sort(messages, function(one, two)
return one.version > two.version end)

return messages[1]
end


--coroutine of the main loop
--manages the UI and user input
function client()    
    --intro babble
    print("Welcome to Twitter!")
    print("latest post:")
    local author, contents = getLatestPost(twitterLog)
    colorPrint(author, colors.lightBlue)
    print(contents)
        
    --command list, backed by later function defs
    local commands = {
    ["new post"] = newpost,
    ["posts by"] = postsby,
    ["more posts"] = listposts,
    ["exit"] = exit,
    }
    --seperate keys vs values of commands
    local commandkeys = {}
    for k, _ in pairs(commands) do
    table.insert(commandkeys, k)
    end
    table.sort(commandkeys)
while true do
    print(" ")
    print(" ")
    colorPrint("Choose an action.", colors.blue)
    local input = read(nil, commandkeys, nil, "use uparrow and downarrow to choose an action.")
    if commands[input] ~= nil then
    
        term.clear()
        term.setCursorPos(1, 1)
        local code, val = pcall(commands[input])
        if not code then
        printError(val)
        sleep(2)
        end
        if val == "exit" then
        break
        end
    
    else
        colorPrint("Invalid command.", colors.red)
        sleep(0.5)
        term.clear()
        term.setCursorPos(1,1)
    end    
    
end
end

--define commands
function newpost()
print("Verify your identity. Place a bound inspection module in the manipulator.")
local currentUser
repeat
write("press any key to scan.\r")
os.pullEvent("key")
currentUser = verifyUser()
if not currentUser then
write("Not found.                \r")
end
until currentUser

print("Access granted. Hello, "..currentUser)
term.clear()
term.setCursorPos(1,1)

print("New Post")
print("Author: @"..currentUser)
print("Message: ")
local input = read()
addPost(twitterLog, { author = currentUser, contents = input})
save(twitterLog)
network_POST(twitterLog)
end
--
function postsby()
print("Not implemented!")
end
--
function listposts()
textutils.pagedPrint(textutils.serialise(twitterLog))
local posts = twitterLog.posts
local maxPointer = table.getn(posts)
local pointer = maxPointer
while true do
term.clear()
term.setCursorPos(1,1)
print("Post "..tostring(pointer).." / "..tostring(maxPointer))
colorPrint(posts[pointer].author, colors.lightBlue)
print(posts[pointer].contents)
print(" ")
print("< or > to navigate. q to exit.")
local _, key = os.pullEvent("key")
if key == keys.left then
pointer = pointer-1
if pointer < 1 then pointer=maxPointer end
elseif key == keys.right then
pointer = pointer+1
if pointer > maxPointer then pointer=1 end
elseif key == keys.q then
break
end

end
end
--
function exit()
colorPrint("Goodbye!", colors.yellow)
sleep(0.5)
term.clear()
term.setCursorPos(1, 1)
return "exit"
end


parallel.waitForAny(recv_handler, client)
