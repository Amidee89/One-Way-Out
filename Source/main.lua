
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/sprites"
import "CoreLibs/crank"
import "CoreLibs/math"
import "CoreLibs/ui"

--setup
local gfx <const> = playdate.graphics
local geometry <const> = playdate.geometry

gfx.setBackgroundColor(gfx.kColorWhite)
playdate.display.setRefreshRate(50)
local crankIndicatorShowing = false

playdate.resetElapsedTime()

-- resetting state
local circles = {}
local startedUp = false
--gameplay
local spaceBetweenCircles = 50

local currentOpeningSize = 20
local circleCenter = geometry.point.new(200,120)
local outerCircle = geometry.arc.new(circleCenter.x, circleCenter.y, 0, 0, 0)

local playerRadius = 10
local playerPosition = geometry.point.new(180,100)
local previousPlayerPosition =  playerPosition:copy()

local playerSpeed = geometry.vector2D.new(20,10)
local playerRotation = 0
local playerSpinSpeed = 0
local distanceFromCenter = 0

local collidedThisFrame = false
local collisionRelocationMagnitude = 0

local minimumInnerRadius = 5

local circleLineWidth = 5
local playerLineWidth = 3

local gravity = 1000
local contactFriction = .8
local bounceElasticity = .8
local airFriction = .9
local terminalVelocity = 400
local terminalSpinning = 400

local currentCrankPosition = 0
local gameSpeed = 40
local baseGameSpeed = 20

function playdate.update()
   if(not startedUp) then
      gameOver()
      startedUp = true
   end
    gfx.clear()
    playdate.drawFPS(0,0)
    playdate.timer.updateTimers()
    collidedThisFrame = ""
    collisionRelocationMagnitude = 0
    previousPlayerPosition = playerPosition:copy()
    checkCommands()
    updateCircles()
    debugMovePlayerWithbuttons()
    checkCrank()
    drawCircles()
    updatePlayerPosition()
    updatePlayerSpeed()
    drawPlayer()
    checkScore()
    playdate.resetElapsedTime()
end

function updateCircles()
   
   
   if (circles[2]["radius"] > 100) then
      gameSpeed += circles[2]["radius"]/100 
   else
      gameSpeed = baseGameSpeed
   end
   for i=1, #circles,1 do
    circles[i]["radius"] -= gameSpeed * playdate.getElapsedTime()
    print(i,": ", circles[i]["radius"])
   end
 
   if circles[1]["radius"]  < playerRadius then
      circles[1]["radius"] = playerRadius
   end

   -- gameover condition
   if (circles[2]["radius"] - circles[1]["radius"] <= playerRadius*2) then
      gameOver()
   end 
   
   outerCircle = geometry.arc.new(circleCenter.x, circleCenter.y, circles[2]["radius"], currentCrankPosition + circles[2]["openingAngle"] + currentOpeningSize,currentCrankPosition + circles[2]["openingAngle"] +(360-currentOpeningSize))
end

function gameOver()
   for i=1,11,1 
   do
      circles[i] = {
         openingAngle = math.random(0,360),
         radius = minimumInnerRadius + (i-1) * spaceBetweenCircles
      }
   end
end

function drawCircles()
    gfx.setLineWidth(circleLineWidth)
    gfx.setStrokeLocation(gfx.kStrokeInside)
    circleToDraw = outerCircle:copy()
    -- rounding to nearest multiple to reduce jitter - TODO this in a decent way when circles are in an array and not hardcoded
    circleToDraw.radius = roundToNearestMultiple(circleToDraw.radius, 1)
    gfx.drawArc(circleToDraw)
    
    gfx.fillCircleAtPoint(circleCenter,roundToNearestMultiple(circles[1]["radius"], 1))
    
    for i=3,11,1 do
    gfx.drawCircleAtPoint(circleCenter,roundToNearestMultiple(circles[i]["radius"], 1))
    end
end

function checkCommands()
   currentCrankPosition = playdate.getCrankPosition()
end

