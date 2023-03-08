#include <amxmodx>
#include <cstrike>
#include <csx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <metadrawer>
#include <mw2_natives>

#define PLUGIN "KillStreak"
#define VERSION "1.4.0"
#define AUTHOR "Cypis Edited by Paolo and Infractem"

#define MAX_DIST 8192.0
#define MAX 32

#define MAX_CLIENTS  32
#define MAX_WEAPONS  30

#define OFFSET_PRIMARYWEAPON 116
#define FFADE_IN	0x0000	

#define PA_LOW  -5.0
#define PA_HIGH 5.0

#define ALPHA_FULLBLINDED    255

const m_flFlashedUntil = 514
const m_flFlashedAt = 515
const m_flFlashHoldTime = 516
const m_flFlashDuration = 517
const m_iFlashAlpha = 518 

new const maxAmmo[31]={
		0,
		90,	//CSW_P228
		0,
		40,	//CSW_SCOUT
		1,	//CSW_HEGRENADE
		60,	//CSW_XM1014
		1,	//CSW_C4
		192, //CSW_MAC10
		252,	//CSW_AUG
		1,	//CSW_SMOKEGRENADE
		72, //CSW_ELITE
		90, //CSW_FIVESEVEN
		180, //CSW_UMP45
		48,	//CSW_SG550
		180,	//CSW_GALIL
		180,	//CSW_FAMAS
		72, //CSW_USP
		120, //CSW_GLOCK18
		60,	//CSW_AWP
		180, //CSW_MP5NAVY
		200, //CSW_M249
		64,	//CSW_M3
		180,	//CSW_M4A1
		150, //CSW_TMP
		90,	//CSW_G3SG1
		2,	//CSW_FLASHBANG
		42,	//CSW_DEAGLE
		180,	//CSW_SG552
		180,	//CSW_AK47
		0,	//CSW_KNIFE
		300 //CSW_P90
};
new strike_blast, sprite_blast, cache_trail, smoke_blast, predator_blast;

new max_kills[MAX+1], bool:radar[2], nalot[MAX+1], predator[MAX+1], nuke[MAX+1], emp[MAX+1], cuav[MAX+1], uav[MAX+1], pack[MAX+1], sentrys[MAX+1], stealth[MAX+1];
new limit_ks[MAX+1], bool:choose_uav[MAX+1], bool:choose_cp[MAX+1], bool:disable_cp[MAX+1], bool:choose_cuav[MAX+1], bool:disable_cuav[MAX+1], bool:choose_nalot[MAX+1];
new bool:choose_stealth[MAX+1], bool:choose_predator[MAX+1], bool:disable_predator[MAX+1], bool:choose_emp[MAX+1], bool:choose_sentrys[MAX+1], bool:disable_sentrys[MAX+1], bool:choose_nuke[MAX+1], bool:ksmenu[2];
new bool:unlockedks[MAX+1], bool:unlockedks1[MAX+1], bool:unlockedks2[MAX+1], bool:unlockedks3[MAX+1], bool:unlockedks4[MAX+1], bool:unlockedks5[MAX+1], bool:unlockedks6[MAX+1];

new bool:aerial_active[MAX+1], bool:cd_active[MAX+1], bool:predator_active[MAX+1], bool:package_active[MAX+1], bool:sentry_package_active[MAX+1], bool:roundended[MAX+1];

new bool:receivedsentry[MAX+1];

new bool:count_kills_sb[MAX+1], bool:count_kills_pa[MAX+1], bool:count_kills_pm[MAX+1], bool:count_kills_sentry[MAX+1];

new user_controll[MAX+1], emp_active, bool:nuke_player[MAX+1], bool:ksdisabled[MAX+1];
new OpforOrigin[3], OpforOrigin2[3], OpforOrigin3[3], OpforOrigin4[3], MainKiller[5];
new RangerOrigin[3], RangerOrigin2[3], RangerOrigin3[3], RangerOrigin4[3];

new nuke_active;

new g_maxplayers

new g_WeaponIndex[ MAX_CLIENTS + 1 ];
new g_WeaponId   [ MAX_CLIENTS + 1 ];

new bool:g_IsAlive   [ MAX_CLIENTS + 1 ];
new bool:g_ColdBPerk[33]
const m_iId					= 43;
const m_flNextPrimaryAttack	= 46;
const m_flNextSecondaryAttack	= 47;
const m_iFOV				= 363;
const m_pActiveItem			= 373;

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	
	register_think("sentry","SentryThink");
	
	register_touch("predator", "*", "touchedpredator");
	register_touch("bomb", "*", "touchedbomb");
	register_touch("bomb2", "*", "touchedbomb2");

	register_forward(FM_Touch, "fw_touch")
	md_init()
	RegisterHam(Ham_TakeDamage, "func_breakable", "TakeDamage");
	RegisterHam( Ham_Spawn , "player", "Event_PlayerSpawn2" , 1 );
	RegisterHam( Ham_Killed, "player", "Event_PlayerKilled2", 1 );

	//register_event("CurWeapon","CurWeapon","be", "1=1");
	//register_event("DeathMsg", "event_deathmsg", "a");
	register_event("HLTV", "NewRound", "a", "1=0", "2=0");
	register_event("SendAudio", "eEndRound", "a", "2&%!MRAD_terwin", "2&%!MRAD_ctwin", "2&%!MRAD_rounddraw")
	g_maxplayers = get_maxplayers();
	
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	
	register_cvar("dropheight_ks", "150.0");
	register_cvar("ks_hpsentry", "750");
	register_cvar("ks_sentry_remove", "1");
	register_cvar( "ks_reset_teamkill", "0" )
	
	/*new command1[] = "Killstreak_Menu"
	register_concmd("say /ks", command1);
	register_concmd("say /killstreak", command1);
	register_concmd("killstreak", command1);
	
	new command2[] = "Choose_Killstreak"
	register_concmd("say /ksmenu", command2);
	register_concmd("ksmenu", command2);*/
	
	//register_concmd("unlockks", "Killstreak_Give");
	
	set_task(2.0, "radar_scan", _, _, _, "b")
	set_task(1.5, "ks_unlock", _, _, _, "b")
	
	RegisterHam(Ham_Killed, "player", "fwd_streakreset", 0);
}
public ks_unlock()
{
	new players[32],num,a;
	get_players(players,num, "gh")
	for(a=0;a<num;a++)
	{
		if(!is_user_connected(a)) continue
		
		Killstreak_Give(a)
	}
}
public plugin_precache()
{
	strike_blast = precache_model("sprites/fexplo.spr");
	sprite_blast = precache_model("sprites/gexplo.spr");
	smoke_blast = precache_model("sprites/smokepredatorexplo.spr");
	predator_blast = precache_model("sprites/predatorexplosion.spr");
	cache_trail = precache_model("sprites/smoke.spr");
	
	precache_generic("sprites/iEnemy.spr");
	precache_generic("sprites/fuzz_radar.spr");
		
	precache_generic("sprites/ksicons.spr");
	precache_generic("sprites/fuzzer.spr");
	
	precache_model("models/p_hegrenade.mdl");
	precache_model("models/cod_carepackageranger.mdl");
	precache_model("models/cod_carepackageopfor.mdl");
	//precache_model("models/cod_plane.mdl");
	precache_model("models/cod_predator.mdl");
	precache_model("models/cod_sentrygun.mdl");
	
	precache_sound("mw/jet_fly1.wav");
	precache_sound("mw/jet_fly2.wav");
	precache_sound("mw/heli_fly.wav");
	
	precache_sound("mw/firemw.wav");
	
	precache_sound("mw/sentrygun_starts.wav");
	precache_sound("mw/sentrygun_stops.wav");
	precache_sound("mw/deployingsentry.wav");
	
	precache_model("models/computergibs.mdl");
	
	precache_generic("gfx/killstreaks/killstreak_uav.tga")
	precache_generic("gfx/killstreaks/killstreak_carepackage.tga")
	precache_generic("gfx/killstreaks/killstreak_counter.tga")
	precache_generic("gfx/killstreaks/killstreak_predator.tga")
	precache_generic("gfx/killstreaks/killstreak_sentrygun.tga")
	precache_generic("gfx/killstreaks/killstreak_air.tga")
	precache_generic("gfx/killstreaks/killstreak_stealth.tga")
	precache_generic("gfx/killstreaks/killstreak_emp.tga")
	precache_generic("gfx/killstreaks/killstreak_nuke.tga")	
	precache_generic("gfx/killstreaks/carepack_uav.tga")
	precache_generic("gfx/killstreaks/carepack_counter.tga")
	precache_generic("gfx/killstreaks/carepack_predator.tga")
	precache_generic("gfx/killstreaks/carepack_air.tga")
	precache_generic("gfx/killstreaks/carepack_stealth.tga")
	precache_generic("gfx/killstreaks/carepack_sentrygun.tga")
	
	precache_generic("gfx/killstreaks/carepack_emp.tga")
	precache_generic("gfx/nuke/nukeon.tga")
	precache_generic("gfx/nuke/nuketest.tga")
	precache_generic("gfx/nuke/nukeflash.tga")
	precache_generic("gfx/nuke/nukeeffect.tga")
	precache_generic("gfx/nuke/nukeeffect2.tga")
	
	precache_generic("gfx/killstreaks/predator/fuzzscreen.tga")
	precache_generic("gfx/killstreaks/predator/predatorhud.tga")
	precache_generic("gfx/killstreaks/predator/laptop.tga")
	precache_generic("gfx/killstreaks/predator/agmscreen.tga")
	precache_generic("gfx/killstreaks/predator/agmscreen2.tga")
	precache_generic("gfx/killstreaks/predator/agmscreen3.tga")
	precache_generic("gfx/killstreaks/predator/agmscreen4.tga")
	
	precache_generic("gfx/bloodscreen/explosionblur.tga")
}
public md_init()
{
	md_loadimage("gfx/nuke/nukeon.tga")
	//md_loadimage("gfx/nuke/nuketest.tga")
	md_loadimage("gfx/nuke/nukeflash.tga")
	md_loadimage("gfx/nuke/nukeeffect.tga")
	md_loadimage("gfx/nuke/nukeeffect2.tga")
	
	md_loadimage("gfx/killstreaks/predator/fuzzscreen.tga")
	md_loadimage("gfx/killstreaks/predator/predatorhud.tga")
	md_loadimage("gfx/killstreaks/predator/laptop.tga")
	md_loadimage("gfx/killstreaks/predator/agmscreen.tga")
	md_loadimage("gfx/killstreaks/predator/agmscreen2.tga")
	md_loadimage("gfx/killstreaks/predator/agmscreen3.tga")
	md_loadimage("gfx/killstreaks/predator/agmscreen4.tga")
}
public plugin_natives()
{
	register_native("use_pred", "CreatePredator2", 1)
	register_native("use_stealth", "CreateStealth", 1)
	register_native("use_sentry", "CreateSentryPack", 1)
	register_native("use_uav", "CreateUVA", 1)
}
public disableks(id)
{
	ksdisabled[id] = true;
	remove_entity_name("sentry")
}
public cold_bloodedperk(id)
{
	if(!is_user_connected(id)) return
	
	g_ColdBPerk[id] = true
}
public Event_NewRound()
{
	new players[32],num,i;
	get_players(players,num,"gh")
	for(i=0;i<num;i++)
	{
		i = players[i];
		if(!is_user_connected(i)) continue;
		
		g_ColdBPerk[i] = false;
		md_removedrawing(i, 1, 27)//remove fuzzradar
		md_removedrawing(i, 1, 28)//remove hudpred
	}
}
public Killstreak_Menu(id)
{
	if(!ksdisabled[id]){
		new menu = menu_create("KillStreak:", "Killstreak_Handler");
		new cb = menu_makecallback("Killstreak_Callback");
		menu_additem(menu, "UAV", _, _, cb);
		menu_additem(menu, "Care Package", _, _, cb);
		menu_additem(menu, "Counter-UAV", _, _, cb);
		menu_additem(menu, "Precision Airstrike", _, _, cb);
		menu_additem(menu, "Predator Missile", _, _, cb);
		menu_additem(menu, "Stealth Bomber", _, _, cb);
		menu_additem(menu, "Sentry Gun", _, _, cb);
		menu_additem(menu, "EMP", _, _, cb);
		menu_additem(menu, "Tactical Nuke", _, _, cb);
		menu_additem(menu, "Kill Streak Loadout Menu", _, _, cb);
		menu_setprop(menu, MPROP_EXITNAME, "Exit^n^n\yKill Streak Menu");
		menu_display(id, menu)
	}
}

public Choose_Killstreak(id)
{
	new menu = menu_create("Select 3 Kill Streaks:", "Choose_Handler");
	new cb2 = menu_makecallback("Choose_Callback");
	menu_additem(menu, "UAV \y[3] - Unlocked at level 1", _, _, cb2);
	menu_additem(menu, "Care Package \y[4] - Unlocked at level 1", _, _, cb2);
	menu_additem(menu, "Counter-UAV \y[4] - Unlocked at level 6)", _, _, cb2);
	menu_additem(menu, "Predator Missile \y[5] - Unlocked at level 1", _, _, cb2);
	menu_additem(menu, "Sentry Gun \y[5] - Unlocked at level 8)", _, _, cb2);
	menu_additem(menu, "Precision Airstrike \y[6] - Unlocked at level 4)", _, _, cb2);
	menu_additem(menu, "Stealth Bomber \y[8] - Unlocked at level 10)", _, _, cb2);
	menu_additem(menu, "EMP \y[15] - Unlocked at level 12", _, _, cb2);
	menu_additem(menu, "Tactical Nuke \y[25] - Unlocked at level 12)", _, _, cb2);
	menu_additem(menu, "Reset \y- Reset loadout upon next respawn", _, _, cb2);
	menu_setprop(menu, MPROP_EXITNAME, "Exit^n^n\yOpen this menu by typing /ksmenu in chat or pressing F4");
	menu_display(id, menu)
}
//killstreak secret unlock test
public Killstreak_Give(id)
{
	uav[id]++;
	cuav[id]++;
	pack[id]++;
	predator[id]++;
	nalot[id]++;
	sentrys[id]++;
	stealth[id]++;
	emp[id]++;
	nuke[id]++;
}

public Killstreak_Callback(id, menu, item)
{
	if(uav[id] <= 0 && item == 0 || pack[id] <= 0 && item == 1 || cuav[id] <= 0 && item == 2 || nalot[id] <= 0 && item == 3 || predator[id] <= 0 && item == 4 || sentrys[id] <= 0 && item == 6 || stealth[id] <= 0 && item == 5 || emp[id] <= 0 && item == 7 || nuke[id] <= 0 && item == 8)
		return ITEM_DISABLED;
	
	return ITEM_ENABLED;
}

public Choose_Callback(id, menu, item)
{
	if(choose_uav[id] && item == 0 || choose_cuav[id] && item == 1 || disable_cuav[id] && item == 1	|| choose_cp[id] && item == 2 || disable_cp[id] && item == 2 || choose_predator[id] && item == 3 || disable_predator[id] && item == 3 || choose_sentrys[id] && item == 4 || disable_sentrys[id] && item == 4 || choose_nalot[id] && item == 5 || choose_stealth[id] && item == 6 || choose_emp[id] && item == 7 || choose_nuke[id] && item == 8)
		return ITEM_DISABLED;

	
	return ITEM_ENABLED;
}

