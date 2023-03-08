// Should the plugin save player data in SQL database?
// To save player data in a vault, change "#define USING_SQL" to "//#define USING_SQL"
// To save player data in SQL, change "//#define USING_SQL" to "#define USING_SQL"
// If you comment //#define USING_REGEX its a little bit more non-steam friendly 

//#define USING_SQL
//#define USING_REGEX

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>
#include <csx>
#include <fun>
#include <xs>
#include <metadrawer>

#if defined USING_REGEX
#include <regex>
#endif

#if defined USING_SQL
#include <sqlx>

new Handle:g_sql_tuple
#else
#include <nvault>

new g_iVault
#endif

#if defined USING_SQL
new g_loaded_data[ 33 ]
#endif

#define VERSION "2.0"

#define XO_PLAYER            5
#define m_pPlayer	     41
#define m_flTimeWeaponIdle   48
#define m_fInReload          54
#define m_fInSpecialReload   55
#define m_flFlashedUntil     514
#define m_flFlashedAt        515
#define m_flFlashHoldTime    516
#define m_flFlashDuration    517
#define m_iFlashAlpha        518
#define ALPHA_FULLBLINDED    255

#define INTERVAL 60

new g_iMaxPlayers
#define FIRST_PLAYER_ID	1
#define IsPlayer(%1) ( FIRST_PLAYER_ID <= %1 <= g_iMaxPlayers )

#define MAX_PLAYERS 32
#define MAX_WEAPONS CSW_P90

new g_iBombTime, g_iPlanter, 
	g_iGetBombPlanted, g_iRounds, 
	g_fwid
	
new g_iMsgSayText

	
new const Float:vecNullOrigin[ 3 ]

new Float:flDistance[ MAX_PLAYERS + 1 ],
	Float:vecOldOrigin[ MAX_PLAYERS + 1 ][ 3 ],
	Float:g_iFeet = 35.0
	
new g_iTeamKills[ 33 ], g_iRoundSparys[ 33 ], 
	g_iKills[ 33 ], g_iShotKills[ 33 ],
	g_iGrenadeKills[ 33 ], g_iBrinkKills[33],
	g_FearlessKills[ 33 ], g_SingleStealthKills[ 33 ],
	g_SinglePrecisionKills[ 33 ], g_SinglePredatorKills[ 33 ], 
	g_iSlasherKills[ 33 ], g_ActivatedUVA[ 33 ], 
	g_ActivatedCUVA[ 33 ], g_ActivatedAirstrike[ 33 ], 
	g_Airborne[ 33 ]
	
new bool:g_iBombPlant, bool:g_bFeet, bool:is_dead[ 33 ],
	bool:StandAlone[ 33 ], bool:OneHpHero[ 33 ],
	bool:is_PlayerInAir[ 33 ], bool:iKillerHasNotMoved[ 33 ],
	bool:iKillerShot[ 33 ], bool:is_Alive[ 33 ], 
	bool:g_iDeathMessages[ 33 ], bool:ongoingdisplay[ 110 ],
	bool:Flawed[33]
	
new bool:is_Connected[ MAX_PLAYERS + 1 ]
new bool:is_DefusingWithKit, bool:g_iGetBombDown

new g_iHelpMotd[ 43 ]

new challenge[99];

#if defined USING_REGEX
new Regex:g_SteamID_pattern
new g_regex_return
#endif
	
enum _:g_iAchCount
{
	CONNECTIONS,
	HEAD_SHOTS,
	DISTANCE_KILLED,
	DISTANCE_WALKED,
	BOMB,
	PLANT_BOMB,
	PLANT_BOMB_COUNT,
	DEFUSED_BOMB,
	TOTAL_KILLS,
	PISTOL_MASTER,
	RIFLE_MASTER,
	SHOTGUN_MASTER,
	SPRAY_N_PRAY,
	MASTER_AT_ARMS,
	PLAY_AROUND,
	STAND_ALONE,
	ONE_HP_HERO,
	BAD_FRIEND,
	URBAN_DESIGNER,
	GRAFFITI,
	AMMO_CONSERVATION,
	FLY_AWAY,
	RELOADER,
	CAMP_FIRE,
	CAMP_KILLS,
	HAT_TRICK,
	COWBOY_DIPLOMACY,
	TOTAL_DAMAGE,
	UAV_USED,
	CP_USED,
	CUAV_USED,
	SENTRY_USED,
	PREDATOR_USED,
	PRECISION_USED,
	STEALTH_USED,
	EMP_USED,
	NUKE_USED,
	RADAR_USED,
	AIRDROP_USED,
	AIRSTRIKE_USED,
	CROUCH_SHOT,
	TDM_WIN,
	NO_DEATHS,
	FRAGS_NODEATHS,
	SURVIVE,	//create timer that gets called off if player dies within 5 minutes
	CARPET_BOMB, // 5 KILLS using any airstrike ks call argument that lasts the entire usage of ks then turn it off afterwards
	RED_CARPET, //Same but with 6 kills and stealth bomber
	GRIM_REAPER, //single predator - 5 kills
	NO_SECRETS, //count UAV use in a single match
	SUNBLOCK, //CUAV count single
	AFTERBURNER, //airstrike single match
	SLASHER, //knife kill without dying
	NO_HANDS, //sentry kills
	PREDATOR_KILL,
	CARPET_BOMBER, //airstrike kills
	THE_SPIRIT, //stealthbomber kills
	STEALTH, //silenced weapons only
	FLASHBANG_VETERAN, //kill enemies who is flashed
	THE_LONER, //10 ks with no ks selected
	AIRBORNE,
	THE_BRINK
}

new const g_iAchsMotd[g_iAchCount][] =
{
	"Modern Warfare 2 Veteran",
	"Headhunter",
	"Eagle Eye",
	"Explorer",
	"OMFG that was close",
	"Short Fuse",
	"Boomala Boomala",
	"Nothing Can Blow Up",
	"Field Domination",
	"Pistol Marksman",
	"Rifle Marksman",
	"Shotgun Marksman",
	"Spray and Pray",
	"Weapon Expertise",
	"Hot Hour",
	"Lost Hope",
	"Raging Vengeance",
	"Defector",
	"Urban Designer",
	"Grafitti",
	"Collateral Damage",
	"Aerial Ace",
	"Reloader",
	"Sniper's Nest",
	"Sniper's Hitlist",
	"Hat Trick",
	"Cowboy Diplomacy",
	"Ravager's Creed",
	"Exposed", //UAV
	"Air Mail", //CP
	"Interference", //CUAV
	"Sentry Veteran", //Sentry 
	"Air To Ground", //Predator
	"Airstrike Veteran", //Airstrike
	"Stealth Bomber Veteran", //Stealth 
	"Blackout", //EMP
	"End Game", //NUKE
	"Radar Inbound", //Radar total
	"Airdrop Inbound", //Airdrop total
	"Airstrike Inbound", //Airstrike total
	"Crouch Shot",
	"Team Player",	//register cvar with tdm as game mode and hook with csdm tickets
	"Flawless",	//count number of deaths per player
	"Fearless",	//count number of kills
	"Survivalist",	
	"Carpet Bomb", // 5 KILLS using any airstrike ks call argument that lasts the entire usage of ks then turn it off afterwards
	"Red Carpet", //Same but with 6 kills and stealth bomber
	"Grim Reaper", //single predator - 5 kills
	"No Secrets", //count UAV use in a single match
	"Sunblock", //CUAV count single
	"Afterburner", //airstrike
	"Slasher", //knife kill without dying
	"Look! No Hands!", //sentry kills
	"Predator", //predator kills
	"Carpet Bomber", //airstrike kills
	"The Spirit", //stealthbomber kills
	"Stealth", //silenced weapons only
	"Flashbang Veteran", //kill enemies who is flashed
	"The Loner",	//Get a 10 ks with no ks selected
	"Airborne",	// kill 2 enemies while on air
	"The Brink" //kill 3 or more enemies while near death
}

new const g_iAchsMaxPoints[g_iAchCount] =
{
	500, 	// Connections
	300,	// Headshots
	4,	// distance killed
	3,	// distance walk
	1,	// bomb
	1,	// Plant bomb
	100,	// plant bomb count
	400,	// Defused Bomb
	10000,	// total kills
	7,	// Pistol master
	11,	// rifle Master
	3,	// shotgun master
	1,	// spray and pray
	26,	// Master of Arms
	60, 	// Play Around
	1,	// Lone Survivor
	1,	// 1 Hp Hero
	5,	// Bad Friend
	300,	// Urban Designer
	1,	// Graffiti Is My Second Name
	1,	// Ammo Conservation
	1,	// Fly away
	500,	// Reloader
	1,	// Sniper's Nest
	50, // Sniper's Hitlist
	1,	// HatTrick
	100,	// Cowboy Diplomacy
	350000,	// Total Damage 350000 Damage points
	50,	//Call in 50 UAV
	50,	//Call in 50 CP
	50,	//CUAV
	50, //Sentry
	50, //Predator
	50, //Precision
	25, //Stealth Bomber
	10, //EMP
	10, //Nuke
	1000, //Total RADAR
	1000, //Total Airdrops 
	1000, //Total Airstrikes
	31,	//crouch shot
	31, //Team Player
	1, //Flawless
	1, //Fearless
	1, //Survivalist
	1, // Carpet bomb
	1, //Red carpet
	1, //grim reaper
	1, //No secrets
	1, //Sunblock
	1, //Afterburner
	1, //Slasher
	1000, //sentry 1k
	1000, //predator 1k
	1000, //airstrike
	1000, //stealth bomber 1k
	1000, //stealth weap1k
	300, //flashbang veteran
	1, //the loner
	1, //airborne
	1, //thebrink
}

new g_iAuthID[ 33 ][ 36 ]

//Cvars
new g_pCvar_Enabled, g_pCvarC4Timer,
	g_pCvar_ShowInfo, g_pCvar_DeathMessage, 
	g_pCvar_BombMessage
	//g_pCvar_FriendlyFire

new const g_szWeaponNames[][] =
{
	"p228",
	"scout",              
	"hegrenade",              
	"xm1014",
	"c4",                    
	"mac10",             
	"aug", 
	"smokegrenade",            
	"elite",          
	"fiveseven",
	"ump45",               
	"sg550",
	"galil",  
	"famas",
	"usp",   
	"glock18",   
	"awp",  
	"mp5navy",     
	"m249",            
	"m3",  
	"m4a1",                
	"tmp",      
	"g3sg1",    
	"flashbang",            
	"deagle",
	"sg552", 
	"ak47",      
	"knife",                   
	"p90"
}

#define WEAPON_SIZE sizeof(g_szWeaponNames)

new const g_iWeaponIDs[WEAPON_SIZE] =
{
	CSW_P228,
	CSW_SCOUT,
	CSW_HEGRENADE,
	CSW_XM1014,
	CSW_C4,
	CSW_MAC10,
	CSW_AUG,
	CSW_SMOKEGRENADE,
	CSW_ELITE,
	CSW_FIVESEVEN,
	CSW_UMP45,
	CSW_SG550,
	CSW_GALIL,
	CSW_FAMAS,
	CSW_USP,
	CSW_GLOCK18,
	CSW_AWP,
	CSW_MP5NAVY,
	CSW_M249,
	CSW_M3,
	CSW_M4A1,
	CSW_TMP,
	CSW_G3SG1,
	CSW_FLASHBANG,
	CSW_DEAGLE,
	CSW_SG552,
	CSW_AK47,
	CSW_KNIFE,
	CSW_P90
}

new const g_iAchsWeaponMaxKills[] =
{
	1000, 	//"p228",           
	1000, 	//"scout",              
	150,  	//"hegrenade",              
	1000,	//"xm1014",
	30,	//"c4",                    
	1000,	//"mac10",             
	1000, 	//"aug", 
	150,	//"smokegrenade",            
	1000, 	//"elite",          
	1000,	//"fiveseven",
	1000,	//"ump45",               
	1000,	//"sg550",
	1000,	//"galil",  
	1000,	//"famas",
	1000,	//"usp",   
	1000,	//"glock18",   
	1000,	//"awp",  
	1000,	//"mp5navy",     
	1000,	//"m249",            
	1000,	//"m3",  
	1000,	//"m4a1",                
	1000,	//"tmp",      
	1000,	//"g3sg1",    
	1000,	//"flashbang",            
	1000,	//"deagle",
	1000,	//"sg552", 
	1000,	//"ak47",      
	250,	//"knife",                   
	1000	//"p90" 
}

new const g_szWeaponNames2[WEAPON_SIZE][] =
{
	"M9",
	"Intervention",              
	"M67 Grenade",              
	"Striker",
	"C4",                    
	"Mini-Uzi",             
	"AUG HBAR", 
	"Smoke Grenade",            
	"Akimbo Magnum",          
	"M1911 .45",
	"Vector",               
	"WA2000",
	"TAR-21",  
	"FAMAS",
	"USP .45",   
	"Glock18 Auto",   
	"Barrett .50cal",  
	"MP5K",     
	"RPD",            
	"SPAS-12",  
	"M4A1",                
	"TMP",      
	"M21 EBR",    
	"Flashbang",            
	"Desert Eagle",
	"ACR", 
	"AK47",      
	"Tactical Knife",                   
	"P90"
}