function checkCrank()
    if playdate.isCrankDocked() then
        if not crankIndicatorShowing then
            playdate.ui.crankIndicator:start()
            crankIndicatorShowing = true
        end
        playdate.ui.crankIndicator:update()
    else
        if crankIndicatorShowing then
            crankIndicatorShowing = false
        end
    end
end

function updatePlayerPosition()

   playerPosition.y +=  playerSpeed.y * playdate.getElapsedTime()
   playerPosition.x += playerSpeed.x * playdate.getElapsedTime()

   checkCollision()
   
   if collidedThisFrame == "outer" then
      
      -- this is how actual intersections look like, but it gets ugly when ball falls vertically or almost so. it would be great to use this,  but I have no idea how to make this work
      
      -- local deltaX = playerPosition.x - previousPlayerPosition.x
      -- 
      -- local deltaY = playerPosition.x - previousPlayerPosition.x
      -- if deltax == 0 then
      --    deltax = .00000001 -- temporary, should make this a separate flow
      -- end
      -- 
      -- m = deltaY/deltaX
      -- b = playerPosition.y - m*playerPosition.x
      -- h = circleCenter.x
      -- k = circleCenter.y
      -- r = currentRadius - playerRadius - circleLineWidth
      -- 
      -- playerPosition.x = (math.sqrt(-b^2 - 2*b*h*m + 2 *b* k - h^2 * m^2 + 2 * h * k * m - k^2 + m^2 * r^2 + r^2) - b * m + h + k * m)/(m^2 + 1) 
      -- playerPosition.y = (m *(math.sqrt(-b^2 - 2* b* h * m + 2 * b* k - h^2 * m^2 + 2 * h* k* m - k^2 + m^2 * r^2 + r^2) + h + k * m) + b)/(m^2 + 1)
      
      -- by far the best fuzzy method of resetting collision, with the added bonus that you get "rolling" from this
      correctionDirectionVector = playerPosition - circleCenter
      playerPosition.x += correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - (circles[2]["radius"]- distanceFromCenter - circleLineWidth))
      playerPosition.y += correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - (circles[2]["radius"]- distanceFromCenter - circleLineWidth ))  
     
   elseif collidedThisFrame == "inner" then
      correctionDirectionVector = playerPosition - circleCenter
      playerPosition.x += correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - playerLineWidth - circles[1]["radius"])
      playerPosition.y += correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - playerLineWidth - circles[1]["radius"]) 
   end
   
   playerRotation += playerSpinSpeed * playdate.getElapsedTime()
   
end

function updatePlayerSpeed()

      -- case collision with big outside circle 
   if(collidedThisFrame == "outer") then
      --removing impulse
      
      originalNormalVector = circleCenter - playerPosition
      normalizedNormal = originalNormalVector:normalized()
      -- bouncing
      playerSpeed = playerSpeed - (normalizedNormal:scaledBy((2 * normalizedNormal:dotProduct(playerSpeed))))
      
        -- adding speed from spinning speed and reducing 
        playerSpeed.x += playerSpinSpeed * normalizedNormal:rightNormal().dx * contactFriction
        playerSpeed.y += playerSpinSpeed * normalizedNormal:rightNormal().dy * contactFriction
        playerSpinSpeed -= contactFriction * playdate.getElapsedTime() * playerSpinSpeed 
        playerSpeed *= bounceElasticity
        playerSpinSpeed -= playdate.getCrankChange() * contactFriction / circles[2]["radius"] * playerRadius
   
   -- case collision with small inside circle 

   elseif (collidedThisFrame == "inner") then
         originalNormalVector = circleCenter - playerPosition
         normalizedNormal = originalNormalVector:normalized()
         -- bouncing
         playerSpeed = playerSpeed - (normalizedNormal:scaledBy((2 * normalizedNormal:dotProduct(playerSpeed))))
   
         -- adding speed from spinning speed and reducing 
         playerSpeed.x += playerSpinSpeed * normalizedNormal:rightNormal().dx * contactFriction
         playerSpeed.y += playerSpinSpeed * normalizedNormal:rightNormal().dy * contactFriction
         playerSpinSpeed -= contactFriction * playdate.getElapsedTime() * playerSpinSpeed 
         playerSpeed *= bounceElasticity
   elseif (collidedThisFrame == "") then
         playerSpinSpeed -= airFriction * playdate.getElapsedTime() * playerSpinSpeed
   end   
      playerSpeed.y += playdate.getElapsedTime() * gravity   
   
   -- to update with math.floor and ceiling if they get implemented in the apis   
   if(playerSpeed.x > terminalVelocity)then
      playerSpeed.x = terminalVelocity
   elseif (playerSpeed.x < -terminalVelocity) then
      playerSpeed.x = -terminalVelocity
   end
   if(playerSpeed.y > terminalVelocity)then
      playerSpeed.y = terminalVelocity
   elseif (playerSpeed.y < -terminalVelocity) then
      playerSpeed.y = -terminalVelocity
   end
   
   if(playerSpinSpeed > terminalSpinning)then
      layerSpinSpeed = terminalSpinning
   elseif (playerSpinSpeed < -terminalSpinning) then
      layerSpinSpeed = -terminalSpinning
   end
