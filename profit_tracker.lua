skill_spells = {}
profit_tracker = {}
local next_item = nil
local tooltip = LibStub("nTipHelper:1")
local main_frame
local AceAddon = LibStub("AceAddon-3.0",true);
local TSM
if AceAddon then TSM = AceAddon:GetAddon("TradeSkillMaster_Crafting",true) end

local function muckit(str)
	local foo = gsub(str,"|","_")
	print(foo)
end
local function get_link(itemid)
	if (profit_tracker.bags[itemid].link == nil) then profit_tracker.bags[key].itemid = 'nameless #'..itemid end
	return profit_tracker.bags[itemid].link
end
local function dump_table(t)
	for key,value in pairs(t) do
		print(key .. '=' .. value)
	end
end
local function money(money_in)
	local copper = floor(money_in % 100)
	local silver = floor(money_in/100) % 100
	local gold = floor(money_in/10000)
	return gold..'g'..silver..'s'..copper..'c'
end
local function do_tooltip(tipFrame,link,quantity) -- basics taken from tradeskillmaster TSM:LoadTooltip
	local itemID = strmatch(link,"item:(%d+)")
	if not itemID then return end

	local info = profit_tracker.bags[''..itemID]
	if info then
		if info.value == nil then info.value = 0 end
		if info.count == nil then info.count = 0 end
		tooltip:SetFrame(tipFrame)
		tooltip:AddLine(" ", nil, true)
		tooltip:SetColor(1,1,0)
		local each = info.value/info.count
		tooltip:AddLine('Profit Tracker count: '..info.count..' value: '..money(info.value)..' each: '..money(each),nil,true)
		if (quantity) then tooltip:AddLine(quantity..' are worth '..money(each*quantity),nil,true); end
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
			local itemlink = GetInboxItemLink(i,1)
			if itemlink ~= nil then
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
				log_change('AH_BUY|'..itemid..'|'..buyout..'|'..bid..'|'..itemName..'|'..playerName..'|'..count)
				return
			end
		elseif invoiceType == 'seller' then
			local msg = 'AH_SALE|'..itemName..'|'..playerName..'|'..buyout..'|'..bid..'|'..count..'|'..deposit..'|'..consignment
			print(msg)
			TakeInboxMoney(i)
			log_change(msg)
			return
		elseif invoiceType then
			print(invoiceType)
		end
	end
	if MailAddonBusy == 'profit_tracker' then MailAddonBusy = nil end
