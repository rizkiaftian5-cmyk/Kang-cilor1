-- Mountain Auto Play - Roblox Studio LocalScript
-- Features: Pathfinding, 23 checkpoints, 10s checkpoint delay,
-- Repeat, Pause/Resume, Stop, anti-stuck, repath, Next/Previous, TP Current.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

local CHECKPOINTS = {
 {name="awal",position=Vector3.new(-3416,1818,-1918)},
 {name="2",position=Vector3.new(-1,7,88)},
 {name="3",position=Vector3.new(-132,99,-1372)},
 {name="4",position=Vector3.new(512,114,-1829)},
 {name="5",position=Vector3.new(1149,18,-1812)},
 {name="6",position=Vector3.new(2167,16,-2175)},
 {name="8",position=Vector3.new(2209,351,-2468)},
 {name="9",position=Vector3.new(1967,385,-3491)},
 {name="10",position=Vector3.new(1144,457,-3772)},
 {name="11",position=Vector3.new(424,409,-3563)},
 {name="12",position=Vector3.new(-182,429,-3762)},
 {name="13",position=Vector3.new(-882,434,-4189)},
 {name="14",position=Vector3.new(-1484,678,-3849)},
 {name="15",position=Vector3.new(-1678,1110,-3889)},
 {name="16",position=Vector3.new(-2464,930,-4505)},
 {name="17",position=Vector3.new(-3079,930,-5134)},
 {name="18",position=Vector3.new(-3861,963,-5664)},
 {name="19",position=Vector3.new(-4120,998,-4842)},
 {name="20",position=Vector3.new(-4236,1239,-3873)},
 {name="21",position=Vector3.new(-3764,1374,-3347)},
 {name="22",position=Vector3.new(-3751,1674,-3103)},
 {name="23",position=Vector3.new(-3723,1725,-2438)},
}

local CONFIG = {
 Repeat=false, CheckpointDelay=10, AgentRadius=2, AgentHeight=5,
 AgentCanJump=true, AgentCanClimb=true, WaypointSpacing=3,
 ReachDistance=5, RepathDelay=0.2, MaxRetries=5,
 MinMoveTimeout=5, MaxMoveTimeout=20, StuckTimeout=2.5,
}

local Character,Humanoid,RootPart
local running,paused=false,false
local currentIndex=1
local runId=0

local function setupCharacter(c)
 Character=c
 Humanoid=c:WaitForChild("Humanoid")
 RootPart=c:WaitForChild("HumanoidRootPart")
end
if Player.Character then setupCharacter(Player.Character) end
Player.CharacterAdded:Connect(setupCharacter)

local function getRoot()
 if not Character or not Character.Parent or not Humanoid or Humanoid.Health<=0 then return nil end
 if not RootPart or not RootPart.Parent then RootPart=Character:FindFirstChild("HumanoidRootPart") end
 return RootPart
end

local Gui=Instance.new("ScreenGui")
Gui.Name="MountainWaypointAutoPlay"
Gui.ResetOnSpawn=false
Gui.Parent=Player:WaitForChild("PlayerGui")

local Main=Instance.new("Frame")
Main.Size=UDim2.fromOffset(390,520)
Main.Position=UDim2.new(0.5,-195,0.5,-260)
Main.BackgroundColor3=Color3.fromRGB(24,24,30)
Main.BorderSizePixel=0
Main.Parent=Gui
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,12)

local Stroke=Instance.new("UIStroke",Main)
Stroke.Color=Color3.fromRGB(90,90,105)
Stroke.Thickness=1

local TitleBar=Instance.new("Frame",Main)
TitleBar.Size=UDim2.new(1,0,0,45)
TitleBar.BackgroundTransparency=1

local Title=Instance.new("TextLabel",TitleBar)
Title.Size=UDim2.new(1,-20,1,0)
Title.Position=UDim2.fromOffset(10,0)
Title.BackgroundTransparency=1
Title.Text="MOUNTAIN AUTO PLAY"
Title.TextColor3=Color3.fromRGB(255,255,255)
Title.Font=Enum.Font.GothamBold
Title.TextSize=18
Title.TextXAlignment=Enum.TextXAlignment.Left

