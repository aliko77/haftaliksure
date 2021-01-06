#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "alikoc77"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

int g_play_time[MAXPLAYERS + 1];

Handle g_hDB = INVALID_HANDLE;
char g_sSQLBuffer[3096];
bool g_bIsMySQl;

char gecen_hafta_name[128],
	gecen_hafta_steam[128];
	
int gecen_hafta_sure;

int g_iHours;
int g_iMinutes;
int g_iSeconds;

public Plugin myinfo = 
{
	name = "Haftalik Sureler",
	author = PLUGIN_AUTHOR,
	description = "aşk bir şarapsa tıpasını götünde patlatayım.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/alikoc77"
};

public void OnPluginStart()
{
	SQL_TConnect(OnSQLConnect, "haftalik_sureler");
	RegConsoleCmd("sm_htoptime", command_htoptime);
	RegAdminCmd("sm_htopreset", command_htopreset, ADMFLAG_BAN);	
}

public void OnPluginEnd(){
	for (int i = 1; i <= MaxClients; i++){
		if (checkstatus(i)){
			OnClientDisconnect(i);
		}
	}
}

public void OnClientPutInServer(int client){
	check_in_db(client);
}

public void OnMapStart()
{
	CreateTimer(1.0, PlayTimeTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client){
	UpdateSQL_client(client);
}

public Action command_htoptime(int client, int args){
	if (checkstatus(client)){
		top_time_menu_S(client);
	}
}

public Action command_htopreset(int client, int args){
	if (checkstatus(client)){
		PrintToChat(client, "[Haftalık Süre] Veriler Sıfırlandı.");
		ResetStats(client);
	}
}

void top_time_menu_S(int iClient)
{
	if(checkstatus(iClient))
	{
		char sQuery[128];
		FormatEx(sQuery, sizeof(sQuery), "SELECT playername, oynama_suresi, steamid FROM haftalik_sureler WHERE oynama_suresi > 0 ORDER BY oynama_suresi");
		SQL_TQuery(g_hDB, OverallTopPlayersTime_Callback, sQuery, iClient);
	}
}

public void OverallTopPlayersTime_Callback(Handle owner, Handle dbRs, char [] sError, any iClient)
{
	if(!dbRs)
	{
		LogError("OverallTopPlayersTime - %s", sError);
		return;
	}

	if(checkstatus(iClient))
	{
		int i;
		char sName[32], sTemp[512], steamid[32], alisko[256];
		Menu hMenu = new Menu(OverallTopPlayersTimeHandler);
		hMenu.SetTitle("[Haftalık Süreler]");
		if (strlen(gecen_hafta_name) > 0 && strlen(gecen_hafta_steam) > 0){
			Format(alisko, 256, "Geçenki Lider: ★ %s - [%s] ★", gecen_hafta_name, gecen_hafta_steam);
			AddMenuItem(hMenu, "", alisko);
		}
		while (SQL_HasResultSet(dbRs) && SQL_FetchRow(dbRs)){
			i++;
			SQL_FetchString(dbRs, 0, sName, sizeof(sName));
			SQL_FetchString(dbRs, 2, steamid, sizeof(steamid));
			g_iHours = 0;
			g_iMinutes = 0;
			g_iSeconds = 0;
			ShowTimer(SQL_FetchInt(dbRs, 1));
			Format(sTemp, 512, "%s - %i s, %i d, %i san", sName, g_iHours, g_iMinutes, g_iSeconds);
			Format(sTemp, 512, "%s [%s]", sTemp, steamid);
			if(SQL_FetchInt(dbRs, 1) > 1.0){
				hMenu.AddItem("", sTemp, ITEMDRAW_DISABLED);
			}
			if (GetMenuItemCount(hMenu) < 1){
				AddMenuItem(hMenu, "", "Veri Yok");
			}
		}

		hMenu.ExitButton = true;
		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int OverallTopPlayersTimeHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot){
	switch(mAction){
		case MenuAction_End: delete hMenu;
	}
}

public Action PlayTimeTimer(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(checkstatus(i))
		{
			++g_play_time[i];
		}
	}
}

public int OnSQLConnect(Handle owner, Handle hndl, char [] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Database failure: %s", error);
		
		SetFailState("Databases dont work");
	}
	else
	{
		g_hDB = hndl;
		
		SQL_GetDriverIdent(SQL_ReadDriver(g_hDB), g_sSQLBuffer, sizeof(g_sSQLBuffer));
		g_bIsMySQl = StrEqual(g_sSQLBuffer,"mysql", false) ? true : false;
		
		if(g_bIsMySQl)
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `haftalik_sureler` (`playername` varchar(128) NOT NULL, `steamid` varchar(32) PRIMARY KEY NOT NULL, `oynama_suresi` INT(32) NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer);

			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `onceki_kral` (`playername` varchar(128) NOT NULL, `steamid` varchar(32) PRIMARY KEY NOT NULL, `oynama_suresi` INT(32) NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer);

		}
		else
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS haftalik_sureler (playername varchar(128) NOT NULL, steamid varchar(32) PRIMARY KEY NOT NULL, oynama_suresi INT(32) NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer);

			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS onceki_kral (playername varchar(128) NOT NULL, steamid varchar(32) PRIMARY KEY NOT NULL, oynama_suresi INT(32) NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer);

		}
	}
}

