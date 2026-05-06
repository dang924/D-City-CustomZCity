AddCSLuaFile()

if SERVER then return end

local lastPos = Vector()
local lastValue = 0
local lerp = Lerp
matproxy.Add( {
	name = "MwEnvMapTintVeh",
	
	init = function(self, mat, values)
		local color = {1, 1, 1} 

		if (values.color != nil) then
			color = string.Explode(" ", string.Replace(string.Replace(values.color, "[", ""), "]", ""))
		end

		self.min = values.min || 0
		self.max = values.max || 1
		self.color = Vector(color[1], color[2], color[3])
		mat:SetTexture("$envmap", values.envmap || "env_cubemap")
	end,

	bind = function(self, mat, ent)
		if (!IsValid(ent)) then return end

		if (!lastPos:IsEqualTol(ent:GetPos(), 1)) then
			local c = render.GetLightColor(ent:GetPos())
			lastValue = (c.x * 0.2126) + (c.y * 0.7152) + (c.z * 0.0722)
			lastValue = math.min(lastValue * 2, 1)
			lastPos = ent:GetPos()
		end

		ent.m_MwEnvMapTintVeh = lerp(10 * RealFrameTime(), ent.m_MwEnvMapTintVeh || 0, lastValue)
		mat:SetVector("$envmaptint", self.color * lerp(ent.m_MwEnvMapTintVeh, self.min, self.max))
	end
})