public Choose_Handler(id, menu, item)
{
	//if(!is_user_alive(id))
	//	return PLUGIN_HANDLED;
	
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	
	
	switch(item)
	{
		case 0:
		{
			if(unlockedks[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_uav[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) UAV selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) UAV selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) UAV selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		}
		case 1:{
			if(unlockedks[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_cp[id] = true;
					disable_cuav[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) Care Package selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) Care Package selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) Care Package selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}

					
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 2:{
			if(unlockedks1[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_cuav[id] = true;
					disable_cp[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) Counter-UAV selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) Counter-UAV selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) Counter-UAV selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}

			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 3:{
			if(unlockedks[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_predator[id] = true;
					disable_sentrys[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) Predator Missile selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) Predator Missile selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) Predator Missile selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 4:{
			if(unlockedks2[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_sentrys[id] = true;
					disable_predator[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) Sentry Gun selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) Sentry Gun selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) Sentry Gun selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 5:{
			if(unlockedks3[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_nalot[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) Precision Airstrike selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) Precision Airstrike selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) Precision Airstrike selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 6:{
			if(unlockedks4[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_stealth[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) Stealth Bomber selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) Stealth Bomber selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) Stealth Bomber selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 7:{
			if(unlockedks5[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_emp[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) EMP selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) EMP selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) EMP selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 8:{
			if(unlockedks6[id])
			{
				limit_ks[id]++
				if(limit_ks[id] < 4)
				{
					choose_nuke[id] = true;
					client_cmd(id, "spk sound/mw/select.wav");
					if(limit_ks[id] == 1)
					{
						client_print(id, print_chat, "[KILLSTREAK] (1/3) Tactical Nuke selected.");
					}
					if(limit_ks[id] == 2)
					{
						client_print(id, print_chat, "[KILLSTREAK] (2/3) Tactical Nuke selected.");
					}
					if(limit_ks[id] == 3)
					{
						client_print(id, print_chat, "[KILLSTREAK] (3/3) Tactical Nuke selected. Your kill streak loadout is now set.");
						ksmenu[id] = false;
					}
					if(limit_ks[id] < 3)
					{
						Choose_Killstreak(id)
					}
				}
				if(limit_ks[id] == 4)
				{
					client_print(id, print_chat, "[KILLSTREAK] You have already reached the three kill streak loadout limit.");
				}
			}
			else
			{
				client_print(id, print_chat, "[KILLSTREAK] You haven't unlocked this killstreak yet.");
				if(limit_ks[id] < 3)
				{
					Choose_Killstreak(id)
				}
			}
		} 
		case 9:{
		resetstreaks(id)
		client_cmd(id, "spk sound/mw/select.wav");
		}
	}
	return PLUGIN_HANDLED;
}

//triggered on choosing reset in menu, check hamspawn
public resetstreaks(id)
{
	client_print(id, print_chat, "[KILLSTREAK] Your settings and current rewards will be reset on your next respawn.");
	ksmenu[id] = true;
}

public unlockks(id){
	unlockedks[id] = true;
}
public unlockks1(id){
	unlockedks1[id] = true;
}
public unlockks2(id){
	unlockedks2[id] = true;
}
public unlockks3(id){
	unlockedks3[id] = true;
}
public unlockks4(id){
	unlockedks4[id] = true;
}
public unlockks5(id){
	unlockedks5[id] = true;
	unlockedks6[id] = true;
}

//triggered on roundspawn if reset argument is true(ksmenu) upon choosing reset in menu
public corereset(id)
{
		limit_ks[id] = 0;
		choose_cp[id] = false;
		disable_cp[id] = false;
		choose_predator[id] = false;
		disable_predator[id] = false;
		choose_uav[id] = false;
		choose_cuav[id] = false;
		disable_cuav[id] = false;
		choose_emp[id] = false;
		choose_nalot[id] = false;
		choose_stealth[id] = false;
		choose_sentrys[id] = false;
		disable_sentrys[id] = false;
		choose_nuke[id] = false;
		//to do only once
		ksmenu[id] = false;
		client_print(id, print_chat, "[KILLSTREAK] Your kill streak loadout is not set. Press F4 or type /ksmenu in chat to open kill streak menu.");
}

//triggered on roundspawn
public timeredksmenu(id)
{
	if(limit_ks[id] < 3)
	{
		//Choose_Killstreak(id)
		//client_print(id, print_chat, "[KILLSTREAK] Press F4 or type 'ksmenu' in console to open kill streak loadout menu.");
	}
}

public Killstreak_Handler(id, menu, item)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED;
	
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	client_cmd(id, "spk sound/mw/select.wav");
	
	switch(item)
	{
		case 0:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !receivedsentry[id])
				{
					if(!cd_active[id])
					{
						set_task(0.5, "CreateUVA", id);
						uav[id]--;
					}
				}
			}
		}
		case 1:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !receivedsentry[id])
				{
					if(!package_active[id] && !cd_active[id])
					{
						CreatePack(id)
					}
					else
					{
						if(package_active[id])
							airspace(id);
					}
					set_task(0.1, "startkillstreak", id)
					set_task(1.0, "stopkillstreak", id)
				}
			}
		} 
		case 2:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				set_task(0.1, "startkillstreak", id)
				set_task(1.0, "stopkillstreak", id);
				
				if(!nuke_active && !receivedsentry[id])
				{
					if(!cd_active[id])
					{
						set_task(0.5, "CreateCUVA", id)
						cuav[id]--;
					}
				}
			}
		} 
		case 3:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !receivedsentry[id])
				{
					if(!aerial_active[id] && !cd_active[id])
					{
						CreateNalot(id)
					}
					else
					{
						if(aerial_active[id])
							airspace(id);
					}
				}
				set_task(0.1, "startkillstreak", id)
				set_task(1.0, "stopkillstreak", id)
			}
		} 
		case 4:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !receivedsentry[id])
				{
					if(!predator_active[id] && !cd_active[id])
					{
						CreatePredator2(id)
					}
					else
					{
						if(predator_active[id])
							airspace(id)
						//acg_drawtga(id, "gfx/killstreaks/predator/laptop.tga", 255, 255, 255, 255, 0.5, 0.5, 0, FX_FADE, 0.2, 0.0, 0.0, 0.5, 1, ALIGN_BOTTOM, 898)
						//md_drawimage(id, 23, 0, "gfx/killstreaks/predator/laptop.tga", 0.5,0.5,0,0,255,255,255,255,0.0,0.5,2.0, ALIGN_NORMAL)
					}
				}
				set_task(0.1, "startkillstreak", id)
				set_task(4.0, "stopkillstreak", id)
			}
		} 
		case 5:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !receivedsentry[id])
				{
					if(!aerial_active[id] && !cd_active[id])
					{
						CreateStealth(id)
					}
					else
					{
						if(aerial_active[id])
							airspace(id);
					}
				}
				set_task(0.1, "startkillstreak", id)
				set_task(1.0, "stopkillstreak", id)
			}
		} 
		case 6:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !receivedsentry[id])
				{	
					if(!sentry_package_active[id] && !cd_active[id])
					{
						CreateSentryPack(id)
					}
					else
					{
						if(!sentry_package_active[id])
							airspace(id)
					}
				}
				set_task(0.1, "startkillstreak", id)
				set_task(1.0, "stopkillstreak", id)
			}
		} 
		case 7:{
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !receivedsentry[id])
				{
					if(!cd_active[id])
					{
						set_task(0.5, "CreateEmp", id)
						emp[id]--;
					}
				}
				set_task(0.1, "startkillstreak", id)
				set_task(1.0, "stopkillstreak", id)
			}
		} 
		case 8: {
			if(!emp_active || (emp_active && get_user_team(id) == get_user_team(emp_active)))
			{
				if(!nuke_active && !cd_active[id] && !receivedsentry[id])
				{

					set_task(0.5, "CreateNuke", id)
					nuke[id]--;
				}
			}
			set_task(0.1, "startkillstreak", id)
			set_task(1.0, "stopkillstreak", id)
		}
		case 9: {
			Choose_Killstreak(id)
		}
	}
	return PLUGIN_HANDLED;
}

public NewRound()
{
	for ( new i = 1; i <= g_maxplayers; i++ )
	{
		max_kills[i] = 0;
		limit_ks[i] = 0;
		user_controll[i] = 0;
		nalot[i] = 0;
		stealth[i] = 0;
		predator[i] = 0;
		nuke[i] = 0;
		cuav[i] = 0;
		uav[i] = 0;
		emp[i] = 0;
		pack[i] = 0;
		sentrys[i] = 0;	
		
		choose_cp[i] = false;
		disable_cp[i] = false;
		choose_predator[i] = false;
		disable_predator[i] = false;
		choose_uav[i] = false;
		choose_cuav[i] = false;
		disable_cuav[i] = false;
		choose_emp[i] = false;
		choose_nalot[i] = false;
		choose_stealth[i] = false;
		choose_sentrys[i] = false;
		disable_sentrys[i] = false;
		choose_nuke[i] = false;
		
		ksdisabled[i] = false;
		
		cd_active[i] = false;
		aerial_active[i] = false;
		sentry_package_active[i] = false;
		package_active[i] = false;
		predator_active[i] = false;
		
		unlockedks[i] = false;
		unlockedks1[i] = false;
		unlockedks2[i] = false;
		unlockedks3[i] = false;
		unlockedks4[i] = false;
		unlockedks5[i] = false;
		unlockedks6[i] = false;
		
		receivedsentry[i] = false;
		
		//client_cmd(i, "mp3 play sound/mw/background2.mp3");
		//set_task(342.0, "background", i, _, _, "b")

	}
	new num, players[32], PlayerCoords[3];
	get_players(players, num, "gh")
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(task_exists(i+997))
		{
			remove_task(i+997);
		}
		
		if(cs_get_user_team(i) == CS_TEAM_CT )
		{
			ResetUVA(i);
			get_user_origin(players[a], PlayerCoords)
			//acg_drawspronradar (i, "fuzz_radar", 255, 255, 255, PlayerCoords, players[a], FX_FADE, 0.1, 0.1, 0.0, 0.3, DRAW_NORMAL, 370, 0)
		}
		if(cs_get_user_team(i) == CS_TEAM_T )
		{
			ResetUVA(i);
			get_user_origin(players[a], PlayerCoords)
			//acg_drawspronradar (i, "fuzz_radar", 255, 255, 255, PlayerCoords, players[a], FX_FADE, 0.1, 0.1, 0.0, 0.3, DRAW_NORMAL, 370, 0)
		}
	}
	
	remove_entity_name("predator")
	remove_entity_name("bomb")
	remove_entity_name("pack")
	remove_entity_name("sentpack")
	
	nukegone()
	
	if(get_cvar_num("ks_sentry_remove"))
		remove_entity_name("sentry")
}

public client_putinserver(id){
	max_kills[id] = 0;
	limit_ks[id] = 0;
	user_controll[id] = 0;
	nalot[id] = 0;
	stealth[id] = 0;
	predator[id] = 0;
	nuke[id] = 0;
	cuav[id] = 0;
	uav[id] = 0;
	emp[id] = 0;
	pack[id] = 0;
	sentrys[id] = 0;
	receivedsentry[id] = false;
	
	set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN)

	set_task (0.1, "task_drawnormalradar", id)
	return PLUGIN_CONTINUE
}


public client_disconnect ( PlayerId )
{
	g_IsAlive   [ PlayerId ] = false;
	new ent = -1
	while((ent = find_ent_by_class(ent, "sentry")))
	{
		if(entity_get_int(ent, EV_INT_iuser2) == PlayerId)
			remove_entity(ent);
	}
	return PLUGIN_CONTINUE;
}

public client_death(killer,victim,wpnindex,hitplace,TK)
{	
	
	user_controll[victim] = 0;
			
	new ent = find_drop_pack(victim, "pack")
	new ent2 = find_drop_pack(victim, "sentpack")


	if(is_valid_ent(ent))
	{
		if(task_exists(2571+ent))
		{
			remove_task(2571+ent);
			bartime(victim, 0);
		}
	}
	if(is_valid_ent(ent2))
	{
		if(task_exists(2572+ent2))
		{
			remove_task(2572+ent2);
			bartime(victim, 0);
		}
	}
	
	//if(killer == victim)
		//max_kills[victim] = 0;
	
	max_kills[victim] = 0;
	
	if(!is_user_alive(killer) || !is_user_connected(killer))
		return PLUGIN_CONTINUE;
	
	//if(max_kills[killer] == 10 && !ksmenu[killer])
		//callfunc(killer, "theloner_ACH", "Achievements_v2.1.amxx")
		
	if(!is_user_bot(victim) && ksmenu[ victim ] == true)
		corereset(victim)
		
	if(get_user_team(killer) != get_user_team(victim) && !nuke_player[killer])
	{
		max_kills[killer]++;
		switch(max_kills[killer])
		{
			case 3:
			{
				if(!nuke_active )
				{
					if(choose_uav[killer])
					{
						uav[killer]++;
						Killstreak_DisplaySound(killer, "uav", 0);
					}
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE1 = (random(100));

						if (BOTSTREAK_CHANCE1 > 100 || BOTSTREAK_CHANCE1 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE1 >= 1 && BOTSTREAK_CHANCE1 <= 60)
							{
								if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
								{
									if(!cd_active[killer] && !ksdisabled[killer])
									{
										CreateBotstreak(killer, "UVA")
									}
								}
								ammo_resupply(killer)
							}
							else
							{
								if (BOTSTREAK_CHANCE1 >= 61 && BOTSTREAK_CHANCE1 <= 99)
								{
									ammo_resupply(killer)
								}
								else
								{
									if (BOTSTREAK_CHANCE1 < 0)
									{
										client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
									}
								}
							}
						}
					}
				}
			}
			case 4:
			{
				if(!nuke_active )
				{
					if(choose_cp[killer])
					{
						pack[killer]++;
						Killstreak_DisplaySound(killer, "carepackage", 0);
					}
					if(choose_cuav[killer])
					{
						cuav[killer]++
						Killstreak_DisplaySound(killer, "counter", 0);
					}
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE2 = (random(100));

						if (BOTSTREAK_CHANCE2 > 100 || BOTSTREAK_CHANCE2 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE2 >= 1 && BOTSTREAK_CHANCE2 <= 50)
							{
								if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
								{
									if(!cd_active[killer] && !ksdisabled[killer])
									{
										CreateBotstreak(killer, "CUVA")
									}
								}
								ammo_resupply(killer)
							}
							else
							{
								if (BOTSTREAK_CHANCE2 >= 51 && BOTSTREAK_CHANCE2 <= 99)
								{
									ammo_resupply(killer)
								}
								else
								{
									if (BOTSTREAK_CHANCE2 < 0)
									{
										client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
									}
								}
							}
						}
					}
				}
			}
			case 5:
			{
				if(!nuke_active )
				{				
					if(choose_predator[killer])
					{
						predator[killer]++;
						Killstreak_DisplaySound(killer, "predator", 0);
					}
					if(choose_sentrys[killer] )
					{
						sentrys[killer]++
						Killstreak_DisplaySound(killer, "sentrygun", 0);
					}
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE3 = (random(100));

						if (BOTSTREAK_CHANCE3 > 100 || BOTSTREAK_CHANCE3 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE3 >= 1 && BOTSTREAK_CHANCE3 <= 30)
							{
								if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
								{
									if(!cd_active[killer] || !ksdisabled[killer])
									{
										set_task(5.0, "sentryready", killer);
										new num, players[32];
										get_players(players, num, "gh");
										for(new a = 0; a < num; a++)
										{
											new i = players[a];
											if(get_user_team(killer) != get_user_team(i))
												enemykillstreak(i, "sentrygun", 0)
											else
												friendkillstreak(i, "sentrygun", 0)
										}
									}
								}
							}
							else
							{
								if (BOTSTREAK_CHANCE3 >= 31 && BOTSTREAK_CHANCE3 <= 85)
								{
									if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
									{
										if(!predator_active[killer] && !ksdisabled[killer])
										{
											CreateBotstreak(killer, "Predator2")
											
										}
									}
								}
								else
								{
									if (BOTSTREAK_CHANCE3 >= 86 && BOTSTREAK_CHANCE3 <= 99)
									{
										return PLUGIN_CONTINUE;
									}
									else
									{
										if (BOTSTREAK_CHANCE3 < 0)
										{
											client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
										}
									}
								}
							}
						}
					}
				}
			}
			case 6:
			{
				if(!nuke_active )
				{
					if(choose_nalot[killer])
					{
						nalot[killer]++
						Killstreak_DisplaySound(killer, "air", 0);
					}
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE4 = (random(100));

						if (BOTSTREAK_CHANCE4 > 100 || BOTSTREAK_CHANCE4 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE4 >= 1 && BOTSTREAK_CHANCE4 <= 40)
							{
								return PLUGIN_CONTINUE;
							}
							else
							{
								if (BOTSTREAK_CHANCE4 >= 41 && BOTSTREAK_CHANCE4 <= 99)
								{
									if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
									{
										if(!aerial_active[killer] && !ksdisabled[killer] && !cd_active[killer])
										{
											CreateBotstreak(killer, "Nalot")
										}
									}
								}
								else
								{
									if (BOTSTREAK_CHANCE4 < 0)
									{
										client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
									}
								}
							}
						}
					}
				}
			}
			
			case 8:
			{
				if(!nuke_active )
				{
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE5 = (random(100));

						if (BOTSTREAK_CHANCE5 > 100 || BOTSTREAK_CHANCE5 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE5 >= 1 && BOTSTREAK_CHANCE5 <= 20)
							{
								if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
								{
									if(!cd_active[killer] && !ksdisabled[killer])
									{
										CreateBotstreak(killer, "")
									}
								}
								ammo_resupply(killer)
							}
							else
							{
								if (BOTSTREAK_CHANCE5 >= 21 && BOTSTREAK_CHANCE5 <= 99)
								{
									ammo_resupply(killer)
								}
								else
								{
									if (BOTSTREAK_CHANCE5 < 0)
									{
										client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
									}
								}
							}
						}
					}
				}
			}
			case 9:
			{
				if(!nuke_active )
				{
					if(choose_stealth[killer])
					{
						stealth[killer]++
						Killstreak_DisplaySound(killer, "stealth", 0);
					}
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE5 = (random(100));

						if (BOTSTREAK_CHANCE5 > 100 || BOTSTREAK_CHANCE5 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE5 >= 1 && BOTSTREAK_CHANCE5 <= 50)
							{
								if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
								{
									if(!cd_active[killer] && !ksdisabled[killer] && !aerial_active[killer])
									{
										CreateBotstreak(killer, "Stealth")
									}
								}
								ammo_resupply(killer)
							}
							else
							{
								if (BOTSTREAK_CHANCE5 >= 51 && BOTSTREAK_CHANCE5 <= 99)
								{
									ammo_resupply(killer)
								}
								else
								{
									if (BOTSTREAK_CHANCE5 < 0)
									{
										client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
									}
								}
							}
						}
					}
				}
			}
			case 12:
			{
				if(!nuke_active )
				{
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE6 = (random(100));

						if (BOTSTREAK_CHANCE6 > 100 || BOTSTREAK_CHANCE6 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE6 >= 1 && BOTSTREAK_CHANCE6 <= 20)
							{
								if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
								{
									if(!aerial_active[killer] && !ksdisabled[killer] && !cd_active[killer])
									{
										CreateBotstreak(killer, "Nalot")
									}
								}
								ammo_resupply(killer)
							}
							else
							{
								if (BOTSTREAK_CHANCE6 >= 21 && BOTSTREAK_CHANCE6 <= 99)
								{
									ammo_resupply(killer)
								}
								else
								{
									if (BOTSTREAK_CHANCE6 < 0)
									{
										client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
									}
								}
							}
						}
					}
				}
			}
			
			case 15:
			{
				if(!nuke_active )
				{
					if(choose_emp[killer])
					{
						emp[killer]++;
						Killstreak_DisplaySound(killer, "emp", 0);
					}
					if(is_user_bot(killer))
					{
						new BOTSTREAK_CHANCE6 = (random(100));

						if (BOTSTREAK_CHANCE6 > 100 || BOTSTREAK_CHANCE6 < 0)
						{
							client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
						}
						else
						{
							if (BOTSTREAK_CHANCE6 >= 1 && BOTSTREAK_CHANCE6 <= 20)
							{
								
								if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
								{
									if(!ksdisabled[killer])
									{
										CreateBotstreak(killer, "Nuke")
										
										ammo_resupply(killer)
									}
								}
							}
							else
							{
								if (BOTSTREAK_CHANCE6 >= 21 && BOTSTREAK_CHANCE6 <= 99)
								{
									if(!ksdisabled[killer])
									{
										CreateBotstreak(killer, "")
										
										ammo_resupply(killer)
									}
								}
								else
								{
									if (BOTSTREAK_CHANCE6 < 0)
									{
										client_print(killer, print_chat, "[BOTSTREAK] Invalid Item!");
									}
								}
							}
						}
					}
				}
			}
			case 25:
			{
				if(choose_nuke[killer])
				{
					nuke[killer]++;
					Killstreak_DisplaySound(killer, "nuke", 0);
				}
				if(is_user_bot(killer))
				{
					if(!emp_active || (emp_active && get_user_team(killer) == get_user_team(emp_active)))
						CreateBotstreak(killer, "Nuke")
				}
			}
		}
	}
	else
	{
		//hotfix for not respawning for TK-ing
		set_user_health(killer, 0)
		max_kills[killer] = 0;
		
		//callfunc(killer, "tkrespawn", "csdm_main.amxx")
	}
	
	if(!is_user_bot(victim))
		timeredksmenu(victim);
		

	return PLUGIN_CONTINUE
}
/*
public event_deathmsg()
{
	new kill_ks[32];
	new id = read_data(1);
	read_data(4, kill_ks, charsmax(kill_ks));
	
	if(equal(kill_ks, "grenade"))
	{
		
	}
}
*/
public ammo_resupply(id)
{
	new weapons[32], weaponsnum;
	get_user_weapons(id, weapons, weaponsnum);
	for(new i=0; i<weaponsnum; i++)
	{
		if(maxAmmo[weapons[i]] > 0){
			cs_set_user_bpammo(id, weapons[i], maxAmmo[weapons[i]]);
		}
	}
	
	callfunc(id, "event_CurWeapon", "ModernWarfare2_BETA.amxx")
}