local dragging=false
local dragStart,startPosition
TitleBar.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  dragging=true;dragStart=input.Position;startPosition=Main.Position
 end
end)
TitleBar.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
UserInputService.InputChanged:Connect(function(input)
 if not dragging then return end
 if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
 local d=input.Position-dragStart
 Main.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,startPosition.Y.Scale,startPosition.Y.Offset+d.Y)
end)

local Status=Instance.new("TextLabel",Main)
Status.Size=UDim2.new(1,-20,0,28)
Status.Position=UDim2.fromOffset(10,45)
Status.BackgroundTransparency=1
Status.Text="Status: Ready"
Status.TextColor3=Color3.fromRGB(180,180,190)
Status.Font=Enum.Font.Gotham
Status.TextSize=13
Status.TextXAlignment=Enum.TextXAlignment.Left
local function setStatus(t) Status.Text="Status: "..t end

local Current=Instance.new("TextLabel",Main)
Current.Size=UDim2.new(1,-20,0,25)
Current.Position=UDim2.fromOffset(10,72)
Current.BackgroundTransparency=1
Current.TextColor3=Color3.fromRGB(120,210,255)
Current.Font=Enum.Font.GothamBold
Current.TextSize=13
Current.TextXAlignment=Enum.TextXAlignment.Left
local function updateCurrent()
 local c=CHECKPOINTS[currentIndex]
 Current.Text=c and string.format("Checkpoint: %d/%d [%s]",currentIndex,#CHECKPOINTS,c.name) or "Checkpoint: -"
end
Current.Parent=Main

local function makeButton(text,x,y,w,fn)
 local b=Instance.new("TextButton",Main)
 b.Size=UDim2.fromOffset(w,36);b.Position=UDim2.fromOffset(x,y)
 b.BackgroundColor3=Color3.fromRGB(45,45,55);b.BorderSizePixel=0
 b.Text=text;b.TextColor3=Color3.fromRGB(255,255,255)
 b.Font=Enum.Font.GothamBold;b.TextSize=12
 Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
 b.MouseButton1Click:Connect(fn)
 return b
end

local List=Instance.new("ScrollingFrame",Main)
List.Size=UDim2.new(1,-20,0,190)
List.Position=UDim2.fromOffset(10,103)
List.BackgroundColor3=Color3.fromRGB(17,17,22)
List.BorderSizePixel=0;List.ScrollBarThickness=4
Instance.new("UICorner",List).CornerRadius=UDim.new(0,8)
local Layout=Instance.new("UIListLayout",List)
Layout.Padding=UDim.new(0,4);Layout.SortOrder=Enum.SortOrder.LayoutOrder
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
 List.CanvasSize=UDim2.fromOffset(0,Layout.AbsoluteContentSize.Y+8)
end)

local function refreshList()
 for _,child in ipairs(List:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
 for index,c in ipairs(CHECKPOINTS) do
  local row=Instance.new("Frame",List)
  row.Size=UDim2.new(1,-8,0,40);row.BackgroundColor3=Color3.fromRGB(32,32,40)
  row.BorderSizePixel=0;row.LayoutOrder=index
  Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)
  local label=Instance.new("TextLabel",row)
  label.Size=UDim2.new(1,-65,1,0);label.Position=UDim2.fromOffset(8,0)
  label.BackgroundTransparency=1;label.Text=string.format("%02d  %s",index,c.name)
  label.TextColor3=Color3.fromRGB(235,235,240);label.Font=Enum.Font.Gotham
  label.TextSize=12;label.TextXAlignment=Enum.TextXAlignment.Left
  local tp=Instance.new("TextButton",row)
  tp.Size=UDim2.fromOffset(45,28);tp.Position=UDim2.new(1,-52,0.5,-14)
  tp.Text="TP";tp.Font=Enum.Font.GothamBold;tp.TextSize=10
  tp.TextColor3=Color3.fromRGB(255,255,255);tp.BackgroundColor3=Color3.fromRGB(55,95,165)
  Instance.new("UICorner",tp).CornerRadius=UDim.new(0,5)
  tp.MouseButton1Click:Connect(function()
   local root=getRoot()
   if not root then setStatus("Character belum siap");return end
   root.CFrame=CFrame.new(c.position+Vector3.new(0,3,0))
   currentIndex=index;updateCurrent();setStatus("TP: "..c.name)
  end)
 end
