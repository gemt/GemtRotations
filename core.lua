--[[
	function UpdateVars()
	function CastSnD()
	function CastEvis()
	function PlayRogue()
	function BuffIndex(buffname)
	function BuffDur(buffName)
	function NumCP()
	function SpellInRange(actionBarIndex)
	function SpellTexture(spell)
	function SpellIndex(spellName) 
	function SpellCD(spell)
	function _print(msg)
	function AutoAttack(attackIndex)
]]--

-- http://wowwiki.wikia.com/wiki/Events/Removed "SPELLCAST_STOP" -- this is where the magic is at
-- SPELLCAST_INTERRUPTED 
-- SPELLCAST_FAILURE

local cp 		= 0;
local sndDur 	= 0;
local gcd 	= 0;
local energy 	= 0;
	
local used_evis = false;
local waiting_for_evis_confirmation = false;
local current_state = 1;

local Frame = CreateFrame("FRAME");
Frame:RegisterEvent("SPELLCAST_STOP")
Frame:RegisterEvent("UNIT_SPELLMISS");
Frame:RegisterEvent("SPELLCAST_INTERRUPTED")
Frame:RegisterEvent("SPELLCAST_FAILURE")
Frame:RegisterEvent("UNIT_COMBO_POINTS");
Frame:RegisterEvent("PLAYER_LEAVE_COMBAT");

local spell_start_timer = 0;

Frame:SetScript("OnEvent", function()
	--_print(event);
	if event == "PLAYER_LEAVE_COMBAT" then
		ResetVariables();
		_print("left combat. Reset variables");
	end
	
	if event == "SPELLCAST_STOP" then
		--_print("CP: "..NumCP());
		if waiting_for_evis_confirmation == true then
			waiting_for_evis_confirmation = false;
			used_evis = true;
		end
	end
	
	if  event == "SPELLCAST_INTERRUPTED"  
	or event == "SPELLCAST_FAILURE" 
	or event == "UNIT_SPELLMISS" 
	then
		_print(event);
		_print("Got SPELLCAST_INTERRUPTED. Should we not have incremeted RotationIndex?");
	end
	
	--[[
	-- 'RESISTED', 'DODGED', 'PARRIED' or 'BLOCKED'
	-- need to figure out if sinister strike and eviscerate use
	-- energy if it fails in this event
	if event == "UNIT_SPELLMISS" then
		--spell_failed = true;
		_print("UNIT_SPELLMIS triggered");
	end
	]]--
end)

Frame:SetScript("OnUpdate", function()
	
	--[[
	if spell_start_timer > 0.5 and spell_failed ~= true then
		-- incrementing the rotation index,
		-- setting it back to 1 if we have finished one rotation.
		RotationIndex = RotationIndex + 1;
		if RotationIndex > rotation_count then
			RotationIndex = 1;
		end
	end
	]]--
end)

function ResetVariables()
	cp 		= NumCP();
	sndDur 	= BuffDur("Slice and Dice");
	gcd 		= SpellCD("Sinister Strike");
	energy 	= UnitMana("player");
	
	used_evis = false;
	waiting_for_evis_confirmation = false;
	
	current_state = 1;
end

function UpdateVars()
	cp 		= NumCP();
	sndDur 	= BuffDur("Slice and Dice");
	gcd 		= SpellCD("Sinister Strike");
	energy 	= UnitMana("player");
end

function CastSnD()
	--add some check that prevents SnD from being used if duration 
	--is already rather high. If energy is also high, consider skipping to some other state.
	CastSpellByName("Slice and Dice");
end

function CastEvis()
	if cp ~= 5 then	
		_print("tried to cast evis with "..cp.."CP.");
	end
	CastSpellByName("Eviscerate");
	spell_start_timer = GetTime();
	waiting_for_evis_confirmation = true;
end

function CastSinister()
	CastSpellByName("Sinister Strike");
end