public fwd_streakreset(id)
{
	max_kills[id] = 0;
}

public enemykillstreak(id, const killstreak[], empnuke)
{
	new announce_chance = (random(9))

	if(empnuke)
		announce_chance += 4;
	if(announce_chance > 1)
	{
		if(cs_get_user_team(id) == CS_TEAM_T ){
			client_cmd(id, "spk sound/mw/%s_enemy2.wav", killstreak)
		}
		if(cs_get_user_team(id) == CS_TEAM_CT ){
			client_cmd(id, "spk sound/mw/%s_enemy.wav", killstreak)
		}
	}
}

public friendkillstreak(id, const killstreak[], empnuke)
{
	new announce_chance = (random(9))

	if(empnuke)
		announce_chance += 4;
	if(announce_chance > 1)
	{
		if(cs_get_user_team(id) == CS_TEAM_T ){
			client_cmd(id, "spk sound/mw/%s_friend2.wav", killstreak)
		}
		if(cs_get_user_team(id) == CS_TEAM_CT ){
			client_cmd(id, "spk sound/mw/%s_friend.wav", killstreak)
		}
	}
}

public Killstreak_DisplaySound(id, const reward[], carepack)
{
	if(cs_get_user_team(id) == CS_TEAM_T ){
		client_cmd(id, "spk sound/mw/%s_give2.wav", reward)
	}
	if(cs_get_user_team(id) == CS_TEAM_CT ){
		client_cmd(id, "spk sound/mw/%s_give.wav", reward)
	}
	new ksimage[50];
	if(!carepack)
		formatex(ksimage, charsmax(ksimage), "gfx/killstreaks/killstreak_%s.tga", reward);
	else
		formatex(ksimage, charsmax(ksimage), "gfx/killstreaks/carepack_%s.tga", reward);
		
	//acg_drawtga(id, ksimage, 255, 255, 255, 255, 0.5, 0.24, 1, FX_FADE, 0.0, 0.4, 0.0, 3.0, 0, 0, 906)
	md_drawimage(id, 23, 0, ksimage, 0.5,0.5,0,0,255,255,255,255,0.0,0.5,2.0, ALIGN_NORMAL)
	//displaystatuscollective(id)
	
	//set_task(3.0, "displaystatusremovalcollective", id)
}

public displaystatusremovalcollective(id)
{
	callfunc(id, "displaystatusremoval", "gunxpmod.amxx")
}

public displaystatuscollective(id)
{
	callfunc(id, "displaystatus", "gunxpmod.amxx")
}

public task_drawnormalradar(id)
{
	/*if (acg_userstatus(id))
	{
		acg_drawoverviewradar (id, 1, 0, 0, 210, 210, 255, 255, 255)
	}*/
	return PLUGIN_CONTINUE;
}

public task_drawnoradar(id)
{
	/*if (acg_userstatus(id))
	{
		acg_drawoverviewradar (id, 0, 0, 0, 210, 210, 255, 255, 255)
	}*/
	return PLUGIN_CONTINUE;
}


public task_flashedradar(id)
{
	//if (acg_userstatus(id))
		//radar_fuzz(id, 1)
	return PLUGIN_CONTINUE;
}


//uav
public CreateUVA(id)
{
	static TimeUav[2];
	new team = get_user_team(id) == 1? 0: 1;
	radar[team] = true;
	
	new num, players[32];
	get_players(players, num, "gh")
	for(new a = 0; a < num; a++)
	{
		new i = players[a]
		if(get_user_team(id) != get_user_team(i))
			enemykillstreak(i, "uav", 0)
		else
			friendkillstreak(i, "uav", 0)
	}
	radar_scan()
	
	if(task_exists(7354+team))
	{
		new times = (TimeUav[team]-get_systime())+60
		change_task(7354+team, float(times));
		change_task(id, float(times));
		TimeUav[team] = TimeUav[team]+times;
	}
	else
	{
		new data[1];
		data[0] = team;
		set_task(30.0, "deluav", 7354+team, data, 1);
		TimeUav[team] = get_systime()+30;
	}
	
	//call gunxpmod xp bonus
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 100)
	
	//call achievement data
	callfunc(id, "uav_ACH", "Achievements_v2.1.amxx")
	callfunc(id, "radar_ACH", "Achievements_v2.1.amxx")
}

public deluav(data[1])
{
	radar[data[0]] = false;
	for(new i = 0; i<32;i++)
	{
		md_removedrawing(0, 5, i)
	}
}

public radar_scan()
{
	new num, players[32];
	get_players(players, num, "gh")
	for(new z=0; z<num; z++)
	{
		new ids = players[z];
		if(!is_user_alive(ids) || !radar[get_user_team(ids) == 1? 0: 1])
			continue;
		
		//if(g_ColdBPerk[ids]) continue;
		
		if(!emp_active)
			radar_continue(ids)
		else if(get_user_team(ids) == get_user_team(emp_active))
			radar_continue(ids)
	}
}
radar_continue(id)
{
	new num, players[32];
	new PlayerCoords[3], PlayerCoords1[3],PlayerCoords2[3], PlayerCoords3[3];
	new PlayerCoords4[3], PlayerCoords5[3], PlayerCoords6[3], PlayerCoords7[3];
	new PlayerCoords8[3], PlayerCoords9[3], PlayerCoords10[3], PlayerCoords11[3];
	new PlayerCoords12[3], PlayerCoords13[3], PlayerCoords14[3], PlayerCoords15[3];
	new PlayerCoords16[3], PlayerCoords17[3], PlayerCoords18[3], PlayerCoords19[3];
	new PlayerCoords20[3], PlayerCoords21[3], PlayerCoords22[3], PlayerCoords23[3];
	new PlayerCoords24[3], PlayerCoords25[3], PlayerCoords26[3], PlayerCoords27[3];
	new PlayerCoords28[3], PlayerCoords29[3], PlayerCoords30[3], PlayerCoords31[3];
	get_players(players, num, "gh")
	for(new a=0; a<num; a++)
	{
		a = players[a];
		//if(g_ColdBPerk[a]) continue;
		if(!is_user_alive(players[a]) || get_user_team(players[a]) == get_user_team(id))
			continue;
		{	
			get_user_origin(players[a], PlayerCoords,0)
			md_drawspriteonradar(id, 1, 0, "sprites/overviews/iEnemy.spr", PlayerCoords, 255,255,255,255, SPR_ADDITIVE)

		}
		if(!is_user_alive(players[1]) || get_user_team(players[1]) == get_user_team(id))
			continue;
		{		
			get_user_origin(players[1], PlayerCoords1,0)
			md_drawspriteonradar(id, 2, 0, "sprites/overviews/iEnemy.spr", PlayerCoords1, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[2]) || get_user_team(players[2]) == get_user_team(id))
			continue;
		{ 		
			get_user_origin(players[2], PlayerCoords2,0)
			md_drawspriteonradar(id, 3, 0, "sprites/overviews/iEnemy.spr", PlayerCoords2, 255,255,255,255, SPR_ADDITIVE)

		}
		if(!is_user_alive(players[3]) || get_user_team(players[3]) == get_user_team(id))
			continue;
		{ 	
			get_user_origin(players[3], PlayerCoords3,0)
			md_drawspriteonradar(id, 4, 0, "sprites/overviews/iEnemy.spr", PlayerCoords3, 255,255,255,255, SPR_ADDITIVE)

		}
		if(!is_user_alive(players[4]) || get_user_team(players[4]) == get_user_team(id))
			continue;
		{ 	
			get_user_origin(players[4], PlayerCoords4,0)
			md_drawspriteonradar(id, 5, 0, "sprites/overviews/iEnemy.spr", PlayerCoords4, 255,255,255,255, SPR_ADDITIVE)
		}
		if(!is_user_alive(players[5]) || get_user_team(players[5]) == get_user_team(id))
			continue;		
		{ 		
			get_user_origin(players[5], PlayerCoords5,0)
			md_drawspriteonradar(id, 6, 0, "sprites/overviews/iEnemy.spr", PlayerCoords5, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[6]) || get_user_team(players[6]) == get_user_team(id))
			continue;
		{ 	
			get_user_origin(players[6], PlayerCoords6,0)
			md_drawspriteonradar(id, 7, 0, "sprites/overviews/iEnemy.spr", PlayerCoords6, 255,255,255,255, SPR_ADDITIVE)

		}
		if(!is_user_alive(players[7]) || get_user_team(players[7]) == get_user_team(id))
			continue;
		{ 	
			get_user_origin(players[7], PlayerCoords7,0)
			md_drawspriteonradar(id, 8, 0, "sprites/overviews/iEnemy.spr", PlayerCoords7, 255,255,255,255, SPR_ADDITIVE)
		}
		if(!is_user_alive(players[8]) || get_user_team(players[8]) == get_user_team(id))
			continue;
		{ 		
			get_user_origin(players[8], PlayerCoords8,0)
			md_drawspriteonradar(id, 9, 0, "sprites/overviews/iEnemy.spr", PlayerCoords8, 255,255,255,255, SPR_ADDITIVE)
		}
		if(!is_user_alive(players[9]) || get_user_team(players[9]) == get_user_team(id))
			continue;
		{ 			
			get_user_origin(players[9], PlayerCoords9,0)
			md_drawspriteonradar(id, 10, 0, "sprites/overviews/iEnemy.spr", PlayerCoords9, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[10]) || get_user_team(players[10]) == get_user_team(id))
			continue;
		{ 		
			get_user_origin(players[10], PlayerCoords10,0)
			md_drawspriteonradar(id, 11, 0, "sprites/overviews/iEnemy.spr", PlayerCoords10, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[11]) || get_user_team(players[11]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[11], PlayerCoords11,0)
			md_drawspriteonradar(id, 12, 0, "sprites/overviews/iEnemy.spr", PlayerCoords11, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[12]) || get_user_team(players[12]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[12], PlayerCoords12,0)
			md_drawspriteonradar(id, 13, 0, "sprites/overviews/iEnemy.spr", PlayerCoords12, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[13]) || get_user_team(players[13]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[13], PlayerCoords13,0)
			md_drawspriteonradar(id, 14, 0, "sprites/overviews/iEnemy.spr", PlayerCoords13, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[14]) || get_user_team(players[14]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[14], PlayerCoords14,0)
			md_drawspriteonradar(id, 15, 0, "sprites/overviews/iEnemy.spr", PlayerCoords14, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[15]) || get_user_team(players[15]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[15], PlayerCoords15,0)
			md_drawspriteonradar(id, 16, 0, "sprites/overviews/iEnemy.spr", PlayerCoords15, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[16]) || get_user_team(players[16]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[16], PlayerCoords16,0)
			md_drawspriteonradar(id, 17, 0, "sprites/overviews/iEnemy.spr", PlayerCoords16, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[17]) || get_user_team(players[17]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[17], PlayerCoords17,0)
			md_drawspriteonradar(id, 18, 0, "sprites/overviews/iEnemy.spr", PlayerCoords17, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[18]) || get_user_team(players[18]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[18], PlayerCoords18,0)
			md_drawspriteonradar(id, 19, 0, "sprites/overviews/iEnemy.spr", PlayerCoords18, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[19]) || get_user_team(players[19]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[19], PlayerCoords19,0)
			md_drawspriteonradar(id,20, 0, "sprites/overviews/iEnemy.spr", PlayerCoords19, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[20]) || get_user_team(players[20]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[20], PlayerCoords20,0)
			md_drawspriteonradar(id, 21, 0, "sprites/overviews/iEnemy.spr", PlayerCoords20, 255,255,255,255, SPR_ADDITIVE)
			
		}
		
		if(!is_user_alive(players[21]) || get_user_team(players[21]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[21], PlayerCoords21,0)
			md_drawspriteonradar(id, 22, 0, "sprites/overviews/iEnemy.spr", PlayerCoords21, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[22]) || get_user_team(players[22]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[22], PlayerCoords22,0)
			md_drawspriteonradar(id, 23, 0, "sprites/overviews/iEnemy.spr", PlayerCoords22, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[23]) || get_user_team(players[23]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[23], PlayerCoords23,0)
			md_drawspriteonradar(id, 24, 0, "sprites/overviews/iEnemy.spr", PlayerCoords23, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[24]) || get_user_team(players[24]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[24], PlayerCoords24,0)
			md_drawspriteonradar(id, 25, 0, "sprites/overviews/iEnemy.spr", PlayerCoords24, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[25]) || get_user_team(players[25]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[25], PlayerCoords25,0)
			md_drawspriteonradar(id, 26, 0, "sprites/overviews/iEnemy.spr", PlayerCoords25, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[26]) || get_user_team(players[26]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[26], PlayerCoords26,0)
			md_drawspriteonradar(id, 27, 0, "sprites/overviews/iEnemy.spr", PlayerCoords26, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[27]) || get_user_team(players[27]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[27], PlayerCoords27,0)
			md_drawspriteonradar(id, 28, 0, "sprites/overviews/iEnemy.spr", PlayerCoords27, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[28]) || get_user_team(players[28]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[28], PlayerCoords28,0)
			md_drawspriteonradar(id, 29, 0, "sprites/overviews/iEnemy.spr", PlayerCoords28, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[29]) || get_user_team(players[29]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[29], PlayerCoords29,0)
			md_drawspriteonradar(id, 30, 0, "sprites/overviews/iEnemy.spr", PlayerCoords29, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[30]) || get_user_team(players[30]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[30], PlayerCoords30,0)
			md_drawspriteonradar(id, 31, 0, "sprites/overviews/iEnemy.spr", PlayerCoords30, 255,255,255,255, SPR_ADDITIVE)
			
		}
		if(!is_user_alive(players[31]) || get_user_team(players[31]) == get_user_team(id))
			continue;
		{
			get_user_origin(players[31], PlayerCoords31,0)
			md_drawspriteonradar(id, 32, 0, "sprites/overviews/iEnemy.spr", PlayerCoords31, 255,255,255,255, SPR_ADDITIVE)
			
		}

	}
	return;
}

