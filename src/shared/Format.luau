-- Formatage des nombres pour l'affichage (ReplicatedStorage.Shared.Format)
local Format = {}

-- 12345 -> "12 345"
function Format.number(value: number): string
	local digits = tostring(math.floor(value))
	local negative = digits:sub(1, 1) == "-"
	if negative then
		digits = digits:sub(2)
	end
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (if negative then "-" else "") .. (grouped:gsub("^%s", ""))
end

local SUFFIXES = {
	{ 1e15, " Bd" },
	{ 1e12, " B" },
	{ 1e9, " Md" },
	{ 1e6, " M" },
	{ 1e3, " k" },
}

-- 1234 -> "1,2 k", 3500000 -> "3,5 M" (en dessous de 10 000, le nombre complet)
function Format.short(value: number): string
	value = math.floor(value)
	if math.abs(value) < 10000 then
		return Format.number(value)
	end
	for _, entry in SUFFIXES do
		if math.abs(value) >= entry[1] then
			local scaled = value / entry[1]
			local text = if scaled >= 100 then ("%d"):format(scaled) else ("%.1f"):format(math.floor(scaled * 10) / 10)
			return (text:gsub("%.0$", ""):gsub("%.", ",")) .. entry[2]
		end
	end
	return Format.number(value)
end

-- 125 -> "2 min 05 s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	local rest = seconds % 60
	if hours > 0 then
		return ("%d h %02d"):format(hours, minutes)
	elseif minutes > 0 then
		return ("%d min %02d s"):format(minutes, rest)
	end
	return ("%d s"):format(rest)
end

function Format.percent(value: number): string
	if value >= 10 then
		return ("%d %%"):format(math.floor(value + 0.5))
	end
	return (("%.1f %%"):format(value):gsub("%.", ","))
end

return Format
