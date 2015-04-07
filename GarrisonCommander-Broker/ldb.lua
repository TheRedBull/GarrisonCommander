local me, ns = ...
if (not LibStub:GetLibrary("LibDataBroker-1.1",true)) then
	--@debug@
	print("Missing libdatabroker")
	--@end-debug@
	return
end
local pp=print
if (LibDebug) then LibDebug() end
--@debug@
LoadAddOn("Blizzard_DebugTools")
--@end-debug@
local L=LibStub("AceLocale-3.0"):GetLocale(me,true)
--local addon=LibStub("AceAddon-3.0"):NewAddon(me,"AceTimer-3.0","AceEvent-3.0","AceConsole-3.0") --#addon
local addon=LibStub("LibInit"):NewAddon(me,"AceTimer-3.0","AceEvent-3.0","AceConsole-3.0","AceHook-3.0") --#addon
local C=addon:GetColorTable()
local dataobj --#Missions
local farmobj --#Farms
local workobj --#Works
local SecondsToTime=SecondsToTime
local type=type
local strsplit=strsplit
local tonumber=tonumber
local tremove=tremove
local time=time
local tinsert=tinsert
local tContains=tContains
local G=C_Garrison
local format=format
local table=table
local math=math
local GetQuestResetTime=GetQuestResetTime
local CalendarGetDate=CalendarGetDate
local CalendarGetAbsMonth=CalendarGetAbsMonth
local GameTooltip=GameTooltip
local pairs=pairs
local select=select
local READY=READY
local NEXT=NEXT
local NONE=C(NONE,"Red")
local DONE=C(DONE,"Green")
local NEED=C(NEED,"Red")

local CAPACITANCE_SHIPMENT_COUNT=CAPACITANCE_SHIPMENT_COUNT -- "%d of %d Work Orders Available";
local CAPACITANCE_SHIPMENT_READY=CAPACITANCE_SHIPMENT_READY -- "Work Order ready for pickup!";
local CAPACITANCE_START_WORK_ORDER=CAPACITANCE_START_WORK_ORDER -- "Start Work Order";
local CAPACITANCE_WORK_ORDERS=CAPACITANCE_WORK_ORDERS -- "Work Orders";
local GARRISON_FOLLOWER_XP_ADDED_SHIPMENT=GARRISON_FOLLOWER_XP_ADDED_SHIPMENT -- "%s has earned %d XP for completing %d |4Work Order:Work Orders;.";
local GARRISON_LANDING_SHIPMENT_LABEL=GARRISON_LANDING_SHIPMENT_LABEL -- "Work Order";
local GARRISON_LANDING_SHIPMENT_STARTED_ALERT=GARRISON_LANDING_SHIPMENT_STARTED_ALERT -- "Work Order Started";
local GARRISON_SHIPMENT_IN_PROGRESS=GARRISON_SHIPMENT_IN_PROGRESS -- "Work Order In-Progress";
local GARRISON_SHIPMENT_READY=GARRISON_SHIPMENT_READY -- "Work Order Ready";
local QUEUED_STATUS_WAITING=QUEUED_STATUS_WAITING -- "Waiting"
local CAPACITANCE_ALL_COMPLETE=format(CAPACITANCE_ALL_COMPLETE,'') -- "All work orders will be completed in: %s";
local  GARRISON_NUM_COMPLETED_MISSIONS=format(GARRISON_NUM_COMPLETED_MISSIONS,'999'):gsub('999','') -- "%d Completed |4Mission:Missions;";
local KEY_BUTTON1="Shift " .. KEY_BUTTON1
local KEY_BUTTON2="Shift " .. KEY_BUTTON2
local EMPTY=EMPTY -- "Empty"
local dbversion=1
local frequency=5
local ldbtimer=nil