public targetverification(id)
{
	//acg_drawtext(id, 0.5, 0.700, "Target acquired.", 255, 255, 255, 200, 0.0, 0.3, 5.6, 1, TS_BORDER, 1, 0, 30)
	md_drawtext(id,16, "Target acquired.", 0.5,0.700,0,0,255,255,255,200,0.0,0.3,1.0, ALIGN_NORMAL)
	//acg_drawtext(id, 0.5, 0.5, ">         <", 210, 210, 210, 255, 0.0, 0.3, 0.5, 1, TS_BORDER, 1, 0, 24)
	md_drawtext(id,17, ">         <", 0.5,0.5,0,0,255,255,255,200,0.0,0.3,0.5, ALIGN_NORMAL)
}

public airspace(id)
{	
	//acg_drawtext(id, 0.5, 0.700, "Airspace too crowded.", 255, 255, 255, 200, 0.0, 0.3, 5.6, 1, TS_BORDER, 1, 0, 30)
	md_drawtext(id,18, "Airspace too crowded.", 0.5,0.5,0,0,255,255,255,200,0.0,0.3,0.5, ALIGN_NORMAL)
}

//airpack
public CreatePack(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			enemykillstreak(i, "carepackage", 0)
		}
		else
		{
			cd_active[i] = true;
			set_task(1.0, "cooldownover", i+696)
			package_active[i] = true;
			set_task(8.0, "packageover", i)
			friendkillstreak(i, "carepackage", 0)
		}
		set_task(0.2, "soundhelifunc", i)
	}
	CreateHeli(id)
	pack[id]--;
	targetverification(id)
	set_task(4.0, "CarePack", id+742)
	
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 100)
	
	callfunc(id, "cp_ACH", "Achievements_v2.1.amxx")
	callfunc(id, "airdrop_ACH", "Achievements_v2.1.amxx")
}

public CreateSentryPack(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{		
			enemykillstreak(i, "sentrygun", 0)
		}
		else
		{
			cd_active[i] = true;
			set_task(1.0, "cooldownover", i+696)
			sentry_package_active[id] = true;
			set_task(8.0, "sentrypackageover", i)
			friendkillstreak(i, "sentrygun", 0)
		}
		set_task(0.2, "soundhelifunc", i)
	}
	CreateHeli2(id)
	sentrys[id]--;
	targetverification(id)
	set_task(4.0, "CareSentryPack", id+743)
	
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 150)
	
	callfunc(id, "sentry_ACH", "Achievements_v2.1.amxx")
	callfunc(id, "airdrop_ACH", "Achievements_v2.1.amxx")
}

public CarePack(taskid)
{
	new id = (taskid - 742)	
	
	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		OpforOrigin2[0] += random_num(-40,40);
		OpforOrigin2[1] += random_num(-40,40);
		OpforOrigin2[2] += 400; 
		new Float:LocVecs[3];
		IVecFVec(OpforOrigin2, LocVecs);
		create_ent(id, "pack", "models/cod_carepackageopfor.mdl", 2, 6, LocVecs);	
	}
	
	if(cs_get_user_team(id) == CS_TEAM_CT )
	{
		RangerOrigin2[0] += random_num(-40,40);
		RangerOrigin2[1] += random_num(-40,40);
		RangerOrigin2[2] += 400; 
		new Float:LocVecs[3];
		IVecFVec(RangerOrigin2, LocVecs);
		create_ent(id, "pack", "models/cod_carepackageranger.mdl", 2, 6, LocVecs);
	}
}

public CareSentryPack(taskid)
{
	new id = (taskid - 743)
	
	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		OpforOrigin3[0] += random_num(-40,40);
		OpforOrigin3[1] += random_num(-40,40);
		OpforOrigin3[2] += 400;  
		new Float:LocVecs[3];
		IVecFVec(OpforOrigin3, LocVecs);
		create_ent(id, "sentpack", "models/cod_carepackageopfor.mdl", 2, 6, LocVecs);
	}
	
	if(cs_get_user_team(id) == CS_TEAM_CT )
	{
		RangerOrigin3[0] += random_num(-40,40);
		RangerOrigin3[1] += random_num(-40,40);
		RangerOrigin3[2] += 400; 
		new Float:LocVecs[3];
		IVecFVec(RangerOrigin3, LocVecs);
		create_ent(id, "sentpack", "models/cod_carepackageranger.mdl", 2, 6, LocVecs);
	}
}

public pickup_pack(info[2])
{
	new id = info[0];
	new ent = info[1];
	
	new PICKUP_CHANCE = (random(100));

	if (PICKUP_CHANCE > 100 || PICKUP_CHANCE < 0)
	{
		client_print(id, print_chat, "[Care Package] Invalid Item!");
	}
	else
	{
		stopkillstreak(id)
		if (PICKUP_CHANCE >= 83 && PICKUP_CHANCE <= 100)
		{
			if(!is_user_connected(id) || !is_user_alive(id))
			return;

			ammo_resupply(id)
			give_item(id, "weapon_hegrenade");
			give_item(id, "weapon_flashbang");
			give_item(id, "weapon_flashbang");
			client_print(id, print_chat, "[Care Package] Received Supply");
		}
		else
		{
			//8 percent
			if (PICKUP_CHANCE >= 75 && PICKUP_CHANCE <= 82)
			{
				stealth[id]++;
				Killstreak_DisplaySound(id, "stealth", 1)
				if(is_user_bot(id))
				{
					set_task(2.0, "CreateStealth", id)
				}
			}
			else
			{
				//4 percent
				if (PICKUP_CHANCE >= 72 && PICKUP_CHANCE <= 75)
				{
					emp[id]++;
					Killstreak_DisplaySound(id, "emp", 1)
					if(is_user_bot(id))
					{
						set_task(2.0, "CreateEmp", id)
					}
				}
				else
				{
					//13 percent
					if (PICKUP_CHANCE >= 59 && PICKUP_CHANCE <= 71)
					{
						Killstreak_DisplaySound(id, "sentrygun", 1)
						sentryready (id)
					}
					else
					{
						//15 percent
						if (PICKUP_CHANCE >= 47 && PICKUP_CHANCE <= 58)
						{
							nalot[id]++;
							Killstreak_DisplaySound(id, "air", 1)
							if(is_user_bot(id))
							{
								set_task(2.0, "CreateNalot", id)
							}
						}
						
						else
						{
							//13 percent
							if (PICKUP_CHANCE >= 35 && PICKUP_CHANCE <= 47)
							{
								predator[id]++;
								Killstreak_DisplaySound(id, "predator", 1)
								if(is_user_bot(id))
								{
									set_task(2.0, "CreatePredator2", id)
								}
							}
							else
							{
								//17 percent
								if (PICKUP_CHANCE >= 17 && PICKUP_CHANCE <= 34)
								{
									cuav[id]++;
									Killstreak_DisplaySound(id, "counter", 1)
									if(is_user_bot(id))
									{
										set_task(2.0, "CreateCUVA", id)
									}
								}
								else
								{
									//17 percent
									if (PICKUP_CHANCE >= 0 && PICKUP_CHANCE <= 16)
									{
										uav[id]++;
										Killstreak_DisplaySound(id, "uav", 1)
										if(is_user_bot(id))
										{
											set_task(2.0, "CreateUVA", id)
										}
									}
									else
									{
										if (PICKUP_CHANCE < 0)
										{
											client_print(id, print_chat, "[Care Package] Invalid Item!");
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	remove_entity(ent);
}
public pickup_sentpack(info[2])
{
	new id = info[0];
	new ent = info[1];
	
	remove_entity(ent);
	
	stopkillstreak(id)
	set_task(0.5, "sentryready", id)
}

public soundhelifunc(id)
{
	client_cmd(id, "spk sound/mw/heli_fly.wav");
}

public client_PreThink(id)
{	
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE;	
		
	/*
	/////////supposed controllable missile
	if(user_controll[id])
	{
		new ent = user_controll[id];
		if(is_valid_ent(ent))
		{
			new Float:Velocity[3], Float:Angle[3];
			velocity_by_aim(id, 100, Velocity);
			entity_get_vector(id, EV_VEC_v_angle, Angle);
			
			entity_set_vector(ent, EV_VEC_velocity, Velocity);
			entity_set_vector(ent, EV_VEC_angles, Angle);
		}
		else
			attach_view(id, id);
	}*/
	////////////care package//////////////
	static ent_id[MAX+1];
	new ent = find_drop_pack(id, "pack");
	
	if(is_valid_ent(ent))
		//acg_drawtext(id, 0.5, 0.700, "Press and hold \yF \wto open Care Package", 255, 255, 255, 200, 0.0, 0.3, 0.3, 1, TS_BORDER, 1, 0, 30)
		md_drawtext(id,19, "Press and hold \yF \wto open Care Package", 0.5,0.700,0,0,255,255,255,200,0.0,0.5,1.0, ALIGN_NORMAL)
	
	if(is_user_bot(id)) //bot pickup package
	{
		if(is_valid_ent(ent))
		{
			if(!task_exists(2571+ent))
			{
				new freeze_chance = (random(10))
				if(freeze_chance > 10 || freeze_chance < 0)
				{
					return 0;
				}
				else
				{
					if(freeze_chance <= 7)
					{
						set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN)
						set_task(1.1, "unfreezemovement", id)
					}
					else
					{
						if(freeze_chance >= 8)
						{
							return 0;
						}
					}
				}
				ent_id[id] = ent;
				bartime(id, 1)	
				
				new info[2];
				info[0] = id;
				info[1] = ent;
				set_task(1.0, "pickup_pack", 2571+ent, info, 2);
			}
		}
		else
		{
			if(task_exists(2571+ent_id[id]))
			{
				remove_task(2571+ent_id[id]);
				bartime(id, 0);
				ent_id[id] = 0;
			}
		}
	}
	else
	{
		//human pickup package
		if(is_valid_ent(ent) && UTIL_IsUSE(id)) 
		{
			if(!task_exists(2571+ent))
			{
				ent_id[id] = ent;
				bartime(id, 1)	
				
				new info[2];
				info[0] = id;
				info[1] = ent;
				set_task(1.0, "pickup_pack", 2571+ent, info, 2);
				startkillstreak(id)
			}
		}
		else
		{
			if(task_exists(2571+ent_id[id]))
			{
				remove_task(2571+ent_id[id]);
				bartime(id, 0);
				ent_id[id] = 0;
				stopkillstreak(id)
			}
		}
	}
	//////////sentry package///////////////
	static ent2_id[MAX+1]
	new ent2 = find_drop_pack(id, "sentpack");
	if(is_valid_ent(ent2))
		//acg_drawtext(id, 0.5, 0.700, "Press and hold \yF \wfor a Sentry Gun", 255, 255, 255, 200, 0.0, 0.3, 0.3, 1, TS_BORDER, 1, 0, 30)
		md_drawtext(id,20, "Press and hold [E] for a Sentry Gun", 0.5,0.700,0,0,255,255,255,200,0.0,0.5,1.0, ALIGN_NORMAL)
		
	if(is_user_bot(id)) //bot pickup sent package
	{
		if(is_valid_ent(ent2))
		{
			if(!task_exists(2572+ent2))
			{
				new freeze_chance = (random(10))
				if(freeze_chance > 10 || freeze_chance < 0)
				{
					return 0;
				}
				else
				{
					if(freeze_chance <= 7)
					{
						set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN)
						set_task(1.1, "unfreezemovement", id)
					}
					else
					{
						if(freeze_chance >= 8)
						{
							return 0;
						}
					}
				}
				ent2_id[id] = ent2;
				bartime(id, 1)	
				
				new info[2];
				info[0] = id;
				info[1] = ent2;
				set_task(1.0, "pickup_sentpack", 2572+ent2, info, 2);
			}
		}
		else
		{
			if(task_exists(2572+ent2_id[id]))
			{
				remove_task(2572+ent2_id[id]);
				bartime(id, 0);
				ent2_id[id] = 0;
			}
		}
	}
	else
	{
		if(is_valid_ent(ent2) && UTIL_IsUSE(id)) //human pickup sent package
		{
			if(!task_exists(2572+ent2))
			{
				ent2_id[id] = ent2;
				bartime(id, 1)	
				
				new info[2];
				info[0] = id;
				info[1] = ent2;
				set_task(1.0, "pickup_sentpack", 2572+ent2, info, 2);
				startkillstreak(id)
			}
		}
		else		
		{
			if(task_exists(2572+ent2_id[id]))
			{
				set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN)
				remove_task(2572+ent2_id[id]);
				bartime(id, 0);
				ent2_id[id] = 0;
				stopkillstreak(id)
			}
		}
	}
	////// sentry deploy//////
	if((receivedsentry[id] && (UTIL_IsUSE(id) || UTIL_IsFIRE(id)) && is_user_alive(id)) && !nuke_active && !ksdisabled[id])
	{
		sentrydeploying(id)
		if(!task_exists(id+556))
		{
			bartime(id, 1)
			if(!is_user_bot(id))
				set_task(1.0, "CreateSentry", id+556)
			else
				set_task(0.1, "CreateSentry", id+556)
				
			startkillstreak(id)
			emit_sound(id, CHAN_AUTO, "mw/deployingsentry.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
		}
	}
	else
	{
		if(task_exists(id+556))
		{
			bartime(id, 0)
			stopkillstreak(id)
			remove_task(id+556)
		}
	}
	
	if(receivedsentry[id])
	{
		startkillstreak(id)
		//acg_drawtext(id, 0.5, 0.700, "Press and hold \yF \w or \yMOUSE 1 \wto deploy SENTRY GUN", 255, 255, 255, 200, 0.0, 0.3, -1.0, 1, TS_BORDER, 1, 0, 30)
		md_drawtext(id,21, "Target acquired.", 0.5,0.700,0,0,255,255,255,200,0.0,0.5,1.0, ALIGN_NORMAL)
	}
	
	////////////draw radar conditions///////////////
	if(get_user_flashed(id))
		task_flashedradar(id)
	
	return PLUGIN_CONTINUE;
}

//counter-uva
public CreateCUVA(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			radar_fuzz(i, 0)
			set_task(0.5, "cuav_removeelements", i, _, _, "a", 56)
			radar_fuzz_img(i)
			set_task(30.0, "remove_radar_fuzz", i)
			enemykillstreak(i, "counter", 0)
		}
		else
		{
			cd_active[i] = true;
			set_task(1.0, "cooldownover", i+696)
			friendkillstreak(i, "counter", 0)
			//callfunc(id, "disable_dot", "mw2_weaponbox.amxx")
		}
	}
	radar[get_user_team(id) == 1? 1: 0] = false;
	
	
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 100)
	
	callfunc(id, "cuav_ACH", "Achievements_v2.1.amxx")
	callfunc(id, "radar_ACH", "Achievements_v2.1.amxx")
}
public radar_fuzz_img(id)
{
	md_drawimage(id, 27, 0, "gfx/killstreaks/fuzz_radar.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.5, 30.0, ALIGN_NORMAL)
}
public remove_radar_fuzz(id)
{
	md_removedrawing(id, 1, 27)
}
public radar_fuzz(id, flash)
{
	new fuzzme[3];
	get_user_origin(id, fuzzme)
	if(!flash)
	{
		//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, fuzzme, id, FX_FADE, 0.2, 0.2, 0.0, 30.0, DRAW_NORMAL, 370, 0)
		//acg_playspr(id, 0, 0.1, 1, 370)
	}
	else
	{
		//if(get_user_flashed(id))
			//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, fuzzme, id, FX_FADE, 0.0, 0.5, 0.0, 0.5, DRAW_NORMAL, 371, 0)
	}
}

public cuav_removeelements(id)
{
	new removeelements[3];
	get_user_origin(id, removeelements)
	//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, removeelements, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_NORMAL, 362, 0)
	//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, removeelements, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_NORMAL, 363, 0)
	//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, removeelements, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_NORMAL, 364, 0)
	//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, removeelements, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_NORMAL, 365, 0)
	//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, removeelements, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_NORMAL, 368, 0)
	//acg_drawspronradar (id, "fuzz_radar", 255, 255, 255, removeelements, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_NORMAL, 369, 0)
}

public ResetUVA(id)
{
	radar[get_user_team(id) == 1? 1: 0] = false;
}

//emp
public CreateEmp(id)
{
	new num, players[32];
	get_players(players, num, "gh")
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		empflash(i)
		if(get_user_team(id) != get_user_team(i))
		{
			task_drawnoradar(i)
			remove_entity_name("sentry")
			/*callfunc(i, "emp_on1", "cwzNEW.amxx");
			callfunc(i, "emp_on2", "compass.amxx");
			callfunc(i, "emp_on3", "CSMW2_HUD.amxx");
			callfunc(i, "emp_on4", "csdm_tickets.amxx");
			callfunc(i, "emp_on5", "mw2_weaponbox.amxx");*/
			enemykillstreak(i, "emp", 1)
			set_task(60.0,"del_emp", i+103);
		}
		else
		{
			cd_active[i] = true;
			set_task(4.0, "cooldownover", i+696)
			friendkillstreak(i, "emp", 1)
		}
	}
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 500)
	emp_active = id;
	//callfunc(id, "emp_ACH", "Achievements_v2.1.amxx")
}

public empflash(i)
{
	//yellow
	//acg_drawtga(i, "gfx/nuke/nukeeffect.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 0.4, 0.4, 0.0, 1.4, 1, 0, 667)
	//white
	//acg_drawtga(i, "gfx/nuke/nukeeffect2.tga", 255, 255, 255, 200, 0.0, 0.0, 1, FX_FADE, 0.2, 0.2, 0.0, 1.2, 1, 0, 668)
}


public del_emp(taskid)
{
	new i = (taskid - 103)
	/*callfunc(i, "emp_off1", "cwzNEW.amxx");
	callfunc(i, "emp_off2", "compass.amxx");
	callfunc(i, "emp_off3", "CSMW2_HUD.amxx");
	callfunc(i, "emp_off4", "csdm_tickets.amxx");
	callfunc(i, "emp_off5", "mw2_weaponbox.amxx");*/
	task_drawnormalradar(i)
	emp_active = 0;
}


//nuke
public CreateNuke(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		set_task(0.0, "nuke_on", i)
		set_task(1.0, "nukeflash", i, _, _, "a", 10)
		set_task(0.0, "nukecd10", i)
		set_task(1.0, "nukecd9", i)
		set_task(2.0, "nukecd8", i)
		set_task(3.0, "nukecd7", i)
		set_task(4.0, "nukecd6", i)
		set_task(5.0, "nukecd5", i)
		set_task(6.0, "nukecd4", i)
		set_task(7.0, "nukecd3", i)
		set_task(8.0, "nukecd2", i)
		set_task(9.0, "nukecd1", i)
		set_task(10.0, "nukecd0", i)
		
		//callfunc(id, "nukeactivated", "csdm_tickets.amxx")

		
		if(get_user_team(id) != get_user_team(i))
		{	
			enemykillstreak(i, "nuke", 1)
		}
		else
		{
			friendkillstreak(i, "nuke", 1)
		}
	}
	set_task(10.0,"shakehud");
	set_task(14.5,"del_nuke", id);

	nuke_active = id;
	
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 100)
	
	//callfunc(id, "nuke_ACH", "Achievements_v2.1.amxx")

}

public shakehud()
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		{
			message_begin(MSG_ALL, get_user_msgid("ScreenShake"), {0,0,0}, i);
			write_short(255<<12);
			write_short(6<<12);
			write_short(255<<12);
			message_end();
			
			nukelight(i)
			
			set_pev(i, pev_flags, pev(i, pev_flags) | FL_FROZEN)
			
			set_task(0.2, "StripWeaponsNuke", i, _, _, "a", 100) 
			
			//callfunc(i, "boolnuke", "gunxpmod.amxx")
		}
	}
}

