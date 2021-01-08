CabView = {};

addModEventListener(CabView);

function CabView.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function CabView.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabView)
	SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CabView)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CabView)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CabView)
end

function CabView:onRegisterActionEvents(isSelected, isOnActiveVehicle)
    local actionEventId
    if isOnActiveVehicle then
        _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'CABVIEW_LEAN_FORWARD', self, CabView.KeyDown_LeanForward, true, true, false, true)
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
		g_inputBinding:setActionEventTextVisibility(actionEventId, false)
    end
end

function CabView:onLoad(savegame)
	spec = self.spec_cabView
	spec.vehicleId	= self.rootNode
	
	--RESTRICT LEANING OUT OF BACK WINDOW FOR THESE VEHICLES
	if self.typeDesc == 'car' or
	self.typeDesc == 'truck' or
	self.typeName == 'carFillable' or
	self.typeName == 'addOtherVehiclesHere' then
		--print("Leaning RESTRICTED")
		spec.restrictLean = true
	else
		spec.restrictLean = false
	end
	
	-- FIND INDOOR CAMERA:
	spec.indoorCameraNode = nil
	if self.spec_enterable ~= nil then
		for index, camera in pairs(self.spec_enterable.cameras) do
			if camera.isInside then
				spec.indoorCameraNode = camera.cameraPositionNode
				spec.originalRotX = camera.rotX
				spec.originalRotY = camera.rotY%(2*math.pi)
				spec.rotationOffset = spec.originalRotY - math.pi
			end
		end
	end
end

function CabView:onEnterVehicle(isControlling, playerStyle, farmId)
	if isControlling then
		self.spec_cabView.resetView = true
		CabView.leanButtonPressed = false
		CabView.lean = 0
	end
end

function CabView:onLeaveVehicle(isControlling, playerStyle, farmId)
	--print("LEAVING VEHICLE")
	CabView.leanButtonPressed = false
	CabView.lean = 0
end

function CabView:KeyDown_LeanForward(actionName, inputValue)
	if CabView.isInsideCamera then
		if inputValue == 1 then
			--print("lean forward")
			CabView.leanButtonPressed = true
		else
			--print("lean backward")
			CabView.leanButtonPressed = false
		end
	end
end