local spellids={
	[158754]='herb',
	[158745]='mine',
	[170599]='mine',
	[170691]='herb',
}
local buildids={
	mine={61,62,63},
	herb={29,136,137}
}
local names={
	mine="Lunar Fall",
	herb="Herb Garden"
}
local today=0
local yesterday=0
local lastreset=0
function addon:ldbCleanup()
	local now=time()
	for i=1,#self.db.realm.missions do
		local s=self.db.realm.missions[i]
		if (type(s)=='string') then
			local t,ID,pc=strsplit('.',s)
			t=tonumber(t) or 0
			if pc==ns.me and t < now then
				tremove(self.db.realm.missions,i)
				i=i-1
			end
		end
	end
end
function addon:ldbUpdate()
	dataobj:Update()
end
function addon:GARRISON_MISSION_STARTED(event,missionID)
	local duration=select(2,G.GetPartyMissionInfo(missionID)) or 0
	local k=format("%015d.%4d.%s",time() + duration,missionID,ns.me)
	tinsert(self.db.realm.missions,k)
	table.sort(self.db.realm.missions)
	self:ldbUpdate()
end
function addon:CheckEvents()
	if (G.IsOnGarrisonMap()) then
		self:RegisterEvent("UNIT_SPELLCAST_START")
		--self:RegisterEvent("ITEM_PUSH")
	else
		self:UnregisterEvent("UNIT_SPELLCAST_START")
		--self:UnregisterEvent("ITEM_PUSH")
	end
end
function addon:ZONE_CHANGED_NEW_AREA()
	self:ScheduleTimer("CheckEvents",1)
	self:ScheduleTimer("DiscoverFarms",1)

end
function addon:UNIT_SPELLCAST_START(event,unit,name,rank,lineID,spellID)
	if (unit=='player') then
		if spellids[spellID] then
			name=names[spellids[spellID]]
			if not self.db.realm.farms[ns.me][name] or  today > (tonumber(self.db.realm.farms[ns.me][name]) or 0) then
				self:CheckDateReset()
				self.db.realm.farms[ns.me][name]=today
				farmobj:Update()
			end
		end
	end
end
function addon:ITEM_PUSH(event,bag,icon)
--@debug@
	self:print(event,bag,icon)
--@end-debug@
end
function addon:CheckDateReset()
	local oldToday=today
	local reset=GetQuestResetTime()
	local weekday, month, day, year = CalendarGetDate()
	if (day <1 or reset<1) then
		self:ScheduleTimer("CheckDateReset",1)
		return day,reset
	end

	today=year*10000+month*100+day
	if month==1 and day==1 then
		local m, y, numdays, firstday = CalendarGetAbsMonth( 12, year-1 )
		yesterday=y*10000+m*100+numdays
	elseif day==1 then
		local m, y, numdays, firstday = CalendarGetAbsMonth( month-1, year)
		yesterday=y*10000+m*100+numdays
	else
		yesterday=year*10000+month*100+day-1
	end
	if (reset<3600*3) then
		today=yesterday
	end
	self:ScheduleTimer("CheckDateReset",60)
--@debug@
	if (today~=oldToday) then
		self:Popup(format("o:%s y:%s t:%s r:%s [w:%s m:%s d:%s y:%s] ",oldToday,yesterday,today,reset,CalendarGetDate()))
		dataobj:Update()
		farmobj:Update()
		workobj:Update()
	end
--@end-debug@
end
function addon:CountMissing()
	local tot=0
	local missing=0
	for p,j in pairs(self.db.realm.farms) do
		for s,_ in pairs(j) do
			tot=tot+1
			if not j[s] or j[s] < today then missing=missing+1 end
		end
	end
	return missing,tot
end
function addon:CountEmpty()
	local tot=0
	local missing=0
	local expire=time()+3600*24
	for p,j in pairs(self.db.realm.orders) do
		for s,_ in pairs(j) do
			tot=tot+1
			if not j[s] or j[s] < expire then missing=missing+1 end
		end
	end
	return missing,tot