public nukelight(i)
{
	//acg_drawtga(i, "gfx/nuke/nukeeffect.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 4.0, 4.0, 0.0, 20.0, 1, 0, 667)
	//acg_drawtga(i, "gfx/nuke/nukeeffect2.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 7.0, 4.0, 0.0, 20.0, 1, 0, 668)
}

public del_nuke(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		
		set_task(0.2, "loopingdeath", id, _, _, "a", 10)
		if(is_user_alive(i))
		{
			if(get_user_team(id) != get_user_team(i))
			{
				cs_set_user_armor(i, 0, CS_ARMOR_NONE);
			}
			else
			{	
				user_silentkill(i)
			}
		}
	}
	
	//callfunc(id, "roundwinxp", "gunxpmod.amxx")
	nuke_player[id] = false;
	max_kills[id] = 0;
}

public loopingdeath(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(is_user_alive(i))
		{
			if(get_user_team(id) != get_user_team(i))
			{
				UTIL_Kill(id, i, float(get_user_health(i)), DMG_BULLET, 3)
			}
		}
	}
}

public nukegone()
{
	nuke_active = 0;
}



//Nuke Countdown
public nuke_on(id)
{
	//acg_drawtga(id, "gfx/nuke/nukeon.tga", 255, 255, 255, 255, 0.17, 0.0, 0, FX_NONE, 0.0, 0.0, 0.0, 10.0, 0, 0, 488)
}

public nukeflash(id)
{
	//acg_drawtga(id, "gfx/nuke/nukeflash.tga", 255, 255, 255, 255, 0.17, 0.0, 0, FX_FADE, 0.2, 0.2, 0.0, 0.6, 0, 0, 489)
}

public nukecd10(id)
{
	//acg_drawtext(id, 0.24, 0.025, "10", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "10.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd9(id)
{
	//acg_drawtext(id, 0.225, 0.025, "9", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "9.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd8(id)
{
	//acg_drawtext(id, 0.225, 0.025, "8", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "8.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd7(id)
{
	//acg_drawtext(id, 0.225, 0.025, "7", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "7.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd6(id)
{
	//acg_drawtext(id, 0.225, 0.025, "6", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "6.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd5(id)
{
	//acg_drawtext(id, 0.225, 0.025, "5", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "5.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd4(id)
{
	//acg_drawtext(id, 0.225, 0.025, "4", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "4.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd3(id)
{
	//acg_drawtext(id, 0.225, 0.025, "3", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "3.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd2(id)
{
	//acg_drawtext(id, 0.225, 0.025, "2", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "2.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd1(id)
{
	//acg_drawtext(id, 0.225, 0.025, "1", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "1", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public nukecd0(id)
{
	//acg_drawtext(id, 0.225, 0.025, "0", 255, 255, 255, 255, 0.1, 0.1, 0.8, 1, TS_SHADOW, 0, 0, 4)
	md_drawtext(id,23, "0.", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

//Sentry Gun Notify deployment
public sentryready(id)
{
	receivedsentry[id] = true;
	md_drawtext(id,20, "Press and hold [E] or MOUSE 1 to deploy SENTRY GUN", 0.5,0.700,0,0,255,255,255,200,0.0,0.5,1.0, ALIGN_NORMAL)
	//acg_drawtext(id, 0.5, 0.700, "Press and hold \yF \w or \yMOUSE 1 \wto deploy SENTRY GUN", 255, 255, 255, 200, 0.0, 0.3, -1.0, 1, TS_BORDER, 1, 0, 30)
}

public sentrydeploying(id)
{
	//acg_drawtext(id, 0.5, 0.700, "Deploying SENTRY GUN", 255, 255, 255, 200, 0.0, 0.3, 5.6, 1, TS_BORDER, 1, 0, 30)
	md_drawtext(id,24, "Deploying SENTRY GUN", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}

public sentrydeployed(id)
{
	//acg_drawtext(id, 0.5, 0.700, "SENTRY GUN deployed", 255, 255, 255, 200, 0.0, 0.3, 5.6, 1, TS_BORDER, 1, 0, 30)
	md_drawtext(id,25, "SENTRY GUN deployed", 0.24,0.25,0,0,255,255,255,255,0.0,0.0,1.0, ALIGN_NORMAL)
}


//stealthbomber
public CreateStealth(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) == get_user_team(i))
		{
			aerial_active[i] = true;
			set_task(12.0, "aerialover", i)
			cd_active[i] = true;
			set_task(1.0, "cooldownover", i+696)
			friendkillstreak(i, "air", 0)
		}
		set_task(0.3, "soundjetfunc2", i)
	}
	set_task(3.0, "carpetbomb", id)
	CreatePlane2(id)
	targetverification(id)
	stealth[id]--;
	
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 300)
	
	callfunc(id, "stealth_ACH", "Achievements_v2.1.amxx")
	callfunc(id, "airstrike_ACH", "Achievements_v2.1.amxx")
	//for single use ACH
	count_kills_sb[id] = true;
	set_task(12.0, "stealth_kill_counter", id)
}

public stealth_kill_counter(id)
{
	count_kills_sb[id] = false;
	//callfunc(id, "reset_kills_pm", "Achievements_v2.1.amxx")
}


//nalot
public CreateNalot(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			enemykillstreak(i, "air", 0)
		}
		else
		{
			aerial_active[i] = true;
			set_task(9.0, "aerialover", i)
			cd_active[i] = true;
			set_task(1.0, "cooldownover", i+696)
			friendkillstreak(i, "air", 0)
		}
		set_task(0.3, "soundjetfunc", i)
	}
	set_task(3.0, "startbombing", id)
	CreatePlane(id)
	targetverification(id)
	nalot[id]--;
	
	//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 200)
	
	callfunc(id, "precision_ACH", "Achievements_v2.1.amxx")

	callfunc(id, "airstrike_ACH", "Achievements_v2.1.amxx")
	count_kills_pa[id] = true;
	//set_task(9.0, "precision_kill_counter", id)
}

public precision_kill_counter(id)
{
	count_kills_pa[id] = false;
	//callfunc(id, "reset_kills_pm", "Achievements_v2.1.amxx")
}

public soundjetfunc(id)
{
	client_cmd(id, "spk sound/mw/jet_fly1.wav");
}

public startbombing(id)
{
	set_task(2.0, "dropbombs", id, _, _, "a", 3);
}

public dropbombs(id)
{
	set_task(0.1, "CreateBombs", id+997, _, _, "a", 3);
}

public carpetbomb(id)
{
	set_task(0.5, "CreateBombs2", id+998, _, _, "a", 18);
}

public soundjetfunc2(id)
{
	client_cmd(id, "spk sound/mw/jet_fly2.wav");
}
//nalot style
public CreateBombs(taskid)
{	
	new id = (taskid-997);
	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		new radlocation1[3];
		OpforOrigin[0] += random_num(-20,20);
		OpforOrigin[1] += random_num(-300,300);
		OpforOrigin[2] += 100;
		
		for(new i=0; i<15; i++) 
		{
			radlocation1[0] = OpforOrigin[0]+1*random_num(-250,250); 
			radlocation1[1] = OpforOrigin[1]+1*random_num(-250,250); 
			radlocation1[2] = OpforOrigin[2]; 
			
			new Float:LocVec[3]; 
			IVecFVec(radlocation1, LocVec); 
			create_ent(id, "bomb", "models/p_hegrenade.mdl", 2, 6, LocVec);
		}
	}
	
	if(cs_get_user_team(id) == CS_TEAM_CT )
	{
		new radlocation2[3];
		RangerOrigin[0] += random_num(-20,20);
		RangerOrigin[1] += random_num(-300,300);
		RangerOrigin[2] += 100;
		
		for(new i=0; i<15; i++) 
		{
			radlocation2[0] = RangerOrigin[0]+1*random_num(-250,250); 
			radlocation2[1] = RangerOrigin[1]+1*random_num(-250,250); 
			radlocation2[2] = RangerOrigin[2]; 
			
			new Float:LocVec[3]; 
			IVecFVec(radlocation2, LocVec); 
			create_ent(id, "bomb", "models/p_hegrenade.mdl", 2, 6, LocVec);
		}
	}
	
}  
//stealthbomber style
public CreateBombs2(taskid)
{	
	new id = (taskid-998);
	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		new radlocation3[3];
		OpforOrigin4[0] += random_num(-20,20);
		OpforOrigin4[1] += random_num(-900,900);
		OpforOrigin4[2] += 100;
		
		for(new i=0; i<20; i++) 
		{
			radlocation3[0] = OpforOrigin4[0]+1*random_num(-300,300); 
			radlocation3[1] = OpforOrigin4[1]+1*random_num(-300,300); 
			radlocation3[2] = OpforOrigin4[2]; 
			
			new Float:LocVec[3]; 
			IVecFVec(radlocation3, LocVec); 
			create_ent(id, "bomb2", "models/p_hegrenade.mdl", 2, 6, LocVec);
		}
	}
	
	if(cs_get_user_team(id) == CS_TEAM_CT )
	{
		new radlocation4[3];
		RangerOrigin4[0] += random_num(-20,20);
		RangerOrigin4[1] += random_num(-900,900);
		RangerOrigin4[2] += 100;
		
		for(new i=0; i<20; i++) 
		{
			radlocation4[0] = RangerOrigin4[0]+1*random_num(-300,300); 
			radlocation4[1] = RangerOrigin4[1]+1*random_num(-300,300); 
			radlocation4[2] = RangerOrigin4[2]; 
			
			new Float:LocVec[3]; 
			IVecFVec(radlocation4, LocVec); 
			create_ent(id, "bomb2", "models/p_hegrenade.mdl", 2, 6, LocVec);
		}
	}
	
} 

public CreatePlane(id)
{
	new Float:Origin[3], Float:Angle[3], Float:Velocity[3];
	new Pository[3];
	
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			get_user_origin(id, Pository, 3);
			//acg_drawdefinedspronradar (i, "jeticon2", 255, 255, 255, Pository, 0, FX_FADE, 9.0, 1.0, 0.0, 12.0, DRAW_ADDITIVE, 364, 1);
		}
		else
		{
			get_user_origin(id, Pository, 3);
			//acg_drawdefinedspronradar (i, "jeticon", 255, 255, 255, Pository, 0, FX_FADE, 1.0, 1.0, 0.0, 12.0, DRAW_ADDITIVE, 365, 1);
		}
	}

	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		get_user_origin(id, OpforOrigin, 3);
	}
	
	if(cs_get_user_team(id) == CS_TEAM_CT )
	{
		get_user_origin(id, RangerOrigin, 3);
	}
	
	velocity_by_aim(id, 0, Velocity);
	entity_get_vector(id, EV_VEC_origin, Origin);
	entity_get_vector(id, EV_VEC_v_angle, Angle);
	
	Angle[0] = Velocity[2] = 0.0;
	Origin[2] += 10.0;
	
	new ent = create_entity("info_target");
	
	entity_set_string(ent, EV_SZ_classname, "plane");
	
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
	entity_set_edict(ent, EV_ENT_owner, id);
	entity_set_origin(ent, Origin);
	
	//create_ent(id, "plane", "", 2, 8, Origin, ent);
	//create_ent(id, "samolot", "models/cod_plane.mdl", 2, 8, Origin, ent);
	
	entity_set_vector(ent, EV_VEC_velocity, Velocity);
	entity_set_vector(ent, EV_VEC_angles, Angle);
	
	emit_sound(ent, CHAN_AUTO, "mw/jet_fly1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	set_task(9.0, "del_plane", ent+5731);
}

public CreatePlane2(id)
{
	new Float:Origin[3], Float:Angle[3], Float:Velocity[3];
	new Pository[3];
	
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) == get_user_team(i))
		{
			get_user_origin(id, Pository, 3);
			//acg_drawdefinedspronradar (i, "stealthicon", 255, 255, 255, Pository, 0, FX_FADE, 1.0, 1.0, 0.0, 12.0, DRAW_ADDITIVE, 365, 1);
		}
	}

	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		get_user_origin(id, OpforOrigin4, 3);
	}
	
	if(cs_get_user_team(id) == CS_TEAM_CT )
	{
		get_user_origin(id, RangerOrigin4, 3);
	}
	velocity_by_aim(id, 0, Velocity);
	entity_get_vector(id, EV_VEC_origin, Origin);
	entity_get_vector(id, EV_VEC_v_angle, Angle);
	
	Angle[0] = Velocity[2] = 0.0;
	Origin[2] += 10.0;
	
	new ent = create_entity("info_target");
	
	entity_set_string(ent, EV_SZ_classname, "plane2");
	
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
	entity_set_edict(ent, EV_ENT_owner, id);
	entity_set_origin(ent, Origin);
	
	//create_ent(id, "plane", "", 2, 8, Origin, ent);
	//create_ent(id, "samolot", "models/cod_plane.mdl", 2, 8, Origin, ent);
	
	entity_set_vector(ent, EV_VEC_velocity, Velocity);
	entity_set_vector(ent, EV_VEC_angles, Angle);
	
	emit_sound(ent, CHAN_AUTO, "mw/jet_fly2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	set_task(9.0, "del_plane2", ent+5734);
}


public CreateHeli(id)
{
	new Float:Origin[3], Float:Angle[3], Float:Velocity[3];
	new Pository2[3];
	
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			get_user_origin(id, Pository2, 3);
			//acg_drawdefinedspronradar (i, "helicon2", 255, 255, 255, Pository2, 0, FX_FADE, 7.0, 1.0, 0.0, 9.0, DRAW_ADDITIVE, 368, 1);
			//acg_drawdefinedspronradar (i, "packicon2", 255, 255, 255, Pository2, 0, FX_FADE, 9.0, 1.0, 0.0, 14.0, DRAW_ADDITIVE, 358, 0);
		}
		else
		{
			get_user_origin(id, Pository2, 3);
			//acg_drawdefinedspronradar (i, "helicon", 255, 255, 255, Pository2, 0, FX_FADE, 1.0, 1.0, 0.0, 9.0, DRAW_ADDITIVE, 369, 1);
			//acg_drawdefinedspronradar (i, "packicon", 255, 255, 255, Pository2, 0, FX_FADE, 9.0, 0.0, 0.0, 14.0, DRAW_ADDITIVE, 359, 0);
		}
	}
	
	
	if(cs_get_user_team(id) == CS_TEAM_T )
		get_user_origin(id, OpforOrigin2, 3);
		
	if(cs_get_user_team(id) == CS_TEAM_CT )
		get_user_origin(id, RangerOrigin2, 3);
	
	velocity_by_aim(id, 0, Velocity);
	entity_get_vector(id, EV_VEC_origin, Origin);
	entity_get_vector(id, EV_VEC_v_angle, Angle);
	
	Angle[0] = Velocity[2] = 0.0;
	Origin[2] += 10.0;
	
	new ent = create_entity("info_target");
	
	entity_set_string(ent, EV_SZ_classname, "helipack");
	
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
	entity_set_edict(ent, EV_ENT_owner, id);
	entity_set_origin(ent, Origin);
	
	emit_sound(ent, CHAN_AUTO, "mw/heli_fly.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	//create_ent(id, "helipack", "", 2, 8, Origin, ent);
	//create_ent(id, "samolot1", "models/cod_plane.mdl", 2, 8, Origin, ent);
	
	entity_set_vector(ent, EV_VEC_velocity, Velocity);
	entity_set_vector(ent, EV_VEC_angles, Angle);

	set_task(4.0, "del_heli1", ent+5732);
}

