--import "mlib.lua"

local unpack = table.unpack or unpack


function getCircleSegmentIntersection( circleX, circleY, radius, x1, y1, x2, y2 )

	local slope, intercept = getSlope( x1, y1, x2, y2 ), getYIntercept( x1, y1, x2, y2 )

	if isPointOnCircle( x1, y1, circleX, circleY, radius ) and isPointOnCircle( x2, y2, circleX, circleY, radius ) then -- Both points are on line-segment.
		return 'chord', x1, y1, x2, y2
	end

	if slope then
		if checkCirclePoint( x1, y1, circleX, circleY, radius ) and checkCirclePoint( x2, y2, circleX, circleY, radius ) then -- Line-segment is fully in circle.
			return 'enclosed', x1, y1, x2, y2
		elseif x3 and x4 then
			if checkSegmentPoint( x3, y3, x1, y1, x2, y2 ) and not checkSegmentPoint( x4, y4, x1, y1, x2, y2 ) then -- Only the first of the points is on the line-segment.
				return 'tangent', x3, y3
			elseif checkSegmentPoint( x4, y4, x1, y1, x2, y2 ) and not checkSegmentPoint( x3, y3, x1, y1, x2, y2 ) then -- Only the second of the points is on the line-segment.
				return 'tangent', x4, y4
			else -- Neither of the points are on the circle (means that the segment is not on the circle, but "encasing" the circle)
				if checkSegmentPoint( x3, y3, x1, y1, x2, y2 ) and checkSegmentPoint( x4, y4, x1, y1, x2, y2 ) then
					return 'secant', x3, y3, x4, y4
				else
					return false
				end
			end
		elseif not x4 then -- Is a tangent.
			if checkSegmentPoint( x3, y3, x1, y1, x2, y2 ) then
				return 'tangent', x3, y3
			else -- Neither of the points are on the line-segment (means that the segment is not on the circle or "encasing" the circle).
				local length = getLength( x1, y1, x2, y2 )
				local distance1 = getLength( x1, y1, x3, y3 )
				local distance2 = getLength( x2, y2, x3, y3 )

				if length > distance1 or length > distance2 then
					return false
				elseif length < distance1 and length < distance2 then
					return false
				else
					return 'tangent', x3, y3
				end
			end
		end
	else
		local lengthToPoint1 = circleX - x1
		local remainingDistance = lengthToPoint1 - radius
		local intercept = math.sqrt( -( lengthToPoint1 ^ 2 - radius ^ 2 ) )

		if -( lengthToPoint1 ^ 2 - radius ^ 2 ) < 0 then return false end

		local topX, topY = x1, circleY - intercept
		local bottomX, bottomY = x1, circleY + intercept

		local length = getLength( x1, y1, x2, y2 )
		local distance1 = getLength( x1, y1, topX, topY )
		local distance2 = getLength( x2, y2, topX, topY )

		if bottomY ~= topY then -- Not a tangent
			if checkSegmentPoint( topX, topY, x1, y1, x2, y2 ) and checkSegmentPoint( bottomX, bottomY, x1, y1, x2, y2 ) then
				return 'chord', topX, topY, bottomX, bottomY
			elseif checkSegmentPoint( topX, topY, x1, y1, x2, y2 ) then
				return 'tangent', topX, topY
			elseif checkSegmentPoint( bottomX, bottomY, x1, y1, x2, y2 ) then
				return 'tangent', bottomX, bottomY
			else
				return false
			end
		else -- Tangent
			if checkSegmentPoint( topX, topY, x1, y1, x2, y2 ) then
				return 'tangent', topX, topY
			else
				return false
			end
		end
	end
end

function getSlope( x1, y1, x2, y2 )
	if checkFuzzy( x1, x2 ) then return false end -- Technically it's undefined, but this is easier to program.
	return ( y1 - y2 ) / ( x1 - x2 )
end

function getYIntercept( x, y, ... )
	local input = checkInput( ... )
	local slope

	if #input == 1 then
		slope = input[1]
	else
		slope = getSlope( x, y, unpack( input ) )
	end

	if not slope then return x, true end -- This way we have some information on the line.
	return y - slope * x, false
end

function isPointOnCircle( x, y, circleX, circleY, radius )
	return checkFuzzy( getLength( circleX, circleY, x, y ), radius )
end

-- Checks if a point is within the radius of a circle.
function checkCirclePoint( x, y, circleX, circleY, radius )
	return getLength( circleX, circleY, x, y ) <= radius
end

-- Gives whether or not a point lies on a line segment.
function checkSegmentPoint( px, py, x1, y1, x2, y2 )
	-- Explanation around 5:20: https://www.youtube.com/watch?v=A86COO8KC58
	local x = checkLinePoint( px, py, x1, y1, x2, y2 )
	if not x then return false end

	local lengthX = x2 - x1
	local lengthY = y2 - y1

	if checkFuzzy( lengthX, 0 ) then -- Vertical line
		if checkFuzzy( px, x1 ) then
			local low, high
			if y1 > y2 then low = y2; high = y1
			else low = y1; high = y2 end

			if py >= low and py <= high then return true
			else return false end
		else
			return false
		end
	elseif checkFuzzy( lengthY, 0 ) then -- Horizontal line
		if checkFuzzy( py, y1 ) then
			local low, high
			if x1 > x2 then low = x2; high = x1
			else low = x1; high = x2 end

			if px >= low and px <= high then return true
			else return false end
		else
			return false
		end
	end

	local distanceToPointX = ( px - x1 )
	local distanceToPointY = ( py - y1 )
	local scaleX = distanceToPointX / lengthX
	local scaleY = distanceToPointY / lengthY

	if ( scaleX >= 0 and scaleX <= 1 ) and ( scaleY >= 0 and scaleY <= 1 ) then -- Intersection
		return true
	end
	return false
end

-- Returns the length of a line.
function getLength( x1, y1, x2, y2 )
	local dx, dy = x1 - x2, y1 - y2
	return math.sqrt( dx * dx + dy * dy )
end

function checkLinePoint( x, y, x1, y1, x2, y2 )
	local m = getSlope( x1, y1, x2, y2 )
	local b = getYIntercept( x1, y1, m )

	if not m then -- Vertical
		return checkFuzzy( x, x1 )
	end
	return checkFuzzy( y, m * x + b )
end -- }}}


-- Deals with floats / verify false false values. This can happen because of significant figures.
function checkFuzzy( number1, number2 )
	return ( number1 - .00001 <= number2 and number2 <= number1 + .00001 )
end


-- Used to handle variable-argument functions and whether they are passed as func{ table } or func( unpack( table ) )
function checkInput( ... )
	local input = {}
	if type( ... ) ~= 'table' then input = { ... } else input = ... end
	return input
end

