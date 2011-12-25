skill_spells = {}
profit_tracker = {}
local next_item = nil
local tooltip = LibStub("nTipHelper:1")
local main_frame

local function muckit(str)
	local foo = gsub(str,"|","_")
	print(foo)
end
local function dump_table(t)
	for key,value in pairs(t) do
		print(key .. '=' .. value)
	end
end
function do_tooltip(tipFrame,link,quantity) -- basics taken from tradeskillmaster TSM:LoadTooltip
	local itemID = strmatch(link,"item:(%d+)")
	if not itemID then return end

	local info = profit_tracker.bags[''..itemID]
	if info then
		if info.value == nil then info.value = 0 end
		if info.count == nil then info.count = 0 end
		tooltip:SetFrame(tipFrame)
		tooltip:AddLine(" ", nil, true)
		tooltip:SetColor(1,1,0)
		tooltip:AddLine('Profit Tracker count: '..info.count..' value: '..floor(abs(info.value/10000))..'g each: '..(floor(abs((info.value/info.count)/10000))..'g'),nil,true)
		tooltip:SetColor(0.4,0.4,0.9)
	end
end
local function log_change(msg)
	if profit_tracker.log == nil then profit_tracker.log = {} end
	table.insert(profit_tracker.log,msg)
end
function check_mailbox()
	if profit_tracker.bags == nil then profit_tracker.bags = {} end
	local money = GetMoney()
	if profit_tracker.money == nil then profit_tracker.money = money end

	for i = 0,GetInboxNumItems() do
		--packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(i)
		--bodyText, texture, isTakeable, isInvoice = GetInboxText(i)
		invoiceType, itemName, playerName, bid, buyout, deposit, consignment, moneyDelay, etaHour, etaMin, count = GetInboxInvoiceInfo(i)
		if invoiceType == 'buyer' then
			print(invoiceType)
			print(itemName)
			print(playerName)
			print(bid)
			print(buyout)
			print(count)
			local itemid = strmatch(GetInboxItemLink(i,1),"item:(%d+)")
			muckit(itemid)
			if profit_tracker.bags[''..itemid] == nil then
				profit_tracker.bags[''..itemid] = {}
				profit_tracker.bags[''..itemid].count = 0
				profit_tracker.bags[''..itemid].value = 0
			end
			if profit_tracker.bags[''..itemid].value == nil then profit_tracker.bags[''..itemid].value = 0 end
			profit_tracker.bags[''..itemid].count = profit_tracker.bags[''..itemid].count + count
			profit_tracker.bags[''..itemid].value = profit_tracker.bags[''..itemid].value + buyout
			TakeInboxItem(i,1)
			log_change('AH_BUY|'..itemid..'|'..buyout..'|'..bid..'|'..itemName..'|'..playerName)
			return
		else
			print(invoiceType)
		end
	end
