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
local circleCenter = geometry.point.new(200,120)
local playerSpeed = geometry.vector2D.new(0,0)
local playerSpinSpeed = 0
local currentOpeningSize = 20
local gravity = 0.25
local playerRadius = 10
local playerRotation = 0
local circleLineWidth = 5
local playerLineWidth = 3
local distanceFromCenter = 0
local grip = .8
local contactFriction = .90
local bounceElasticity = .96
local airFriction = .995
local collidedThisFrame = false

function playdate.update()
    gfx.clear()
    playdate.drawFPS(0,0)
    playdate.timer.updateTimers()
    collidedThisFrame = false
    previousPlayerPosition = playerPosition:copy()
    --checkCommands()
    checkCrank()
    drawCircle()
    updatePlayerPosition()
    updatePlayerSpeed()
    debugMovePlayerWithbuttons()
    drawPlayer()
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
        -- case collision with line circle
        correctionDirectionVector = playerPosition - circleCenter
        playerPosition.x = playerPosition.x + (correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter)))
        playerPosition.y = playerPosition.y + (correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter)))  
    end
    
    playerRotation += playerSpinSpeed * playdate.getElapsedTime()

end

function updatePlayerSpeed()

    if (collidedThisFrame) then
        
        -- case collision with line circle
        print("in comes: ",playerSpeed)
        originalNormalVector = circleCenter - playerPosition
        normalizedNormal = originalNormalVector:normalized()
        playerSpeed = playerSpeed - (normalizedNormal:scaledBy((2 * normalizedNormal:dotProduct(playerSpeed))))
        playerSpeed *= bounceElasticity
        print("out goes: ",playerSpeed)
    
        playerSpinSpeed += playdate.getCrankChange() * grip / currentRadius * playerRadius
        playerSpinSpeed -= contactFriction * playdate.getElapsedTime()
        
    else
        playerSpinSpeed -= airFriction * playdate.getElapsedTime()
    end
    playerSpeed.y += playdate.getElapsedTime()*gravity
    
end

function checkCollision()
    
    -- outline circle detection
    distanceFromCenter = playerPosition:distanceToPoint(circleCenter) + circleLineWidth    
    if  distanceFromCenter + playerRadius > currentRadius - circleLineWidth then
        return true
    else
        return false
    end
end

function drawPlayer()
    gfx.setLineWidth(playerLineWidth)
    gfx.drawCircleAtPoint(playerPosition.x, playerPosition.y, playerRadius)
end

function debugMovePlayerWithbuttons()
   if playdate.buttonIsPressed(playdate.kButtonUp) then
       playerSpeed.dy -= 10
   end
   if playdate.buttonIsPressed(playdate.kButtonDown) then
       playerPosition.y += 10
       if(playerPosition.y > 280) then
           playerPosition.y = 280
       end
   end
   if playdate.buttonIsPressed(playdate.kButtonLeft) then
       playerPosition.x -= 10
       if(playerPosition.x < -50) then
           playerPosition.x = -50
       end
   end
   if playdate.buttonIsPressed(playdate.kButtonRight) then
       playerPosition.x += 10
       if(playerPosition.x > 450) then
           playerPosition.x = 450
       end
   end 
end