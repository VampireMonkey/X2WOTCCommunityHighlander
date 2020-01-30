//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_StaffSlot.uc
//  AUTHOR:  Mark Nauta
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class XComGameState_StaffSlot extends XComGameState_BaseObject;

var() protected name                   m_TemplateName;
var() protected X2StaffSlotTemplate    m_Template;

var StateObjectReference			   Facility;
var StateObjectReference			   Room; // Use for staff slots that don't have a facility (Build Slot)
var StateObjectReference			   CovertAction;
var StaffUnitInfo					   AssignedStaff;

// Start Issue #706
// DEPRECATED
var int MaxAdjacentGhostStaff; // the maximum number of ghost staff units this slot can create
var int AvailableGhostStaff; // the current number of possible ghost units which can be staffed in adjacent rooms
// DEPRECATED

// The Creator Unit
var StateObjectReference CreatorRef;
// References to Ghost children created by this Staffslot
var array<StateObjectReference> Ghosts;
// End Issue #706

var() bool							   bIsLocked; // If the staff slot is locked and cannot be staffed
var() bool							   bRequireFamous; // If this staff slot requires a famous unit to be staffed there

var() Name							   RequiredClass; // If this staff slot requires a specific soldier class
var() int							   RequiredMinRank; // If this staff slot requires a soldier of at least a specific rank

var StateObjectReference			   LinkedStaffSlot;

//#############################################################################################
//----------------   INITIALIZATION   ---------------------------------------------------------
//#############################################################################################

//---------------------------------------------------------------------------------------
static function X2StrategyElementTemplateManager GetMyTemplateManager()
{
	return class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
}

//---------------------------------------------------------------------------------------
simulated function name GetMyTemplateName()
{
	return m_TemplateName;
}

//---------------------------------------------------------------------------------------
simulated function X2StaffSlotTemplate GetMyTemplate()
{
	if(m_Template == none)
	{
		m_Template = X2StaffSlotTemplate(GetMyTemplateManager().FindStrategyElementTemplate(m_TemplateName));
	}
	return m_Template;
}

//---------------------------------------------------------------------------------------
event OnCreation(optional X2DataTemplate Template)
{
	super.OnCreation( Template );

	m_Template = X2StaffSlotTemplate(Template);
	m_TemplateName = Template.DataName;
}

//#############################################################################################
//----------------   ACCESS   -----------------------------------------------------------------
//#############################################################################################

//---------------------------------------------------------------------------------------
function LockSlot()
{
	bIsLocked = true;
}

//---------------------------------------------------------------------------------------
function UnlockSlot()
{
	bIsLocked = false;
}

//---------------------------------------------------------------------------------------
function bool IsLocked()
{
	return bIsLocked;
}

//#############################################################################################
//----------------   FILLING/EMPTYING   -------------------------------------------------------
//#############################################################################################

//---------------------------------------------------------------------------------------
function bool IsUnitAvailableForThisSlot()
{
	local array<StaffUnitInfo> ValidUnits;
		
	if (IsSlotFilled())
	{
		return true;
	}

	ValidUnits = GetValidUnitsForSlot();
	if (ValidUnits.Length > 0)
	{
		return true;
	}

	return false;
}

//---------------------------------------------------------------------------------------
function array<StaffUnitInfo> GetValidUnitsForSlot()
{
	local array<StaffUnitInfo> ValidUnits;

	if (GetMyTemplate().GetValidUnitsForSlotFn != None)
	{
		ValidUnits = GetMyTemplate().GetValidUnitsForSlotFn(self);
	}

	return ValidUnits;
}

//---------------------------------------------------------------------------------------
function bool ValidUnitForSlot(StaffUnitInfo UnitInfo)
{
	if (GetMyTemplate().IsUnitValidForSlotFn != None)
	{
		return GetMyTemplate().IsUnitValidForSlotFn(self, UnitInfo);
	}

	// If there is no function to check if the unit is valid, assume all staff are allowed
	return true;
}