end
function scan_bags()
	local temp = {}
	local names = {}
	for i = 0,4 do
		local numSlots = GetContainerNumSlots(i)
		for j = 1,numSlots do
			local id = GetContainerItemID(i,j)
			if id then
				texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(i,j)
				--print(i..'.'..j..'=='..id..' '..count)
				if lootable then print('lootable'..lootable) end
				if locked then print('locked'..link..count) end
				if temp[''..id] == nil then
					temp[''..id] = count
				else
					temp[''..id] = temp[''..id] + count
				end
				names[''..id] = link
			else
				--print(i..'.'..j..' empty')
			end
		end
	end
	if profit_tracker.bags == nil then profit_tracker.bags = {} end
	local money = GetMoney()
	local money_lost = 0
	local lost = {}
	local gained = {}
	if profit_tracker.money == nil then profit_tracker.money = money end
	if profit_tracker.money == money then
	else
		print('money changed '..profit_tracker.money..' -> '..money..'('..(money - profit_tracker.money)..')')
		profit_tracker.money = money
	end
	for key,value in pairs(temp) do
		local entry = profit_tracker.bags[key]
		if profit_tracker.bags[key] then -- item already tracked
			if profit_tracker.bags[key].value == nil then profit_tracker.bags[key].value = 0 end
			if profit_tracker.bags[key].count == value then -- no change
			else -- count changed
				print('item '..entry.link..' changed count, '..profit_tracker.bags[key].count..' -> '..value)
				local change = value - profit_tracker.bags[key].count
				if change > 0 then -- gain
					gained[key] = change
				else
					lost[key] = change * -1
				end
				profit_tracker.bags[key].count = value
			end
		else -- not tracked
			profit_tracker.bags[key] = {}
			profit_tracker.bags[key].count = value
			profit_tracker.bags[key].value = 0
			print('item '..key..' is newly tracked')
			gained[key] = value
		end
		profit_tracker.bags[key].link = names[key]
	end
	local value_changing = 0
	for key,value in pairs(lost) do
		local per_item = profit_tracker.bags[key].value / (profit_tracker.bags[key].count + value)
		value_changing = value_changing + (per_item * value)
		profit_tracker.bags[key].value = profit_tracker.bags[key].value - (per_item * value)
		print(names[key]..' went down '..value..' worth '..(per_item * value))
	end
	local gain_count = 0
	for key,value in pairs(gained) do gain_count = gain_count + 1 end -- FIXME #gained ??
	print('gained '..gain_count..' seperate item types')
	for key,value in pairs(gained) do
		print(names[key]..' went up '..value..' worth '..(value_changing / gain_count))
		profit_tracker.bags[key].value = profit_tracker.bags[key].value + (value_changing / gain_count)
	end
end
local delay = nil
local function delay_scan()
	delay = delay - 1
	if delay < 1 then
		main_frame:SetScript("OnUpdate",nil)
		delay = nil
		scan_bags()
	end
end
local function start_scan()
	delay = 30
	main_frame:SetScript("OnUpdate",delay_scan)
end
local function eventHandler(self,event,...)
	local arg1,arg2,arg3 = ...
	if event == "BAG_UPDATE" then
		start_scan()
	elseif event == "LOOT_CLOSED" then
		start_scan()
		print(event)
	elseif event == "CHAT_MSG_LOOT" then
		--scan_bags()
		start_scan()
		if next_item then
			message,sender, language, channelString, target, flags, unknown1, channelNumber, channelName, unknown2, counter = ...
			local res = strmatch(message,next_item)
			if res then
				print('item made')
				next_item = nil
				start_scan()
			end
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local caster,spell_name,arg3,arg4,spellid = ...
		if skill_spells[''..spellid] then
			print('its a skill spell')
			next_item = spell_name
		elseif spellid == 51005 then
			print('milling time!')
			--start_scan()
		elseif spellid == 86008 then
			local max = GetNumTradeSkills()
			for i = 1,max do
				skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps = GetTradeSkillInfo(i)
				link = GetTradeSkillRecipeLink(i)
				if link then
					local muck = gsub(link,"|","_")
					local spellid = strmatch(link,"enchant:(%d+)")
					if spellid then
						skill_spells[''..spellid] = link
					else
						print(muck)
					end
				end
			end
		else
			print(spellid)
			print(spell_name)
			print(GetSpellInfo(spellid))
		end
	else
		print(event)
	end
end
local function profit_tracker_init()
	local frame = CreateFrame("FRAME","Profit_Tracker")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	frame:RegisterEvent("CHAT_MSG_LOOT")
	frame:RegisterEvent("LOOT_CLOSED")
	frame:RegisterEvent("MERCHANT_CLOSED")
	frame:RegisterEvent("BAG_UPDATE")
	frame:RegisterEvent("MAIL_SHOW")
	frame:RegisterEvent("MAIL_INBOX_UPDATE")
	frame:RegisterEvent("MAIL_CLOSED")
	frame:SetScript("OnEvent",eventHandler)
	main_frame = frame
	tooltip:Activate()
	tooltip:AddCallback(function(...) do_tooltip(...) end)
end
profit_tracker_init()