function FindState()
	if current_state == 1 then 	-- cast SS while cp < 3
		if cp >= 3 then
			current_state = 2;
		end
	elseif current_state == 2 then	-- cast SnD
		--SnD is used with at least 3 CP, which is 15 sec duration.
		--Using 10 sec as a simple way to see if it was "recently" used.
		_print(sndDur);
		if sndDur > 10 then
			current_state = 3;
		end
	elseif current_state == 3 then	-- cast SS while cp < 5
		if cp == 5 then
			current_state = 4;
		end
	elseif current_state == 4 then	-- cast SnD
		--SnD is used with 5 CP, which is 21 sec duration.
		--Using 15 sec as a simple way to see if it was "recently" used.
		if sndDur > 15 then
			current_state = 5;
		end
	elseif current_state == 5 then	-- cast SS while cp < 5
		--Maybe we need to jump to state 6 if sndDur is less
		--than a certain number in order to keep it up
		if cp == 5 then 
			current_state = 6;
		end
		if sndDur < 10 then
			_print("in 5th state, but SnD duration is < 5. Consder using evis before 5CP?");
		end
	elseif current_state == 6 then	-- cast Evis
		--need a good way to see if we recently casted evis so we can jump to state 10
		if used_evis == true then
			used_evis = false;
			current_state = 1;
		end
	end
end

function HandleState()
	if current_state == 1 then 	-- cast SS
		CastSinister();
	elseif current_state == 2 then	-- cast SnD
		CastSnD();
	elseif current_state == 3 then	-- cast SS 
		CastSinister();
	elseif current_state == 4 then	-- cast SnD
		CastSnD();
	elseif current_state == 5 then	-- cast SS
		CastSinister();
	elseif current_state == 6 then	-- cast Evis
		CastEvis();
	end
end

-- Rotation: 3SnD 5SnD 4Evis repeat
function PlayRogue()

	UpdateVars();
	
	--[[
	_print("ComboPoints: "..cp)
	_print("SnD duration: "..sndDur)
	_print("GlobalCooldown: "..gcd)
	_print("Energy: "..energy")
	]]--
	
	-- Make sure autoattack is on
	AutoAttack(48);
	
	FindState();
	HandleState();
	
	_print("state:"..current_state);
	
end

-- Returns the index in the buff frame of buff 'buffname'
--
-- Returns -1 if 'buffname' was not found.
-- NOTE: Will only be able to find buffs that the player 
-- calling the function has in his spellbook
function BuffIndex(buffname)
	local i=1;
	local buffTexture=SpellTexture(buffname)
	
	if buffTexture == -1 then 
		return -1;
	end

	while UnitBuff("player",i)
	do
		local spell,rank=UnitBuff("player",i)
		if spell == buffTexture then
			local ret_val = i -1;
			return ret_val;
		end
		i=i+1
	end
	
	return -1
end

-- Returns the duration of buff 'buffName'
--
-- NOTE: Will only be able to find buffs that the player 
-- calling the function has in his spellbook
function BuffDur(buffName)
	local index = BuffIndex(buffName);
	if index >=0 then 
		local _retVal = GetPlayerBuffTimeLeft(index);
		return _retVal;
	else
		return 0;
	end
end

-- Returns the number of ComboPoints on the target
function NumCP()
	return GetComboPoints("player","target");
end

-- Returns true if the spell at 'actionBarIndex' is in range of players target.
-- Supposedly not a very fast function, may slow things down if spammed
function SpellInRange(actionBarIndex)
	return IsActionInRange(actionBarIndex);
end


-- Returns the spell texture path of 'spell'.
-- Returns nil if 'spell' is not found.
function SpellTexture(spell)
	local demoID = SpellIndex(spell)
	retVal = GetSpellTexture(demoID, BOOKTYPE_SPELL);
	return retVal;
end

-- Returns the spellbook index of 'spellName'
-- If 'spellName' is not found, nil is returned.
function SpellIndex(spellName) 
	local i = 1; 
	while true do 
		local name, rank = GetSpellName(i, "spell");
		
		if name and strfind(strlower(spellName), strlower(name)) then
			return i; 
		elseif not name then
			return nil
		end
		i = i + 1; 
	end
	return nil;
end

-- Returns the cooldown of 'spell'
-- If 'spell' is not found, returns nil.
function SpellCD(spell)
	local num = SpellIndex(spell);
	
	if not num then 
		return nil
	end
	
	start,dur = GetSpellCooldown(num,'spell');
	rcd=start+dur-GetTime(); 
	if rcd < 0 then 
		return 0; 
	else 
		return rcd; 
	end 
end


--Prints a message in the default chatframe.
--Only visible to you.
function _print( msg )
    if not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage ( msg )
end

-- Toggles autoattack on. 
-- Parameter is action bars index of the 'attack' spell
function AutoAttack(attackIndex)
	if not IsCurrentAction(attackIndex) then
		UseAction(attackIndex);
	end
end