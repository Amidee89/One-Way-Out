
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


--gameplay
local currentRadius = 50
local currentOpeningSize = 20
local circleCenter = geometry.point.new(200,120)
local outerCircle = geometry.arc.new(circleCenter.x, circleCenter.y, currentRadius, 0, 0)

local nextRadius = 100

local playerRadius = 10
local playerPosition = geometry.point.new(180,100)
local previousPlayerPosition =  playerPosition:copy()

local playerSpeed = geometry.vector2D.new(20,10)
local playerRotation = 0
local playerSpinSpeed = 0
local distanceFromCenter = 0

local collidedThisFrame = false
local collisionRelocationMagnitude = 0

local innerRadius = 10
local minimumInnerRadius = 5

local circleLineWidth = 5
local playerLineWidth = 3

local gravity = 400
local contactFriction = .8
local bounceElasticity = .8
local airFriction = .9
local terminalVelocity = 400
local terminalSpinning = 400

local currentCrankPosition = 0
local gameSpeed = 10

function playdate.update()
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
   if (currentRadius > 100) then
      gameSpeed += currentRadius/100
      
   else
      gameSpeed = 10
   end
   currentRadius -= gameSpeed * playdate.getElapsedTime()
   innerRadius -= gameSpeed * playdate.getElapsedTime()
   if innerRadius < playerRadius then
      innerRadius = playerRadius
   end
   nextRadius -= gameSpeed * playdate.getElapsedTime()
   -- gameover condition
   if (currentRadius - innerRadius <= playerRadius*2) then
      gameOver()
   end 
   
   outerCircle = geometry.arc.new(circleCenter.x, circleCenter.y, currentRadius, currentCrankPosition + currentOpeningSize,currentCrankPosition+(360-currentOpeningSize))
end

function gameOver()
   innerRadius = 10
   currentRadius = 50
   nextRadius = 100
end

function drawCircles()
    gfx.setLineWidth(circleLineWidth)
    gfx.setStrokeLocation(gfx.kStrokeInside)
    gfx.drawArc(outerCircle)
    gfx.fillCircleAtPoint(circleCenter,innerRadius)
    gfx.drawCircleAtPoint(circleCenter,nextRadius)
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
      playerPosition.x += correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter - circleLineWidth))
      playerPosition.y += correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter - circleLineWidth ))  
     
   elseif collidedThisFrame == "inner" then
      correctionDirectionVector = playerPosition - circleCenter
      playerPosition.x += correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - playerLineWidth - innerRadius)
      playerPosition.y += correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - playerLineWidth - innerRadius) 
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
        playerSpinSpeed -= playdate.getCrankChange() * contactFriction / currentRadius * playerRadius
   
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
   if distanceFromCenter + playerRadius > currentRadius - circleLineWidth then
      
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
  return -v1.dx*v2.dy + v1.dy*v2.dx > 0;
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
   if checkOuterCircleCollision(circleCenter, currentRadius, playerPosition) then
        collidedThisFrame = "outer"
   elseif checkInnerCircleCollision(circleCenter, innerRadius, playerPosition) then
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
   
   if (collidedThisFrame == "" and distanceFromCenter > playerRadius + currentRadius )then
      innerRadius = currentRadius
      currentRadius = nextRadius
      nextRadius = currentRadius + 50
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