public int OnSQLConnectCallback(Handle owner, Handle hndl, char [] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("OnSQLConnectCallback Query failure: %s", error);
		return;
	}
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(checkstatus(i))
		{
			OnClientPutInServer(i);
		}
	}	
}

void check_in_db(int client){
	if(!g_hDB){
		LogError("check_in_db - database is invalid");
	}
	else{
		if(!IsFakeClient(client)){
			char sQuery[256], steam[32];
			GetClientAuthId(client, AuthId_Steam2, steam, 32);
			FormatEx(sQuery, sizeof(sQuery), "SELECT oynama_suresi FROM haftalik_sureler WHERE steamid = '%s';", steam);
			SQL_TQuery(g_hDB, CheckSQL_client_cb, sQuery, client);
		}
	}
}

public int CheckSQL_client_cb(Handle owner, Handle hndl, char [] error, any client)
{	
	if(hndl == INVALID_HANDLE)
	{
		LogError("CheckSQL_client Query failure: %s", error);
		return;
	}
	if(!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) 
	{
		InsertSQL_client(client);
		return;
	}
	if(IsClientInGame(client)){
		g_play_time[client] = SQL_FetchInt(hndl, 0);
	}
}

public void InsertSQL_client(int client){
	char query[255];
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, 32);
	Format(query, sizeof(query), "INSERT INTO haftalik_sureler (playername, steamid, oynama_suresi) VALUES ('%s', '%s', '%i')", GetFixNamePlayer(client), steamid, g_play_time[client]);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query);
}

public void UpdateSQL_client(int client)
{
	char buffer[3096];
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, 32);	
	Format(buffer, sizeof(buffer), "UPDATE haftalik_sureler SET oynama_suresi = '%i' WHERE steamid = '%s';", g_play_time[client], steamid);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, buffer);
	g_play_time[client] = 0;
}

public int SaveSQLPlayerCallback(Handle owner, Handle hndl, char [] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("SaveSQLPlayerCallback Query failure: %s", error);
	}
}

bool checkstatus(int client){
	return (client && IsClientInGame(client) && !IsFakeClient(client));
}

char[] GetFixNamePlayer(int client)
{
	char Name[MAX_NAME_LENGTH+1];
	char SafeName[(sizeof(Name)*2)+1];
	if(!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
	}	
	return Name;
}

void ResetStats(int client)
{
	for(int i = 1; i <= MaxClients; i++){
		if(checkstatus(i)){
			OnClientDisconnect(i);
		}
	}		
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT playername, steamid, oynama_suresi FROM haftalik_sureler ORDER BY oynama_suresi DESC LIMIT 1");
	SQL_TQuery(g_hDB, ShowTotalCallback, sQuery, client);
}

public int ShowTotalCallback(Handle owner, Handle hndl, char [] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}
	SQL_FetchString(hndl, 0, gecen_hafta_name, 128);
	SQL_FetchString(hndl, 1, gecen_hafta_steam, 128);
	gecen_hafta_sure = SQL_FetchInt(hndl, 2);
	SQL_LockDatabase(g_hDB);
	SQL_FastQuery(g_hDB, "DELETE FROM haftalik_sureler;");
	SQL_FastQuery(g_hDB, "DELETE FROM onceki_kral;");
	SQL_UnlockDatabase(g_hDB);
	
	char query[256];
	Format(query, sizeof(query), "INSERT INTO onceki_kral (playername, steamid, oynama_suresi) VALUES ('%s', '%s', '%i')", gecen_hafta_name, gecen_hafta_steam, gecen_hafta_sure);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query);	
	
	for(int i = 1; i <= MaxClients; i++){
		if(checkstatus(i)){
			g_play_time[i] = 0;
			check_in_db(i);
		}
	}	
}

void ShowTimer(int Time)
{
	g_iHours = 0;
	g_iMinutes = 0;
	g_iSeconds = Time;
	
	while(g_iSeconds > 3600)
	{
		g_iHours++;
		g_iSeconds -= 3600;
	}
	while(g_iSeconds > 60)
	{
		g_iMinutes++;
		g_iSeconds -= 60;
	}
}