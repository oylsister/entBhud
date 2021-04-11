/*	
	EntBhud.sp Copyright (C) 2021 Oylsister
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

//#define EntBossHP

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#if defined EntBossHP
#include <entbosshp>
#endif

#include <multicolors>
#include <zombiereloaded>

#pragma newdecls required

char sClientEntityName[64][MAXPLAYERS];
int iClientEntity[MAXPLAYERS];

Handle entBhud_Cookie = INVALID_HANDLE;

bool g_bEnableBHud[MAXPLAYERS+1];
bool g_bHitmarker[MAXPLAYERS+1];

float g_fClientLastHit[MAXPLAYERS+1];

ConVar g_hCvar_ShowMode;
ConVar g_hCvar_MinPlayerHit;
ConVar g_hCvar_HitChannel;
ConVar g_hCvar_HitRed;
ConVar g_hCvar_HitGreen;
ConVar g_hCvar_HitBlue;
ConVar g_hCvar_HudVoteProgress;
ConVar g_hCvar_HudChannel;

int g_iShowMode;
int g_iMinPlayerHit;
int g_iHitChannel;
int iRed;
int iGreen;
int iBlue;
bool g_bHudVoteProgress;
int g_iHudChannel;

public Plugin myinfo = 
{
	name = "entBhud an Improved Bhud",
	author = "Oylsister",
	description = "Showing an entity health with hitmarker",
	version = "1.0",
	url = "https://github.com/oylsister/entBhud"
};

public void OnPluginStart()
{
	g_hCvar_ShowMode = CreateConVar("sm_entbhud_showmode", "1.0", "Specific player count mode for showing bhud [0 = Showing All, 1 = Dynamic, 2 = Specific Number]", _, true, 0.0, true, 2.0);
	g_hCvar_MinPlayerHit = CreateConVar("sm_entbhud_minplayerhit", "2.0", "How many player is required to hit the same entity before showing to all player", _, true, 1.0, true, 63.0);
	
	g_hCvar_HitChannel = CreateConVar("sm_entbhud_hitchannel", "2.0", "HUD channel for Hit marker", _, true, 0.0, true, 5.0);
	g_hCvar_HitRed = CreateConVar("sm_entbhud_hitred", "255.0", "HUD channel for Hit marker", _, true, 0.0, true, 255.0);
	g_hCvar_HitGreen = CreateConVar("sm_entbhud_hitcolor", "0", "HUD channel for Hit marker", _, true, 0.0, true, 255.0);
	g_hCvar_HitBlue = CreateConVar("sm_entbhud_hitcolor", "0", "HUD channel for Hit marker", _, true, 0.0, true, 255.0);
	
	g_hCvar_HudVoteProgress = CreateConVar("sm_entbhud_hudvoteprogress", "1.0", "HUD channel for Hit marker", _, true, 0.0, true, 1.0);
	g_hCvar_HudChannel = CreateConVar("sm_entbhud_hudchannel", "3.0", "HUD channel for Hit marker", _, true, 0.0, true, 5.0);
	
	entBhud_Cookie = RegClientCookie("entBhud_cookie", "[entBhud] Toggle Showing Entity Health", CookieAccess_Protected);
	SetCookieMenuItem(entBhudMenu_Cookie, 0, "[entBhud] Showing Entity HP");
	for(int client = 1; client <= MaxClients; client++) 
	{
		if(AreClientCookiesCached(client)) 
			OnClientCookiesCached(client);
	}

	HookEntityOutput("func_physbox", "OnHealthChanged", OnDamage);
	HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", OnDamage);
	HookEntityOutput("func_breakable", "OnHealthChanged", OnDamage);
	HookEntityOutput("prop_dynamic", "OnHealthChanged", OnDamageHook);
	HookEntityOutput("math_counter", "OutValue", OnDamageCounter);
	
	HookConVarChange(g_hCvar_ShowMode, OnConVarChanged);
	HookConVarChange(g_hCvar_MinPlayerHit, OnConVarChanged);
	HookConVarChange(g_hCvar_HitChannel, OnConVarChanged);
	HookConVarChange(g_hCvar_HitRed, OnConVarChanged);
	HookConVarChange(g_hCvar_HitGreen, OnConVarChanged);
	HookConVarChange(g_hCvar_HitBlue, OnConVarChanged);
	HookConVarChange(g_hCvar_HudVoteProgress, OnConVarChanged);
	HookConVarChange(g_hCvar_HudChannel, OnConVarChanged);

	RegConsoleCmd("sm_bhud", entBhudMenu);

	LoadTranslations("entBhud.phrases");
}

public void OnConVarChanged(ConVar convar, const char[] newValue, const char[] oldValue)
{
	if (convar == g_hCvar_ShowMode)
		g_iShowMode = GetConVarInt(g_hCvar_ShowMode);
		
	else if (convar == g_hCvar_MinPlayerHit)
		g_iMinPlayerHit = GetConVarInt(g_hCvar_MinPlayerHit);
		
	else if (convar == g_hCvar_HitChannel)
		g_iHitChannel = GetConVarInt(g_hCvar_HitChannel);
		
	else if (convar == g_hCvar_HitRed)
		iRed = GetConVarInt(g_hCvar_HitRed);
	
	else if (convar == g_hCvar_HitGreen)
		iGreen = GetConVarInt(g_hCvar_HitGreen);
	
	else if (convar == g_hCvar_HitBlue)
		iBlue = GetConVarInt(g_hCvar_HitBlue);
		
	else if (convar == g_hCvar_HudVoteProgress)
		g_bHudVoteProgress = GetConVarBool(g_hCvar_HudVoteProgress);
		
	else if (convar == g_hCvar_HudChannel)
		g_iHudChannel = GetConVarInt(g_hCvar_HudChannel);
}

public void OnClientCookiesCached(int client)
{
	char sBuffer[4];
	GetClientCookie(client, entBhud_Cookie, sBuffer, sizeof(sBuffer));

	if(sBuffer[0] != '\0') 
	{
		char sTemp[2];
		FormatEx(sTemp, sizeof(sTemp), "%c", sBuffer[1]);
		g_bEnableBHud[client] = StrEqual(sTemp, "1");
		
		FormatEx(sTemp, sizeof(sTemp), "%c", sBuffer[2]);
		g_bHitmarker[client] = StrEqual(sTemp, "1");
	}
	
	else 
	{
		g_bEnableBHud[client] = true;	
		g_bHitmarker[client] = true;
        	
		char sCookie[4];
		FormatEx(sCookie, sizeof(sCookie), "%b%b", g_bEnableBHud[client], g_bHitmarker[client]);
		SetClientCookie(client, entBhud_Cookie, sCookie);
	}
}
public void entBhudMenu_Cookie(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    	if(action == CookieMenuAction_SelectOption)
        	entBhudMenu(client, 1);
}

public int entBhudMenu_Handler(Menu menu, MenuAction action, int client, int param)
{
    if(action == MenuAction_Select) 
	{
		switch (param)
		{
			case 0:
			{
				g_bEnableBHud[client] = !g_bEnableBHud[client];
				CPrintToChat(client, "%t %t {lightgreen}%t{default}.", "prefix", "Toggle_BHud", g_bEnableBHud[client] ? "Enabled" : "Disabled");
        		}
			case 1:
			{
				g_bHitmarker[client] = !g_bHitmarker[client];
				CPrintToChat(client, "%t %t {lightgreen}%t{default}.", "prefix", "Toggle_Hitmarker", g_bHitmarker[client] ? "Enabled" : "Disabled");
			}
		}
		char sCookie[4];
		FormatEx(sCookie, sizeof(sCookie), "%b%b", g_bEnableBHud[client], g_bHitmarker[client]);
		SetClientCookie(client, entBhud_Cookie, sCookie);

		entBhudMenu(client, 1);
	}
	
	else if(action == MenuAction_Cancel)
		ShowCookieMenu(client);

	else if(action == MenuAction_End)
		delete menu;
}

public Action entBhudMenu(int client, int args)
{
	Menu menu = new Menu(entBhudMenu_Handler, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("%t\n", "Cookies_MenuName");

	char sTemp[256];
	FormatEx(sTemp, sizeof(sTemp), "%t: %t", "Menu_BHud", g_bEnableBHud[client] ? "Enabled" : "Disabled");
	menu.AddItem("bBhud", sTemp);
	FormatEx(sTemp, sizeof(sTemp), "%t: %t", "Menu_Hitmarker", g_bHitmarker[client] ? "Enabled" : "Disabled");
	menu.AddItem("bHM", sTemp);
    
	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

public void OnDamageHook(const char[] output, int entity, int activator, float delay)
{
	if (activator > 0 && activator < MAXPLAYERS)
		g_fClientLastHit[activator] = GetEngineTime();
}

public void OnDamage(const char[] output, int entity, int activator, float delay)
{
	// if it's map trigger, don't show it only show to client
	if (activator < 1 || activator > MAXPLAYERS) 
		return;

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	
	// Get client time last hit to entity
	g_fClientLastHit[activator] = GetEngineTime();
	
	// in case when map is hook OnTakeDamage for calculate math_counter HP, don't show it (mostly they set to 999999)
	if (health > 500000) 
		return;

	// when client start shooting let's assigned which entity
	if (iClientEntity[activator] != entity)
	{
		// remember entity name that client damage to
		GetEntPropString(entity, Prop_Data, "m_iName", sClientEntityName[activator], sizeof(sClientEntityName));

		// if Entity has no name then replace it with "Health"
		if(strlen(sClientEntityName[activator]) == 0)
			Format(sClientEntityName[activator], sizeof(sClientEntityName), "Health");

		// remember which entity that client damage to
		iClientEntity[activator] = entity;
	}

	// show hit marker
	if (g_bHitmarker[activator])
		ShowHitMarker(activator);

	// send message to player
	SendBossHPMsg(activator, entity, sClientEntityName[activator], health);
}

public void OnDamageCounter(const char[] output, int entity, int activator, float delay)
{
	// is it valid entity and client is hitting it
	if ((IsValidEntity(entity) || IsValidEdict(entity)) && activator > 0 && activator <= MAXPLAYERS)
	{
		// if player didn't hit anything before so let's not showing it if it's map trigger.
		if (g_fClientLastHit[activator] < GetEngineTime() - 0.5) 
			return;
		
		// Math_counter result always come out as OutValue
		int value = RoundToNearest(GetEntDataFloat(entity, FindDataMapInfo(entity, "m_OutValue")));

		// Get entity name 
		GetEntPropString(entity, Prop_Data, "m_iName", sClientEntityName[activator], sizeof(sClientEntityName));
		
		// if Entity has no name then replace it with "Health" but mostly math_counter gonna have a name anyway.
		if(strlen(sClientEntityName[activator]) == 0)
			Format(sClientEntityName[activator], sizeof(sClientEntityName), "Health");

		// when mat_counter entity is not changed or hit by client it will remain as -1, so let's not make it. 
		iClientEntity[activator] = 0;
		
		// health is not 0? the showing it!
		if (value > 0)
		{
			if (g_bHitmarker[activator])
				ShowHitMarker(activator);	
			
			SendBossHPMsg(activator, 0, sClientEntityName[activator], value);
		}
	}
}

public void SendBossHPMsg(int client, int entity, const char[] entityname, int health)
{
	int iHuman;
	int iPlayerHit;
	float fTime = GetEngineTime();
	float g_fShowAllBHud;
	
	#if defined EntBossHP
	// prevent showing them if the boss got assigned in private plugin "entBossHP"
	if(!entBossHP_IsCounterAssigned(entityname) || !entBossHP_IsBreakableAssigned(entityname))
	{
		// if entity name is exactly same from above then don't show it
		return;
	}
	#endif
	
	// check if client currently shooting the target or not. and bhud time is really not active
	if (g_fClientLastHit[client] > GetEngineTime() - 0.5 && g_fShowAllBHud + 0.1 < fTime)
	{
		// If show all to every player no matter who
		if(g_iShowMode == 0)
		{
			if(IsVoteInProgress() && g_bHudVoteProgress)
			{
				SetHudTextParams(-1.0, 0.4, 0.1, 255, 255, 255, 255, 1, 0.0, 0.1, 0.1);
				for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && g_bEnableBHud[i])
					{
						if(health <= 0)
						{
							ShowHudText(i, g_iHudChannel, "%s: %d HP", entityname, 0);
						}
						else
						{
							ShowHudText(i, g_iHudChannel, "%s: %d HP", entityname, health);
						}
					}
				}
			}
			else
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && g_bEnableBHud[i])
					{
						if(health <= 0)
						{
							PrintHintTextToAll("%s: %d HP", entityname, 0);
						}
						else
						{
							PrintHintTextToAll("%s: %d HP", entityname, health);
						}
					}
				}
			}
		}
		
		// if show when specific number human player hit the same entity 
		if(g_iShowMode > 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					// check if client is human or what
					if(ZR_IsClientHuman(i))
					{
						// so human hit the entity
						iHuman++;
					
						// if player did hit entity and it same entity with other player
						if (g_fClientLastHit[i] > fTime - 2.0 && (iClientEntity[i] == entity || StrEqual(sClientEntityName[i], entityname, false))) 
						{
							// so there is more than one player that hit the same target
							iPlayerHit++;
						}
					}
				}
			}
			// Dynamic mode
			if(g_iShowMode == 1)
			{
				// if more player hit the target than half of the team, then start told them that we're shooting something now 
				if(iPlayerHit >= iHuman / 2)
				{
					// again make sure that there is no negative number
					if(health <= 0)
					{
						PrintHintTextToAll("%s: %d HP", entityname, 0);
					}
					else
					{
						PrintHintTextToAll("%s: %d HP", entityname, health);
					}
				}
			}
			// Specific player min
			else if(g_iShowMode == 2)
			{
				// if more player hit the target than half of the team, then start told them that we're shooting something now 
				if(iPlayerHit >= g_iMinPlayerHit)
				{
					// again make sure that there is no negative number
					if(health <= 0)
					{
						PrintHintTextToAll("%s: %d HP", entityname, 0);
					}
					else
					{
						PrintHintTextToAll("%s: %d HP", entityname, health);
					}
				}
			}
			// Let say that only 1 human hit some small object that really not that important 
			else if((g_iShowMode == 1 && iPlayerHit < iHuman / 2) || (g_iShowMode == 2 && iPlayerHit < g_iMinPlayerHit))
			{		
				for (int i = 1; i <= MaxClients; ++i)
				{
					if (g_fClientLastHit[i] > fTime - 2.0 && (iClientEntity[i] == entity || StrEqual(sClientEntityName[i], entityname, false))) 
					{
						if(IsVoteInProgress() && g_bHudVoteProgress)
						{
							SetHudTextParams(-1.0, 0.4, 0.1, 255, 255, 255, 255, 1, 0.0, 0.1, 0.1);
							{
								if(IsClientInGame(i) && g_bEnableBHud[i])
								{
									if(health <= 0)
									{
										ShowHudText(i, g_iHudChannel, "%s: %d HP", entityname, 0);
									}
									else
									{
										ShowHudText(i, g_iHudChannel, "%s: %d HP", entityname, health);
									}
								}
							}
						}
						else
						{
							if(IsClientInGame(i) && g_bEnableBHud[i])
							{
								// Showing only to that client and make sure it won't go negative number
								if(health <= 0)
								{
									PrintHintText(i, "%s: %d HP", entityname, 0);
								}
								else
								{
									PrintHintText(i, "%s: %d HP", entityname, health);
								}
							}
						}
					}
				}
			}
		}
	}
	// so last time that it show to all player it's this.
	g_fShowAllBHud = fTime;
}

public void ShowHitMarker(int client)
{
	SetHudTextParams(-1.0, -1.0, 0.1, iRed, iGreen, iBlue, 255, 1, 0.0, 0.1, 0.1);
	ShowHudText(client, g_iHitChannel, "◞  ◟\n◝  ◜");
}