new const g_iGunEvents[][] = {
	"events/awp.sc",
	"events/g3sg1.sc",
	"events/ak47.sc",
	"events/scout.sc",
	"events/m249.sc",
	"events/m4a1.sc",
	"events/sg552.sc",
	"events/aug.sc",
	"events/sg550.sc",
	"events/m3.sc",
	"events/xm1014.sc",
	"events/usp.sc",
	"events/mac10.sc",
	"events/ump45.sc",
	"events/fiveseven.sc",
	"events/p90.sc",
	"events/deagle.sc",
	"events/p228.sc",
	"events/glock18.sc",
	"events/mp5n.sc",
	"events/tmp.sc",
	"events/elite_left.sc",
	"events/elite_right.sc",
	"events/galil.sc",
	"events/famas.sc"
}

new g_iPlayersKills[ MAX_PLAYERS+1 ][ MAX_WEAPONS+1 ]
new g_iAchLevel[ MAX_PLAYERS+1 ][ g_iAchCount ]
new g_iTimerEntity, g_iJoinTime[ MAX_PLAYERS ]

new Trie:g_tWeaponNameToID
new iWeaponID, g_iGunEvent_IDsBitsum

public plugin_init() {
	
	#if defined USING_SQL
	register_plugin( "Achievements (SQL)", VERSION, "!Pastout!!" )
	#else
	register_plugin( "Achievements", VERSION, "!Pastout!!" )
	#endif
	md_init()
	g_pCvar_Enabled = register_cvar("ach_enable", "1")// 1 = on || 0 = off
	if ( !get_pcvar_num( g_pCvar_Enabled ) )
		return;
	
	g_pCvarC4Timer = get_cvar_pointer( "mp_c4timer" )
	g_pCvar_ShowInfo = register_cvar( "ach_showinfo", "1" )
	g_pCvar_DeathMessage = register_cvar( "ach_deathmessage", "0" )
	g_pCvar_BombMessage = register_cvar( "ach_bombmessage", "0" )
	//g_pCvar_FriendlyFire = get_cvar_pointer( "mp_friendlyfire" )
	
	new command[] = "CmdMainMenu"
	register_clcmd( "challenge", command )
	register_clcmd( "say /challenge", command )
	register_clcmd( "say /challenges", command )
	register_clcmd( "say /cha", command )
	register_clcmd( "say /challengehelp", "Ach_HelpMenu" )
	register_clcmd( "say /deathmessage", "CmdDeathMessage" )
	
	register_event( "DeathMsg", "Event_PlayerKilled", "a" )
	register_event( "HLTV", "Event_NewRound", "a", "1=0", "2=0" )
	register_event( "StatusIcon", "Event_GotBomb", "be", "1=1", "1=2", "2=c4" )
	register_event( "ResetHUD", "Event_ResetHud", "be" )
	register_event( "23", "Event_Spray", "a", "1=112" )
	
	register_logevent( "Event_PlayerAction", 3, "1=triggered" )
	
	g_iTimerEntity = create_entity( "info_target" )
	entity_set_string( g_iTimerEntity, EV_SZ_classname, "hud_entity" )
	register_think( "hud_entity", "FwdHUDThink" )
	entity_set_float( g_iTimerEntity, EV_FL_nextthink, get_gametime() + 1.0 )
	
	g_iMaxPlayers = get_maxplayers()
	g_tWeaponNameToID = TrieCreate()
	g_iMsgSayText = get_user_msgid("SayText")
	
	for( new i = 0; i < WEAPON_SIZE; i++ )
	{
		TrieSetCell( g_tWeaponNameToID, g_szWeaponNames[i], g_iWeaponIDs[i] )
	}
	
	new const NO_RELOAD = ( 1 << 2 ) | ( 1 << CSW_KNIFE ) | ( 1 << CSW_C4 ) | ( 1 << CSW_M3 ) |
		( 1 << CSW_XM1014 ) | ( 1 << CSW_HEGRENADE ) | ( 1 << CSW_FLASHBANG ) | ( 1 << CSW_SMOKEGRENADE )
    
	new szWeaponName[ 20 ]
	for( new i = CSW_P228; i <= CSW_P90; i++ ) {
		if( NO_RELOAD & ( 1 << i ) )
			continue;
			
		get_weaponname( i, szWeaponName, 19 )
		RegisterHam( Ham_Weapon_Reload, szWeaponName, "FwdHamWeaponReload", 1 )
	}
	
	RegisterHam( Ham_Weapon_Reload, "weapon_m3",     "FwdHamShotgunReload", 1 )
	RegisterHam( Ham_Weapon_Reload, "weapon_xm1014", "FwdHamShotgunReload", 1 )
	RegisterHam( Ham_TraceAttack, "player", "FwdHamTraceAttack" )
	RegisterHam( Ham_Spawn, "player", "FwdPlayerSpawn", 1 )

	unregister_forward( FM_PrecacheEvent, g_fwid, 1 )
	//register_forward( FM_PlaybackEvent, "FwdPlaybackEvent" )
	register_forward( FM_CmdStart, "FwdCmdStart" )

	new dir[ 23 ]
	get_configsdir( dir, 22 )
	formatex( g_iHelpMotd, 42, "%s/achievements.txt", dir )
	
	#if !defined USING_SQL
	g_iVault = nvault_open("Achievements")
    
	if(g_iVault == INVALID_HANDLE)
		set_fail_state( "Error opening nVault" )
	
	#endif
	
	#if defined USING_REGEX
	new err[ 2 ]
	g_SteamID_pattern = regex_compile( "^^STEAM_0:(0|1):\d+$", g_regex_return, err, sizeof( err ) - 1 )
	#endif
}
public md_init()
{
	md_loadimage("gfx/challenge.tga")
}
public achievement_display(id)
{
	//acg_drawtga(id, "gfx/challenge.tga", 255, 255, 255, 255, 0.5, 0.2, 1, FX_FADE, 0.4, 0.4, 0.0, 5.0, 0, 0, 921)
	md_drawimage(id, 29, 0, "gfx/challenge.tga", 0.3, 0.2, 0, 0, 255,255,255,255, 0.0, 0.5, 4.0, ALIGN_NORMAL)
	//acg_drawtext(id, 0.5, 0.240, challenge, 255, 255, 255, 200, 0.4, 0.4, 5.0, 1, TS_SHADOW, 1, 0, 14)
	md_drawtext(id, 19, challenge, 0.3, 0.4, 0, 0, 255,255,255,255, 0.0, 0.5, 4.0, ALIGN_NORMAL)
	client_cmd(id, "spk sound/achievement.wav")
	//callfunc(id, "displaystatuscollective", "addon_killstreaks.amxx")

	//set_task(3.0, "call_ks_statusremoval", id)
	//native acg_drawtga(id, const szTGA[], red, green, blue, alpha, Float:x, Float:y, center, effects, Float:fadeintime, Float:fadeouttime, Float:fxtime, Float:holdtime, bfullscreen, align, channel)
}

public displaystatus2(id){
	ongoingdisplay[id] = true;
}

public displaystatusremoval2(id){
	ongoingdisplay[id] = false;
}

public call_ks_statusremoval(id){
	callfunc(id, "displaystatusremovalcollective", "addon_killstreaks.amxx")
}

public client_damage( iAttacker, iVictim, gDamage, iWeapon, iHitplace, TA )
{
	#if defined USING_REGEX
	if( !IsUserAuthorized( iAttacker ) || !IsUserAuthorized( iVictim ) )
	{
		return PLUGIN_HANDLED
	}
	#endif
	
	new szName[ 32 ]
	get_user_name( iAttacker, szName, charsmax( szName ) )
	
	new iPreviousLevel = g_iAchLevel[ iAttacker ][ TOTAL_DAMAGE ] / g_iAchsMaxPoints[ TOTAL_DAMAGE ]
	new iNewLevel = ( g_iAchLevel[ iAttacker ][ TOTAL_DAMAGE ] += gDamage ) / g_iAchsMaxPoints[ TOTAL_DAMAGE ]
	if( iNewLevel > iPreviousLevel )
	{
		format(challenge, charsmax(challenge), "Ravager's Creed: Reach a milestone of causing 350000 total damage.")
		if(!ongoingdisplay[iAttacker])
		{
			set_task(0.3, "achievement_display", iAttacker)
		}
		else
		{
			set_task(3.0, "achievement_display", iAttacker)
		}
		//callfuncfloat(iAttacker, "ks_bonus_xp", "gunxpmod.amxx", 10000)
	}
	
	#if defined USING_REGEX
	return PLUGIN_HANDLED
	#endif
}