end
function addon:WorkUpdate(event,success,shipments_running,shipmentCapacity,plotID)

	local buildings = G.GetBuildings();
	for i = 1, #buildings do
		if plotID == buildings[i].plotID then
			local buildingID,name=G.GetBuildingInfo(buildings[i].buildingID)
			local numPending = G.GetNumPendingShipments()
			if not numPending or numPending==0 then
				if not shipments_running or shipments_running==0 then
					self.db.realm.orders[ns.me][name]=0
				end
			else
				local endQueue=select(6,G.GetPendingShipmentInfo(numPending))
				self.db.realm.orders[ns.me][name]=time()+endQueue
			end
		end
	end
end
function addon:DiscoverFarms()
	local buildings = G.GetBuildings();
	for i = 1, #buildings do
		local buildingID = buildings[i].buildingID;
		if ( buildingID) then
			local name, texture, shipmentCapacity, shipmentsReady, shipmentsTotal, creationTime, duration, timeleftString, itemName, itemIcon, itemQuality, itemID = G.GetLandingPageShipmentInfo(buildingID);
			if (tContains(buildids.mine,buildingID)) then
				names.mine=name
				if not self.db.realm.farms[ns.me][name] then
					self.db.realm.farms[ns.me][name]=0
				end
			end
			if (tContains(buildids.herb,buildingID)) then
				names.herb=name
				if not self.db.realm.farms[ns.me][name] then
					self.db.realm.farms[ns.me][name]=0
				end
			end
			if (shipmentCapacity ) then
				if (creationTime) then
					local numPending=shipmentsTotal-shipmentsReady
					local endQueue=duration*numPending-(time()-creationTime)
					if not numPending or numPending==0 then
						self.db.realm.orders[ns.me][name]=0
					else
						self.db.realm.orders[ns.me][name]=time()+endQueue
					end
				end
			end
		end
	end
	farmobj:Update()
end
function addon:SetDbDefaults(default)
	default.realm={
		missions={},
		farms={["*"]={
				["*"]=false
			}},
		orders={["*"]={
				["*"]=false
			}},
		dbversion=1
	}
end
function addon:OnInitialized()
	if dbversion>self.db.realm.dbversion then
		self.db:ResetDB()
		self.db.realm.dbversion=dbversion
	end
	-- Compatibility with alpha
	if self.db.realm.lastday then
		for k,v in pairs(addon.db.realm.farms) do
			for s,d in pairs(v) do
				v[s]=tonumber(self.db.realm.lastday) or 0
			end
		end
		self.db.realm.lastday=nil
	end
	-- Extra sanity check for cases where a broken version messed up things
	for k,v in pairs(addon.db.realm.farms) do
		for s,d in pairs(v) do
			v[s]=tonumber(v[s]) or 0
		end
	end

	ns.me=GetUnitName("player",false)
	self:RegisterEvent("GARRISON_MISSION_STARTED")
	self:RegisterEvent("GARRISON_MISSION_NPC_OPENED","ldbCleanup")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("SHIPMENT_CRAFTER_INFO")
	--self:RegisterEvent("SHIPMENT_CRAFTER_REAGENT_UPDATE",print)
	self:AddLabel(GARRISON_NUM_COMPLETED_MISSIONS)
	self:AddToggle("OLDINT",false,L["Use old interface"],L["Uses the old, more intrusive interface"])
	self:AddToggle("SHOWNEXT",false,L["Show next toon"],L["Show the next toon whicg will complete a mission"])
	self:AddSlider("FREQUENCY",5,1,60,L["Update frequency"])
	frequency=self:GetNumber("FREQUENCY",5)
end
function addon:ApplyFREQUENCY(value)
	frequency=value
	if (ldbtimer) then
		self:CancelTimer(ldbtimer)
	end
	ldbtimer=self:ScheduleRepeatingTimer("ldbUpdate",frequency)
end
function addon:SHIPMENT_CRAFTER_INFO(...)
	self:WorkUpdate(...)

end
function addon:DelayedInit()
	self:CheckDateReset()
	self:WorkUpdate()
	self:ZONE_CHANGED_NEW_AREA()
	ldbtimer=self:ScheduleRepeatingTimer("ldbUpdate",frequency)
	farmobj:Update()
	workobj:Update()
	dataobj:Update()