public CreateHeli2(id)
{
	new Float:Origin[3], Float:Angle[3], Float:Velocity[3];
	new Pository2[3];
	
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			get_user_origin(id, Pository2, 3);
			//acg_drawdefinedspronradar (i, "helicon2", 255, 255, 255, Pository2, 0, FX_FADE, 7.0, 1.0, 0.0, 9.0, DRAW_ADDITIVE, 368, 1);
			//acg_drawdefinedspronradar (i, "packicon2", 255, 255, 255, Pository2, 0, FX_FADE, 5.0, 1.0, 0.0, 5.0, DRAW_ADDITIVE, 358, 1);
		}
		else
		{
			get_user_origin(id, Pository2, 3);
			//acg_drawdefinedspronradar (i, "helicon", 255, 255, 255, Pository2, 0, FX_FADE, 1.0, 1.0, 0.0, 9.0, DRAW_ADDITIVE, 369, 1);
			//acg_drawdefinedspronradar (i, "packicon", 255, 255, 255, Pository2, 0, FX_FADE, 5.0, 0.0, 0.0, 5.0, DRAW_ADDITIVE, 359, 1);
		}
	}
	
	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		get_user_origin(id, OpforOrigin3, 3);
	}
	if(cs_get_user_team(id) == CS_TEAM_CT )
	{
		get_user_origin(id, RangerOrigin3, 3);
	}

	velocity_by_aim(id, 0, Velocity);
	entity_get_vector(id, EV_VEC_origin, Origin);
	entity_get_vector(id, EV_VEC_v_angle, Angle);
	
	Angle[0] = Velocity[2] = 0.0;
	Origin[2] += 10.0;
	
	new ent = create_entity("info_target");
	
	entity_set_string(ent, EV_SZ_classname, "helisent");
	
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
	entity_set_edict(ent, EV_ENT_owner, id);
	entity_set_origin(ent, Origin);
	
	emit_sound(ent, CHAN_AUTO, "mw/heli_fly.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	//create_ent(id, "helisent", "", 2, 8, Origin, ent);
	//create_ent(id, "samolot2", "models/cod_plane.mdl", 2, 8, Origin, ent);
	
	entity_set_vector(ent, EV_VEC_velocity, Velocity);
	entity_set_vector(ent, EV_VEC_angles, Angle);

	
	set_task(4.0, "del_heli2", ent+5733);
}

public del_plane(taskid)
{
	remove_entity(taskid-5731);
}

public del_plane2(taskid)
{
	remove_entity(taskid-5734);
}

public del_heli1(taskid)
{
	remove_entity(taskid-5732);
}

public del_heli2(taskid)
{
	remove_entity(taskid-5733);
}



public touchedbomb(ent, id)
{
	if(!is_valid_ent(ent))
		return PLUGIN_CONTINUE;

	bombs_explode(ent, 200.0, 250.0);
	return PLUGIN_CONTINUE;
	
}

public touchedbomb2(ent, id)
{
	if(!is_valid_ent(ent))
		return PLUGIN_CONTINUE;

	bombs_explode2(ent, 200.0, 350.0);
	return PLUGIN_CONTINUE;
	
}

//predator
/*public CreatePredator(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
			client_cmd(i, "spk sound/mw/predator_enemy.wav");
		else
			client_cmd(i, "spk sound/mw/predator_friend.wav");
	}

	new Float:Origin[3], Float:Angle[3], Float:Velocity[3], ent;
	Velocity[0]+= 1.0;
	Velocity[1]+= 1.0;
	Velocity[2]+= 1.0;
	
	Origin[2] += 120.0;
	
	velocity_by_aim(id, 50, Velocity);
	entity_get_vector(id, EV_VEC_origin, Origin);
	entity_get_vector(id, EV_VEC_v_angle, Angle);
	
	Angle[0] *= -1.0;
	
	create_ent(id, "predator", "models/cod_predator.mdl", 2, 5, Origin, ent);
	
	entity_set_vector(ent, EV_VEC_velocity, Velocity);
	entity_set_vector(ent, EV_VEC_angles, Angle);
	
	entity_set_origin(ent, Origin);
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(ent);
	write_short(cache_trail);
	write_byte(10);
	write_byte(5);
	write_byte(205);
	write_byte(237);
	write_byte(163);
	write_byte(200);
	message_end();
	
	predator[id] = false;
	
	attach_view(id, ent);
	//user_controll[id] = ent;

}*/

public touchedpredator(ent, id)
{
	if(!is_valid_ent(ent))
		return PLUGIN_CONTINUE;
	
	new owner = entity_get_edict(ent, EV_ENT_owner);
	
	set_task(0.0, "fuzzscreen", owner)
	unfreezepredator(owner)
	predator_explode(ent, 300.0, 700.0);
	//attach_view(id, owner);
	return PLUGIN_CONTINUE;
}

public CreatePredator2(id)
{
	new num, players[32];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			enemykillstreak(i, "predator", 0)
		}
		else
		{
			cd_active[i] = true;
			set_task(1.0, "cooldownover", i+696)
			predator_active[i] = true;
			set_task(4.0, "predatorover", i)
			friendkillstreak(i, "predator", 0)
		}
		set_task(2.0, "sound_predfunc", i);
	}
	
	ksdisabled[id] = true;
	set_task(4.5, "enablemenu_pred", id)
	
	if(!is_user_bot(id))
	{
		set_task(0.5, "freezepredator", id)
		set_task(3.5, "unfreezepredator", id)
	}
	
	//acg_drawtga(id, "gfx/killstreaks/predator/laptop.tga", 255, 255, 255, 255, 0.5, 0.5, 0, FX_FADE, 0.3, 0.0, 0.0, 0.5, 1, ALIGN_BOTTOM, 898)
	//md_drawimage(id, 23, 0, "gfx/killstreaks/predator/laptop.tga", 0.5,0.5,0,0,255,255,255,255,0.0,0.5,2.0, ALIGN_NORMAL)
	set_task(0.5, "laptopscreen", id)
	set_task(2.3, "agmscreen2", id)
	set_task(3.16, "agmscreen3", id)
	set_task(3.9, "targetlock_display", id)
	
	set_task(4.0, "target_lock", id+998)
	
	predator[id]--;
	
	callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 150)
	
	callfunc(id, "predator_ACH", "Achievements_v2.1.amxx")
	count_kills_pm[id] = true;
	//set_task(5.5, "predator_kill_counter", id)
}

public predator_kill_counter(id)
{
	count_kills_pm[id] = false;
	//callfunc(id, "reset_kills_pm", "Achievements_v2.1.amxx")
}

public enablemenu_pred(id)
{
	ksdisabled[id] = false;
}

