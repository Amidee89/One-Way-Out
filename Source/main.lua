
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
local playerSpeed = geometry.vector2D.new(0,0)
local playerSpinSpeed = 0
local currentOpeningSize = 20
local gravity = 200
local playerRadius = 10
local playerRotation = 0
local circleLineWidth = 5
local playerLineWidth = 3
local distanceFromCenter = 0
local collisionRelocationMagnitude = 0
local contactFriction = .8
local bounceElasticity = .9
local airFriction = .9
local collidedThisFrame = false
local terminalVelocity = 400
local terminalSpinning = 400

function playdate.update()
    gfx.clear()
    playdate.drawFPS(0,0)
    playdate.timer.updateTimers()
    collidedThisFrame = false
    collisionRelocationMagnitude = 0
    previousPlayerPosition = playerPosition:copy()
    --checkCommands()
    debugMovePlayerWithbuttons()
    checkCrank()
    drawCircle()
    updatePlayerPosition()
    updatePlayerSpeed()
    drawPlayer()
    playdate.resetElapsedTime()
end

function drawCircle()
    gfx.setLineWidth(circleLineWidth)
    gfx.setStrokeLocation(gfx.kStrokeInside)
    gfx.drawArc(circleCenter.x, circleCenter.y, currentRadius, playdate.getCrankPosition()+currentOpeningSize,playdate.getCrankPosition()+(360-currentOpeningSize))
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
    if checkCollision() then
        collidedThisFrame = true      
        -- iterative method
        local currentSegment = geometry.lineSegment.new(previousPlayerPosition.x,previousPlayerPosition.y,playerPosition.x,playerPosition.y)
        local midpoint = currentSegment:midPoint()
        for i = 10, 1, 1
        do
            midpoint = currentSegment:midPoint()
            if (checkCircleCollision(circleCenter, currentRadius, midpoint)) then
                currentSegment = geometry.lineSegment.new(previousPlayerPosition.x,previousPlayerPosition.y,midpoint.x,midpoint.y)
            else
                currentSegment = geometry.lineSegment.new(midpoint.x,midpoint.y,PlayerPosition.x,PlayerPosition.y)
            end
        end
        if(checkCircleCollision(circleCenter, currentRadius, midpoint))then
            playerPosition = midpoint:copy()
            -- shift towards circle center 
            correctionDirectionVector = playerPosition - circleCenter
            playerPosition.x = playerPosition.x + (correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter - circleLineWidth)))
            playerPosition.y = playerPosition.y + (correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter - circleLineWidth )))  
        else
            playerPosition = midpoint:copy()
        end        
    end
    
    playerRotation += playerSpinSpeed * playdate.getElapsedTime()

end

function updatePlayerSpeed()

   if (collidedThisFrame) then
        -- case collision with line circle, bouncing
        originalNormalVector = circleCenter - playerPosition
        normalizedNormal = originalNormalVector:normalized()
        playerSpeed = playerSpeed - (normalizedNormal:scaledBy((2 * normalizedNormal:dotProduct(playerSpeed))))
        
        -- adding speed from spinning speed and reducing 
        playerSpeed.x += playerSpinSpeed * normalizedNormal:rightNormal().dx * contactFriction
        playerSpeed.y += playerSpinSpeed * normalizedNormal:rightNormal().dy * contactFriction
        playerSpinSpeed -= contactFriction * playdate.getElapsedTime() * playerSpinSpeed

        playerSpeed *= bounceElasticity
        
        
        playerSpinSpeed -= playdate.getCrankChange() * contactFriction / currentRadius * playerRadius
        
   else
        playerSpinSpeed -= airFriction * playdate.getElapsedTime() * playerSpinSpeed
   end
   playerSpeed.y += playdate.getElapsedTime() * gravity   
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


function checkCircleCollision (center, radius, point)
    distanceFromCenter = point:distanceToPoint(center) 
    if  distanceFromCenter + playerRadius > currentRadius - circleLineWidth then
        return true
    else
        return false
    end
end
    
function checkCollision()
    
    -- outline circle detection
    distanceFromCenter = playerPosition:distanceToPoint(circleCenter) 
    if  distanceFromCenter + playerRadius > currentRadius - circleLineWidth then
        return true
    else
        return false
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


