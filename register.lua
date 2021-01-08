-- ============================================================= --
-- Cabin View MOD
-- ============================================================= --
CabViewREGISTER = {};

g_specializationManager:addSpecialization('cabView', 'CabView', Utils.getFilename('CabView.lua', g_currentModDirectory), true);

for name, data in pairs( g_vehicleTypeManager:getVehicleTypes() ) do
	local vehicleType = g_vehicleTypeManager:getVehicleTypeByName(tostring(name));
	if  SpecializationUtil.hasSpecialization(Drivable,  data.specializations) and
		SpecializationUtil.hasSpecialization(Motorized, data.specializations) and
		SpecializationUtil.hasSpecialization(Enterable, data.specializations) and
		not SpecializationUtil.hasSpecialization(ConveyorBelt, data.specializations) then
			--print(tostring(vehicleType.name))
			g_vehicleTypeManager:addSpecialization(name, 'cabView') 
	end
end