public targetlock_display(id)
{
	//acg_drawtga(id, "gfx/killstreaks/predator/agmscreen4.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 0.2, 0.0, 0.0, 0.83, 1, 0, 898)
	new g_screenSize[2]
	g_screenSize[0] = md_getscreenwidth()
	g_screenSize[1] = md_getscreenheight()
	
	md_drawimage(id, 28, 0, "gfx/killstreaks/predator/predatorhud.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.0, 0.0, ALIGN_NORMAL)
	md_drawimage(id, 24, 0, "gfx/killstreaks/predator/agmscreen4.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.5, 1.0, ALIGN_NORMAL, g_screenSize[0], g_screenSize[1])
}

public laptop_end(id)
{
	if(is_user_alive(id)){
		//acg_drawtga(id, "gfx/killstreaks/predator/laptop.tga", 255, 255, 255, 255, 0.5, 0.5, 0, FX_FADE, 0.0, 0.3, 0.0, 0.5, 1, ALIGN_BOTTOM, 898)
		new g_screenSize[2]
		g_screenSize[0] = md_getscreenwidth()
		g_screenSize[1] = md_getscreenheight()
	
		//md_drawimage(id, 22, 0, "gfx/killstreaks/predator/laptop.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.5, 2.0, ALIGN_NORMAL, g_screenSize[0], g_screenSize[1])
	}
}

public laptopscreen(id)
{
	Display_Fade(id,(1<<12),(4<<12),(1<<16),20, 20, 20, 255);
	//acg_drawtga(id, "gfx/killstreaks/predator/agmscreen.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 1.4, 0.0, 0.0, 1.7, 1, 0, 898)
	new g_screenSize[2]
	g_screenSize[0] = md_getscreenwidth()
	g_screenSize[1] = md_getscreenheight()
	
	md_drawimage(id, 28, 0, "gfx/killstreaks/predator/predatorhud.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.0, 0.0, ALIGN_NORMAL)
	md_drawimage(id, 25, 0, "gfx/killstreaks/predator/agmscreen.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.5, 1.5, ALIGN_NORMAL, g_screenSize[0], g_screenSize[1])
	//acg_drawtga(id, "gfx/killstreaks/predator/predatorhud.tga", 255, 255, 255, 255, 0.5, 0.5, 1, FX_FADE, 0.0, 0.2, 0.0, 4.5, 0, 0, 899)
	md_drawimage(id, 26, 0, "gfx/killstreaks/predator/predatorhud.tga", 0.5,0.5,0,0,255,255,255,255,0.0,0.5,2.0, ALIGN_NORMAL)
	//acg_drawtext(id, 0.5, 0.700, "Scanning targets...", 255, 255, 255, 200, 0.0, 0.3, 5.6, 1, TS_BORDER, 1, 0, 12)
}


public agmscreen2(id)
{
	//acg_drawtext(id, 0.5, 0.700, "Target Locked.", 255, 255, 255, 200, 0.0, 0.3, 1.7, 1, TS_BORDER, 1, 0, 12)
	//acg_drawtga(id, "gfx/killstreaks/predator/agmscreen2.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 0.2, 0.0, 0.0, 0.83, 1, 0, 896)
	new g_screenSize[2]
	g_screenSize[0] = md_getscreenwidth()
	g_screenSize[1] = md_getscreenheight()
	
	md_drawimage(id, 28, 0, "gfx/killstreaks/predator/predatorhud.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.0, 0.0, ALIGN_NORMAL)
	md_drawimage(id, 25, 0, "gfx/killstreaks/predator/agmscreen2.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.5, 1.0, ALIGN_NORMAL, g_screenSize[0], g_screenSize[1])
}

public agmscreen3(id)
{
	//acg_drawtga(id, "gfx/killstreaks/predator/agmscreen3.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 0.2, 0.0, 0.0, 0.83, 1, 0, 897)
	new g_screenSize[2]
	g_screenSize[0] = md_getscreenwidth()
	g_screenSize[1] = md_getscreenheight()
	
	md_drawimage(id, 28, 0, "gfx/killstreaks/predator/predatorhud.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.0, 0.0, ALIGN_NORMAL)
	md_drawimage(id, 25, 0, "gfx/killstreaks/predator/agmscreen3.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.5, 1.0, ALIGN_NORMAL, g_screenSize[0], g_screenSize[1])
}

public fuzzscreen(id)
{
	if(is_user_alive(id))
		set_task(0.5, "laptop_end", id);
	client_cmd(id, "spk sound/mw/fuzz_sound.wav");
	new g_screenSize[2]
	g_screenSize[0] = md_getscreenwidth()
	g_screenSize[1] = md_getscreenheight()
	
	md_removedrawing(id, 1, 28)
	md_drawimage(id, 25, 0, "gfx/killstreaks/predator/fuzzscreen.tga", 0.0, 0.0, 0, 0, 255,255,255,255, 0.0, 0.5, 1.0, ALIGN_NORMAL, g_screenSize[0], g_screenSize[1])
	//acg_drawtga(id, "gfx/killstreaks/predator/fuzzscreen.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_NONE, 0.0, 0.0, 0.0, 1.0, 1, 0, 904);
}

public freezepredator(id)
{
	client_cmd(id, "+duck")
	client_cmd(id, "+speed")
}

public unfreezepredator(id)
{
	client_cmd(id, "-duck")
	client_cmd(id, "-speed")
}

public unfreezemovement(id)
{
	if(is_user_bot(id))
		set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
}

//thanks to bugsy
enum Teams
{
    Team_Unassigned,
    Team_T,
    Team_CT,
    Team_Spectator
}

predator_target(id)
{
	new iPlayers[32], iPnum
	get_players(iPlayers, iPnum, "ae", Teams:get_user_team( id ) == Team_T ? "CT" : "TERRORIST")

	return iPnum ? iPlayers[random(iPnum)] : 0;
}

public sound_predfunc(id)
{
	client_cmd(id, "spk sound/mw/predator_sound.wav");
}

public target_lock(taskid)
{	
	new id = (taskid-998);
	new ent = create_entity("info_target");
	new iPlayer = predator_target(id)
	new AerialCoords[3];
	
	
	if(is_user_alive(iPlayer))
	{
		new dropheight = get_cvar_num("dropheight_ks")
		get_user_origin(iPlayer, AerialCoords);
		AerialCoords[0] += random_num(-20,20);
		AerialCoords[1] += random_num(-20,20);
		AerialCoords[2] += dropheight
		
		/*new num, players[32];
		get_players(players, num, "gh");
		for(new a = 0; a < num; a++)
		{
			new i = players[a];
			if(get_user_team(id) != get_user_team(i))
				acg_drawdefinedspronradar (i, "predicon2", 255, 255, 255, AerialCoords, 0, FX_FADE, 1.0, 1.0, 0.0, 4.0, DRAW_ADDITIVE, 362, 1);
			else
				acg_drawdefinedspronradar (i, "predicon", 255, 255, 255, AerialCoords, 0, FX_FADE, 1.0, 1.0, 0.0, 4.0, DRAW_ADDITIVE, 363, 1);
		}*/
		
		new Float:LocVec[3], Float:fAngles[3]; 
		IVecFVec(AerialCoords, LocVec); 
		
		entity_set_string(ent, EV_SZ_classname, "predator");
		
		entity_set_model(ent, "models/cod_predator.mdl");
		
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
		
		entity_set_edict(ent, EV_ENT_owner, id);
		
		entity_set_origin(ent, LocVec);
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_BEAMFOLLOW);
		write_short(ent);
		write_short(cache_trail);
		write_byte(10);
		write_byte(5);
		write_byte(205);
		write_byte(237);
		write_byte(163);
		write_byte(200);
		message_end();
		
		entity_get_vector(ent, EV_VEC_v_angle, fAngles)
		entity_set_vector(ent, EV_VEC_v_angle, fAngles)
		fAngles[0] *= 0.0;
		
		//attach_view(id, ent);
		//acg_removedrawnimage(id, 2, 1)
	}
}



//sentry gun
public CreateSentry(taskid) 
{
	//if(!(entity_get_int(id, EV_INT_flags) & FL_ONGROUND)) 
	//return;

	new id = (taskid-556)
	new entlist[3];
	if(find_sphere_class(id, "func_bomb_target", 650.0, entlist, 2))
	{
		client_print(id, print_chat, "You can't place a Sentry near a Bombsite.");
		return;
	}
	if(find_sphere_class(id, "func_buyzone", 650.0, entlist, 2))
	{
		client_print(id, print_chat, "You can't place a Sentry near a Buyzone.");
		return;
	}
	
	receivedsentry[id] = false;
	stopkillstreak(id)
	sentrydeployed(id)
	//if(acg_userstatus(id))
		//acg_removedrawnimage(id, 3, 30)
		
	
	new num, players[32], SentryCoords[3], Float:Origin[3];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(get_user_team(id) != get_user_team(i))
		{
			get_user_origin(id, SentryCoords);
			//acg_drawdefinedspronradar (i, "sentricon2", 255, 255, 255, SentryCoords, 0, FX_FADE, 5.0, 1.0, 0.0, 58.0, DRAW_ADDITIVE, -1, 0);
		}
		else
		{
			get_user_origin(id, SentryCoords);
			//acg_drawdefinedspronradar (i, "sentricon", 255, 255, 255, SentryCoords, 0, FX_FADE, 1.0, 1.0, 0.0, 58.0, DRAW_ADDITIVE, -1, 0);
		}
	}
	
	entity_get_vector(id, EV_VEC_origin, Origin);
	Origin[2] += 120.0;
	
	new health[12], ent = create_entity("func_breakable");
	get_cvar_string("ks_hpsentry",health, charsmax(health));
	
	DispatchKeyValue(ent, "health", health);
	DispatchKeyValue(ent, "material", "6");
	
	entity_set_string(ent, EV_SZ_classname, "sentry");
	entity_set_model(ent, "models/cod_sentrygun.mdl");
	
	entity_set_float(ent, EV_FL_takedamage, DAMAGE_YES);
	
	entity_set_size(ent, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 48.0});
	
	entity_set_origin(ent, Origin);
	entity_set_int(ent, EV_INT_solid, SOLID_SLIDEBOX);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
	entity_set_int(ent, EV_INT_iuser2, id);
	entity_set_vector(ent, EV_VEC_angles, Float:{0.0, 0.0, 0.0});
	entity_set_byte(ent, EV_BYTE_controller2, 127);

	entity_set_float(ent, EV_FL_nextthink, get_gametime()+1.0);
	client_cmd(id, "spk sound/mw/plant.wav")
	
	set_task(60.0, "del_sentry", ent);
	set_task(60.0, "del_sentricon", id);
	//kill counter
	count_kills_sentry[id] = true;
	set_task(60.0, "sentry_kill_counter", id)
}

public sentry_kill_counter(id)
{
	count_kills_sentry[id] = false;
}



public SentryThink(ent)
{
	if(!is_valid_ent(ent)) 
		return PLUGIN_CONTINUE;
	
	new Float:SentryOrigin[3], Float:closestOrigin[3];
	entity_get_vector(ent, EV_VEC_origin, SentryOrigin);

	new id = entity_get_int(ent, EV_INT_iuser2);
	new target = entity_get_edict(ent, EV_ENT_euser1);
	new firemods = entity_get_int(ent, EV_INT_iuser1);
	
	if(firemods)
	{ 
		if(/*ExecuteHam(Ham_FVisible, target, ent)*/fm_is_ent_visible(target, ent) && is_user_alive(target)) 
		{
			if(UTIL_In_FOV(target,ent))
			{
				goto fireoff;
			}
			if(g_ColdBPerk[target])
			{
				goto fireoff;
			}
			
			new Float:TargetOrigin[3];
			entity_get_vector(target, EV_VEC_origin, TargetOrigin);
				
			emit_sound(ent, CHAN_AUTO, "mw/firemw.wav", 0.8, ATTN_NORM, 0, PITCH_NORM);
			sentry_turntotarget(ent, SentryOrigin, TargetOrigin);
				
			new Float:hitRatio = random_float(0.0, 1.0) - 0.40;
			if(hitRatio <= 0.0)
			{
				UTIL_Kill(id, target, random_float(50.0, 87.0), DMG_BULLET, 1);
				
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
				write_byte(TE_TRACER);
				write_coord(floatround(SentryOrigin[0]));
				write_coord(floatround(SentryOrigin[1]));
				write_coord(floatround(SentryOrigin[2]));
				write_coord(floatround(TargetOrigin[0]));
				write_coord(floatround(TargetOrigin[1]));
				write_coord(floatround(TargetOrigin[2]));
				message_end();
			}
			entity_set_float(ent, EV_FL_nextthink, get_gametime()+0.1);
			return PLUGIN_CONTINUE;
		}
		else
		{
fireoff:
			firemods = 0;
			entity_set_int(ent, EV_INT_iuser1, 0);
			entity_set_edict(ent, EV_ENT_euser1, 0);
			emit_sound(ent, CHAN_AUTO, "mw/sentrygun_stops.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			
			entity_set_float(ent, EV_FL_nextthink, get_gametime()+1.0);
			return PLUGIN_CONTINUE;
		}
	}

	new closestTarget = getClosestPlayer(ent)
	if(closestTarget)
	{
		emit_sound(ent, CHAN_AUTO, "mw/sentrygun_starts.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
		entity_get_vector(closestTarget, EV_VEC_origin, closestOrigin);
		sentry_turntotarget(ent, SentryOrigin, closestOrigin);
		
		entity_set_int(ent, EV_INT_iuser1, 1);
		entity_set_edict(ent, EV_ENT_euser1, closestTarget);
		
		entity_set_float(ent, EV_FL_nextthink, get_gametime()+1.0);
		return PLUGIN_CONTINUE;
	}

	if(!firemods)
	{
		new controler1 = entity_get_byte(ent, EV_BYTE_controller1)+1;
		if(controler1 > 255)
			controler1 = 0;
		entity_set_byte(ent, EV_BYTE_controller1, controler1);
		
		new controler2 = entity_get_byte(ent, EV_BYTE_controller2);
		if(controler2 > 127 || controler2 < 127)
			entity_set_byte(ent, EV_BYTE_controller2, 127);
			
		entity_set_float(ent, EV_FL_nextthink, get_gametime()+0.05);
	}
	return PLUGIN_CONTINUE
}

public sentry_turntotarget(ent, Float:sentryOrigin[3], Float:closestOrigin[3]) 
{
	new newTrip, Float:newAngle = floatatan(((closestOrigin[1]-sentryOrigin[1])/(closestOrigin[0]-sentryOrigin[0])), radian) * 57.2957795;

	if(closestOrigin[0] < sentryOrigin[0])
		newAngle += 180.0;
	if(newAngle < 0.0)
		newAngle += 360.0;
	
	sentryOrigin[2] += 35.0
	if(closestOrigin[2] > sentryOrigin[2])
		newTrip = 0;
	if(closestOrigin[2] < sentryOrigin[2])
		newTrip = 255;
	if(closestOrigin[2] == sentryOrigin[2])
		newTrip = 127;
		
	entity_set_byte(ent, EV_BYTE_controller1,floatround(newAngle*0.70833));
	entity_set_byte(ent, EV_BYTE_controller2, newTrip);
	entity_set_byte(ent, EV_BYTE_controller3, entity_get_byte(ent, EV_BYTE_controller3)+20>255? 0: entity_get_byte(ent, EV_BYTE_controller3)+20);
}

public TakeDamage(ent, idinflictor, killer, Float:damage, damagebits)
{
	if(!is_user_alive(killer))
		return HAM_IGNORED;
	
	new classname[32];
	entity_get_string(ent, EV_SZ_classname, classname, 31);
	
	if(equal(classname, "sentry")) 
	{
		new id = entity_get_int(ent, EV_INT_iuser2);
		if(get_user_team(killer) == get_user_team(id))
			return HAM_SUPERCEDE;

		if(damage >= entity_get_float(ent, EV_FL_health))
		{
			new Float:Origin[3];
			entity_get_vector(ent, EV_VEC_origin, Origin);	
			new entlist[33];
			new numfound = find_sphere_class(ent, "player", 190.0, entlist, 32);
			
			for(new i=0; i < numfound; i++)
			{		
				new pid = entlist[i];
				
				if(!is_user_alive(pid) || get_user_team(id) == get_user_team(pid))
					continue;
				//UTIL_Kill(id, pid, 70.0, (1<<24));
			}
			client_cmd(id, "spk sound/mw/sentrygun_gone.wav");
			Sprite_Blast(Origin);
			//remove_entity(ent); //how to give it to crash because the server immediately removes sentry guns
			set_task(1.0, "del_sentry", ent); //how not to give it as a sentry and being shot
			set_task(0.1, "del_sentricon", ent)
		}
	}
	return HAM_IGNORED;
}

public del_sentry(ent)
{
	remove_entity(ent);
}

public del_sentricon(ent)
{
	new num, players[32], SentryCoords[3];
	get_players(players, num, "gh");
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		//acg_drawdefinedspronradar (i, "sentricon2", 0, 0, 0, SentryCoords, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_ADDITIVE, 360, 0);
		//acg_drawdefinedspronradar (i, "sentricon", 0, 0, 0, SentryCoords, 0, FX_FADE, 0.0, 0.0, 0.0, 0.1, DRAW_ADDITIVE, 361, 0);
	}
}

//wybuch, zadaje=from(damage?), promien(radius)
bombs_explode(ent, Float:zadaje, Float:promien)
{
	if(!is_valid_ent(ent)) 
		return;
	
	new killer = entity_get_edict(ent, EV_ENT_owner);
	
	new Float:entOrigin[3], Float:fDamage, Float:Origin[3];
	entity_get_vector(ent, EV_VEC_origin, entOrigin);
	entOrigin[2] += 1.0;
	
	new entlist[33];
	new numfound = find_sphere_class(ent, "player", promien, entlist, 32);	
	for(new i=0; i < numfound; i++)
	{		
		new victim = entlist[i];
		
		Display_Shake(victim,(1<<14),(1<<14),(1<<14))	
		
		if(is_user_alive(victim))
		{
			//acg_drawtga(victim, "gfx/bloodscreen/explosionblur.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 0.0, 0.5, 0.0, 2.0, 1, 0, 665);
			//new Float:fVec[3];
			//fVec[0] = random_float(PA_LOW , PA_HIGH);
			//fVec[1] = random_float(PA_LOW , PA_HIGH);
			//fVec[2] = random_float(PA_LOW , PA_HIGH);
			//entity_set_vector(victim , EV_VEC_punchangle , fVec);
		}
		
		//get_user_team determines TK or not
		if(!is_user_alive(victim) || get_user_team(killer) == get_user_team(victim))
			continue;

		
		entity_get_vector(victim, EV_VEC_origin, Origin);
		fDamage = zadaje - floatmul(zadaje, floatdiv(get_distance_f(Origin, entOrigin), promien));
		fDamage *= estimate_take_hurt(entOrigin, victim, 0);
		if(fDamage>0.0)
			UTIL_Kill(killer, victim, fDamage, DMG_BULLET, 4);
		
	
	}
	Strike_Blast(entOrigin);
	remove_entity(ent);
}

bombs_explode2(ent, Float:zadaje, Float:promien)
{
	if(!is_valid_ent(ent)) 
		return;
	
	new killer = entity_get_edict(ent, EV_ENT_owner);
	
	new Float:entOrigin[3], Float:fDamage, Float:Origin[3];
	entity_get_vector(ent, EV_VEC_origin, entOrigin);
	entOrigin[2] += 1.0;
	
	new entlist[33];
	new numfound = find_sphere_class(ent, "player", promien, entlist, 32);	
	for(new i=0; i < numfound; i++)
	{		
		new victim = entlist[i];
		
		Display_Shake(victim,(1<<14),(6<<14),(1<<14))

		//client_cmd(victim, "volume 0.0");
		//client_cmd(victim, "MP3volume 0.0");
		//set_task(5.0, "volume_up_1", victim)
		//set_task(0.1, "force_walk", victim, _, _, "a", 55)
		//set_task(3.2, "remove_force_walk", victim, _, _, "a", 3)
		
		//explosionblur
		if(is_user_alive(victim))
		{	
			//acg_drawtga(victim, "gfx/bloodscreen/explosionblur.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 0.0, 0.5, 0.0, 6.0, 1, 0, 665);
		}
		
		//get_user_team determines TK or not
		if(!is_user_alive(victim) || get_user_team(killer) == get_user_team(victim))
			continue;

		
		entity_get_vector(victim, EV_VEC_origin, Origin);
		fDamage = zadaje - floatmul(zadaje, floatdiv(get_distance_f(Origin, entOrigin), promien));
		fDamage *= estimate_take_hurt(entOrigin, victim, 0);
		if(fDamage>0.0)
			UTIL_Kill(killer, victim, fDamage, DMG_BULLET, 4);
	}
	Strike_Blast(entOrigin);
	remove_entity(ent);
}



public force_walk(id)
{
	client_cmd(id, "+speed");
}

public remove_force_walk(id)
{
	client_cmd(id, "-speed");
}

predator_explode(ent, Float:zadaje, Float:promien)
{
	if(!is_valid_ent(ent)) 
		return;
	
	new killer = entity_get_edict(ent, EV_ENT_owner);
	
	new Float:entOrigin[3], Float:fDamage, Float:Origin[3];
	entity_get_vector(ent, EV_VEC_origin, entOrigin);
	entOrigin[2] += 1.0;
	
	new entlist[33];
	new numfound = find_sphere_class(ent, "player", promien, entlist, 32);	
	for(new i=0; i < numfound; i++)
	{
		new victim = entlist[i];
		
		Display_Shake(victim,(1<<14),(1<<14),(1<<14))

		//client_cmd(victim, "volume 0.0");
		//client_cmd(victim, "MP3volume 0.0");
		//set_task(1.0, "volume_up_1", victim)
		
		//explosionblur
		if(is_user_alive(victim))
		{
			//new Float:fVec[3];
			//fVec[0] = random_float(PA_LOW , PA_HIGH);
			//fVec[1] = random_float(PA_LOW , PA_HIGH);
			//fVec[2] = random_float(PA_LOW , PA_HIGH);
			//entity_set_vector(victim , EV_VEC_punchangle , fVec);
			//acg_drawtga(victim, "gfx/bloodscreen/explosionblur.tga", 255, 255, 255, 255, 0.0, 0.0, 1, FX_FADE, 0.0, 0.5, 0.0, 4.0, 1, 0, 665)
		}
		
		//determine tk
		if(!is_user_alive(victim) || get_user_team(killer) == get_user_team(victim))
			continue;
			
		entity_get_vector(victim, EV_VEC_origin, Origin);
		fDamage = zadaje - floatmul(zadaje, floatdiv(get_distance_f(Origin, entOrigin), promien));
		fDamage *= estimate_take_hurt(entOrigin, victim, 0);
		if(fDamage>0.0)
			UTIL_Kill(killer, victim, fDamage, DMG_BULLET, 2);


	}
	Sprite_Blast2(entOrigin);
	Smoke_Blast(entOrigin);
	remove_entity(ent);
}


public message_DeathMsg()
{
	new killer = get_msg_arg_int(1);
	if(MainKiller[0] & (1<<killer))
	{
		set_msg_arg_string(4, "blank");
		return PLUGIN_CONTINUE;
	}
	if(MainKiller[1] & (1<<killer))
	{
		set_msg_arg_string(4, "sentry");
		if(count_kills_sentry[killer])
			callfunc(killer, "count_kills_sentry", "Achievements_v2.1.amxx");
		else
			callfunc(killer, "reset_kills_sentry", "Achievements_v2.1.amxx");
		return PLUGIN_CONTINUE;
	}
	if(MainKiller[2] & (1<<killer))
	{
		set_msg_arg_string(4, "predator");
		//predator
		if(count_kills_pm[killer])
			callfunc(killer, "count_kills_pm", "Achievements_v2.1.amxx");
		else
			callfunc(killer, "reset_kills_pm", "Achievements_v2.1.amxx");
		return PLUGIN_CONTINUE;
	}
	if(MainKiller[3] & (1<<killer))
	{
		set_msg_arg_string(4, "nuke");
		return PLUGIN_CONTINUE;
	}
	if(MainKiller[4] & (1<<killer))
	{
		set_msg_arg_string(4, "airstrike");
		//stealth
		if(count_kills_sb[killer])
			callfunc(killer, "count_kills_sb", "Achievements_v2.1.amxx");
		else
			callfunc(killer, "reset_kills_sb", "Achievements_v2.1.amxx");
		//precision
		if(count_kills_pa[killer])
			callfunc(killer, "count_kills_pa", "Achievements_v2.1.amxx");
		else
			callfunc(killer, "reset_kills_pa", "Achievements_v2.1.amxx");
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_CONTINUE;
}

public cooldownover(taskid)
{
	new id = (taskid - 696)	
	
	cd_active[id] = false;
}

public aerialover(id)
{
	aerial_active[id] = false;
}

public packageover(id)
{
	package_active[id] = false;
}

public sentrypackageover(id)
{
	sentry_package_active[id] = false;
}

public predatorover(id)
{
	predator_active[id] = false;
}



stock create_ent(id, szName[], szModel[], iSolid, iMovetype, Float:fOrigin[3], &ent=-1)
{
	new ent1 = create_entity("info_target");
	entity_set_string(ent1, EV_SZ_classname, szName);
	entity_set_model(ent1, szModel);
	entity_set_int(ent1, EV_INT_solid, iSolid);
	entity_set_int(ent1, EV_INT_movetype, iMovetype);
	entity_set_edict(ent1, EV_ENT_owner, id);
	entity_set_origin(ent1, fOrigin);

	
	if(ent != -1)
		ent = ent1;
}

stock Strike_Blast(Float:iOrigin[3])
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	write_coord(floatround(iOrigin[0]));
	write_coord(floatround(iOrigin[1])); 
	write_coord(floatround(iOrigin[2]));
	write_short(strike_blast);
	write_byte(32);
	write_byte(20); 
	write_byte(0);
	message_end();
}

stock Sprite_Blast(Float:iOrigin[3])
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	write_coord(floatround(iOrigin[0]));
	write_coord(floatround(iOrigin[1])); 
	write_coord(floatround(iOrigin[2]));
	write_short(sprite_blast);
	write_byte(32);
	write_byte(20); 
	write_byte(0);
	message_end();
}

stock Sprite_Blast2(Float:iOrigin[3])
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	write_coord(floatround(iOrigin[0]));
	write_coord(floatround(iOrigin[1])); 
	write_coord(floatround(iOrigin[2]));
	write_short(predator_blast);
	write_byte(32);
	write_byte(20); 
	write_byte(0);
	message_end();
}

stock Smoke_Blast(Float:iOrigin[3])
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	write_coord(floatround(iOrigin[0]));
	write_coord(floatround(iOrigin[1])); 
	write_coord(floatround(iOrigin[2]));
	write_short(smoke_blast);
	write_byte(32);
	write_byte(20); 
	write_byte(0);
	message_end();
}

stock Float:estimate_take_hurt(Float:fPoint[3], ent, ignored) 
{
	new Float:fFraction, Float:fOrigin[3], tr;
	entity_get_vector(ent, EV_VEC_origin, fOrigin);
	engfunc(EngFunc_TraceLine, fPoint, fOrigin, DONT_IGNORE_MONSTERS, ignored, tr);
	get_tr2(tr, TR_flFraction, fFraction);
	if(fFraction == 1.0 || get_tr2(tr, TR_pHit) == ent)
		return 1.0;
	return 0.6;
}

stock bartime(id, number)
{
	message_begin(MSG_ONE, get_user_msgid("BarTime"), _, id);
	write_short(number);
	message_end();	
}

stock callfuncfloat(id, const func[], const plugin[], floatamount )
{
	if(!is_user_connected(id)) return
	
	callfunc_begin(func, plugin)
	callfunc_push_int(id)
	callfunc_push_float(Float:(floatamount))
	callfunc_end();
}


stock callfunc(id, const func[], const plugin[])
{
	if(!is_user_connected(id)) return
	
	callfunc_begin(func, plugin)
	callfunc_push_int(id)
	callfunc_end();
}

stock callfuncstr(id, const func[], const plugin[], const killstreak[] )
{
	if(!is_user_connected(id)) return
	
	callfunc_begin(func, plugin)
	callfunc_push_int(id)
	callfunc_push_str(killstreak)
	callfunc_end();
}


stock Display_Fade(id,duration,holdtime,fadetype,red,green,blue,alpha)
{
	message_begin(MSG_ONE, get_user_msgid("ScreenFade"),{0,0,0},id);
	write_short(duration);
	write_short(holdtime);
	write_short(fadetype);
	write_byte(red);
	write_byte(green);
	write_byte(blue);
	write_byte(alpha);
	message_end();
}

stock Display_Shake(id,amplitude,duration,frequency)
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenShake"),{0,0,0},id);
	write_short(amplitude);
	write_short(duration);
	write_short(frequency);
	message_end();
}

stock find_drop_pack(id, const class[])
{
	new Float:origin[3], classname[32], ent;
	entity_get_vector(id, EV_VEC_origin, origin);
	
	while((ent = find_ent_in_sphere(ent, origin, 75.0)) != 0) 
	{
		entity_get_string(ent, EV_SZ_classname, classname, 31);
		if(equali(classname, class))
			return ent;
	}
	return 0;
}

stock print_info(id, const ks_name[], const ks_usage[] = "s")
{
	new ks_user[64];
	get_user_name(id, ks_user, 63);
	client_print(0, print_chat, "[KillStreak] %s i%s used by %s", ks_name, ks_usage, ks_user);
}
	
stock UTIL_Kill(killer, target, Float:damage, damagebits, ile=0)
{
	MainKiller[ile] |= (1<<killer);
	ExecuteHam(Ham_TakeDamage, target, killer, killer, damage, damagebits);
	MainKiller[ile] &= ~(1<<killer);
}
	
stock getClosestPlayer(ent)
{
	new iClosestPlayer = 0, Float:flClosestDist = MAX_DIST, Float:flDistanse, Float:fOrigin[2][3];
	new num, players[32];
	get_players(players, num, "gh")
	for(new a = 0; a < num; a++)
	{
		new i = players[a];
		if(!is_user_connected(i) || !is_user_alive(i) || /*!ExecuteHam(Ham_FVisible, i, ent)*/!fm_is_ent_visible(i, ent) || get_user_team(i) == get_user_team(entity_get_int(ent, EV_INT_iuser2)))
			continue;
		
		if(UTIL_In_FOV(i, ent))
			continue;
		
		entity_get_vector(i, EV_VEC_origin, fOrigin[0]);
		entity_get_vector(ent, EV_VEC_origin, fOrigin[1]);
		
		flDistanse = get_distance_f(fOrigin[0], fOrigin[1]);
		
		if(flDistanse <= flClosestDist)
		{
			iClosestPlayer = i;
			flClosestDist = flDistanse;
		}
	}
	return iClosestPlayer;
}

stock bool:UTIL_In_FOV(id,ent)
{
	if((get_pdata_int(id, 510) & (1<<16)) && (Find_Angle(id, ent) > 0.0))
		return true;
	return false;
}

stock Float:Find_Angle(id, target)
{
	new Float:Origin[3], Float:TargetOrigin[3];
	pev(id,pev_origin, Origin);
	pev(target,pev_origin,TargetOrigin);
	
	new Float:Angles[3], Float:vec2LOS[3];
	pev(id,pev_angles, Angles);
	
	xs_vec_sub(TargetOrigin, Origin, vec2LOS);
	vec2LOS[2] = 0.0;
	
	new Float:veclength = vector_length(vec2LOS);
	if (veclength <= 0.0)
		vec2LOS[0] = vec2LOS[1] = 0.0;
	else
	{
		new Float:flLen = 1.0 / veclength;
		vec2LOS[0] = vec2LOS[0]*flLen;
		vec2LOS[1] = vec2LOS[1]*flLen;
	}
	engfunc(EngFunc_MakeVectors, Angles);
	
	new Float:v_forward[3];
	get_global_vector(GL_v_forward, v_forward);
	
	new Float:flDot = vec2LOS[0]*v_forward[0]+vec2LOS[1]*v_forward[1];
	if(flDot > 0.5)
		return flDot;
	
	return 0.0;
}

stock bool:fm_is_ent_visible(index, entity, ignoremonsters = 0) {
	new Float:start[3], Float:dest[3];
	pev(index, pev_origin, start);
	pev(index, pev_view_ofs, dest);
	xs_vec_add(start, dest, start);

	pev(entity, pev_origin, dest);
	engfunc(EngFunc_TraceLine, start, dest, ignoremonsters, index, 0);

	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	if (fraction == 1.0 || get_tr2(0, TR_pHit) == entity)
		return true;

	return false;
}

public fw_touch(touched, weapon)
{
	if (!pev_valid(weapon)) return FMRES_IGNORED
	
	static class[32]
	pev(weapon, pev_classname, class, 31)
	
	if (equal(class, "weaponbox") || equal(class, "weapon_shield") || equal(class, "grenade") || equal(class, "item_thighpack") || equal(class, "pack") || equal(class, "sentpack"))
	{
		lie_flat(weapon)
	}
	
	return FMRES_IGNORED
}

//lieflat by nomexous
stock lie_flat(ent)
{
	// If the entity is not on the ground, don't bother continuing.
	if (pev(ent, pev_flags) & ~FL_ONGROUND) return
	
	// I decided to make all the variables static; suprisingly, the touch function can be called upwards of 5 times per drop.
	// I dunno why, but I suspect it's because the item "skips" on the ground.
	static Float:origin[3], Float:traceto[3], trace = 0, Float:fraction, Float:angles[3], Float:angles2[3]
	
	pev(ent, pev_origin, origin)
	pev(ent, pev_angles, angles)
	
	// We want to trace downwards 10 units.
	xs_vec_sub(origin, Float:{0.0, 0.0, 10.0}, traceto)
	
	engfunc(EngFunc_TraceLine, origin, traceto, IGNORE_MONSTERS, ent, trace)
	
	// Most likely if the entity has the FL_ONGROUND flag, flFraction will be less than 1.0, but we need to make sure.
	get_tr2(trace, TR_flFraction, fraction)
	if (fraction == 1.0) return
	
	// Normally, once an item is dropped, the X and Y-axis rotations (aka roll and pitch) are set to 0, making them lie "flat."
	// We find the forward vector: the direction the ent is facing before we mess with its angles.
	static Float:original_forward[3]
	angle_vector(angles, ANGLEVECTOR_FORWARD, original_forward)
	
	// If your head was an entity, no matter which direction you face, these vectors would be sticking out of your right ear,
	// up out the top of your head, and forward out from your nose.
	static Float:right[3], Float:up[3], Float:fwd[3]
	
	// The plane's normal line will be our new ANGLEVECTOR_UP.
	get_tr2(trace, TR_vecPlaneNormal, up)
	
	// This checks to see if the ground is flat. If it is, don't bother continuing.
	if (up[2] == 1.0) return
	
	// The cross product (aka vector product) will give us a vector, which is in essence our ANGLEVECTOR_RIGHT.
	xs_vec_cross(original_forward, up, right)
	// And this cross product will give us our new ANGLEVECTOR_FORWARD.
	xs_vec_cross(up, right, fwd)
	
	// Converts from the forward vector to angles. Unfortunately, vectors don't provide enough info to determine X-axis rotation (roll),
	// so we have to find it by pretending our right anglevector is a forward, calculating the angles, and pulling the corresponding value
	// that would be the roll.
	vector_to_angle(fwd, angles)
	vector_to_angle(right, angles2)
	
	// Multiply by -1 because pitch increases as we look down.
	angles[2] = -1.0 * angles2[0]
	
	// Finally, we turn our entity to lie flat.
	set_pev(ent, pev_angles, angles)
}
//volume effects
public volume_up_1(id) {
  client_cmd(id , "volume 0.2");
  client_cmd(id , "MP3Volume 0.2");
  set_task(0.2 , "volume_up_2" , id);
}

public volume_up_2(id) {
  client_cmd(id , "volume 0.4");
  client_cmd(id , "MP3Volume 0.4");
  set_task(0.2 , "volume_up_3" , id);
}

public volume_up_3(id) {
  client_cmd(id , "volume 0.6");
  client_cmd(id , "MP3Volume 0.6");
  set_task(0.2 , "volume_up_4" , id);
}

public volume_up_4(id) {
  client_cmd(id , "volume 0.8");
  client_cmd(id , "MP3Volume 0.8");
  set_task(0.2 , "volume_up_5" , id);
}

public volume_up_5(id) {
  client_cmd(id , "volume 1.0");
  client_cmd(id , "MP3Volume 1.0");
}

public eEndRound()
{
	for ( new i = 1; i <= g_maxplayers; i++ )
	{
		max_kills[i] = 0;
		limit_ks[i] = 0;
		//user_controll[i] = 0;
		nalot[i] = 0;
		predator[i] = 0;
		nuke[i] = 0;
		cuav[i] = 0;
		uav[i] = 0;
		emp[i] = 0;
		pack[i] = 0;
		sentrys[i] = 0;
		
		choose_cp[i] = false;
		disable_cp[i] = false;
		choose_predator[i] = false;
		disable_predator[i] = false;
		choose_uav[i] = false;
		choose_cuav[i] = false;
		disable_cuav[i] = false;
		choose_emp[i] = false;
		choose_nalot[i] = false;
		choose_sentrys[i] = false;
		disable_sentrys[i] = false;
		choose_nuke[i] = false;
		ksdisabled[i] = false;
		
		cd_active[i] = false;
		aerial_active[i] = false;
		sentry_package_active[i] = false;
		package_active[i] = false;
		predator_active[i] = false;
		
		unlockedks[i] = false;
		unlockedks1[i] = false;
		unlockedks2[i] = false;
		unlockedks3[i] = false;
		unlockedks4[i] = false;
		unlockedks5[i] = false;
		unlockedks6[i] = false;
		
		roundended[i] = true;
		
		disableks(i)
	}
	return PLUGIN_CONTINUE;
}

//stripweapons
public StripWeaponsNuke(i) 
{ 
	strip_user_weapons(i) 
	set_pdata_int(i, OFFSET_PRIMARYWEAPON, 0) 
}

public CreateBotstreak(id, const ks[])
{
	new randomtimes = random(10)
	new botstreak[100]
	formatex(botstreak, charsmax(botstreak), "Create%s", ks);
	
	if(randomtimes == 10)
		set_task(10.0, botstreak, id)
	if(randomtimes == 9)
		set_task(9.0, botstreak, id)
	if(randomtimes == 8)
		set_task(8.0, botstreak, id)
	if(randomtimes == 7)
		set_task(7.0, botstreak, id)
	if(randomtimes == 6)
		set_task(6.0, botstreak, id)
	if(randomtimes == 5)
		set_task(5.0, botstreak, id)
	if(randomtimes == 4)
		set_task(4.0, botstreak, id)
	if(randomtimes == 3)
		set_task(3.0, botstreak, id)
	if(randomtimes == 2)
		set_task(2.0, botstreak, id)
	if(randomtimes == 1)
		set_task(1.0, botstreak, id)
	if(randomtimes == 0)
		set_task(1.0, botstreak, id)
}



//temporary weapondisable during killstreak used

public startkillstreak( const PlayerId )
{
	if ( g_IsAlive[ PlayerId ] )
	{
		CacheWeaponInfo ( PlayerId );
		UTIL_SetNextAttack ( g_WeaponIndex[ PlayerId ], 5.0 );
		callfunc( PlayerId, "ZoomFalse", "custom_zoom.amxx")
		UTIL_SetModel ( PlayerId, 0 );
	}

}

public stopkillstreak( const PlayerId )
{
	if ( g_IsAlive[ PlayerId ] )
	{
		UTIL_SetNextAttack ( g_WeaponIndex[ PlayerId ], 0.0 );
		callfunc( PlayerId, "ZoomFalse", "custom_zoom.amxx")
		ExecuteHamB( Ham_Item_Deploy, g_WeaponIndex[ PlayerId ], 1 );
	}
}
//background firing noise cod realism
public background(id)
{
	if(!nuke_active && !roundended[id])
		client_cmd(id, "mp3 play sound/mw/background2.mp3");
	return PLUGIN_CONTINUE;
}

public Event_PlayerSpawn2 ( const PlayerId )
{
	if ( is_user_alive( PlayerId ) )
	{
		g_IsAlive[ PlayerId ] = true;
		if(ksmenu[ PlayerId ] == true)
		{
			//current reward removal
			uav[ PlayerId ] = 0;
			cuav[ PlayerId ] = 0;
			pack[ PlayerId] = 0;
			predator[ PlayerId ] = 0;
			nalot[ PlayerId ] = 0;
			sentrys[ PlayerId ] = 0;
			emp[ PlayerId ] = 0;
			nuke[ PlayerId ] = 0;
			//sentry removal
			new ent = -1
			while((ent = find_ent_by_class(ent, "sentry")))
			{
				if(entity_get_int(ent, EV_INT_iuser2) == PlayerId)
					remove_entity(ent);
			}
			md_removedrawing(PlayerId, 1, 27)
			//corereset( PlayerId );
		}
	}
}


public Event_PlayerKilled2 ( const VictimId, const AttackerId, const ShouldGib )
{
	g_IsAlive[ VictimId ] = false;
}


//stock weaponcaching
UTIL_SetNextAttack ( const WeapIndex, const Float:Delay )
{
	set_pdata_float( WeapIndex, m_flNextPrimaryAttack, Delay );
	set_pdata_float( WeapIndex, m_flNextSecondaryAttack, Delay );
}

CacheWeaponInfo ( const PlayerId )
{
	g_WeaponIndex[ PlayerId ] = get_pdata_cbase( PlayerId, m_pActiveItem );
	g_WeaponId   [ PlayerId ] = get_pdata_int( g_WeaponIndex[ PlayerId ], m_iId, 4 );
}

UTIL_SetModel ( const PlayerId, const Model )
{
	set_pev( PlayerId, pev_viewmodel, Model );
	set_pev( PlayerId, pev_weaponmodel, Model );
}

/*
UTIL_ResetZoom ( const PlayerId )
{
	set_pdata_int( PlayerId, m_iFOV, 90 );
}*/

UTIL_IsUSE ( const PlayerId )
{
	static Buttons;
	Buttons = pev( PlayerId, pev_button );

	return ( Buttons == IN_USE);
}

UTIL_IsFIRE ( const PlayerId )
{
	static Buttons;
	Buttons = pev( PlayerId, pev_button );

	return ( Buttons == IN_ATTACK);
}


get_user_flashed(id, &iPercent=0) 
{ 
    new Float:flFlashedAt = get_pdata_float(id, m_flFlashedAt) 

    if( !flFlashedAt ) 
    { 
        return 0 
    } 

    new Float:flGameTime = get_gametime() 
    new Float:flTimeLeft = flGameTime - flFlashedAt 
    new Float:flFlashDuration = get_pdata_float(id, m_flFlashDuration) 
    new Float:flFlashHoldTime = get_pdata_float(id, m_flFlashHoldTime) 
    new Float:flTotalTime = flFlashHoldTime + flFlashDuration 

    if( flTimeLeft > flTotalTime ) 
    { 
        return 0 
    } 

    new iFlashAlpha = get_pdata_int(id, m_iFlashAlpha) 

    if( iFlashAlpha == ALPHA_FULLBLINDED ) 
    { 
        if( get_pdata_float(id, m_flFlashedUntil) - flGameTime > 0.0 ) 
        { 
            iPercent = 100 
        } 
        else 
        { 
            iPercent = 100-floatround(((flGameTime - (flFlashedAt + flFlashHoldTime))*100.0)/flFlashDuration) 
        } 
    } 
    else 
    { 
        iPercent = 100-floatround(((flGameTime - flFlashedAt)*100.0)/flTotalTime) 
    } 

    return iFlashAlpha 
}  
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
