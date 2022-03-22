
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
local playerPosition = geometry.point.new(180,100)
local previousPlayerPosition =  playerPosition:copy()
local circleCenter = geometry.point.new(200,120)
local playerSpeed = geometry.vector2D.new(20,10)
local playerSpinSpeed = 0
local currentOpeningSize = 20
local gravity = 400
local playerRadius = 10
local playerRotation = 0
local circleLineWidth = 5
local playerLineWidth = 3
local distanceFromCenter = 0
local collisionRelocationMagnitude = 0
local contactFriction = .8
local bounceElasticity = .8
local airFriction = .9
local collidedThisFrame = false
local terminalVelocity = 400
local terminalSpinning = 400
local innerRadius = 10

function playdate.update()
    gfx.clear()
    playdate.drawFPS(0,0)
    playdate.timer.updateTimers()
    collidedThisFrame = ""
    collisionRelocationMagnitude = 0
    previousPlayerPosition = playerPosition:copy()
    --checkCommands()
    debugMovePlayerWithbuttons()
    checkCrank()
    drawCircles()
    updatePlayerPosition()
    updatePlayerSpeed()
    drawPlayer()
    playdate.resetElapsedTime()
end

function drawCircles()
    gfx.setLineWidth(circleLineWidth)
    gfx.setStrokeLocation(gfx.kStrokeInside)
    gfx.drawArc(circleCenter.x, circleCenter.y, currentRadius, playdate.getCrankPosition()+currentOpeningSize,playdate.getCrankPosition()+(360-currentOpeningSize))
    gfx.fillCircleAtPoint(circleCenter,innerRadius)
end

function checkCommands()
    if playdate.buttonIsPressed(playdate.kButtonUp) then
        currentRadius -= 10
        if(currentRadius < playerRadius + circleLineWidth) then
            currentRadius = playerRadius + circleLineWidth
        end
    end
    if playdate.buttonIsPressed(playdate.kButtonDown) then
        currentRadius += 10
        if(currentRadius > 120) then
            currentRadius = 120
        end
    end
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
      local currentSegment = geometry.lineSegment.new(previousPlayerPosition.x,previousPlayerPosition.y,playerPosition.x,playerPosition.y)
      for i = 1, 10, 1
      do
         local currentSegment = geometry.lineSegment.new(previousPlayerPosition.x,previousPlayerPosition.y,playerPosition.x,playerPosition.y)
           local midpoint = currentSegment:midPoint()
           for i = 1, 10, 1
           do
               midpoint = currentSegment:midPoint()
               if (checkInnerCircleCollision(circleCenter, currentRadius, midpoint)) then
                   currentSegment = geometry.lineSegment.new(previousPlayerPosition.x,previousPlayerPosition.y,midpoint.x,midpoint.y)
               else
                   currentSegment = geometry.lineSegment.new(midpoint.x,midpoint.y,PlayerPosition.x,PlayerPosition.y)
               end
           end
      end

        if(checkInnerCircleCollision(circleCenter, currentRadius, playerPosition))then
            -- shift towards circle center 
            correctionDirectionVector = playerPosition - circleCenter
            playerPosition.x = playerPosition.x + (correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter - circleLineWidth)))
            playerPosition.y = playerPosition.y + (correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter - circleLineWidth )))  
        else
            playerPosition = midpoint:copy()
        end        
      --playerPosition = previousPlayerPosition:copy()
   end
    
   playerRotation += playerSpinSpeed * playdate.getElapsedTime()

end

function updatePlayerSpeed()

      -- case collision with inside of circle 
   if(collidedThisFrame == "outer") then
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
   if  distanceFromCenter + playerRadius > currentRadius - circleLineWidth then

       return true
   else
        return false
   end
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
        print("outer", playdate.getElapsedTime())
   elseif checkInnerCircleCollision(circleCenter, innerRadius, playerPosition) then
        collidedThisFrame = "inner"
        print("inner", playdate.getElapsedTime())

   else 
       collidedThisFrame = ""
    end
end

function drawPlayer()
    gfx.setLineWidth(playerLineWidth)
    gfx.drawCircleAtPoint(playerPosition.x, playerPosition.y, playerRadius)
    gfx.drawLine(playerPosition.x,playerPosition.y, playerPosition.x+playerRadius*math.cos(playerRotation),playerPosition.y+playerRadius*math.sin(playerRotation))
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
