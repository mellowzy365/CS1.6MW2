#include <amxmodx>
#include <fakemeta>
#include <metadrawer>


#define NORTH	0
#define WEST	90
#define SOUTH	180
#define EAST	270

new VERSION[]="0.1"

//new gHudSyncInfo, gHudSyncInfo2

new const g_DirNames[4][] = { "N", "E", "S", "W" }
//new DirSymbol[32] = "----<>----"

new g_pcvar_compass, g_pcvar_method

new bool:emp_active[33];

public plugin_init() {
	register_plugin("Compass & ACG", VERSION, "Tirant & Infract3m")
	
	g_pcvar_compass = register_cvar("amx_compass", "1");
	g_pcvar_method = register_cvar("amx_compass_method", "4");
	
	register_forward(FM_PlayerPreThink, "fw_Player_PreThink")
	
	//gHudSyncInfo = CreateHudSyncObj();
	//gHudSyncInfo2 = CreateHudSyncObj();
}

public fw_Player_PreThink(id)
{
	if (is_user_alive(id) && get_pcvar_num(g_pcvar_compass))
	{
		new Float:fAngles[3], iAngles[3]
		pev(id, pev_angles, fAngles)
		
		FVecIVec(fAngles,iAngles)
		iAngles[1] %= 360
		
		
		new Float:fHudCoordinates;
		
		{
			new iFakeAngle = iAngles[1] % 90
			new Float:fFakeHudAngle = (float(iFakeAngle) / 100.0) + 0.49
			if (iFakeAngle>45) fFakeHudAngle += 0.05
			if (fFakeHudAngle >= 0.95) fFakeHudAngle -= 0.95
			else if (fFakeHudAngle <= 0.05) fFakeHudAngle += 0.05
			
			new DirName[32]
			new Method = get_pcvar_num(g_pcvar_method)
			
			if (iFakeAngle == 0)
			{
				fHudCoordinates = -1.0
				
				if (Method != 4)
				{
					if (iAngles[1] == NORTH) format(DirName, 31, "%s", g_DirNames[0])
					else if (iAngles[1] == WEST) format(DirName, 31, "%s", g_DirNames[3])
					else if (iAngles[1] == SOUTH) format(DirName, 31, "%s", g_DirNames[2])
					else if (iAngles[1] == EAST) format(DirName, 31, "%s", g_DirNames[1])
				}
			}
			else
			{
				fHudCoordinates = fFakeHudAngle
				
				if (Method == 1)
					format(DirName, 31, "%d", iAngles[1])
				if (Method == 2)
				{
					if (NORTH < iAngles[1] < WEST || iAngles[1] > EAST)
					{
						if (NORTH < iAngles[1] < WEST)
						{
							iAngles[1] %= 90
							format(DirName, 31, "N %d W", iAngles[1])
						}
						else if (iAngles[1] > EAST)
						{
							iAngles[1] = (90 - (iAngles[1] % 90))
							format(DirName, 31, "N %d E", iAngles[1])
						}
					}
					else
					{
						if (SOUTH > iAngles[1] > WEST)
						{
							iAngles[1] = (90 - (iAngles[1] % 90))
							format(DirName, 31, "S %d W", iAngles[1])
						}
						else if (SOUTH < iAngles[1] < EAST)
						{
							iAngles[1] %= 90
							format(DirName, 31, "S %d E", iAngles[1])
						}
					}
				}
				if (Method == 3)
				{
					if (NORTH < iAngles[1] < WEST || iAngles[1] > EAST)
					{
						if (NORTH < iAngles[1] < WEST)
						{
							iAngles[1] %= 90
							format(DirName, 31, "NW", iAngles[1])
						}
						else if (iAngles[1] > EAST)
						{
							iAngles[1] = (90 - (iAngles[1] % 90))
							format(DirName, 31, "NE", iAngles[1])
						}
					}
					else
					{
						if (SOUTH > iAngles[1] > WEST)
						{
							iAngles[1] = (90 - (iAngles[1] % 90))
							format(DirName, 31, "SW", iAngles[1])
						}
						else if (SOUTH < iAngles[1] < EAST)
						{
							iAngles[1] %= 90
							format(DirName, 31, "SE", iAngles[1])
						}
					}
				}
				if (Method == 4)
				{
					if (336 >= iAngles[1] <= 23 )
					{
						format(DirName, 31, "%s", g_DirNames[0]) //north
					}
					
					if (248 <= iAngles[1] <= 292) 
					{
						format(DirName, 31, "%s", g_DirNames[1]) //east
					}
					
					if (158 <= iAngles[1] <= 203) 
					{
						format(DirName, 31, "%s", g_DirNames[2]) //south
					}
					
					if (68 <= iAngles[1] <= 112) 
					{
						format(DirName, 31, "%s", g_DirNames[3]) //west
					}
					if (24 <= iAngles[1] <= 67)
					{
						iAngles[1] %= 90
						format(DirName, 31, "NW", iAngles[1])
					}
					if (335 >= iAngles[1] >= 293)
					{
						iAngles[1] = (90 - (iAngles[1] % 90))
						format(DirName, 31, "NE", iAngles[1])
					}

					if (157 >= iAngles[1] >= 113)
					{
						iAngles[1] = (90 - (iAngles[1] % 90))
						format(DirName, 31, "SW", iAngles[1])
					}
					if (247 >= iAngles[1] >= 204)
					{
						iAngles[1] %= 90
						format(DirName, 31, "SE", iAngles[1])
					}
				}
			}
			
			if (Method )
			{
				if(!emp_active[id])
					md_drawtext(id, 6, DirName, 0.9, 0.76, 0, 0, 255,255,255,255, 0.0, 0.0, 0.0, ALIGN_NORMAL)
				else
					md_removedrawing(id, 0, 6)
			}
		}
		
		//set_hudmessage(255, 255, 255, fHudCoordinates, 0.9, 0, 0.0, 3.0, 0.0, 0.0);
		//ShowSyncHudMsg(id, gHudSyncInfo, "^n%s", DirSymbol);
	}
}

//1920x1080
//0.938, 0.850
//1600x900
//0.926, 0.833
//1280x720
//0.905, 0.78


public emp_on2(id)
{
	emp_active[id] = true;
}

public emp_off2(id)
{
	emp_active[id] = false;
}