end
function scan_bags()
	local lost_msg = {}
	local gained_msg = {}
	local temp = {} -- all items currently held
	local names = {}
	for i = 0,4 do -- loop over bags and populate temp
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
	local cur_money = GetMoney()
	local money_lost = 0
	local lost = {}
	local gained = {}
	local value_changing = 0
	if profit_tracker.money == nil then profit_tracker.money = cur_money end
	if profit_tracker.money == cur_money then
	else
		money_lost = profit_tracker.money - cur_money
		profit_tracker.money = cur_money
	end
	for key,value in pairs(temp) do -- for each item in my bags, check db
		local entry = profit_tracker.bags[key]
		if profit_tracker.bags[key] then -- item already tracked
			entry.link = names[key]
			if profit_tracker.bags[key].value == nil then profit_tracker.bags[key].value = 0 end
			if profit_tracker.bags[key].count == value then -- no change
			else -- count changed
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
	for key,value in pairs(profit_tracker.bags) do -- for each item in db, check if its NOT in bags(temp)
		local entry = temp[key]
		if temp[key] then -- its fine, loop above got it
		else
			if profit_tracker.bags[key].count > 0 then
				lost[key] = profit_tracker.bags[key].count
				profit_tracker.bags[key].count = 0
			end
		end
	end
	if money_lost > 0 then
		print('money lost: '..money(money_lost))
	else
		if money_lost < 0 then
			print('money gained: '..money(-1*money_lost))
		end
	end

	local gain_count = 0
	local loss_count = 0

	for key,value in pairs(gained) do gain_count = gain_count + 1 end
	for key,value in pairs(lost) do loss_count = loss_count + 1 end

	if (loss_count > 0) then print('lost '..loss_count..' seperate items') end
	if loss_count == 0 and gain_count > 0 and money_lost > 0 then value_changing = money_lost end -- i lost no items, gained some items, and lost money
	for key,value in pairs(lost) do
		local per_item = profit_tracker.bags[key].value / (profit_tracker.bags[key].count + value)
		value_changing = value_changing + (per_item * value)
		profit_tracker.bags[key].value = profit_tracker.bags[key].value - (per_item * value)

		print(get_link(key)..' went down '..value..' worth '..money(per_item * value))
		table.insert(lost_msg,key..','..value..','..per_item)
		if (key == 54440) then update_dreamcloth(profit_tracker.bags[key].value / profit_tracker.bags[key].count) end
	end
	if (gain_count > 0) then print('gained '..gain_count..' seperate item types') end
	for key,value in pairs(gained) do
		print(names[key]..' went up '..value..' worth '..money(value_changing / gain_count))
		profit_tracker.bags[key].value = profit_tracker.bags[key].value + (value_changing / gain_count)
		table.insert(gained_msg,key..','..value..','..(value_changing / gain_count/value))
		if (key == 54440) then update_dreamcloth(profit_tracker.bags[key].value / profit_tracker.bags[key].count) end
	end
	if gain_count == 0 and value_changing > 0 then
		print('value changing '..money(value_changing))
		local change = (money_lost * -1) - value_changing
		if change > 0 then
			print('PROFIT!!! '..money(change))
		else
			if change < 0 then
				print('loss:( '..money(change*-1))
			end
		end
	end
	if value_changing or gain_count or loss_count then
		log_change('CRAFTING|'..table.concat(lost_msg,'/')..'|'..table.concat(gained_msg,'/')..'|'..value_changing..'|'..gain_count..'|'..loss_count)
	end
end
function show_assets()
	local count = 0
	local value = 0
	for key,item in pairs(profit_tracker.bags) do
		count = count + item.count
		value = value + item.value
	end
	print(count..' items totaling '..money(value))
end
local function update_dreamcloth(price)
	if (TSM == nil) then return end
	local dreamcloth = TSM.Data.Tailoring.mats[54440]
	dreamcloth.customValue = price
	dreamcloth.source = 'custom'
end
local delay = nil
local function delay_scan()
	delay = delay - 1
	if delay < 1 then
		main_frame:SetScript("OnUpdate",nil)
		delay = nil
		scan_bags()
		if MailAddonBusy == 'profit_tracker' then
			check_mailbox()
		end
	end
end
local function rescan_ah()
	local count = GetNumAuctionItems('owner')
	print(count..' auctions found')
	local i
	for i = 1,count do
		name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo('owner',i)
		if name then
			print(i..' '..name)
		end
	end
end
local function start_scan()
	delay = 30
	main_frame:SetScript("OnUpdate",delay_scan)
end
local function delay_mailbox()
	main_frame:SetScript("OnUpdate",nil)
	check_mailbox()
end
local function eventHandler(self,event,...)
	local arg1,arg2,arg3 = ...
	if event == "BAG_UPDATE" then
		start_scan()
	elseif event == "LOOT_CLOSED" then
		start_scan()
		print(event)
	elseif event == 'MAIL_SHOW' then
		MailAddonBusy = 'profit_tracker'
		check_mailbox()
	elseif event == 'MAIL_INBOX_UPDATE' then
		MailAddonBusy = 'profit_tracker'
		main_frame:SetScript("OnUpdate",delay_mailbox)
	elseif event == 'MAIL_CLOSED' then
		if MailAddonBusy == 'profit_tracker' then
			print('profit tracker interupted while scanning mailbox')
			MailAddonBusy = nil
		end
		scan_bags()
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
			--print(spellid)
			--print(spell_name)
			--print(GetSpellInfo(spellid))
		end
	elseif event == "AUCTION_OWNED_LIST_UPDATE" then
		rescan_ah()
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
	frame:RegisterEvent("PLAYER_MONEY")
	frame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
	frame:SetScript("OnEvent",eventHandler)
	main_frame = frame
	tooltip:Activate()
	tooltip:AddCallback(function(...) do_tooltip(...) end)
end
profit_tracker_init()