end
function addon:OnEnabled()
	self:ScheduleTimer("DelayedInit",5)
end
function addon:Gradient(perc)
	return self:ColorGradient(perc,1,0,0,1,1,0,0,1,0)
end

function addon:ColorGradient(perc, ...)
	if perc >= 1 then
		local r, g, b = select(select('#', ...) - 2, ...)
		return r, g, b
	elseif perc <= 0 then
		local r, g, b = ...
		return r, g, b
	end
	local num = select('#', ...) / 3
	local segment, relperc = math.modf(perc*(num-1))
	local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)
	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end
function addon:ColorToString(r,g,b)
	return format("%02X%02X%02X", 255*r, 255*g, 255*b)
end

dataobj=LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("GC-Missions", {
	type = "data source",
	label = "GC "  .. GARRISON_NUM_COMPLETED_MISSIONS,
	text=QUEUED_STATUS_WAITING,
	category = "Interface",
	icon = "Interface\\ICONS\\ACHIEVEMENT_GUILDPERK_WORKINGOVERTIME"
})
farmobj=LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("GC-Farms", {
	type = "data source",
	label = "GC " .. "Harvesting",
	text=QUEUED_STATUS_WAITING,
	category = "Interface",
	icon = "Interface\\Icons\\Inv_ore_gold_nugget"
	--icon = "Interface\\Icons\\Trade_Engineering"
})
workobj=LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("GC-WorkOrders", {
	type = "data source",
	label = "GC " ..CAPACITANCE_WORK_ORDERS,
	text=QUEUED_STATUS_WAITING,
	category = "Interface",
	icon = "Interface\\Icons\\Trade_Engineering"
})
function farmobj:Update()
	local n,t=addon:CountMissing()
	if (t>0) then
		local c=addon:ColorToString(addon:Gradient((t-n)/t))
		farmobj.text=format("|cff%s%d|r/|cff%s%d|r",c,t-n,C.Green.c,t)
	else
		farmobj.text=NONE
	end
end
function farmobj:OnTooltipShow()
	self:AddDoubleLine(L["Time to next reset"],SecondsToTime(GetQuestResetTime()))
	for k,v in kpairs(addon.db.realm.farms) do
		if (k==ns.me) then
			self:AddLine(k,C.Green())
		else
			self:AddLine(k,C.Orange())
		end
		for s,d in kpairs(v) do
			self:AddDoubleLine(s,(d and d==today) and DONE or NEED)
		end
	end
	self:AddLine("Manually mark my tasks:",C:Cyan())
	self:AddDoubleLine(KEY_BUTTON1,DONE)
	self:AddDoubleLine(KEY_BUTTON2,NEED)
	self:AddLine(me,C.Silver())
end

function dataobj:OnTooltipShow()
	self:AddLine(L["Mission awaiting"])
	local db=addon.db.realm.missions
	local now=time()
	for i=1,#db do
		if db[i] then
			local t,missionID,pc=strsplit('.',db[i])
			t=tonumber(t) or 0
			local name=G.GetMissionName(missionID)
			if (name) then
				local msg=format("|cff%s%s|r: %s",pc==ns.me and C.Green.c or C.Orange.c,pc,name)
				if t > now then
					self:AddDoubleLine(msg,SecondsToTime(t-now),nil,nil,nil,C.Red())
				else
					self:AddDoubleLine(msg,DONE)
				end
			end
		end
	end

	self:AddLine(me,C.Silver())
end

function dataobj:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	dataobj.OnTooltipShow(GameTooltip)
	GameTooltip:Show()
end

function dataobj:OnLeave()
	GameTooltip:Hide()
end
function farmobj:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	farmobj.OnTooltipShow(GameTooltip)
	GameTooltip:Show()
end
function workobj:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	workobj.OnTooltipShow(GameTooltip)
	GameTooltip:Show()