function CabView:vehicleCameraUpdate(superFunc, dt)
	-- CATCH AND ATTEMPT TO FIX THIS OCCASSIONAL ERROR
	if self.rotX==nil or self.rotY==nil then
		--print("CABVIEW: Catch Error...")
		self.rotX = self.origRotX
		self.rotY = self.origRotY
	end

	-- RETURN NORMAL FUNCTION WHEN CAB VIEW IS NOT INSTALLED
	if self.vehicle.spec_cabView == nil then
		return superFunc(self, dt)
	end

	-- DISABLE CABVIEW FOR UNIVERSAL PASSENGER (PASSENGERS ONLY)
	if self.vehicle.spec_universalPassenger ~= nil then
		if g_universalPassenger.currentPassengerVehicle ~= nil then
			if self.vehicle == g_universalPassenger.currentPassengerVehicle then
				--print("Universal Passenger")
				return superFunc(self, dt)
			end
		end
	end
	
	-- RESET VIEW IF REQUIRED
	spec = self.vehicle.spec_cabView
	if self.isInside and spec.resetView then
		self.rotX = spec.originalRotX
		self.rotY = spec.originalRotY
		spec.resetView = false
	end

    local target = self.zoomTarget
    if self.zoomLimitedTarget >= 0 then
        target = math.min(self.zoomLimitedTarget, self.zoomTarget)
    end
    self.zoom = target + ( math.pow(0.99579, dt) * (self.zoom - target) )
	
    if self.lastInputValues.upDown ~= 0 then
        local value = self.lastInputValues.upDown * g_gameSettings:getValue(GameSettings.SETTING.CAMERA_SENSITIVITY)
        self.lastInputValues.upDown = 0
        value = g_gameSettings:getValue("invertYLook") and -value or value
        if self.isRotatable then
            if self.isActivated and not g_gui:getIsGuiVisible() then
                if self.limitRotXDelta > 0.001 then
                    self.rotX = math.min(self.rotX - value, self.rotX)
                elseif self.limitRotXDelta < -0.001 then
                    self.rotX = math.max(self.rotX - value, self.rotX)
                else
                    self.rotX = self.rotX - value
                end
                if self.limit then
                    self.rotX = math.min(self.rotMaxX, math.max(self.rotMinX, self.rotX))
                end
            end
        end
    end
    if self.lastInputValues.leftRight ~= 0 then
        local value = self.lastInputValues.leftRight * g_gameSettings:getValue(GameSettings.SETTING.CAMERA_SENSITIVITY)
        self.lastInputValues.leftRight = 0
        if self.isRotatable then
            if self.isActivated and not g_gui:getIsGuiVisible() then
				self.rotY = self.rotY - value
				if self.isInside then
					-- LIMIT ROTATION to +/- 180 degrees [+5%]
					local minRot = -0.1 * math.pi+spec.rotationOffset
					local maxRot =  2.1 * math.pi+spec.rotationOffset
					self.rotY = MathUtil.clamp(self.rotY, minRot, maxRot)
				end
            end
        end
    end
    --
    if g_gameSettings:getValue("isHeadTrackingEnabled") and isHeadTrackingAvailable() and self.allowHeadTracking and self.headTrackingNode ~= nil then
        local tx,ty,tz = getHeadTrackingTranslation()
        local pitch,yaw,roll = getHeadTrackingRotation()
        if pitch ~= nil then
            local camParent = getParent(self.cameraNode)
            local ctx,cty,ctz;
            local crx,cry,crz;
            if camParent ~= 0 then
                ctx, cty, ctz = localToLocal(self.headTrackingNode, camParent, tx, ty, tz);
                crx, cry, crz = localRotationToLocal(self.headTrackingNode, camParent, pitch,yaw,roll);
            else
                ctx, cty, ctz = localToWorld(self.headTrackingNode, tx, ty, tz);
                crx, cry, crz = localRotationToWorld(self.headTrackingNode, pitch,yaw,roll);
            end
            setRotation(self.cameraNode, crx, cry, crz)
            setTranslation(self.cameraNode, ctx, cty, ctz)
        end
    else
        self:updateRotateNodeRotation()
        if self.limit then
            -- adjust rotation to avoid clipping with terrain
            if self.isRotatable and ((self.useWorldXZRotation == nil and g_gameSettings:getValue("useWorldCamera")) or self.useWorldXZRotation) then
                local numIterations = 4
                for i=1, numIterations do
                    local transX, transY, transZ = self.transDirX*self.zoom, self.transDirY*self.zoom, self.transDirZ*self.zoom
                    local x,y,z = localToWorld(getParent(self.cameraPositionNode), transX, transY, transZ)
                    local terrainHeight = DensityMapHeightUtil.getHeightAtWorldPos(x,0,z)
                    local minHeight = terrainHeight + 0.9
                    if y < minHeight then
                        local h = math.sin(self.rotX)*self.zoom
                        local h2 = h-(minHeight-y)
                        self.rotX = math.asin(MathUtil.clamp(h2/self.zoom, -1, 1))
                        self:updateRotateNodeRotation()
                    else
                        break
                    end
                end
            end
            -- adjust zoom to avoid collision with objects
            if self.allowTranslation then
                self.limitRotXDelta = 0
                local hasCollision, collisionDistance, nx,ny,nz, normalDotDir = self:getCollisionDistance()
                if hasCollision then
                    local distOffset = 0.1
                    if normalDotDir ~= nil then
                        local absNormalDotDir = math.abs(normalDotDir)
                        distOffset = MathUtil.lerp(1.2, 0.1, absNormalDotDir*absNormalDotDir*(3-2*absNormalDotDir))
                    end
                    collisionDistance = math.max(collisionDistance-distOffset, 0.01)
                    self.disableCollisionTime = g_currentMission.time+400
                    self.zoomLimitedTarget = collisionDistance
                    if collisionDistance < self.zoom then
                        self.zoom = collisionDistance
                    end
                    if self.isRotatable and nx ~= nil and collisionDistance < self.transMin then
                        local _,lny,_ = worldDirectionToLocal(self.rotateNode, nx,ny,nz)
                        if lny > 0.5 then
                            self.limitRotXDelta = 1
                        elseif lny < -0.5 then
                            self.limitRotXDelta = -1
                        end
                    end
                else
                    if self.disableCollisionTime <= g_currentMission.time then
                        self.zoomLimitedTarget = -1
                    end
                end
            end
        end
        self.transX, self.transY, self.transZ = self.transDirX*self.zoom, self.transDirY*self.zoom, self.transDirZ*self.zoom
		if self.isInside then
			CabView.isInsideCamera = true
			local limit = 0.4
			local totalSide = 0
			local totalForward = 0
			-- shift camera direction angle to range from -pi to +pi (instead of 0 to 2pi)
			local angle = MathUtil.clamp(self.rotY-(math.pi+spec.rotationOffset), -math.pi, math.pi)

			-- INCREASE/DECREASE LEANING based on control inputs
			if CabView.leanButtonPressed then
				if CabView.lean < limit then
					CabView.lean = CabView.lean + dt/1000
				end
			else
				if CabView.lean > 0 then
					CabView.lean = CabView.lean - dt/1000
				end
			end
			
			if math.abs(angle) <= math.pi/2 then
			-- ADD LEANING FORWARD in the direction player is looking
				--print("LOOK FORWARD/SIDE")
				if angle>0 then
					totalSide = math.sin(angle)*CabView.lean
				end
				if angle<0 then
					totalSide = math.sin(angle)*CabView.lean
				end
				totalForward =  math.cos(angle)*CabView.lean
			else
			-- ADD AUTOMATIC LEANING if looking more than 90 degrees left or right
				--print("LOOK BACK")
				local autoLean = 0
				if angle>math.pi/2 then
					--print("LEAN LEFT")
					autoLean = (angle-math.pi/2)/(2*math.pi)
					totalSide = autoLean + math.sin(angle)*CabView.lean
				end
				if angle<-math.pi/2 then
					--print("LEAN RIGHT")
					autoLean = (angle+math.pi/2)/(2*math.pi)
					totalSide = autoLean + math.sin(angle)*CabView.lean
				end
				if spec.restrictLean then
					totalForward = 0
				else
					totalForward = math.cos(angle)*CabView.lean/2
				end
			end
			
			if totalSide~=0 or totalForward~=0 then
			-- ROTATE NEW TRANSLATIONS BACK INTO ORIGINAL COORDINATE FRAME
				local x,y,z = worldDirectionToLocal(getParent(self.cameraPositionNode), self.transX, self.transY, self.transZ)
				self.transX = self.transX + totalSide*math.cos(-spec.rotationOffset) - totalForward*math.sin(-spec.rotationOffset)
				self.transZ = self.transZ + totalSide*math.sin(-spec.rotationOffset) + totalForward*math.cos(-spec.rotationOffset)
			end
		else
			CabView.isInsideCamera = false
			CabView.leanButtonPressed = false
			CabView.lean = 0
		end
        setTranslation(self.cameraPositionNode, self.transX, self.transY, self.transZ)
        if self.positionSmoothingParameter > 0 then
            local interpDt = g_physicsDt
            if self.vehicle.spec_rideable ~= nil then
                interpDt = self.vehicle.spec_rideable.interpolationDt
            end
            if g_server == nil then
                -- on clients, we interpolate the vehicles with dt, thus we need to use the same for camera interpolation
                interpDt = dt
            end
            if interpDt > 0 then
                local xlook,ylook,zlook = getWorldTranslation(self.rotateNode)
                local lookAtPos = self.lookAtPosition
                local lookAtLastPos = self.lookAtLastTargetPosition
                lookAtPos[1],lookAtPos[2],lookAtPos[3] = self:getSmoothed(self.lookAtSmoothingParameter, lookAtPos[1],lookAtPos[2],lookAtPos[3], xlook,ylook,zlook, lookAtLastPos[1],lookAtLastPos[2],lookAtLastPos[3], interpDt)
                lookAtLastPos[1],lookAtLastPos[2],lookAtLastPos[3] = xlook,ylook,zlook
                local x,y,z = getWorldTranslation(self.cameraPositionNode)
                local pos = self.position
                local lastPos = self.lastTargetPosition
                pos[1],pos[2],pos[3] = self:getSmoothed(self.positionSmoothingParameter, pos[1],pos[2],pos[3], x,y,z, lastPos[1],lastPos[2],lastPos[3], interpDt)
                lastPos[1],lastPos[2],lastPos[3] = x,y,z
                self:setSeparateCameraPose()
            end
        end
    end
end

function CabView:loadMap(name)
	--print("Load Mod: 'CabView'")
	VehicleCamera.update = Utils.overwrittenFunction(VehicleCamera.update, CabView.vehicleCameraUpdate)

	CabView.isInsideCamera = false
	CabView.leanButtonPressed = false
	CabView.lean = 0
	CabView.initialised = false
end

function CabView:deleteMap()
end

function CabView:mouseEvent(posX, posY, isDown, isUp, button)
end

function CabView:keyEvent(unicode, sym, modifier, isDown)
end

function CabView:draw()
end

function CabView:update(dt)
	if not CabView.initialised then
		--DO THIS HERE SO IT HAPPENS AFTER MAP HAS LOADED
		if g_gameStateManager:getGameState()==GameState.PLAY then
			CabView.initialised = true
		end
	end
end