end
refreshList()

local function calculatePath(destination)
 local root=getRoot()
 if not root then return nil end
 local path=PathfindingService:CreatePath({
  AgentRadius=CONFIG.AgentRadius,AgentHeight=CONFIG.AgentHeight,
  AgentCanJump=CONFIG.AgentCanJump,AgentCanClimb=CONFIG.AgentCanClimb,
  WaypointSpacing=CONFIG.WaypointSpacing,
 })
 local ok=pcall(function() path:ComputeAsync(root.Position,destination) end)
 if not ok or path.Status~=Enum.PathStatus.Success then return nil end
 return path
end

local function checkpointDelay(c,token)
 local remaining=CONFIG.CheckpointDelay
 while remaining>0 and running and runId==token do
  while paused and running and runId==token do
   setStatus("Paused di "..c.name);task.wait(0.1)
  end
  if not running or runId~=token then return false end
  setStatus(string.format("%s - lanjut %ds",c.name,math.ceil(remaining)))
  task.wait(1);remaining-=1
 end
 return true
end

local function moveToCheckpoint(c,token)
 local retry=0
 while running and runId==token do
  while paused and running and runId==token do
   if Humanoid then Humanoid:Move(Vector3.zero) end
   task.wait(0.1)
  end
  if not running or runId~=token then return false end
  local root=getRoot()
  if not root then task.wait(0.5);continue end
  if (root.Position-c.position).Magnitude<=CONFIG.ReachDistance then return true end

  local path=calculatePath(c.position)
  if not path then
   retry+=1;setStatus(string.format("Path gagal %d/%d: %s",retry,CONFIG.MaxRetries,c.name))
   if retry>=CONFIG.MaxRetries then return false end
   task.wait(1);continue
  end
  retry=0
  local waypoints=path:GetWaypoints()
  if #waypoints==0 then retry+=1;task.wait(0.5);continue end

  local blocked=false;local blockedIndex=math.huge
  local blockedConnection=path.Blocked:Connect(function(index) blocked=true;blockedIndex=index end)
  local pathFailed=false

  for waypointIndex,waypoint in ipairs(waypoints) do
   if not running or runId~=token then pathFailed=true;break end
   while paused and running and runId==token do
    if Humanoid then Humanoid:Move(Vector3.zero) end
    task.wait(0.1)
   end
   if not running or runId~=token then pathFailed=true;break end
   if blocked and blockedIndex<=waypointIndex then pathFailed=true;break end

   local currentRoot=getRoot()
   if not currentRoot then pathFailed=true;break end
   if waypoint.Action==Enum.PathWaypointAction.Jump then Humanoid.Jump=true end
   Humanoid:MoveTo(waypoint.Position)

   local reached=false
   local connection=Humanoid.MoveToFinished:Connect(function(success) if success then reached=true end end)
   local distance=(currentRoot.Position-waypoint.Position).Magnitude
   local speed=math.max(Humanoid.WalkSpeed,8)
   local timeout=math.clamp((distance/speed)*2.5,CONFIG.MinMoveTimeout,CONFIG.MaxMoveTimeout)
   local started=os.clock();local lastPosition=currentRoot.Position;local lastMove=os.clock()

   while not reached and not pathFailed and running and runId==token do
    if paused then break end
    if os.clock()-started>=timeout then pathFailed=true;break end
    if blocked and blockedIndex<=waypointIndex then pathFailed=true;break end
    local r=getRoot()
    if not r then pathFailed=true;break end
    if (r.Position-waypoint.Position).Magnitude<=CONFIG.ReachDistance then reached=true;break end
    local movement=(r.Position-lastPosition).Magnitude
    if movement>0.5 then lastPosition=r.Position;lastMove=os.clock()
    elseif os.clock()-lastMove>=CONFIG.StuckTimeout then pathFailed=true;break end
    task.wait(0.1)
   end
   connection:Disconnect()
   if paused then break end
   if not reached then pathFailed=true;break end
  end

  blockedConnection:Disconnect()
  if not pathFailed then
   local finalRoot=getRoot()
   if finalRoot and (finalRoot.Position-c.position).Magnitude<=CONFIG.ReachDistance then return true end
  end

  retry+=1;setStatus(string.format("Repath %d/%d: %s",retry,CONFIG.MaxRetries,c.name))
  if retry>=CONFIG.MaxRetries then return false end
  task.wait(CONFIG.RepathDelay)
 end
 return false