end
function workobj:Update()
	local n,t=addon:CountEmpty()
	if (t>0) then
		local c=addon:ColorToString(addon:Gradient((t-n)/t))
		workobj.text=format("|cff%s%d|r/|cff%s%d|r",c,t-n,C.Green.c,t)
	else
		workobj.text=NONE
	end

end
function workobj:OnTooltipShow()
	self:AddLine(CAPACITANCE_WORK_ORDERS)
	for k,v in kpairs(addon.db.realm.orders) do
		if (k==ns.me) then
			self:AddLine(k,C.Green())
		else
			self:AddLine(k,C.Orange())
		end
		for s,d in kpairs(v) do
			local delta=d-time()
			if (delta >0) then
				local hours=delta/(3600*48)
				self:AddDoubleLine(s,SecondsToTime(delta),nil,nil,nil,addon:Gradient(hours))
			else
				self:AddDoubleLine(s,EMPTY,nil,nil,nil,C:Red())
			end
		end
	end
	self:AddLine(me,C.Silver())
end

farmobj.OnLeave=dataobj.OnLeave
workobj.OnLeave=dataobj.OnLeave
function farmobj:OnClick(button)
	if (IsShiftKeyDown()) then
		for k,v in pairs(addon.db.realm.farms) do
			if (k==ns.me) then
				for s,d in pairs(v) do
					if (button=="LeftButton") then
						v[s]=today;
					else
						v[s]=today-1;
					end
				end
			end
		end
		farmobj:Update()
	else
		dataobj:OnClick(button)
	end
	farmobj:Update()

end

function dataobj:OnClick(button)
	if (button=="LeftButton") then
		GarrisonLandingPage_Toggle()
	else
		addon:Gui()
	end
end
workobj.OnClick=dataobj.OnClick
function dataobj:Update()
	if addon:GetBoolean("OLDINT") then return self:OldUpdate() end
	local now=time()
	local n=0
	local t=0
	local prox=false
	for i=1,#addon.db.realm.missions do
		local tm,missionID,pc=strsplit('.',addon.db.realm.missions[i])
		tm=tonumber(tm) or 0
		t=t+1
		if tm>now then
			if not prox then
				local duration=tm-now
				local duration=duration < 60 and duration or math.floor(duration/60)*60
				prox=format("|cff20ff20%s|r in %s",pc,SecondsToTime(duration))
			end
		else
			n=n+1
		end
	end
	if t>0 then
		local c=addon:ColorToString(addon:Gradient(n/t))
		if (prox and addon:GetBoolean("SHOWNEXT")) then
			self.text=format("|cff%s%d|r/|cff%s%d|r (%s)",c,n,C.Green.c,t,prox)
		else
			self.text=format("|cff%s%d|r/|cff%s%d|r",c,n,C.Green.c,t)
		end
	else
		self.text=NONE
	end
end
function dataobj:OldUpdate()
	local now=time()
	local completed=0
	local ready=NONE
	local prox=NONE
	for i=1,#addon.db.realm.missions do
		local t,missionID,pc=strsplit('.',addon.db.realm.missions[i])
		t=tonumber(t) or 0
		if t>now then
			local duration=t-now
			local duration=duration < 60 and duration or math.floor(duration/60)*60
			prox=format("|cff20ff20%s|r in %s",pc,SecondsToTime(duration),completed)
			break;
		else
			if ready==NONE then
				ready=format("|cff20ff20%s|r",pc)
			end
		end
		completed=completed+1
	end
	self.text=format("%s: %s (Tot: |cff00ff00%d|r) %s: %s",READY,ready,completed,NEXT,prox)
end

--@debug@
local function highdebug(tb)
	for k,v in pairs(tb) do
		if type(v) == "function" then
			tb[k]=function(...) print(date(),k) return v(...) end
		end
	end
end
--highdebug(addon)
--highdebug(dataobj)
--highdebug(farmobj)
--highdebug(workobj)
_G.GACB=addon
--@end-debug@