end


function checkOuterCircleCollision (center, radius, point)
   distanceFromCenter = point:distanceToPoint(center) 
   if distanceFromCenter + playerRadius > circles[2]["radius"] - circleLineWidth then
      
      openingBeginning = outerCircle:pointOnArc(0)
      openingEnd = outerCircle:pointOnArc(outerCircle:length())
      centerVector =  playerPosition - circleCenter
      openingBeginningVector =  openingBeginning - circleCenter
      openingEndVector = openingEnd - circleCenter
      --gfx.drawLine(circleCenter.x,circleCenter.y,circleCenter.x+openingBeginningVector.dx, circleCenter.y+openingBeginningVector.dy)
      --gfx.drawLine(circleCenter.x,circleCenter.y,circleCenter.x+openingEndVector.dx, circleCenter.y+openingEndVector.dy)

      if(areVectorsClockwise(openingBeginningVector, centerVector) and areVectorsClockwise(centerVector, openingEndVector)) then
         return false
      else  
         return true
      end
   else
      return false
   end
end
   
function areVectorsClockwise(v1, v2) 
  return -v1.dx*v2.dy + v1.dy*v2.dx > 0
end 
function checkInnerCircleCollision (center, radius, point)
     distanceFromCenter = point:distanceToPoint(center) 
     if  distanceFromCenter - playerRadius < radius then
        return true 
     else
         return false
     end
end
 
function checkCollision()
   if checkOuterCircleCollision(circleCenter, circles[2]["radius"], playerPosition) then
        collidedThisFrame = "outer"
   elseif checkInnerCircleCollision(circleCenter, circles[1]["radius"], playerPosition) then
        collidedThisFrame = "inner"
   else 
       collidedThisFrame = ""
    end
end

function drawPlayer()
    gfx.setLineWidth(playerLineWidth)
    gfx.drawCircleAtPoint(playerPosition.x, playerPosition.y, playerRadius)
    gfx.drawLine(playerPosition.x,playerPosition.y, playerPosition.x+playerRadius*math.cos(playerRotation),playerPosition.y+playerRadius*math.sin(playerRotation))
    
end

function checkScore()
   
   if (collidedThisFrame == "" and distanceFromCenter > playerRadius + circles[2]["radius"] )then
      removed = table.remove(circles,1)
      circles[#circles + 1] = {
         openingAngle = math.random(0,360),
         radius = circles[1]["radius"] + #circles * spaceBetweenCircles
      }
   end
end




function debugMovePlayerWithbuttons()
   if playdate.buttonJustPressed(playdate.kButtonUp) then
       playerSpeed.dy -= 100
   end
   if playdate.buttonJustPressed(playdate.kButtonDown) then
        playerSpeed.dy += 100

   end
   if playdate.buttonJustPressed(playdate.kButtonLeft) then
        playerSpeed.dx -= 100
   
   end
   if playdate.buttonJustPressed(playdate.kButtonRight) then
     playerSpeed.dx += 100
     
   end 
end

function playdate.gameWillResume()
    playdate.resetElapsedTime()
end

function roundToNearestMultiple( number, multiple )
  local half = multiple/2;
  return number + half - (number + half) % multiple;
end