end

local function stop()
 running=false;paused=false;runId+=1
 if Humanoid then Humanoid:Move(Vector3.zero) end
 setStatus("Stopped")
end

local function start()
 if running then setStatus("Sudah berjalan");return end
 running=true;paused=false;runId+=1
 local token=runId
 task.spawn(function()
  while running and runId==token do
   if currentIndex>#CHECKPOINTS then
    if CONFIG.Repeat then
     currentIndex=1;updateCurrent();setStatus("Repeat: kembali ke awal");task.wait(0.5)
    else
     running=false;setStatus("Semua checkpoint selesai");break
    end
   end
   local c=CHECKPOINTS[currentIndex]
   updateCurrent();setStatus("Menuju "..c.name)
   local reached=moveToCheckpoint(c,token)
   if not running or runId~=token then break end
   if reached then
    setStatus("Sampai "..c.name)
    if not checkpointDelay(c,token) then break end
    currentIndex+=1
   else
    setStatus("Gagal: "..c.name)
    if not CONFIG.Repeat then stop();break end
    task.wait(1)
   end
  end
 end)
end

local repeatButton
makeButton("START",10,305,85,start)
makeButton("PAUSE",100,305,85,function()
 if running then paused=true;if Humanoid then Humanoid:Move(Vector3.zero) end;setStatus("Paused") end
end)
makeButton("RESUME",190,305,85,function()
 if running then paused=false;setStatus("Resumed") end
end)
makeButton("STOP",280,305,90,stop)
repeatButton=makeButton("REPEAT: OFF",10,350,175,function()
 CONFIG.Repeat=not CONFIG.Repeat
 repeatButton.Text=CONFIG.Repeat and "REPEAT: ON" or "REPEAT: OFF"
 repeatButton.BackgroundColor3=CONFIG.Repeat and Color3.fromRGB(45,130,80) or Color3.fromRGB(45,45,55)
end)
makeButton("START FROM AWAL",195,350,175,function()
 currentIndex=1;updateCurrent();if not running then start() end
end)
makeButton("NEXT",10,395,85,function()
 if currentIndex<#CHECKPOINTS then currentIndex+=1;updateCurrent();setStatus("Next: "..CHECKPOINTS[currentIndex].name) end
end)
makeButton("PREVIOUS",100,395,85,function()
 if currentIndex>1 then currentIndex-=1;updateCurrent();setStatus("Previous: "..CHECKPOINTS[currentIndex].name) end
end)
makeButton("TP CURRENT",190,395,85,function()
 local c=CHECKPOINTS[currentIndex];local root=getRoot()
 if root and c then root.CFrame=CFrame.new(c.position+Vector3.new(0,3,0));updateCurrent();setStatus("TP: "..c.name) end
end)
makeButton("HIDE",280,395,90,function() Main.Visible=false end)

UserInputService.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.KeyCode==Enum.KeyCode.F6 then Main.Visible=not Main.Visible
 elseif input.KeyCode==Enum.KeyCode.F7 then
  if running then
   paused=not paused
   if paused and Humanoid then Humanoid:Move(Vector3.zero) end
   setStatus(paused and "Paused" or "Resumed")
  end
 elseif input.KeyCode==Enum.KeyCode.F8 then stop() end
end)

updateCurrent()
setStatus("Ready - "..#CHECKPOINTS.." checkpoint")
print("[Mountain Auto Play] Loaded "..#CHECKPOINTS.." checkpoints")
