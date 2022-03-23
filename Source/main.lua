
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
      playerPosition.x += correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - innerRadius)
      playerPosition.y += correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - innerRadius) 
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
        print("outer collision", playdate.getElapsedTime())
   elseif checkInnerCircleCollision(circleCenter, innerRadius, playerPosition) then
        collidedThisFrame = "inner"
        print("inner collision", playdate.getElapsedTime())

   else 
       collidedThisFrame = ""
       print("no collision")
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