public Event_PlayerAction( )
{
	new szArg[ 64 ], szAction[ 64 ], szName[ 64 ]
	new iUserId, id
	
	read_logargv( 0, szArg, 64 )
	read_logargv( 2, szAction, 64 )
	parse_loguser( szArg, szName, 64, iUserId )
	id = find_player( "k", iUserId )
	
	if( id == 0 )
	{
		return
	}
	#if defined USING_REGEX
	if( !IsUserAuthorized( id ) )
	{
		return
	}
	#endif
	if( equal( szAction, "Rescued_A_Hostage" ) )
	{
		g_iAchLevel[ id ][ COWBOY_DIPLOMACY ]++
		switch( g_iAchLevel[ id ][ COWBOY_DIPLOMACY ] )
		{
			case 100:
			{
				g_iAchLevel[ id ][ COWBOY_DIPLOMACY ]++
				format(challenge, charsmax(challenge), "Cowboy Diplomacy: Rescued a total of 100 Hostages.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)	
				}
				//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
		}
		Print( id, "^1[^4AMMX^1]^3 %s^1 has^4 rescued^1 a^3 Hostage^1.", szName )// Hostage rescued 
	}
	
	if( get_pcvar_num( g_pCvar_BombMessage ) == 1 )
	{
		if( equal( szAction, "Begin_Bomb_Defuse_With_Kit" ) )
		{
			is_DefusingWithKit = true
		}
	}
	#if defined USING_REGEX
	return
	#endif
}

public FwdHamWeaponReload( const iWeapon ) {
	
	new iPlayers[ 32 ], iNum, iPlayer
	get_players(iPlayers, iNum, "ah")
	for( new i = 0; i < iNum; i++ ) 
	{
		 iPlayer = iPlayers[ i ]
	}
	
	#if defined USING_REGEX
	if( !IsUserAuthorized( iPlayer ) )
	{
		return PLUGIN_HANDLED
	}
	#endif
	
	new szName[ 32 ]
	get_user_name( iPlayer, szName, charsmax( szName ) )
	
	if( get_pdata_int( iWeapon, m_fInReload, 4 ) ) {
		g_iAchLevel[ iPlayer ][ RELOADER ]++
		switch( g_iAchLevel[ iPlayer ][ RELOADER ] )
		{
			case 500:
			{
				g_iAchLevel[ iPlayer ][ RELOADER ]++
				format(challenge, charsmax(challenge), "Reloader: Reloaded a weapon for a total of 500 reloads")
				if(!ongoingdisplay[iPlayer])
				{
					set_task(0.3, "achievement_display", iPlayer)
				}
				else
				{
					set_task(3.0, "achievement_display", iPlayer)
				}
				//callfuncfloat(iPlayer, "ks_bonus_xp", "gunxpmod.amxx", 10000)
			}
		}
	}
	#if defined USING_REGEX
	return PLUGIN_HANDLED
	#endif
}

public FwdHamShotgunReload( const iWeapon ) {
	if( get_pdata_int( iWeapon, m_fInSpecialReload, 4 ) != 1 )
		return
	new Float:flTimeWeaponIdle = get_pdata_float( iWeapon, m_flTimeWeaponIdle, 4 )
    
	if( flTimeWeaponIdle != 0.55 )
		return
	
	new iPlayers[ 32 ], iNum, iPlayer
	get_players(iPlayers, iNum, "ah")
	for( new i = 0; i < iNum; i++ ) 
	{
		 iPlayer = iPlayers[ i ]
	}
	
	#if defined USING_REGEX
	if( !IsUserAuthorized( iPlayer ) )
	{
		return
	}
	#endif
	
	new szName[ 32 ]
	get_user_name( iPlayer, szName, charsmax( szName ) )
	
	g_iAchLevel[ iPlayer ][ RELOADER ]++
	switch( g_iAchLevel[ iPlayer ][ RELOADER ] )
	{
		case 500:
		{
			g_iAchLevel[ iPlayer ][ RELOADER ]++
			format(challenge, charsmax(challenge), "Reloader: Reloaded a weapon for a total of 1000 reloads")
			if(!ongoingdisplay[iPlayer])
			{
				set_task(0.3, "achievement_display", iPlayer)
			}
			else
			{
				set_task(3.0, "achievement_display", iPlayer)
			}
			//callfuncfloat(iPlayer, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
	}
	#if defined USING_REGEX
	return
	#endif
}

public FwdHUDThink( iEntity )
{
	if ( iEntity != g_iTimerEntity )
		return
		
	static id
	new szName[ 32 ]
	for ( id = 1; id <= MAX_PLAYERS; id++ )
	{
		if ( is_user_connected( id ) && ( ( get_systime() - g_iJoinTime[ id ] ) >= INTERVAL ) )
		{
			#if defined USING_REGEX
			if( !IsUserAuthorized( id ) )
			{
				return
			}
			#endif
			get_user_name( id, szName, charsmax( szName ) )
			g_iJoinTime[ id ] = get_systime()
			g_iAchLevel[ id ][ PLAY_AROUND ]++
			switch( g_iAchLevel[ id ][ PLAY_AROUND ] )
			{
				case 60:
				{
					g_iAchLevel[ id ][ PLAY_AROUND ]++
					format(challenge, charsmax(challenge), "Hot Hour: Play a total of 60 minutes.")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				}
			}
			#if defined USING_REGEX
			return
			#endif
		}
	}
    
	entity_set_float( g_iTimerEntity, EV_FL_nextthink, get_gametime() + 1.0 )
}  

public CmdDeathMessage( id )
{
	if( get_pcvar_num( g_pCvar_DeathMessage ) != 1 )
	{
		
		Print( id, "^4[AMXX]^3 Sorry^1 the^4 death message^1 have been^4 disable^1 for^3 everyone." )
		return PLUGIN_HANDLED
	}
	if( g_iDeathMessages[ id ] == false )
	{
		g_iDeathMessages[ id ] = true
		Print( id, "^4[AMXX]^1 You have^4 Enable^3 death messages^1." )
	} 
	else 
	{
		if( g_iDeathMessages[ id ] == true )
		{
			g_iDeathMessages[ id ] = false
			Print( id, "^4[AMXX]^1 You have^4 Disable^3 death messages^1." )
		}
	}
	return PLUGIN_HANDLED
}

public plugin_precache()
{
	g_fwid = register_forward( FM_PrecacheEvent, "FwdPrecacheEvent", 1 )
	precache_generic("gfx/challenge.tga");
	precache_generic("sound/achievement.wav")
	
	#if defined USING_SQL
	g_sql_tuple = SQL_MakeStdTuple()
	
	SQL_ThreadQuery(g_sql_tuple, "QueryCreateTable", "CREATE TABLE IF NOT EXISTS ^"Achievement^" ( ^"name^" VARCHAR(32) NOT NULL, ^"authid^" VARCHAR(35) NOT NULL, ^"data^" VARCHAR(256) NOT NULL );" )
	
	#endif
}

public FwdPrecacheEvent( type, const name[] ) {
	for( new i = 0; i < sizeof g_iGunEvents; ++i ) {
		if( equal( g_iGunEvents[ i ], name ) ) {
			g_iGunEvent_IDsBitsum |= ( 1<<get_orig_retval() )
			return FMRES_HANDLED
		}
	}
	return FMRES_IGNORED
}

public FwdPlaybackEvent( flags, id, eventid ) {
	if( !( g_iGunEvent_IDsBitsum & ( 1<<eventid) ) || !(1 <= id <= g_iMaxPlayers ) )
		return FMRES_IGNORED
		
	iKillerShot[ id ] = false
	g_iShotKills[ id ] = 0

	return FMRES_HANDLED
}

public FwdHamTraceAttack( this, iAttacker, Float:damage, Float:direction[ 3 ], traceresult, damagebits )
{
	if( is_Connected[ iAttacker ] && is_Alive[ iAttacker ] )
	{
		static g_iWeapon; g_iWeapon = get_user_weapon( iAttacker )
		if( g_iWeapon == CSW_KNIFE || g_iWeapon == CSW_HEGRENADE )
		{
			return PLUGIN_HANDLED
		}
		
		iKillerShot[ iAttacker ] = true
	
	}
	return PLUGIN_HANDLED
}

#if defined USING_SQL
public QueryCreateTable(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
{
	if( failstate == TQUERY_CONNECT_FAILED
	|| failstate == TQUERY_QUERY_FAILED )
	{
		set_fail_state(error)
	}
}
#endif

public Ach_HelpMenu( id )
{
	show_motd( id, g_iHelpMotd, "Achievements Help" )
	Print( id, "^4[AMXX]^1 This server is using^3 Achievements/Challenges(Modern Warfare 2)^4 v%s^1, by^3 Pastout and Infract3m!", VERSION )	
}

public CmdMainMenu( id )
{
	Ach_StartMenu( id )
}

public Ach_StartMenu( id ) {
	//Menu Title
	new title[ 256 ]; formatex( title, sizeof( title ) - 1, "\yMain Menu^n" )
	//Create the menu
	new menu = menu_create( title, "StartMenu_Handle" )
	menu_additem( menu, "\wInfo", "1", 0 )
	menu_additem( menu, "\wWeapon\y Challenges\r Player Info", "2", 0 )
	menu_additem( menu, "\wCustom\y Challenges\r Player Info", "3", 0 )
	menu_additem( menu, "\wHelp", "4", 0 )
	menu_display( id, menu )
}

public StartMenu_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new key = str_to_num( data )
	switch( key )
	{
		case 1:
		{
			Print( id, "^4[AMXX]^1 This server is using^3 Achievements/Challenges(Modern Warfare 2)^4 v%s^1, by^3 Pastout and Infract3m!", VERSION )
			Ach_StartMenu( id )
		}
		case 2:
		{
			Ach_WeaponStartMenu( id )
		}
		case 3:
		{
			Ach_PlayerStartMenu( id )
		}
		case 4:
		{
			Ach_HelpMenu( id )
			Ach_StartMenu( id )
		}
	}
	return PLUGIN_HANDLED
}

public Ach_WeaponStartMenu( id ) {
	new title[ 256 ]; formatex( title, sizeof( title ) - 1, "\rWeapon\w Achievements^n" )
	new menu = menu_create( title, "WeaponStartMenu_Handle" )
	menu_additem( menu, "\yAchievements\r 1/10", "1", 0 )
	menu_additem( menu, "\yAchievements\r 11/20", "2", 0 )
	menu_additem( menu, "\yAchievements\r 21/29", "3", 0 )
	menu_additem( menu, "\wHelp", "4", 0 )
	menu_display( id, menu )
}

public WeaponStartMenu_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new key = str_to_num( data )
	switch( key )
	{
		case 1:
		{
			Ach_PlayerWeaponMenu( id )
		}
		case 2:
		{
			Ach_PlayerWeaponMenu2( id )
		}
		case 3:
		{
			Ach_PlayerWeaponMenu3( id )
		}
		case 4:
		{
			Ach_HelpMenu( id )
			Ach_StartMenu( id )
		}
	}
	return PLUGIN_HANDLED
}

public Ach_PlayerWeaponMenu( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rWeapon Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerWeaponMenu_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerWeaponMenu_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_WeaponStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )

	for( new i = 0; i < 10; i++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_szWeaponNames2[ i ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iPlayersKills[ tempid ][ g_iWeaponIDs[ i ] ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsWeaponMaxKills[ i ] )
	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerWeaponMenu2( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rWeapon Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerWeaponMenu2_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerWeaponMenu2_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_WeaponStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )

	for( new i = 10; i < 20; i++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_szWeaponNames2[ i ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iPlayersKills[ tempid ][ g_iWeaponIDs[ i ] ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsWeaponMaxKills[ i ] )
	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerWeaponMenu3( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rWeapon Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerWeaponMenu3_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerWeaponMenu3_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_WeaponStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )

	for( new i = 20; i < WEAPON_SIZE; i++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_szWeaponNames2[ i ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iPlayersKills[ tempid ][ g_iWeaponIDs[ i ] ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsWeaponMaxKills[ i ] )
	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerStartMenu( id ) {
	new title[ 256 ]; formatex( title, sizeof( title ) - 1, "\rCustom\w Achievements^n" )
	new menu = menu_create( title, "PlayerStartMenu_Handle" )
	menu_additem( menu, "\yAchievements\r 1-10", "1", 0 )
	menu_additem( menu, "\yAchievements\r 11-20", "2", 0 )
	menu_additem( menu, "\yAchievements\r 21-30", "3", 0 )
	menu_additem( menu, "\yAchievements\r 31-40", "4", 0 )
	menu_additem( menu, "\yAchievements\r 41-50", "5", 0 )
	menu_additem( menu, "\yAchievements\r 51-60", "6", 0 )
	menu_additem( menu, "\wHelp", "7", 0 )
	menu_display( id, menu )
}

public PlayerStartMenu_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new key = str_to_num( data )
	switch( key )
	{
		case 1:
		{
			Ach_PlayerLevelMenu( id )
		}
		case 2:
		{
			Ach_PlayerLevelMenu2( id )
		}
		case 3:
		{
			Ach_PlayerLevelMenu3( id )
		}
		case 4:
		{
			Ach_PlayerLevelMenu4( id )
		}
		case 5:
		{
			Ach_PlayerLevelMenu5( id )
		}
		case 6:
		{
			Ach_PlayerLevelMenu6( id )
		}
		case 7:
		{
			Ach_HelpMenu( id )
			Ach_StartMenu( id )
		}
	}
	return PLUGIN_HANDLED
}

public Ach_PlayerLevelMenu( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rCustom Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerLevelMenu_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerLevelMenu_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_PlayerStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )
	
	for( new iLevel = 0; iLevel < 10; iLevel++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_iAchsMotd[ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchLevel[ tempid ][ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsMaxPoints[ iLevel ] )

	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerLevelMenu2( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rCustom Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerLevelMenu2_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerLevelMenu2_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_PlayerStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )
	
	for( new iLevel = 10; iLevel < 20; iLevel++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_iAchsMotd[ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchLevel[ tempid ][ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsMaxPoints[ iLevel ] )

	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerLevelMenu3( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rCustom Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerLevelMenu3_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerLevelMenu3_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_PlayerStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )
	
	for( new iLevel = 20; iLevel < 30; iLevel++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_iAchsMotd[ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchLevel[ tempid ][ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsMaxPoints[ iLevel ] )

	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerLevelMenu4( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rCustom Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerLevelMenu4_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerLevelMenu4_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_PlayerStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )
	
	for( new iLevel = 30; iLevel < 40; iLevel++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_iAchsMotd[ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchLevel[ tempid ][ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsMaxPoints[ iLevel ] )

	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerLevelMenu5( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rCustom Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerLevelMenu5_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerLevelMenu5_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_PlayerStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )

	for( new iLevel = 40; iLevel < 50; iLevel++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_iAchsMotd[ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchLevel[ tempid ][ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsMaxPoints[ iLevel ] )

	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public Ach_PlayerLevelMenu6( id )
{
	new title[ 170 ]; formatex( title, sizeof( title ) - 1, "\rCustom Achievements^n\w - \yPlayer Menu")
	new menu = menu_create( title, "Ach_PlayerLevelMenu6_Handle" )
	
	new players[ 32 ], pnum, tempid
	new szName[ 32 ], szTempid[ 10 ]
	
	get_players( players, pnum )
	
	for( new i; i < pnum; i++ )
	{
		tempid = players[ i ]
		
		get_user_name( tempid, szName, 31 )
		num_to_str( tempid, szTempid, 9 )
		
		menu_additem( menu, szName, szTempid, 0 )
	}
	
	menu_display( id, menu )
}

public Ach_PlayerLevelMenu6_Handle( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		menu_destroy( menu )
		if( is_Connected[ id ] )
			Ach_PlayerStartMenu( id )
		return PLUGIN_HANDLED
	}
	
	new data[ 6 ], iName[ 64 ]
	new access, callback
	menu_item_getinfo( menu, item, access, data, 5, iName, 63, callback )
	
	new tempid = str_to_num( data )
	new tempname[ 32 ]; get_user_name( tempid, tempname, 31 )
	
	static motd[ 2500 ], len
	len = format( motd, sizeof( motd ) - 1,			"<body bgcolor=#744F00>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<table width=100%% cellpadding=2 cellspacing=4 border=4>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#DCA300>" )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=10%% align=left>%s", tempname )
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=15%% align=center>Achievement Level" );
	len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<th width=20%% align=center>Achievement Max Level" )

	for( new iLevel = 50; iLevel < g_iAchCount; iLevel++ )
	{
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<tr align=center bgcolor=#c7c7c7>" )
		len += format( motd[ len ], sizeof( motd ) - len - 1,	"<td align=left>%s", g_iAchsMotd[ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchLevel[ tempid ][ iLevel ] )
		len += format( motd[ len ], sizeof( motd ) - len - 1, 	"<td align=center>%i", g_iAchsMaxPoints[ iLevel ] )

	}
	len += format( motd[ len ], sizeof( motd ) - len - 1,	"</table></body>" )
	
	show_motd( id, motd, "Player Info" )
	menu_display( id, menu )
	menu_destroy( menu )
	return PLUGIN_HANDLED
}

public plugin_end()
{
	TrieDestroy( g_tWeaponNameToID )
	#if !defined USING_SQL
	nvault_close( g_iVault )
	#endif
}

public FwdPlayerSpawn(id)
{
	if( !is_user_alive( id ) )
	{
		return HAM_IGNORED
	}
	
	set_task(300.0, "bool_survive", id+144)
	is_Alive[ id ] = true
	
	return HAM_IGNORED;
}

public client_connect( id )
{
	is_dead[ id ] = false
	ResetStats( id )
}

public client_authorized( id )
{
	if( !is_user_bot( id ) && !is_user_hltv( id ) )
	{
		#if defined USING_REGEX
		get_user_authid( id, g_iAuthID[ id ], charsmax( g_iAuthID[] ) - 1 )
		
		if( !IsValidAuthid( g_iAuthID[ id ] ) )
		{
			g_iAuthID[ id ][0] = 0
		}
		else
		{
			g_iLoadStats( id )
		}
		#else
		get_user_authid( id, g_iAuthID[ id ], charsmax( g_iAuthID[] ) )
		g_iLoadStats( id )
		#endif
	}
}

public client_putinserver( id )
{
	is_Connected[ id ] = true
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iJoinTime[ id ] = get_systime()
		is_Alive[ id ] = false
		g_iDeathMessages[ id ] = true
		g_iAchLevel[ id ][ CONNECTIONS ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ CONNECTIONS ] )
		{
			case 100:
			{
				format(challenge, charsmax(challenge), "MW2 Veteran(Bronze): Play in a total of 100 matches.")
				if(!ongoingdisplay[id])
				{
					set_task(60.3, "achievement_display", id)
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				}
				return PLUGIN_HANDLED
			}
            
			case 250:
			{
				format(challenge, charsmax(challenge), "MW2 Veteran(Silver): Play in a total of 250 matches.")
				if(!ongoingdisplay[id])
				{
					set_task(60.3, "achievement_display", id)
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 7500)
				}
				return PLUGIN_HANDLED
			}
            
			case 500:
			{
				format(challenge, charsmax(challenge), "MW2 Veteran(Gold): Play in a total of 500 matches.")
				if(!ongoingdisplay[id])
				{
					set_task(60.3, "achievement_display", id)
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
				}
				return PLUGIN_HANDLED
			}
            
			case 1000:
			{
				format(challenge, charsmax(challenge), "MW2 Veteran(Platinum): Play in a total of 1000 matches.")
				if(!ongoingdisplay[id])
				{
					set_task(60.3, "achievement_display", id)
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 15000)
				}
				return PLUGIN_HANDLED
			}
		}
	}
	return PLUGIN_HANDLED
}

public client_disconnect( id )
{
	g_iSaveStats( id )

	g_iJoinTime[ id ] = 0
	is_Connected[ id ] = false
	is_Alive[ id ] = false

	#if defined USING_SQL
	g_loaded_data[ id ] = 0
	#endif
}

public FwdCmdStart( id, handle )
{
	if ( !is_Connected[ id ] && !is_Alive[ id ] ) 
	{
		return FMRES_IGNORED
	}
	#if defined USING_REGEX
	if( !IsUserAuthorized( id ) )
	{
		return FMRES_IGNORED
	}
	#endif

	if( g_iAchLevel[ id ][ CAMP_FIRE ] <= 1 )
	{
		if( entity_get_int( id, EV_INT_button ) & ( IN_MOVELEFT | IN_MOVERIGHT | IN_BACK | IN_FORWARD ) )
		{
			iKillerHasNotMoved[ id ] = false
			g_iKills[ id ] = 0
		}
		else 
		{
			iKillerHasNotMoved[ id ] = true
		}
	}
	
	if( g_iAchLevel[ id ][ CAMP_KILLS ] <= 50 )
	{
		if( entity_get_int( id, EV_INT_button ) & ( IN_MOVELEFT | IN_MOVERIGHT | IN_BACK | IN_FORWARD ) )
		{
			iKillerHasNotMoved[ id ] = false
		}
		else 
		{
			iKillerHasNotMoved[ id ] = true
		}
	}
	
	if( g_iAchLevel[ id ][ FLY_AWAY ] <= 1 )
	{
		if( entity_get_int( id, EV_INT_flags ) & FL_ONGROUND )
		{
			is_PlayerInAir[ id ] = false
		}
		else
		{
			is_PlayerInAir[ id ] = true
		}
	}
	
	if( g_iAchLevel[ id ][ DISTANCE_WALKED ] <= 2 && iKillerHasNotMoved[ id ] == false )
	{
		new Float:vecOrigin[ 3 ]
		entity_get_vector( id, EV_VEC_origin, vecOrigin )
	
		if( !xs_vec_equal( vecOldOrigin[ id ], vecNullOrigin ) )
		{
			flDistance[ id ] += get_distance_f( vecOrigin, vecOldOrigin[ id ] )
		}
		
		xs_vec_copy( vecOrigin, vecOldOrigin[ id ] )
		
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )
		
		switch( g_iAchLevel[ id ][ DISTANCE_WALKED ] )
		{
			case 0:
			{
				if( flDistance[ id ]/g_iFeet >= 125 )//baby steps
				{
					g_iAchLevel[ id ][ DISTANCE_WALKED ]++
					
					format(challenge, charsmax(challenge), "Pioneer: Walk a total of 125 feet.")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 300)
				}
			}
			case 1:
			{
				if( flDistance[ id ]/g_iFeet >= 5280 )//1 mile hey?
				{
					g_iAchLevel[ id ][ DISTANCE_WALKED ]++
					format(challenge, charsmax(challenge), "Trekker: Walk a total of 1 mile.")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 6000)
				}
			}
			case 2:
			{
				if( flDistance[ id ]/g_iFeet >= 52800 )//Ten miles hey? Is this possible IDK lol
				{
					g_iAchLevel[ id ][ DISTANCE_WALKED ]++
					format(challenge, charsmax(challenge), "Explorer: Walk a total of 10 miles.")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 15000)
				}
			}
		}
	}
	
	new iPlayers[ 32 ], iNum, iPlayer, ctCount, tCount
	get_players( iPlayers, iNum, "ah" )
	
	for( new i = 0; i < iNum; i++ ) 
	{
		iPlayer = iPlayers[ i ]
		
		static CsTeams:iTeam
		iTeam = cs_get_user_team( iPlayers[ i ] )
		
		switch( iTeam )
		{
			case CS_TEAM_CT:
			{
				ctCount++
			}
			
			case CS_TEAM_T:
			{
				tCount++
			}
		}
	}
	if(get_user_team(id) == get_user_team(iPlayer))
	{
		if( ctCount == 1 || tCount == 1 )
		{
			StandAlone[ iPlayer ] = true
		}
		else
		{
			StandAlone[ iPlayer ] = false;
		}
	}
	
	return FMRES_IGNORED
}

ResetStats( id )
{
	flDistance[ id ] = 0.0
	xs_vec_copy( vecNullOrigin, vecOldOrigin[ id ] )
}

public Event_NewRound()
{
	remove_task(0)
	
	if( get_pcvar_num( g_pCvar_ShowInfo ) == 1 )
	{
		if( g_iRounds >= 6 ) {
			Print( 0, "^4[AMXX]^1 This server is using^3 Achievements/Challenges(MW2 mod^4 v%s^1, by^3 Pastout and Infract3m!", VERSION )
			Print( 0, "^4[AMXX]^1 Type^3 /challengehelp^1 for information about^4 challenges")
			g_iRounds = 0
		}
		
		g_iRounds++
	}
	
	for( new i = 0; i < g_iMaxPlayers; i++ ) 
	{
		g_iTeamKills[ i ] = 0
		g_iRoundSparys[ i ] = 0
		StandAlone[ i ] = false
		Flawed[ i ] = false;
	}
	g_iBombPlant = false
	g_iGetBombPlanted = 26
	set_task( 1.0, "CheckBombPlantedTimer", 0, _, _, "a", g_iGetBombPlanted )
}

public CheckBombPlantedTimer( )
{ 
	g_iGetBombPlanted--
	if( g_iGetBombPlanted >= 1 )
	{
		g_iGetBombDown = true
		
	} else {	
		g_iGetBombDown = false
		remove_task(0)
	}
}

public bomb_defused( iDefuser )
{
	#if defined USING_REGEX
	if( !IsUserAuthorized( iDefuser ) )
	{
		return PLUGIN_HANDLED
	}
	#endif
	new szName[ 32 ]
	get_user_name( iDefuser, szName, charsmax( szName ) )
	
	switch( g_iAchLevel[ iDefuser ][ BOMB ] )
	{
		case 0:
		{
			if( g_iBombPlant == true )
			{
				Print( iDefuser, "^4[Challenge]^3 %s^1 has earned ^3'^1OMFG that was close^3'^4 Challenge!", szName ) 
				client_cmd(iDefuser, "spk sound/achievement.wav")
				set_task(0.3, "achievement_display", iDefuser)
			}
			g_iAchLevel[ iDefuser ][ BOMB ]++
		}
	}
	
	g_iAchLevel[ iDefuser ][ DEFUSED_BOMB ]++
	switch( g_iAchLevel[ iDefuser ][ DEFUSED_BOMB ] )
	{
		case 50: 
		{	
			Print( iDefuser, "^4[Challenge]^3 %s^1 has earned ^3'^1C4 Defuser^3'^4 Challenge!", szName ) 
			client_cmd(iDefuser, "spk sound/achievement.wav")
			set_task(0.3, "achievement_display", iDefuser)
		}
		case 100: 
		{
			Print( iDefuser, "^4[Challenge]^3 %s^1 has earned ^3'^1That Was Easy^3'^4 Challenge!", szName ) 
			client_cmd(iDefuser, "spk sound/achievement.wav")
			set_task(0.3, "achievement_display", iDefuser)
		}
		case 150: 
		{
			Print( iDefuser, "^4[Challenge]^3 %s^1 has earned ^3'^1Like a Game^3'^4 Challenge!", szName ) 
			client_cmd(iDefuser, "spk sound/achievement.wav")
			set_task(0.3, "achievement_display", iDefuser)
		}
		case 200: 
		{
			Print( iDefuser, "^4[Challenge]^3 %s^1 has earned ^3'^1Master of C4^3'^4 Challenge!", szName ) 
			client_cmd(iDefuser, "spk sound/achievement.wav")
			set_task(0.3, "achievement_display", iDefuser)
		}
		case 400: 
		{
			Print( iDefuser, "^4[Challenge]^3 %s^1 has earned ^3'^1Nothing Can Blow Up^3'^4 Challenge!", szName ) 
			client_cmd(iDefuser, "spk sound/achievement.wav")
			set_task(0.3, "achievement_display", iDefuser)
		}
	}
	if( get_pcvar_num( g_pCvar_BombMessage ) == 1 )
	{
		Print( iDefuser, "^4[AMXX]^3 %s^1 has defused the^4 bomb.", szName ) 
	}
	#if defined USING_REGEX
	return PLUGIN_HANDLED
	#endif
}

public bomb_defusing( id )
{
	if( get_pcvar_num( g_pCvar_BombMessage ) == 1 )
	{
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )
		Print( id, "^1[^4AMMX^1]^3 %s^1 is defusing the^4 bomb^1 with%s a^3 kit^1.", szName, is_DefusingWithKit ? "" : "out" ) 
	}
}

public bomb_planting( id )
{
	if( get_pcvar_num( g_pCvar_BombMessage ) == 1 )
	{
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )
		Print( id, "^4[AMXX]^3 %s^1 is planting the^4 bomb.", szName ) 
	}
}

public bomb_planted( iPlanter )
{
	#if defined USING_REGEX
	if( !IsUserAuthorized( iPlanter ) )
	{
		return PLUGIN_HANDLED
	}
	#endif
	
	new szName[ 32 ]
	get_user_name( iPlanter, szName, charsmax( szName ) )
	
	g_iBombTime = get_pcvar_num( g_pCvarC4Timer )
	set_task( 1.0, "CheckC4Timer", 0, _, _, "a", g_iBombTime )
	
	g_iAchLevel[ iPlanter ][ PLANT_BOMB_COUNT ]++

	if( is_Connected[ iPlanter ] && is_Alive[ iPlanter ] )
	{
		switch( g_iAchLevel[ iPlanter ][ PLANT_BOMB ] )
		{
			case 0:
			{
				if( g_iGetBombDown == true )
				{
					g_iAchLevel[ iPlanter ][ PLANT_BOMB ]++
					Print( iPlanter, "^4[Challenge]^3 %s^1 has earned ^3'^1Short Fuse^3'^4 Challenge!", szName ) 
					client_cmd(iPlanter, "spk sound/achievement.wav")
					set_task(0.3, "achievement_display", iPlanter)
				}
			}
		}
	
		switch( g_iAchLevel[ iPlanter ][ PLANT_BOMB_COUNT ]++ )
		{
			case 100:
			{
				Print( iPlanter, "^4[Challenge]^3 %s^1 has earned ^3'^1Boomala Boomala^3'^4 Challenge!", szName ) 
				client_cmd(iPlanter, "spk sound/achievement.wav")
				set_task(0.3, "achievement_display", iPlanter)
			}
		}
	}
	if( get_pcvar_num( g_pCvar_BombMessage ) == 1 )
	{
		Print( iPlanter, "^1[^4AMMX^1]^3 %s^1 has planted the^4 bomb.", szName ) 
	}
	#if defined USING_REGEX
	return PLUGIN_HANDLED
	#endif
}

public CheckC4Timer()
{ 
	g_iBombTime --
	if( g_iBombTime <= 1 )
	{
		g_iBombPlant = true
		remove_task(0)
	}
}

public Event_ResetHud( id )
{
	is_dead[ id ] = false
}

public Event_GotBomb( id )
{
	g_iPlanter = id
}

public bomb_explode( g_iPlayer )
{
	if( get_pcvar_num( g_pCvar_BombMessage ) == 1 )
	{
		Print( g_iPlayer, "^1[^4AMMX^1] The^3 bomb^1 has^4 exploded." )  
	}
	if( g_iPlanter <= 0 ) return PLUGIN_CONTINUE
	set_task( 0.5, "check_dead", 9743248 )
	return PLUGIN_CONTINUE
}

public check_dead( )
{
	new frags = 0
	new kname[ 32 ], kteam[ 10 ], kauthid[ 32 ]
	get_user_name( g_iPlanter, kname, 31 )
	get_user_team( g_iPlanter, kteam, 9 )
	get_user_authid( g_iPlanter, kauthid, 31 )

	new players[ 32 ], inum
	get_players( players, inum )
	for( new i = 0; i < inum; i++ )
	{
		new team = get_user_team( players[ i ] )
		if( is_Connected[ players[ i ] ] && !is_Alive[ players[ i ] ] && team != 0 && team != 3 )
		{
			if( !is_dead[ players[ i ] ] && team != get_user_team( g_iPlanter ) && players[ i ] != g_iPlanter )
			{
				++frags
				message_begin( MSG_BROADCAST, 83, {0,0,0}, 0 )
				write_byte( g_iPlanter )
				write_byte( players[ i ] )
				write_byte( 0 )
				write_string("c4")
				message_end()

				new vname[ 32 ], vteam[ 10 ], vauthid[ 32 ]

				get_user_name( players[ i ], vname, 31 )
				get_user_team( players[ i ], vteam, 9 )
				get_user_authid( players[ i ], vauthid, 31 )
		
				log_message("^"%s<%d><%s><%s>^" killed ^"%s<%d><%s><%s>^" with ^"%s^"", 
					kname, get_user_userid( g_iPlanter ), kauthid, kteam, 
 					vname, get_user_userid( players[ i ] ), vauthid, vteam, "c4" )
				g_iPlayersKills[ g_iPlanter ][ CSW_C4 ]++
				if( g_iPlayersKills[ g_iPlanter ][ CSW_C4 ] == 30 )
				{
					Print( g_iPlanter, "^4[Challenge]^3 %s^1 has earned ^3'^1C4 Killer^3'^4 Challenge!", kname )
					client_cmd(g_iPlanter, "spk sound/achievement.wav")
					set_task(0.3, "achievement_display", g_iPlanter)
				}
			}
		}
	}
	if( frags )
	{
		frags += get_user_frags( g_iPlanter )
		set_user_frags( g_iPlanter, frags )
	}
}

public client_death( iKiller, iVictim, iWeapon, iHitplace, TK )
{
	#if defined USING_REGEX
	if( !IsUserAuthorized( iKiller ) || !IsUserAuthorized( iVictim ) )
	{
		return PLUGIN_HANDLED
	}
	#endif
	
	new g_iKiller[ 32 ]
	get_user_name( iKiller, g_iKiller, charsmax( g_iKiller ) )
	if( ( iWeapon == CSW_HEGRENADE ) && !TK && is_Alive[ iKiller ] )
	{
		g_iPlayersKills[ iKiller ][ CSW_HEGRENADE ]++
		if( g_iPlayersKills[ iKiller ][ CSW_HEGRENADE ] == 150 )
		{
			format(challenge, charsmax(challenge), "M67 Grenade Expert: Kill 150 enemies using M26 Grenades.")
			if(!ongoingdisplay[iKiller])
			{
				set_task(0.3, "achievement_display", iKiller)
			}
			else
			{
				set_task(3.0, "achievement_display", iKiller)
			}
			//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
		
		g_iGrenadeKills[ iKiller ]++
		if( g_iGrenadeKills[ iKiller ] == 3 )
		{
			g_iAchLevel[ iKiller ][ HAT_TRICK ]++
			switch( g_iAchLevel[ iKiller ][ HAT_TRICK ] )
			{
				case 1:
				{
					g_iAchLevel[ iKiller ][ HAT_TRICK ]++
					format(challenge, charsmax(challenge), "Hat Trick: Kill 3 players using a M67 Grenade.")
					if(!ongoingdisplay[iKiller])
					{
						set_task(0.3, "achievement_display", iKiller)
					}
					else
					{
						set_task(3.0, "achievement_display", iKiller)
					}
					//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 3000)
				}
			}
			g_iGrenadeKills[ iKiller ] = 0
		}
		
		set_task( 0.3, "ResetGrenadeKills", iKiller+131 )
	}
	
	if( (OneHpHero[ iKiller ] == true) && !TK && is_Alive[ iKiller ])
	{
		g_iBrinkKills[ iKiller ]++
		if( g_iBrinkKills[ iKiller ] == 3 )
		{
			g_iAchLevel[ iKiller ][ THE_BRINK ]++
			switch( g_iAchLevel[ iKiller ][ THE_BRINK ] )
			{
				case 1:
				{
					g_iAchLevel[ iKiller ][ THE_BRINK ]++
					format(challenge, charsmax(challenge), "The Brink: Get a 3 or more kill streak while near death.")
					if(!ongoingdisplay[iKiller])
					{
						set_task(0.3, "achievement_display", iKiller)
					}
					else
					{
						set_task(3.0, "achievement_display", iKiller)
					}
					//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 4500)
				}
				case 2:
				{
				
				}
			}
			g_iBrinkKills[ iKiller ] = 0
		}
		set_task( 4.0, "ResetBrinkKills", iKiller+127 )
	}
	
	#if defined USING_REGEX
	return PLUGIN_HANDLED
	#endif
}

public ResetGrenadeKills(taskid)
{
	new id = (taskid - 131)
	g_iGrenadeKills[ id ] = 0
}

public ResetBrinkKills(taskid)
{
	new id = (taskid - 127)
	g_iBrinkKills[ id ] = 0
}

public grenade_throw( id, grenadeIndex, weaponId )
{
	#if defined USING_REGEX
	if( !IsUserAuthorized( id ) )
	{
		return PLUGIN_HANDLED
	}
	#endif
	
	new g_iName[ 32 ]
	get_user_name( id, g_iName, charsmax( g_iName ) )
	
	switch( weaponId )
	{
		case CSW_FLASHBANG:
		{
			g_iPlayersKills[ id ][ CSW_FLASHBANG ]++
			
			if( g_iPlayersKills[ id ][ CSW_FLASHBANG ] == 300 )
			{
				format(challenge, charsmax(challenge), "Light Liberation: Blind 300 players using flashbangs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				//callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 3000)
			}
		}
		case CSW_SMOKEGRENADE:
		{
			g_iPlayersKills[ id ][ CSW_SMOKEGRENADE ]++
			
			if( g_iPlayersKills[ id ][ CSW_SMOKEGRENADE ] == 150 )
			{
				format(challenge, charsmax(challenge), "Fog of War: Use a total of 150 Smoke Grenades.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 3000)
			}
		}
	}
	#if defined USING_REGEX
	return PLUGIN_HANDLED
	#endif
}

get_user_flashed( id, &iPercent=0 )
{
	new Float:flFlashedAt = get_pdata_float( id, m_flFlashedAt, XO_PLAYER )
	
	if( !flFlashedAt )
	{
		return 0
	}
	
	new Float:flGameTime = get_gametime()
	new Float:flTimeLeft = flGameTime - flFlashedAt
	new Float:flFlashDuration = get_pdata_float( id, m_flFlashDuration, XO_PLAYER )
	new Float:flFlashHoldTime = get_pdata_float( id, m_flFlashHoldTime, XO_PLAYER )
	new Float:flTotalTime = flFlashHoldTime + flFlashDuration
	
	if( flTimeLeft > flTotalTime )
	{
		return 0
	}
	
	new iFlashAlpha = get_pdata_int( id, m_iFlashAlpha, XO_PLAYER )
	
	if( iFlashAlpha == ALPHA_FULLBLINDED )
	{
		if( get_pdata_float( id, m_flFlashedUntil, XO_PLAYER) - flGameTime > 0.0 )
		{
			iPercent = 100
		}
		else
		{
			iPercent = 100-floatround( ( ( flGameTime - ( flFlashedAt + flFlashHoldTime ) ) * 100.0 )/flFlashDuration )
		}
	}
	else
	{
		iPercent = 100-floatround( ( ( flGameTime - flFlashedAt ) * 100.0 ) / flTotalTime )
	}
	
	return iFlashAlpha;
}

public Event_PlayerKilled()
{
	new iKiller = read_data( 1 )
	new iVictim = read_data( 2 )
	
	is_dead[ iVictim ] = true
	Flawed[ iVictim ] = true;
	
	if(task_exists(iVictim+144))
	{
		remove_task(iVictim+144);
	}
	
	is_Alive[ iKiller ] = bool:is_user_alive( iKiller )
	
	if( !IsPlayer( iKiller ) || iKiller == iVictim )
	{
		return PLUGIN_HANDLED
	}
	
//	if( get_pcvar_num( g_pCvar_FriendlyFire ) == 0 )
//	{
//		return PLUGIN_HANDLED
//	}
	#if defined USING_REGEX
	if( !IsUserAuthorized( iKiller ) || !IsUserAuthorized( iVictim ) )
	{
		return PLUGIN_HANDLED
	}
	#endif
	
	new headshot = read_data( 3 )
	new g_iKiller[ 32 ], g_iVictim[ 32 ], g_iWeapon[ 16 ], g_iOrigin[ 3 ], g_iOrigin2[ 3 ]
	read_data(4, g_iWeapon, 15)

	get_user_origin( iKiller, g_iOrigin )
	get_user_origin( iVictim, g_iOrigin2 )
	new flDistance = get_distance( g_iOrigin, g_iOrigin2 )
	
	get_user_name( iKiller, g_iKiller, charsmax( g_iKiller ) )
	get_user_name( iVictim, g_iVictim, charsmax( g_iVictim ) )
	
	if(!Flawed[ iKiller ])
	{
		g_FearlessKills[ iKiller ]++
		//fearless
		if( g_FearlessKills[ iKiller ] == 10 )
		{
			g_iAchLevel[ iKiller ][ FRAGS_NODEATHS ]++
			switch( g_iAchLevel[ iKiller ][ FRAGS_NODEATHS ] )
			{
				case 1:
				{
					format(challenge, charsmax(challenge), "Fearless: Kill 10 enemies in a single match without dying.")
					if(!ongoingdisplay[iKiller])
					{
						set_task(0.3, "achievement_display", iKiller)
					}
					else
					{
						set_task(3.0, "achievement_display", iKiller)
					}
					//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 2000)
				}
			}
		}
	}
	else
		g_FearlessKills[ iKiller ] = 0;
	
	if( iKillerShot[ iKiller ] == true )
	{
		g_iShotKills[ iKiller ]++
		if( g_iShotKills[ iKiller ] >= 2 )
		{
			g_iAchLevel[ iKiller ][ AMMO_CONSERVATION ]++
			switch( g_iAchLevel[ iKiller ][ AMMO_CONSERVATION ] )
			{
				case 1:
				{
					g_iAchLevel[ iKiller ][ AMMO_CONSERVATION ]++
					format(challenge, charsmax(challenge), "Collateral Damage: Killed two or more enemies using a single bullet.")
					if(!ongoingdisplay[iKiller])
					{
						set_task(0.3, "achievement_display", iKiller)
					}
					else
					{
						set_task(3.0, "achievement_display", iKiller)
					}
					//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 3000)
				}
			}
		}
		else
			g_iShotKills[ iKiller ] = 0 
	}
	
	if( headshot )
	{
		
		g_iAchLevel[ iKiller ][ HEAD_SHOTS ]++
		
		switch( g_iAchLevel[ iKiller ][ HEAD_SHOTS ] )
		{
			case 300: 
			{
				format(challenge, charsmax(challenge), "Headhunter: Kill 300 enemies using headshots.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
		}
	}

	if( TrieGetCell( g_tWeaponNameToID, g_iWeapon, iWeaponID ) )
	{
		g_iPlayersKills[ iKiller ][ iWeaponID ]++

		switch( iWeaponID )
		{
			case CSW_P228:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 200: 
					{
						g_iAchLevel[ iKiller ][ PISTOL_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "M9 Expert: Kill 200 enemies using M9.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
				stealth_weapon(iKiller)
			}
			case CSW_SCOUT:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 1000: 
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "Intervention Expert: Kill 1000 enemies using Intervention.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}

			case CSW_XM1014:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						g_iAchLevel[ iKiller ][ SHOTGUN_MASTER ]++
						format(challenge, charsmax(challenge), "Striker Expert: Kill 300 enemies using Striker.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 6000)
					}
				}
			}

			case CSW_MAC10:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "Mini-Uzi Expert: Kill 300 enemies using Mini-Uzi.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
			}
			case CSW_AUG:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 700:
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++	
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "AUG HBAR Expert: Kill 1000 enemies using AUG HBAR.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
				
			}
			/*
			case CSW_SMOKEGRENADE:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{

				}
			}*/
			case CSW_ELITE:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300:
					{
						g_iAchLevel[ iKiller ][ PISTOL_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "Akimbo Magnum Expert: Kill 300 enemies using Akimbo Magnum.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
			}
			case CSW_FIVESEVEN:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300: 
					{
						g_iAchLevel[ iKiller ][ PISTOL_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "COLT Expert: Kill 300 enemies using COLT.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
			}
			case CSW_UMP45:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 500: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "Vector Expert: Kill 500 enemies using Vector.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
			}
			case CSW_SG550:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 1000: 
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "WA2000 Expert: Kill 1000 enemies using WA2000.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_GALIL:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 500: 
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "TAR-21 Expert: Kill 500 enemies using TAR-21.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_FAMAS:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 500: 
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "FAMAS Expert: Kill 500 enemies using FAMAS.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_USP:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 200:
					{
						g_iAchLevel[ iKiller ][ PISTOL_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "USP .45 Expert: Kill 200 enemies using USP .45.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 5000)
					}
				}
			}
			case CSW_GLOCK18:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300:
					{
						g_iAchLevel[ iKiller ][ PISTOL_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "M93 Raffica Expert: Kill 300 enemies using M93 Raffica.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
			}
			case CSW_AWP:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 1000:
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "Barrett .50cal Expert: Kill 1000 enemies using Barrett .50cal.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_MP5NAVY:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 500: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						Print( iKiller, "^4[Challenge]^3 %s^1 has earned ^3'^1MP5K Expert^3'^4 Challenge!", g_iKiller )
						format(challenge, charsmax(challenge), "MP5K Expert: Kill 500 enemies using MP5K.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_M249:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 1000:
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "RPD Expert: Kill 1000 enemies using RPD.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_M3:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						g_iAchLevel[ iKiller ][ SHOTGUN_MASTER ]++
						format(challenge, charsmax(challenge), "SPAS-12 Expert: Kill 300 enemies using SPAS-12.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						//callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
			}
			case CSW_M4A1:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 700:
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "M4 Carbine Expert: Kill 700 enemies using M4 Carbine.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
				stealth_weapon(iKiller)
			}
			case CSW_TMP:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "TMP Expert: Kill 300 enemies using TMP.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
				stealth_weapon(iKiller)
			}
			case CSW_G3SG1:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 1000:
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "M21-EBR Expert: Kill 1000 enemies using M21-EBR.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			/*
			case CSW_FLASHBANG:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{

				}
			}*/
			case CSW_DEAGLE:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 300: 
					{
						g_iAchLevel[ iKiller ][ PISTOL_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "Desert Eagle Expert: Kill 300 enemies using Desert Eagle.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 7500)
					}
				}
			}
			case CSW_SG552:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 700: 
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "ACR Expert: Kill 700 enemies using ACR.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_AK47:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 700:
					{
						g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "AK47 Expert: Kill 700 enemies using AK47.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_KNIFE:
			{
				g_iSlasherKills[iKiller]++
				switch( g_iSlasherKills[ iKiller ])
				{
					case 3:
					{
						g_iAchLevel[ iKiller ][ SLASHER ]++
						switch( g_iAchLevel[ iKiller ][ SLASHER ] )
						{
							case 1:
							{
								format(challenge, charsmax(challenge), "Slasher: Get a 3 melee kill streak without dying.")
								if(!ongoingdisplay[iKiller])
								{
									set_task(0.3, "achievement_display", iKiller)
								}
								else
								{
									set_task(3.0, "achievement_display", iKiller)
								}
								callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 3500)
							}
						}
					}
				}
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 10: 
					{
						format(challenge, charsmax(challenge), "Knife Veteran I: Kill 10 enemies with a melee attack.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
					case 50: 
					{
						format(challenge, charsmax(challenge), "Knife Veteran II: Kill 50 enemies with a melee attack.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
					case 100: 
					{
						format(challenge, charsmax(challenge), "Knife Veteran III: Kill 200 enemies with a melee attack.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
					case 250: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "Knife Veteran IV: Kill 250 enemies with a melee attack.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
			case CSW_P90:
			{
				switch( g_iPlayersKills[ iKiller ][ iWeaponID ] )
				{
					case 700: 
					{
						g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
						format(challenge, charsmax(challenge), "ES P90 Expert: Kill 700 enemies using ES P90.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
					}
				}
			}
		}
	}

	if( floatround( flDistance/g_iFeet ) == 1 )
	{
		g_bFeet = false
	} else {
		g_bFeet = true
	}
		
	switch( g_iAchLevel[ iKiller ][ DISTANCE_KILLED ] )
	{
		case 0:
		{
			if( floatround( flDistance/g_iFeet ) <= 5 )
			{
				g_iAchLevel[ iKiller ][ DISTANCE_KILLED ]++
				format(challenge, charsmax(challenge), "Close Quarters: Kill an enemy within 5 feet from your position.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 500)
			}
		}
		
		case 1:
		{
			if( 6 <= floatround( flDistance/g_iFeet ) <= 50 )
			{
				g_iAchLevel[ iKiller ][ DISTANCE_KILLED ]++
				format(challenge, charsmax(challenge), "Steady Aim: Kill an enemy within 50 feet from your position.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 1000)
			}	
		}
		
		case 2:
		{
			if( 51 <= floatround( flDistance/g_iFeet ) <= 99 )
			{
				g_iAchLevel[ iKiller ][ DISTANCE_KILLED ]++
				format(challenge, charsmax(challenge), "Long Shot: Kill an enemy within 99 feet from your position.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 1500)
			}
		}
		
		case 3:
		{
			if( 100 <= floatround( flDistance/g_iFeet ) <= 150 )
			{
				g_iAchLevel[ iKiller ][ DISTANCE_KILLED ]++
				format(challenge, charsmax(challenge), "Hunter's Precision: Kill an enemy within 150 feet from your position.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 3000)
			}
		}
		case 4:
		{
			if( 151 <= floatround( flDistance/g_iFeet ) <= 300 )
			{
				format(challenge, charsmax(challenge), "Eagle Eye: Kill an enemy within 300 feet from your position.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
		}
	}
	
	g_iAchLevel[ iKiller ][ TOTAL_KILLS ]++
	switch( g_iAchLevel[ iKiller ][ TOTAL_KILLS ] )
	{
		case 5000:
		{
			format(challenge, charsmax(challenge), "Field Control: Reach a milestone total of 5000 total kills.")
			if(!ongoingdisplay[iKiller])
			{
				set_task(0.3, "achievement_display", iKiller)
			}
			else
			{
				set_task(3.0, "achievement_display", iKiller)
			}
			callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 25000)
		}
		case 10000:
		{
			format(challenge, charsmax(challenge), "Field Domination: Reach a milestone total of 10000 total kills.")
			if(!ongoingdisplay[iKiller])
			{
				set_task(0.3, "achievement_display", iKiller)
			}
			else
			{
				set_task(3.0, "achievement_display", iKiller)
			}
			callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 50000)
		}
	}
	
	switch( g_iAchLevel[ iKiller ][ PISTOL_MASTER ] )
	{
		case 6:
		{
			g_iAchLevel[ iKiller ][ PISTOL_MASTER ]++
			format(challenge, charsmax(challenge), "Pistol Marksman: Unlocked all Pistol challenges.")
			if(!ongoingdisplay[iKiller])
			{
				set_task(0.3, "achievement_display", iKiller)
			}
			else
			{
				set_task(3.0, "achievement_display", iKiller)
			}
			callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 25000)
		}
	}

	switch( g_iAchLevel[ iKiller ][ RIFLE_MASTER ] )
	{
		case 10:
		{
			g_iAchLevel[ iKiller ][ RIFLE_MASTER ]++
			format(challenge, charsmax(challenge), "Rifle Marksman: Unlocked all Rifle Challenges.")
			if(!ongoingdisplay[iKiller])
			{
				set_task(0.3, "achievement_display", iKiller)
			}
			else
			{
				set_task(3.0, "achievement_display", iKiller)
			}
			callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 25000)
		}
		case 11:
		{
		
		}
	}
	
	switch( g_iAchLevel[ iKiller ][ SHOTGUN_MASTER ] )
	{
		case 2:
		{
			g_iAchLevel[ iKiller ][ SHOTGUN_MASTER ]++
			format(challenge, charsmax(challenge), "Shotgun Marksman: Unlocked all Shotgun Challenges.")
			if(!ongoingdisplay[iKiller])
			{
				set_task(0.3, "achievement_display", iKiller)
			}
			else
			{
				set_task(3.0, "achievement_display", iKiller)
			}
			callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 25000)
		}
	}
	
	switch( g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ] )
	{
		case 25:
		{
			g_iAchLevel[ iKiller ][ MASTER_AT_ARMS ]++
			format(challenge, charsmax(challenge), "Weapon Expertise: Unlocked all Weapon Challenges.")
			if(!ongoingdisplay[iKiller])
			{
				set_task(0.3, "achievement_display", iKiller)
			}
			else
			{
				set_task(3.0, "achievement_display", iKiller)
			}
			callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 25000)
		}
	}
	
	if( is_PlayerInAir[ iVictim ] == true )
	{
		g_iAchLevel[ iKiller ][ FLY_AWAY ]++
		switch( g_iAchLevel[ iKiller ][ FLY_AWAY ] )
		{
			case 1:
			{
				g_iAchLevel[ iKiller ][ FLY_AWAY ]++
				format(challenge, charsmax(challenge), "Aerial Ace: Kill an enemy jumping in the air.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 500)
			}
		}
	}
	if( is_PlayerInAir[ iKiller ] == true )
	{
		g_Airborne[ iKiller ] ++
		switch( g_Airborne[ iKiller ] )
		{
			case 2:
			{
				g_iAchLevel[ iKiller ][ AIRBORNE ]++
				switch( g_iAchLevel[ iKiller ][ AIRBORNE ] )
				{
					case 1:
					{
						format(challenge, charsmax(challenge), "Airborne: Kill 2 enemies while in the air.")
						if(!ongoingdisplay[iKiller])
						{
							set_task(0.3, "achievement_display", iKiller)
						}
						else
						{
							set_task(3.0, "achievement_display", iKiller)
						}
						callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 5000)
					}
				}
			}
		}
	}
	else
	{
		g_Airborne[ iKiller ] = 0;
	}
	
	//new iPercent, iFlashAlpha;
	if( get_user_flashed(iKiller ))
	{

		g_iAchLevel[ iKiller ][ SPRAY_N_PRAY ]++
		
		switch( g_iAchLevel[ iKiller ][ SPRAY_N_PRAY ] )
		{
			case 1:
			{
				format(challenge, charsmax(challenge), "Spray and Pray: Kill an enemy while blinded by a flashbang.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 3000)
			}
		}
	}
	else
	{
		if( get_pcvar_num( g_pCvar_DeathMessage ) == 1 && g_iDeathMessages[ iKiller ] == true )
		{
			Print( iKiller, "%s^4 %s^3 [^1 %s^3 ]^1 with a^4 %s^1 with a distance of^4 %d F%st^1 away.", g_iKiller, headshot ? "Headshot" : "Killed", g_iVictim, g_iWeapon, floatround( flDistance/g_iFeet ), g_bFeet ? "ee" : "oo" )
		}
	}
	
	if(get_user_flashed(iVictim))
	{
		g_iAchLevel[ iKiller ][ FLASHBANG_VETERAN ]++
			
		switch( g_iAchLevel[ iKiller ][ FLASHBANG_VETERAN ] )
		{
			case 20:
			{
				format(challenge, charsmax(challenge), "Flashbang Veteran I: Kill 20 enemies dazed by a flashbang.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 2500)
			}
			case 75:
			{
				format(challenge, charsmax(challenge), "Flashbang Veteran II: Kill 75 enemies dazed by a flashbang.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
			case 150:
			{
				format(challenge, charsmax(challenge), "Flashbang Veteran III: Kill 150 enemies dazed by a flashbang.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
			case 300:
			{
				format(challenge, charsmax(challenge), "Flashbang Veteran IV: Kill 300 enemies dazed by a flashbang.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 10000)
			}
		}
	}
	
	if( StandAlone[ iVictim ] == true )
	{
		g_iAchLevel[ iVictim ][ STAND_ALONE ]++
		switch( g_iAchLevel[ iVictim ][ STAND_ALONE ] )
		{
			case 1:
			{
				g_iAchLevel[ iVictim ][ STAND_ALONE ]++
				format(challenge, charsmax(challenge), "Lost Hope: Be the lone survivor of your team and die.")
				if(!ongoingdisplay[iVictim])
				{
					set_task(0.3, "achievement_display", iVictim)
				}
				else
				{
					set_task(3.0, "achievement_display", iVictim)
				}
				callfuncfloat(iVictim, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				
			}
			case 2:
			{
			
			}
		}
	}
	
	if( get_user_health( iKiller ) <= 20 )
	{
		OneHpHero[ iKiller ] = true
	}
	
	if( OneHpHero[ iKiller ] == true )
	{
		g_iAchLevel[ iKiller ][ ONE_HP_HERO ]++
		switch( g_iAchLevel[ iKiller ][ ONE_HP_HERO ] )
		{
			case 1:
			{	
				g_iAchLevel[ iKiller ][ ONE_HP_HERO ]++
				format(challenge, charsmax(challenge), "Raging Vengeance: Kill an enemy while heavily wounded.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 2000)
			}
		}
	}
	
	if( cs_get_user_team( iKiller ) == cs_get_user_team( iVictim ) )
	{
		g_iTeamKills[ iKiller ]++
	}
	
	if( g_iTeamKills[ iKiller ] == 5 )
	{
		g_iAchLevel[ iKiller ][ BAD_FRIEND ]++
		switch( g_iAchLevel[ iKiller ][ BAD_FRIEND ] )
		{
			case 1:
			{
				g_iAchLevel[ iKiller ][ BAD_FRIEND ]++
				format(challenge, charsmax(challenge), "Defector: Have a total of 5 teamkills.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 500)
			}
		}
	}
	
	if( iKillerHasNotMoved[ iKiller ] == true )
	{
		g_iKills[ iKiller ]++
		
		if( g_iKills[ iKiller ] == 5 )
		{
			g_iAchLevel[ iKiller ][ CAMP_FIRE ]++
			switch( g_iAchLevel[ iKiller ][ CAMP_FIRE ] )
			{
				case 1:
				{
					g_iAchLevel[ iKiller ][ CAMP_FIRE ]++
					format(challenge, charsmax(challenge), "Sniper's Nest: Kill 5 enemies in a row while camping an area.")
					if(!ongoingdisplay[iKiller])
					{
						set_task(0.3, "achievement_display", iKiller)
					}
					else
					{
						set_task(3.0, "achievement_display", iKiller)
					}
					callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 3000)
				}
			}
		}
		
		g_iAchLevel[ iKiller ][ CAMP_KILLS ]++
		switch(g_iAchLevel[ iKiller ][ CAMP_KILLS ])
		{
			case 15:
			{
				format(challenge, charsmax(challenge), "Sniper's Hitlist I: Kill 15 enemies while camping.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 1000)
			}
			
			case 30:
			{
				g_iAchLevel[ iKiller ][ CAMP_KILLS ]++
				format(challenge, charsmax(challenge), "Sniper's Hitlist II: Kill 30 enemies while camping.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 2500)
			}
			
			case 50:
			{
				g_iAchLevel[ iKiller ][ CAMP_KILLS ]++
				format(challenge, charsmax(challenge), "Sniper's Hitlist II: Kill 30 enemies while camping.")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
		}
	}
	
	if(UTIL_IsCrouching(iKiller))
	{
		g_iAchLevel[ iKiller ][ CROUCH_SHOT ]++
		switch( g_iAchLevel[ iKiller ][ CROUCH_SHOT ] )
		{
			case 5:
			{	
				format(challenge, charsmax(challenge), "Crouch Shot I: Kill 5 enemies while you are crouching")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 500)
			}
			case 15:
			{	
				format(challenge, charsmax(challenge), "Crouch Shot II: Kill 15 enemies while you are crouching")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 1000)
			}
			case 30:
			{	
				g_iAchLevel[ iKiller ][ CROUCH_SHOT ]++
				format(challenge, charsmax(challenge), "Crouch Shot III: Kill 30 enemies while you are crouching")
				if(!ongoingdisplay[iKiller])
				{
					set_task(0.3, "achievement_display", iKiller)
				}
				else
				{
					set_task(3.0, "achievement_display", iKiller)
				}
				callfuncfloat(iKiller, "ks_bonus_xp", "gunxpmod.amxx", 2500)
			}
			case 31:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public Event_Spray( ) 
{ 
	new iPlayers[ 32 ], iNum, iPlayer
	get_players( iPlayers, iNum, "ah" )
	
	for( new i = 0; i < iNum; i++ ) 
	{
		iPlayer = iPlayers[ i ]
	}
	
	#if defined USING_REGEX
	if( !IsUserAuthorized( iPlayer ) )
	{
		return PLUGIN_HANDLED
	}
	#endif

	new szName[ 32 ]
	get_user_name( iPlayer, szName, charsmax( szName ) )
	
	g_iAchLevel[ iPlayer ][ URBAN_DESIGNER ]++
	switch( g_iAchLevel[ iPlayer ][ URBAN_DESIGNER ] )
	{
		case 300:
		{
			g_iAchLevel[ iPlayer ][ URBAN_DESIGNER ]++
			format(challenge, charsmax(challenge), "Urban Designer: Spray 300 decals in total.")
			if(!ongoingdisplay[iPlayer])
			{
				set_task(0.3, "achievement_display", iPlayer)
			}
			else
			{
				set_task(3.0, "achievement_display", iPlayer)
			}
			callfuncfloat(iPlayer, "ks_bonus_xp", "gunxpmod.amxx", 5000)
		}
	}
	
	g_iRoundSparys[ iPlayer ]++
	
	if( g_iRoundSparys[ iPlayer ] == 8 )
	{
		g_iAchLevel[ iPlayer ][ GRAFFITI ]++
		switch( g_iAchLevel[ iPlayer ][ GRAFFITI ] )
		{
			case 1:
			{
				g_iAchLevel[ iPlayer ][ GRAFFITI ]++
				format(challenge, charsmax(challenge), "Graffiti: Spray 8 decals in a single match.")
				if(!ongoingdisplay[iPlayer])
				{
					set_task(0.3, "achievement_display", iPlayer)
				}
				else
				{
					set_task(3.0, "achievement_display", iPlayer)
				}
				callfuncfloat(iPlayer, "ks_bonus_xp", "gunxpmod.amxx", 1000)
			}
		}
	}
	#if defined USING_REGEX
	return PLUGIN_HANDLED
	#endif
}

/////////////////////////////////////
///////KILLSTREAK ACHIEVEMENTS///////
/////////////////////////////////////
public uav_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ UAV_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ UAV_USED ] )
		{
			case 5:
			{
				format(challenge, charsmax(challenge), "Exposed I: Call in a total of 5 UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				return PLUGIN_HANDLED
			}
			case 25:
			{
				format(challenge, charsmax(challenge), "Exposed II: Call in a total of 25 UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 50:
			{
				format(challenge, charsmax(challenge), "Exposed III: Call in a total of 50 UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 51:
			{
			
			}
		}
		
		g_ActivatedUVA[ id ] ++
		switch( g_ActivatedUVA[ id ] )
		{
			case 3:
			{
				g_iAchLevel[ id ][ NO_SECRETS ]++
				switch( g_iAchLevel[ id ][ NO_SECRETS ] )
				{
					case 1:
					{
						format(challenge, charsmax(challenge), "No Secrets: Call in a UAV 3 times in a single match")
						if(!ongoingdisplay[id])
						{
							set_task(0.3, "achievement_display", id)
						}
						else
						{
							set_task(3.0, "achievement_display", id)
						}
						callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
					}
				}
			}
		}
	}
	return PLUGIN_HANDLED
}

public cp_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ CP_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ CP_USED ] )
		{
			case 5:
			{
				format(challenge, charsmax(challenge), "Air Mail I: Call in a total of 5 Care Packages.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				return PLUGIN_HANDLED
			}
			case 25:
			{
				format(challenge, charsmax(challenge), "Air Mail II: Call in a total of 25 Care Packages.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 50:
			{
				format(challenge, charsmax(challenge), "Air Mail III: Call in a total of 50 Care Packages.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 51:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public cuav_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ CUAV_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ CUAV_USED ] )
		{
			case 5:
			{
				format(challenge, charsmax(challenge), "Interference I: Call in a total of 5 Counter-UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				return PLUGIN_HANDLED
			}
			case 25:
			{
				format(challenge, charsmax(challenge), "Interference II: Call in a total of 25 Counter-UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 50:
			{
				format(challenge, charsmax(challenge), "Interference III: Call in a total of 50 Counter-UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 51:
			{
			
			}
		}
	}
	g_ActivatedCUVA[ id ] ++
	switch( g_ActivatedCUVA[ id ] )
	{
		case 3:
		{
			g_iAchLevel[ id ][ SUNBLOCK ]++
			switch( g_iAchLevel[ id ][ SUNBLOCK ] )
			{
				case 5:
				{
					format(challenge, charsmax(challenge), "Sunblock: Call in a Counter-UAV 3 times in a single match")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				}
			}
		}
	}
	return PLUGIN_HANDLED
}

public sentry_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ SENTRY_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ SENTRY_USED ] )
		{
			case 5:
			{
				format(challenge, charsmax(challenge), "Sentry Veteran I: Call in a total of 5 Sentry Packages.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				return PLUGIN_HANDLED
			}
			case 25:
			{
				format(challenge, charsmax(challenge), "Sentry Veteran /iI: Call in a total of 25 Sentry Packages.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 50:
			{
				format(challenge, charsmax(challenge), "Sentry Veteran III: Call in a total of 50 Sentry Packages.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 51:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public predator_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ PREDATOR_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ PREDATOR_USED ] )
		{
			case 5:
			{
				format(challenge, charsmax(challenge), "Air To Ground I: Call in a total of 5 Predator Missiles.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				return PLUGIN_HANDLED
			}
			case 25:
			{
				format(challenge, charsmax(challenge), "Air To Ground II: Call in a total of 25 Predator Missiles.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 50:
			{
				format(challenge, charsmax(challenge), "Air To Ground III: Call in a total of 50 Predator Missiles.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 51:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public precision_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ PRECISION_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ PRECISION_USED ] )
		{
			case 5:
			{
				format(challenge, charsmax(challenge), "Airstrike Veteran I: Call in a total of 5 Precision Airstrikes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1500)
			}
			case 25:
			{
				format(challenge, charsmax(challenge), "Airstrike Veteran II: Call in a total of 25 Precision Airstrikes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 3000)
				return PLUGIN_HANDLED
			}
			case 50:
			{
				format(challenge, charsmax(challenge), "Airstrike Veteran III: Call in a total of 50 Precision Airstrikes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 6000)
				return PLUGIN_HANDLED
			}
			case 51:
			{
			
			}
		}
	}
	g_ActivatedAirstrike[ id ] ++
	switch( g_ActivatedAirstrike[ id ] )
	{
		case 2:
		{
			g_iAchLevel[ id ][ AFTERBURNER ]++
			switch( g_iAchLevel[ id ][ AFTERBURNER ] )
			{
				case 5:
				{
					format(challenge, charsmax(challenge), "Afterburner: Call in an airstrike 2 times in a single match")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				}
			}
		}
	}
	return PLUGIN_HANDLED
}

public stealth_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ STEALTH_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ STEALTH_USED ] )
		{
			case 3:
			{
				format(challenge, charsmax(challenge), "Stealth Bomber I: Call in a total of 3 Stealth Bombers.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1500)
				return PLUGIN_HANDLED
			}
			case 10:
			{
				format(challenge, charsmax(challenge), "Stealth Bomber II: Call in a total of 10 Stealth Bombers.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 3000)
				return PLUGIN_HANDLED
			}
			case 25:
			{
				format(challenge, charsmax(challenge), "Stealth Bomber III: Call in a total of 25 Stealth Bombers.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 6000)
				return PLUGIN_HANDLED
			}
			case 26:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public emp_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ EMP_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ EMP_USED ] )
		{
			case 2:
			{
				format(challenge, charsmax(challenge), "Blackout I: Call in a total of 2 EMPs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 5:
			{
				format(challenge, charsmax(challenge), "Blackout II: Call in a total of 5 EMPs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 10:
			{
				format(challenge, charsmax(challenge), "Blackout III: Call in a total of 10 EMPs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
				return PLUGIN_HANDLED
			}
			case 11:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public nuke_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ NUKE_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ NUKE_USED ] )
		{
			case 2:
			{
				format(challenge, charsmax(challenge), "End Game I: Call in a total of 2 Nukes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 5:
			{
				format(challenge, charsmax(challenge), "End Game II: Call in a total of 5 Nukes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
				return PLUGIN_HANDLED
			}
			case 10:
			{
				format(challenge, charsmax(challenge), "End Game III: Call in a total of 10 Nukes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
				return PLUGIN_HANDLED
			}
			case 11:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public radar_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ RADAR_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ RADAR_USED ] )
		{
			case 50:
			{
				format(challenge, charsmax(challenge), "Radar Inbound I: Call in a total of 50 UAVs/Counter-UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 100:
			{
				format(challenge, charsmax(challenge), "Radar Inbound II: Call in a total of 100 UAVs/Counter-UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 1000:
			{
				format(challenge, charsmax(challenge), "Radar Inbound III: Call in a total of 1000 UAVs/Counter-UAVs.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
				return PLUGIN_HANDLED
			}
			case 1001:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public airstrike_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ AIRSTRIKE_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )
		switch( g_iAchLevel[ id ][ AIRSTRIKE_USED ] )
		{
			case 50:
			{
				format(challenge, charsmax(challenge), "Airstrike Inbound I: Call in a total of 50 Airstrikes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 100:
			{
				format(challenge, charsmax(challenge), "Airstrike Inbound II: Call in a total of 100 Airstrikes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 1000:
			{
				g_iAchLevel[ id ][ AIRDROP_USED ]++
				format(challenge, charsmax(challenge), "Airstrike Inbound III: Call in a total of 1000 Airstrikes.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
				return PLUGIN_HANDLED
			}
			case 1001:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public airdrop_ACH( id )
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ AIRDROP_USED ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )

		switch( g_iAchLevel[ id ][ AIRDROP_USED ] )
		{
			case 50:
			{
				format(challenge, charsmax(challenge), "Airdrop Inbound I: Call in a total of 50 Airdrops.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				return PLUGIN_HANDLED
			}
			case 100:
			{
				format(challenge, charsmax(challenge), "Airdrop Inbound II: Call in a total of 100 Airdrops.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
				return PLUGIN_HANDLED
			}
			case 1000:
			{
				g_iAchLevel[ id ][ AIRDROP_USED ]++
				format(challenge, charsmax(challenge), "Airdrop Inbound III: Call in a total of Airdrops.")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
				return PLUGIN_HANDLED
			}
			case 1001:
			{
			
			}
		}
	}
	return PLUGIN_HANDLED
}

public teamplayer_ACH(id)
{
	if( is_Connected[ id ] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		new mw2mode = get_cvar_num("mw2_gamemode")
		if( mw2mode == 1 )
		{
			g_iAchLevel[ id ][ TDM_WIN ]++
			switch( g_iAchLevel[ id ][ TDM_WIN ] )
			{
				case 5:
				{
					format(challenge, charsmax(challenge), "Team Player I: 	Win 5 Team Deathmatch matches")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 500)
				}
				case 15:
				{
					format(challenge, charsmax(challenge), "Team Player II: Win 15 Team Deathmatch matches")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
				}
				case 30:
				{
					g_iAchLevel[ id ][ TDM_WIN ]++
					format(challenge, charsmax(challenge), "Team Player III: Win 30 Team Deathmatch matches")
					if(!ongoingdisplay[id])
					{
						set_task(0.3, "achievement_display", id)
					}
					else
					{
						set_task(3.0, "achievement_display", id)
					}
					callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
				}
				case 31:
				{
				
				}
			}
		}
	}
}

public flawless_round(id)
{
	if( is_Connected[ id ] && !Flawed[id] )
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		
		g_iAchLevel[ id ][ NO_DEATHS ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )
		switch( g_iAchLevel[ id ][ NO_DEATHS ] )
		{
			case 1:
			{
				format(challenge, charsmax(challenge), "Flawless: Play an entire match without dying")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2000)
			}
		}
	}
}

public bool_survive(taskid)
{
	new id = (taskid - 144)
	if( is_Connected[ id ] && is_user_alive(id))
	{
		#if defined USING_REGEX
		if( !IsUserAuthorized( id ) )
		{
			return PLUGIN_HANDLED
		}
		#endif
		g_iAchLevel[ id ][ SURVIVE ]++
            
		new szName[ 32 ]
		get_user_name( id, szName, charsmax( szName ) )
		switch( g_iAchLevel[ id ][ SURVIVE ] )
		{
			case 1:
			{
				format(challenge, charsmax(challenge), "Survivalist: Survive for 5 minutes straight without dying")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2000)
			}
		}
	}
}

public count_kills_sb(id)
{
	g_SingleStealthKills[id]++
	if( g_SingleStealthKills[ id ] == 6 )
	{
		g_iAchLevel[ id ][ RED_CARPET ]++
		switch( g_iAchLevel[ id ][ RED_CARPET ] )
		{
			case 1:
			{
				g_iAchLevel[ id ][ RED_CARPET ]++
				format(challenge, charsmax(challenge), "Red Carpet: Kill 6 enemies with a single Stealth Bomber")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
			case 2:
			{
			
			}
		}
	}
	g_iAchLevel[ id ][ THE_SPIRIT ]++
	switch( g_iAchLevel[ id ][ THE_SPIRIT ] )
	{
		case 50:
		{
			format(challenge, charsmax(challenge), "The Spirit I: Kill 50 enemies with the Stealth Bomber")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
		}
		case 250:
		{
			format(challenge, charsmax(challenge), "The Spirit II: Kill 250 enemies with the Stealth Bomber")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
		}
		case 500:
		{
			format(challenge, charsmax(challenge), "The Spirit III: Kill 500 enemies with the Stealth Bomber")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
		case 1000:
		{
			format(challenge, charsmax(challenge), "The Spirit IV: Kill 1000 enemies with the Stealth Bomber")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
	}
}

public reset_kills_sb(id)
{
	g_SingleStealthKills[id] = 0;
}

public count_kills_pa(id)
{
	g_SinglePrecisionKills[id]++
	if( g_SinglePrecisionKills[ id ] == 5 )
	{
		g_iAchLevel[ id ][ CARPET_BOMB ]++
		switch( g_iAchLevel[ id ][ CARPET_BOMB ] )
		{
			case 1:
			{
				g_iAchLevel[ id ][ CARPET_BOMB ]++
				format(challenge, charsmax(challenge), "Carpet Bomb: Kill 5 enemies with a single Precision Airstrike")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
			case 2:
			{
			
			}
		}
	}
	g_iAchLevel[ id ][ CARPET_BOMBER ]++
	switch( g_iAchLevel[ id ][ CARPET_BOMBER ] )
	{
		case 50:
		{
			format(challenge, charsmax(challenge), "Carpet Bomber I: Kill 50 enemies with the Precision Airstrike")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
		}
		case 250:
		{
			format(challenge, charsmax(challenge), "Carpet Bomber II: Kill 250 enemies with the Precision Airstrike")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
		}
		case 500:
		{
			format(challenge, charsmax(challenge), "Carpet Bomber III: Kill 500 enemies with the Precision Airstrike")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
		case 1000:
		{
			format(challenge, charsmax(challenge), "Carpet Bomber IV: Kill 1000 enemies with the Precision Airstrike")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
	}
}

public reset_kills_pa(id)
{
	g_SinglePrecisionKills[id] = 0;
}

public count_kills_pm(id)
{
	g_SinglePredatorKills[id]++
	if( g_SinglePredatorKills[ id ] == 5 )
	{
		g_iAchLevel[ id ][ GRIM_REAPER ]++
		switch( g_iAchLevel[ id ][ GRIM_REAPER ] )
		{
			case 1:
			{
				g_iAchLevel[ id ][ GRIM_REAPER ]++
				format(challenge, charsmax(challenge), "Grim Reaper: Kill 5 enemies with a single Predator Missile")
				if(!ongoingdisplay[id])
				{
					set_task(0.3, "achievement_display", id)
				}
				else
				{
					set_task(3.0, "achievement_display", id)
				}
				callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
			}
			case 2:
			{
			
			}
		}
	}
	g_iAchLevel[ id ][ PREDATOR_KILL ]++
	switch( g_iAchLevel[ id ][ PREDATOR_KILL ] )
	{
		case 50:
		{
			format(challenge, charsmax(challenge), "Predator I: Kill 50 enemies with the Predator Missile")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
		}
		case 250:
		{
			format(challenge, charsmax(challenge), "Predator II: Kill 250 enemies with the Predator Missile")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
		}
		case 500:
		{
			format(challenge, charsmax(challenge), "Predator III: Kill 500 enemies with the Predator Missile")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
		case 1000:
		{
			format(challenge, charsmax(challenge), "Predator IV: Kill 1000 enemies with the Predator Missile")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
	}
}

public reset_kills_pm(id)
{
	g_SinglePredatorKills[id] = 0;
}

public count_kills_sentry(id)
{
	g_iAchLevel[ id ][ NO_HANDS ]++
	switch( g_iAchLevel[ id ][ NO_HANDS ] )
	{
		case 50:
		{
			format(challenge, charsmax(challenge), "Look! No Hands! I: Kill 50 enemies with the Sentry Gun")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
		}
		case 250:
		{
			format(challenge, charsmax(challenge), "Look! No Hands! II: Kill 250 enemies with the Sentry Gun")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
		}
		case 500:
		{
			format(challenge, charsmax(challenge), "Look! No Hands! III: Kill 500 enemies with the Sentry Gun")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
		case 1000:
		{
			format(challenge, charsmax(challenge), "Look! No Hands! IV: Kill 1000 enemies with the Sentry Gun")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
	}
}



public stealth_weapon(id)
{
	g_iAchLevel[ id ][ STEALTH ]++
	switch( g_iAchLevel[ id ][ STEALTH ] )
	{
		case 10: 
		{
			format(challenge, charsmax(challenge), "Stealth I: Kill 10 enemies while using a silenced weapon.")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
		}
		case 25: 
		{
			format(challenge, charsmax(challenge), "Stealth II: Kill 25 enemies while using a silenced weapon.")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 2500)
		}
		case 50: 
		{
			format(challenge, charsmax(challenge), "Stealth III: Kill 50 enemies while using a silenced weapon.")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 5000)
		}
		case 500: 
		{
			format(challenge, charsmax(challenge), "Stealth IV: Kill 500 enemies while using a silenced weapon.")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 10000)
		}
	}
}

public theloner_ACH(id)
{
	g_iAchLevel[ id ][ THE_LONER ]++
	switch( g_iAchLevel[ id ][ THE_LONER ] )
	{
		case 1: 
		{
			format(challenge, charsmax(challenge), "The Loner: Get a 10 kill streak with no killstreak rewards selected")
			if(!ongoingdisplay[id])
			{
				set_task(0.3, "achievement_display", id)
			}
			else
			{
				set_task(3.0, "achievement_display", id)
			}
			callfuncfloat(id, "ks_bonus_xp", "gunxpmod.amxx", 1000)
		}
	}
}

Print(index, const Msg[], {Float, Sql, Result,_}:...) {
	new Buffer[190], Buffer2[192];
	formatex(Buffer2, sizeof(Buffer2)-1, "%s", Msg);
	vformat(Buffer, sizeof(Buffer)-1, Buffer2, 3);

	if (!index) {
		for (new i = 1; i <= g_iMaxPlayers; i++) {
			if (!is_user_connected(i))
				continue;

			message_begin(MSG_ONE_UNRELIABLE, g_iMsgSayText,_, i);
			write_byte(i);
			write_string(Buffer);
			message_end();
		}
	}
	else {
		if (!is_user_connected(index))
			return;

		message_begin(MSG_ONE_UNRELIABLE, g_iMsgSayText,_, index);
		write_byte(index);
		write_string(Buffer);
		message_end();
	}
}



#if defined USING_REGEX
IsValidAuthid( authid[] )
{
	return ( regex_match_c( authid, g_SteamID_pattern, g_regex_return ) > 0 )
}

IsUserAuthorized( id )
{
	return g_iAuthID[ id ][ 0 ] != 0
}
#endif

public g_iLoadStats( id )
{
	#if defined USING_SQL
	static query[ 128 ]
	formatex(query, sizeof(query) - 1, "SELECT ^"data^" FROM ^"Achievement^" WHERE ^"authid^" = ^"%s^";", g_iAuthID[ id ] )
	
	static data[ 2 ]
	data[ 0 ] = id
	
	SQL_ThreadQuery( g_sql_tuple, "QueryLoadData", query, data, sizeof( data ) )

	#else
	static data[ 256 ], timestamp
	if( nvault_lookup( g_iVault, g_iAuthID[ id ], data, sizeof( data ) - 1, timestamp ) )
	{
		ParseLoadData( id, data )
		return//
	}
	else
	{
		NewUser( id )
	}
	#endif
}

public NewUser( id )
{
	
	for( new iLevel = 0; iLevel < g_iAchCount; iLevel++ )
	{
		g_iAchLevel[ id ][ iLevel ] = 0
	}

	for( new i = 0; i < WEAPON_SIZE; i++ )
	{
		g_iPlayersKills[ id ][ g_iWeaponIDs[ i ] ] = 0
	}

}

#if defined USING_SQL
public QueryLoadData( failstate, Handle:query, error[], errnum, data[], size, Float:queuetime )
{
	if( failstate == TQUERY_CONNECT_FAILED
	|| failstate == TQUERY_QUERY_FAILED )
	{
		set_fail_state( error )
	}
	else
	{
		if( SQL_NumResults( query ) )
		{
			static sqldata[ 256 ]
			SQL_ReadResult( query, 0, sqldata, sizeof( sqldata ) - 1 )
			ParseLoadData( data[0], sqldata )
		}
		else
		{
			NewUser( data[ 0 ] )
		}
	}
}
#endif

ParseLoadData( id, data[ 256 ] )
{
	new num[ 6 ]
	
	for( new i = 0; i < WEAPON_SIZE; i++ )
	{
		strbreak( data, num, sizeof( num ) - 1, data, sizeof( data ) - 1 )
		g_iPlayersKills[ id ][ g_iWeaponIDs[ i ] ] = clamp( str_to_num( num ), 0, g_iAchsWeaponMaxKills[ i ] )
	}
	
	for( new iLevel = 0; iLevel < g_iAchCount; iLevel++ )
	{
		strbreak( data, num, sizeof( num ) - 1, data, sizeof( data ) - 1 )
		g_iAchLevel[ id ][ iLevel ] = clamp( str_to_num( num ), 0, g_iAchsMaxPoints[ iLevel ] )
	}
	
	#if defined USING_SQL
	g_loaded_data[ id ] = 1
	#endif
}

public g_iSaveStats( id )
{
	#if defined USING_REGEX
	if( !IsUserAuthorized( id ) ) return
	#endif
	
	static data[ 256 ]
	new len
	
	for( new i = 0; i < WEAPON_SIZE; i++ )
	{
		len += formatex( data[ len ], sizeof( data ) - len - 1, " %i", g_iPlayersKills[ id ][ g_iWeaponIDs[ i ] ] )
	}
	
	for( new iLevel = 0; iLevel < g_iAchCount; iLevel++ )
	{
		len += formatex( data[ len ], sizeof( data ) - len - 1, " %i", g_iAchLevel[ id ][ iLevel ] )
	}
	
	#if defined USING_SQL
	static name[ 32 ]
	get_user_name( id, name, sizeof( name ) - 1 )

	static query[ 256 ]
	if( g_loaded_data[ id ] )
	{
		formatex( query, sizeof( query ) - 1, "UPDATE ^"Achievement^" SET ^"name^" = ^"%s^", ^"data^" = ^"%s^" WHERE ^"authid^" = ^"%s^";", name, data, g_iAuthID[ id ] )
	}
	else
	{
		formatex( query, sizeof( query ) - 1, "INSERT INTO ^"Achievement^" ( ^"name^", ^"authid^", ^"data^" ) VALUES ( ^"%s^", ^"%s^", ^"%s^" );", name, g_iAuthID[ id ], data )
	}
	
	SQL_ThreadQuery( g_sql_tuple, "QuerySaveData", query )
	#else
	nvault_set( g_iVault, g_iAuthID[ id ], data )
	#endif
}

#if defined USING_SQL
public QuerySaveData( failstate, Handle:query, error[], errnum, data[], size, Float:queuetime )
{
	if( failstate == TQUERY_CONNECT_FAILED
	|| failstate == TQUERY_QUERY_FAILED )
	{
		set_fail_state( error )
	}
}
#endif


////////////////////////
/////////stocks/////////
////////////////////////

stock callfuncfloat(id, const func[], const plugin[], floatamount )
{
	callfunc_begin(func, plugin)
	callfunc_push_int(id)
	callfunc_push_float(Float:(floatamount))
	callfunc_end();
}

stock callfunc(id, const func[], const plugin[])
{
	callfunc_begin(func, plugin)
	callfunc_push_int(id)
	callfunc_end();
}

UTIL_IsCrouching ( const PlayerId )
{
	static Buttons;
	Buttons = pev( PlayerId, pev_button );

	return ( Buttons == IN_DUCK );
}
