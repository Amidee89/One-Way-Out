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

local crankIndicatorShowing = false

playdate.resetElapsedTime()


--gameplay
local currentRadius = 50
local playerPosition = geometry.point.new(220,120)
local circleCenter = geometry.point.new(200,120)
local playerSpeed = geometry.vector2D.new(0,0)
local playerSpin = 0
local gravity = 0.2
local playerRadius = 10
local playerRotation = 0
local circleLineWidth = 5
local distanceFromCenter = 0

function playdate.update()
    gfx.clear()
    playdate.drawFPS(0,0)
    playdate.timer.updateTimers()

    checkCommands()
    checkCrank()
    drawCircle()
    updatePlayerPosition()
    drawPlayer()
end

function drawCircle()
    gfx.setLineWidth(circleLineWidth)
    gfx.setStrokeLocation(gfx.kStrokeInside)
    gfx.drawArc(circleCenter.x, circleCenter.y, currentRadius, playdate.getCrankPosition()+20,playdate.getCrankPosition()+340)
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
    if checkCollision() then
        correctionDirectionVector = playerPosition - circleCenter
        playerPosition.x = playerPosition.x + (correctionDirectionVector.dx / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter)))
        playerPosition.y = playerPosition.y + (correctionDirectionVector.dy / correctionDirectionVector:magnitude() * -(playerRadius - (currentRadius- distanceFromCenter)))
    end
    
    playerSpeed.y += playdate.getElapsedTime()*gravity
end

function checkCollision()
    distanceFromCenter = playerPosition:distanceToPoint(circleCenter)
    if  distanceFromCenter + playerRadius > currentRadius then
        return true
    else
        return false
    end
end

function drawPlayer()
    gfx.drawCircleAtPoint(playerPosition.x, playerPosition.y, playerRadius)
end