//---------------------------------------------------------------------------------------
function bool CanStaffBeMoved()
{
	// If slot is filled, check if the staffer can be moved without breaking anything
	if (IsSlotFilled())
	{
		if (GetMyTemplate().CanStaffBeMovedFn != None)
		{
			return GetMyTemplate().CanStaffBeMovedFn(self.GetReference());
		}
	}
	
	// If the slot is empty or no slot check function, no issue
	return true;
}

//---------------------------------------------------------------------------------------
function bool IsStaffSlotBusy()
{
	// If slot is filled, check if the staffer is currently busy working on something
	if (IsSlotFilled())
	{
		if (GetMyTemplate().IsStaffSlotBusyFn != None)
		{
			return GetMyTemplate().IsStaffSlotBusyFn(self);
		}
	}

	// If the slot is empty or no function exists, it is not busy
	return false;
}

//---------------------------------------------------------------------------------------
function bool IsSlotFilled()
{
	local StateObjectReference EmptyRef;

	return (AssignedStaff.UnitRef != EmptyRef);
}

//---------------------------------------------------------------------------------------
// Start Issue #706
// Cleaned boilerplate code
function bool IsSlotFilledWithGhost(optional out XComGameState_StaffSlot GhostOwnerSlot)
{
	if (IsSlotFilled() && IsGhost())
	{
		GhostOwnerSlot = GetCreatorSlot();
		return true;
	}

	return false;
}

function bool IsSlotFilledWithCreator()
{
	if (IsSlotFilled() && IsCreator())
	{
		return true;
	}

	return false;
}

function array<XComGameState_StaffSlot> GetAdjacentStaffSlots()
{
	local array<XComGameState_StaffSlot> AdjacentStaffSlots;
	local XComGameState_HeadquartersRoom RoomState;

	RoomState = GetRoomAbsolute();

	if (RoomState != none)
	{
		AdjacentStaffSlots = RoomState.GetAdjacentStaffSlots();
	}

	return AdjacentStaffSlots;
}

function array<XComGameState_StaffSlot> GetAdjacentGhostCreatingStaffSlots()
{
	local array<XComGameState_StaffSlot> AdjacentStaffSlots;
	local XComGameState_HeadquartersRoom RoomState;

	RoomState = GetRoomAbsolute();

	if (RoomState != none)
	{
		AdjacentStaffSlots = RoomState.GetAdjacentGhostCreatingStaffSlots();
	}

	return AdjacentStaffSlots;
}

function bool HasOpenAdjacentStaffSlots(StaffUnitInfo UnitInfo)
{
	local XComGameState_HeadquartersRoom RoomState;

	RoomState = GetRoomAbsolute();

	if (RoomState != none)
	{
		return RoomState.HasOpenAdjacentStaffSlots(UnitInfo);
	}

	return false;
}

function bool HasAvailableAdjacentGhosts()
{
	local XComGameState_HeadquartersRoom RoomState;

	RoomState = GetRoomAbsolute();

	if (RoomState != none)
	{
		return RoomState.HasAvailableAdjacentGhosts();
	}

	return false;
}

// Get all adjacent staffslots which are filled with ghosts created by this staffslot
function array<XComGameState_StaffSlot> GetAdjacentGhostFilledStaffSlots()
{
	local array<XComGameState_StaffSlot> GhostFilledStaffSlots;
	local XComGameState_HeadquartersRoom RoomState;

	if (IsSlotFilledWithCreator())
	{
		RoomState = GetRoomAbsolute();

		if (RoomState != none)
		{
			GhostFilledStaffSlots = RoomState.GetAdjacentGhostFilledStaffSlots(GetAssignedStaffRef());
		}
	}

	return GhostFilledStaffSlots;
}
// End Issue #706

//---------------------------------------------------------------------------------------
function bool IsSlotEmpty()
{
	return (!IsSlotFilled());
}

//---------------------------------------------------------------------------------------
function XComGameState_Unit GetAssignedStaff()
{
	if (IsSlotFilled())
	{
		return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AssignedStaff.UnitRef.ObjectID));
	}
	else
		return None;
}

//---------------------------------------------------------------------------------------
function XComGameState_Unit GetPairedStaff()
{
	if (IsSlotFilled() && AssignedStaff.PairUnitRef.ObjectID != 0)
	{
		return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AssignedStaff.PairUnitRef.ObjectID));
	}
	else
		return None;
}

//---------------------------------------------------------------------------------------
function StateObjectReference GetAssignedStaffRef()
{
	return AssignedStaff.UnitRef;
}

//---------------------------------------------------------------------------------------
function StateObjectReference GetPairedStaffRef()
{
	return AssignedStaff.PairUnitRef;
}

//---------------------------------------------------------------------------------------
function bool CanBeEmptied()
{
	if (IsSlotFilled())
	{
		if (!CanStaffBeMoved()) // If the unit is providing a critical function at their current slot, they can't be moved
		{
			return false;
		}
	}
	
	return true;
}

//---------------------------------------------------------------------------------------
private function bool RemoveUnitFromOldSlot(StaffUnitInfo UnitInfo)
{
	local XComGameStateHistory History;
	local XComGameState_Unit Unit;
	local XComGameState_StaffSlot OldStaffSlot;
	
	History = `XCOMHISTORY;
	Unit = XComGameState_Unit(History.GetGameStateForObjectID(UnitInfo.UnitRef.ObjectID)); // the new unit attempting to fill this staff slot

	// Check the new unit or ghost's current staffing slot and try to empty it
	if (UnitInfo.bGhostUnit)
	{
		OldStaffSlot = XComGameState_StaffSlot(History.GetGameStateForObjectID(UnitInfo.GhostLocation.ObjectID));
	}
	else if (Unit.StaffingSlot.ObjectID != 0)
	{
		OldStaffSlot = XComGameState_StaffSlot(History.GetGameStateForObjectID(Unit.StaffingSlot.ObjectID));
	}

	if (OldStaffSlot != none)
	{
		// if users are trying to assign a unit to the same slot they were previously on, bail out (do nothing).
		if (ObjectID == OldStaffSlot.ObjectID)
		{
			return false; // If old slot is the same as this slot
		}
		else if (!OldStaffSlot.CanBeEmptied())
		{
			return false; // If old slot cannot be emptied
		}

		OldStaffSlot.EmptySlot();
	}

	return true;
}

//---------------------------------------------------------------------------------------
// Attempts to auto-fill this slot with an available Unit
function AutoFillSlot()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_StaffSlot UnitSlotState;
	local array<XComGameState_StaffSlot> AdjacentGhostCreatingSlots;
	local XComGameState_Unit UnitState;
	local StateObjectReference StaffRef;
	local StaffUnitInfo UnitInfo;
	// Start Issue #706
	local array<XComGameState_Unit> AvailableGhosts;
	// End Issue #706

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	AdjacentGhostCreatingSlots = GetAdjacentGhostCreatingStaffSlots();

	// Cycle through all crew members looking for the unstaffed engineer or scientist to fill the slot, and place them there
	foreach XComHQ.Crew(StaffRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(StaffRef.ObjectID));
		UnitSlotState = UnitState.GetStaffSlot();
		UnitInfo.UnitRef = StaffRef;

		// Only assign a ghost unit if there are adjacent slots with available ghosts next to this slot location
		if (AdjacentGhostCreatingSlots.Length > 0)
		{
			// Start Issue #706
			if ((AdjacentGhostCreatingSlots.Find(UnitSlotState) != INDEX_NONE) && UnitSlotState.HasAvailableGhosts())
			{
				AvailableGhosts = UnitSlotState.GetAvailableGhosts();
				// Take the first free Ghost
				UnitInfo.UnitRef = AvailableGhosts[0].GetReference();
			// End Issue #706
				UnitInfo.bGhostUnit = true;
			}
		}

		// Only allow staffing if this unit is creating available ghost units, or if they are available themselves, and are valid for the slot
		if ((UnitSlotState == none || UnitInfo.bGhostUnit) && ValidUnitForSlot(UnitInfo))
		{
			AssignStaffToSlot(UnitInfo);
			break;
		}
	}
}

//---------------------------------------------------------------------------------------
// Attempts to remove the unit from their current staff slot, and then assign them to this slot
function bool AssignStaffToSlot(StaffUnitInfo UnitInfo)
{
	local XComGameState NewGameState;
	local XComGameState_StaffSlot StaffSlotState;

	// First, if this slot provides ghosts make sure that it can be emptied (and replaced by the new unit)
	// Because all ghost units must be manually unstaffed before the unit creating them can be replaced
	// Start Issue #706
	if (IsSlotFilledWithCreator() && !CanBeEmptied())
	// End Issue #706
	{
		return false;
	}

	// If the unit cannot be removed from its old slot, return false. Otherwise, empty the old staff slot.
	if (!RemoveUnitFromOldSlot(UnitInfo))
	{
		return false;
	}
		
	// Need to update game state for self in case we were emptied earlier (replacing unit in the same slot)
	StaffSlotState = XComGameState_StaffSlot(`XCOMHISTORY.GetGameStateForObjectID(ObjectID));
	StaffSlotState.FillSlot(UnitInfo); // Fill this slot with the unit
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger Event On Staff Select");
	`XEVENTMGR.TriggerEvent('OnStaffSelected', , , NewGameState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	
	return true;
}

//---------------------------------------------------------------------------------------
// This function assumes that all validation on whether the unit can actually be placed
// into this staff slot (ValidUnitForSlot) has already been completed!
function FillSlot(StaffUnitInfo UnitInfo, optional XComGameState NewGameState)
{
	local bool bSubmitNewGameState;

	if (NewGameState == none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Fill Staff Slot");
		bSubmitNewGameState = true;
	}

	EmptySlot(NewGameState);

	if(GetMyTemplate() != none && GetMyTemplate().FillFn != none)
	{
		GetMyTemplate().FillFn(NewGameState, self.GetReference(), UnitInfo);

		`XEVENTMGR.TriggerEvent('StaffUpdated', self, self, NewGameState);
	}
	else
	{
		`RedScreen("StaffSlot Template," @ string(GetMyTemplateName()) $ ", has no FillFn.");
	}

	if (bSubmitNewGameState)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		
		// Alerts and XComHQ updates rely on the history, so only trigger them if the new game state was submitted
		DisplaySlotFilledPopup(UnitInfo);
		UpdateXComHQ();
	}
}

//---------------------------------------------------------------------------------------
function EmptySlot(optional XComGameState NewGameState)
{
	local bool bSubmitNewGameState;

	if(IsSlotFilled())
	{
		if (NewGameState == none)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Empty Staff Slot");
			bSubmitNewGameState = true;
		}

		if(GetMyTemplate().EmptyFn != none)
		{
			GetMyTemplate().EmptyFn(NewGameState, self.GetReference());

			`XEVENTMGR.TriggerEvent('StaffUpdated', self, self, NewGameState);
		}
		else
		{
			`RedScreen("StaffSlot Template," @ string(GetMyTemplateName()) $ ", has no EmptyFn.");
		}
		
		if (bSubmitNewGameState)
		{
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			UpdateXComHQ(); // XComHQ updates rely on the history, so only update if the new game state was submitted
		}
	}
}

//---------------------------------------------------------------------------------------
function EmptySlotStopProject()
{
	local XComGameState NewGameState;

	if (IsSlotFilled())
	{
		if (GetMyTemplate().EmptyStopProjectFn != none)
		{
			GetMyTemplate().EmptyStopProjectFn(self.GetReference());

			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Staff");
			`XEVENTMGR.TriggerEvent('StaffUpdated', self, self, NewGameState);
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
		else
		{
			`RedScreen("StaffSlot Template," @ string(GetMyTemplateName()) $ ", has no EmptyStopProjectFn.");
		}

		UpdateXComHQ(); // XComHQ updates rely on the history, so only update if the new game state was submitted
	}
}

//---------------------------------------------------------------------------------------
function UpdateXComHQ()
{
	local XComGameState_HeadquartersXCom XComHQ;

	class'X2StrategyGameRulesetDataStructures'.static.CheckForPowerStateChange();
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	XComHQ.HandlePowerOrStaffingChange();

	`HQPRES.m_kAvengerHUD.UpdateResources();
}

//#############################################################################################
//----------------   DISPLAY   ----------------------------------------------------------------
//#############################################################################################

//---------------------------------------------------------------------------------------
private function DisplaySlotFilledPopup(StaffUnitInfo UnitInfo)
{
	local XComGameState_HeadquartersRoom RoomState;

	// Trigger the appropriate popup to tell the player about the benefit they have received by filling this staff slot
	if (!GetMyTemplate().bPreventFilledPopup)
	{
		// If the unit just added is a ghost, update its location to its new staff slot before passing to the Alerts
		if (UnitInfo.bGhostUnit)
		{
			UnitInfo.GhostLocation = GetReference();
		}

		RoomState = GetRoom();
		if (RoomState != none)
		{
			if (RoomState.ClearingRoom)
			{
				`HQPRES.UIClearRoomSlotFilled(RoomState.GetReference(), UnitInfo);
			}
			else if (RoomState.UnderConstruction)
			{
				`HQPRES.UIConstructionSlotFilled(RoomState.GetReference(), UnitInfo);
			}
		}
		else
		{
			`HQPRES.UIStaffSlotFilled(GetFacility().GetReference(), GetMyTemplate(), UnitInfo);
		}
	}
}

//---------------------------------------------------------------------------------------
function bool ShouldDisplayToDoWarning()
{
	if (GetMyTemplate().ShouldDisplayToDoWarningFn != none)
	{
		return GetMyTemplate().ShouldDisplayToDoWarningFn(self.GetReference());
	}

	return true;
}

//---------------------------------------------------------------------------------------
function string GetNameDisplayString()
{
	if(GetMyTemplate().GetNameDisplayStringFn != none)
	{
		return GetMyTemplate().GetNameDisplayStringFn(self);
	}

	return "MISSING DISPLAY INFO";
}

//---------------------------------------------------------------------------------------
function string GetSkillDisplayString()
{
	if (GetMyTemplate().GetSkillDisplayStringFn != none)
	{
		return GetMyTemplate().GetSkillDisplayStringFn(self);
	}

	return "MISSING DISPLAY INFO";
}

//---------------------------------------------------------------------------------------
function string GetBonusDisplayString(optional bool bPreview)
{
	if (GetMyTemplate().GetBonusDisplayStringFn != none)
	{
		return GetMyTemplate().GetBonusDisplayStringFn(self, bPreview);
	}

	return "MISSING BONUS DISPLAY INFO";
}

//---------------------------------------------------------------------------------------
function string GetLocationDisplayString()
{
	if (GetMyTemplate().GetLocationDisplayStringFn != None)
	{
		return GetMyTemplate().GetLocationDisplayStringFn(self);
	}

	return "MISSING DISPLAY INFO";
}

//---------------------------------------------------------------------------------------
function string GetUnitTypeImage()
{
	local XComGameState_Unit Unit;

	Unit = GetAssignedStaff();

	if (Unit != none)
	{
		if (Unit.IsEngineer())
		{
			return class'UIUtilities_Image'.const.EventQueue_Engineer;
		}
		else if (Unit.IsScientist())
		{
			return class'UIUtilities_Image'.const.EventQueue_Science;
		}
		else if (Unit.IsSoldier())
		{
			// Start Issue #408
			return Unit.GetSoldierRankIcon();
			// End Issue #408
		}
	}

	return "";
}

//#############################################################################################
//----------------   TYPE   ----------------------------------------------------------------
//#############################################################################################

//---------------------------------------------------------------------------------------
function bool IsHidden()
{
	return GetMyTemplate().bHideStaffSlot;
}

//---------------------------------------------------------------------------------------
function bool IsEngineerSlot()
{
	return GetMyTemplate().bEngineerSlot;
}

//---------------------------------------------------------------------------------------
function bool IsScientistSlot()
{
	return GetMyTemplate().bScientistSlot;
}

//---------------------------------------------------------------------------------------
function bool IsSoldierSlot()
{
	return GetMyTemplate().bSoldierSlot;
}

// Start Issue #706
function bool IsCreator()
{
	return GetMyTemplate().CreatesGhosts;
}
// End Issue #706

//#############################################################################################
//----------------   HELPERS   ----------------------------------------------------------------
//#############################################################################################

//---------------------------------------------------------------------------------------
function XComGameState_FacilityXCom GetFacility()
{
	local StateObjectReference EmptyRef;

	if (Facility != EmptyRef)
	{
		return XComGameState_FacilityXCom(`XCOMHISTORY.GetGameStateForObjectID(Facility.ObjectID));
	}
	else
		return None;
}

//---------------------------------------------------------------------------------------
function XComGameState_HeadquartersRoom GetRoom()
{
	local StateObjectReference EmptyRef;

	if (Room != EmptyRef)
	{
		return XComGameState_HeadquartersRoom(`XCOMHISTORY.GetGameStateForObjectID(Room.ObjectID));
	}
	else
		return None;
}

// Start Issue #706
// If regular GetRoom fails, it will try to get the room with GetFacility
// Cuts down on boilerplate code, based on original boilerplate room code
function XComGameState_HeadquartersRoom GetRoomAbsolute()
{
	local XComGameState_HeadquartersRoom RoomState;
	local XComGameState_FacilityXCom FacilityState;

	RoomState = GetRoom();
	FacilityState = GetFacility();

	if (FacilityState == none)
	{
		if (RoomState != none)
		{
			return RoomState;
		}
	}
	else
	{
		return FacilityState.GetRoom();
	}

	return none;
}
// End Issue #706

//---------------------------------------------------------------------------------------
function XComGameState_CovertAction GetCovertAction()
{
	local StateObjectReference EmptyRef;

	if (CovertAction != EmptyRef)
	{
		return XComGameState_CovertAction(`XCOMHISTORY.GetGameStateForObjectID(CovertAction.ObjectID));
	}
	else
		return None;
}

//---------------------------------------------------------------------------------------
function XComGameState_StaffSlot GetLinkedStaffSlot()
{
	local StateObjectReference EmptyRef;

	if(LinkedStaffSlot != EmptyRef)
	{
		return XComGameState_StaffSlot(`XCOMHISTORY.GetGameStateForObjectID(LinkedStaffSlot.ObjectID));
	}
	else
		return None;
}

//---------------------------------------------------------------------------------------
// Start Issue #706
function AddCreator(StateObjectReference Creator)
{
	CreatorRef = Creator;
}
function RemoveCreator()
{
	local StateObjectReference EmptyRef;

	CreatorRef = EmptyRef;
}
function CreateGhosts(optional XComGameState NewGameState)
{
	local bool bSubmitNewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local X2CharacterTemplateManager TemplateManager;
	local X2CharacterTemplate GhostTemplate;
	local XComGameState_Unit Ghost, Creator;
	local int i, Creator_SkillLevel;
	local name GhostTemplateName, Creator_Country;
	local string Creator_FirstName, Creator_LastName, Creator_Nickname;

	if (NewGameState == none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
		bSubmitNewGameState = true;
	}

	TemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	GhostTemplateName = class'CHHelpers'.static.GetGhostTemplateName();
	GhostTemplate = TemplateManager.FindCharacterTemplate(GhostTemplateName);	
	XComHQ = `XCOMHQ;
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
	Creator = GetAssignedStaff();
	Creator_SkillLevel = Creator.GetSkillLevel();
	Creator_FirstName = Creator.GetFirstName();
	Creator_LastName = Creator.GetLastName();
	Creator_Nickname = Creator.GetNickName();
	Creator_Country = Creator.GetCountry();

	for (i = 0; i < MaxGhosts(); i++)
	{
		Ghost = GhostTemplate.CreateInstanceFromTemplate(NewGameState);
		Ghost.SetCharacterName(Creator_FirstName, Creator_LastName, Creator_Nickname);
		Ghost.SetCountry(Creator_Country);
		Ghost.SetSkillLevel(Creator_SkillLevel);
		XComHQ.AddToCrew(NewGameState, Ghost);
	}
	
	`XEVENTMGR.TriggerEvent('CreateGhosts', self, self, NewGameState);

	if (bSubmitNewGameState)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		UpdateXComHQ(); // XComHQ updates rely on the history, so only update if the new game state was submitted
	}
}
function RemoveGhosts(optional XComGameState NewGameState)
{
	local bool bSubmitNewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference GhostRef;
	local XComGameState_Unit Ghost;

	if (NewGameState == none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
		bSubmitNewGameState = true;
	}

	XComHQ = `XCOMHQ;
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));

	foreach Ghosts(GhostRef)
	{
		Ghost = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', GhostRef.ObjectID));
		XComHQ.RemoveFromCrew(GhostRef);
		NewGameState.RemoveStateObject(Ghost.ObjectID);
	}

	`XEVENTMGR.TriggerEvent('RemoveGhosts', self, self, NewGameState);

	if (bSubmitNewGameState)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		UpdateXComHQ(); // XComHQ updates rely on the history, so only update if the new game state was submitted
	}
}
function bool CreatedBy(StateObjectReference GhostCreatorRef)
{
	return (CreatorRef.ObjectID == GhostCreatorRef.ObjectID);
}
function XComGameState_Unit GetCreator()
{
	return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(CreatorRef.ObjectID));
}
function XComGameState_StaffSlot GetCreatorSlot()
{
	return GetCreator().GetStaffSlot();
}
function bool HasGhosts()
{
	return (Ghosts.Length > 0);
}
function array<XComGameState_Unit> GetAvailableGhosts()
{
	local XComGameStateHistory History;
	local array<XComGameState_Unit> FreeGhosts;
	local XComGameState_StaffSlot Slot;
	local StateObjectReference GhostRef;
	local XComGameState_Unit Ghost;

	History = `XCOMHISTORY;

	foreach Ghosts(GhostRef)
	{
		Ghost = XComGameState_Unit(History.GetGameStateForObjectID(GhostRef.ObjectID));
		Slot = Ghost.GetStaffSlot();

		if (Slot == None)
		{
			// Ghost isn't Staffed, therefore it's available
			FreeGhosts.AddItem(Ghost);
		}
	}

	return FreeGhosts;
}
function array<XComGameState_Unit> GetStaffedGhosts()
{
	local XComGameStateHistory History;
	local array<XComGameState_Unit> BusyGhosts;
	local XComGameState_StaffSlot Slot;
	local StateObjectReference GhostRef;
	local XComGameState_Unit Ghost;

	History = `XCOMHISTORY;

	foreach Ghosts(GhostRef)
	{
		Ghost = XComGameState_Unit(History.GetGameStateForObjectID(GhostRef.ObjectID));
		Slot = Ghost.GetStaffSlot();

		if (Slot != None)
		{
			// Ghost is Staffed
			BusyGhosts.AddItem(Ghost);
		}
	}

	return BusyGhosts;
}
function int AvailableGhosts()
{
	return GetAvailableGhosts().Length;
}
function bool HasAvailableGhosts()
{
	return (AvailableGhosts() < MaxGhosts());
}
function int MaxGhosts()
{
	return GetMyTemplate().GetContributionFromSkillFn(GetAssignedStaff());
}
function int StaffedGhosts()
{
	return GetStaffedGhosts().Length;
}
function bool HasStaffedGhosts()
{
	return (GetStaffedGhosts().Length > 0);
}
// Is the Staffed Unit a Ghost?
function bool IsGhost()
{
	return (class'CHHelpers'.default.GhostTemplateNames.Find(GetAssignedStaff().GetMyTemplateName()) != INDEX_NONE);
}
// End Issue #706

DefaultProperties
{
}