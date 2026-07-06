#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = {
    name        = "ClientNetwork",
    author      = "Lomaka [Edited by Dosergen], TouchMe",
    description = "Automatically corrects network settings",
    version     = "build_0002",
    url         = "https://github.com/TouchMe-Inc/l4d2_client_network"
}


#define CVAR_COUNT 4

enum CvarIndex
{
    Cvar_Lerp,
    Cvar_Rate,
    Cvar_CmdRate,
    Cvar_UpdateRate
}

bool g_bLateLoad = false;

/* sm_cn_always_show_motd */
ConVar g_cvAlwaysShowMotd = null;
bool g_bAlwaysShowMotd = false;

/* sm_cn_only_on_connect */
ConVar g_cvOnlyOnConnect = null;
bool g_bOnlyOnConnect = false;

/* sm_cn_title */
ConVar g_cvTitle = null;
char g_szTitle[128];

/* sm_cn_message */
ConVar g_cvMessage = null;
char g_szMessage[512];

ConVar g_cvCvars[CVAR_COUNT];
char   g_szCvarValues[CVAR_COUNT][8];

char g_szCheckCvars[CVAR_COUNT][] = { "cl_interp", "rate", "cl_cmdrate", "cl_updaterate" };


bool g_bWasConnected[MAXPLAYERS + 1];
bool g_bWasShowed[MAXPLAYERS + 1];


/**
 * Called before OnPluginStart.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    g_bLateLoad = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvOnlyOnConnect          = CreateConVar("sm_cn_only_on_connect",  "1",                       "..",                _, true, 0.0, true, 1.0);
    g_cvAlwaysShowMotd         = CreateConVar("sm_cn_always_show_motd", "1",                       "..",               _, true, 0.0, true, 1.0);
    g_cvTitle                  = CreateConVar("sm_cn_title",            "Update network settings", "Motd title");
    g_cvMessage                = CreateConVar("sm_cn_message",          "",                        "Motd message");
    g_cvCvars[Cvar_Lerp]       = CreateConVar("sm_cn_cl_interp",        "0.0",                     "Client lerp",       _, true, 0.0, true, 0.1);
    g_cvCvars[Cvar_Rate]       = CreateConVar("sm_cn_rate",             "100000",                  "Client rate",       _, true, 30.0, true, 128000.0);
    g_cvCvars[Cvar_CmdRate]    = CreateConVar("sm_cn_cl_cmdrate",       "100",                     "Client cmdrate",    _, true, 30.0, true, 128.0);
    g_cvCvars[Cvar_UpdateRate] = CreateConVar("sm_cn_cl_updaterate",    "100",                     "Client updaterate", _, true, 30.0, true, 128.0);

    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

    HookConVarChange(g_cvOnlyOnConnect,  OnCvarChange_OnlyOnConnect);
    HookConVarChange(g_cvAlwaysShowMotd, OnCvarChange_AlwaysShowMotd);
    HookConVarChange(g_cvTitle,          OnCvarChange_Title);
    HookConVarChange(g_cvMessage,        OnCvarChange_Message);

    for (int i = 0; i < CVAR_COUNT; i++) {
        HookConVarChange(g_cvCvars[i],   OnCvarChange_Network);
    }

    g_bOnlyOnConnect = GetConVarBool(g_cvOnlyOnConnect);
    g_bAlwaysShowMotd = GetConVarBool(g_cvAlwaysShowMotd);
    GetConVarString(g_cvTitle, g_szTitle, sizeof g_szTitle);
    GetConVarString(g_cvMessage, g_szMessage, sizeof g_szMessage);

    for (int i = 0; i < CVAR_COUNT; i++)  {
        GetConVarString(g_cvCvars[i], g_szCvarValues[i], sizeof g_szCvarValues[]);
    }

    if (g_bLateLoad) {
        for (int iClient = 1; iClient <= MaxClients; iClient++) {
            OnClientPostAdminCheck(iClient);
        }
    }
}

void Event_PlayerDisconnect(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!iClient || !IsClientConnected(iClient) || IsFakeClient(iClient)) {
        return;
    }

    g_bWasShowed[iClient] = false;
    g_bWasConnected[iClient] = false;
}

void OnCvarChange_AlwaysShowMotd(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bAlwaysShowMotd = GetConVarBool(cv);
}

void OnCvarChange_OnlyOnConnect(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bOnlyOnConnect = GetConVarBool(cv);
}

void OnCvarChange_Title(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    strcopy(g_szTitle, sizeof g_szTitle, szNewValue);
}

void OnCvarChange_Message(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    strcopy(g_szMessage, sizeof g_szMessage, szNewValue);
}

void OnCvarChange_Network(ConVar cv, const char[] szOldValue, const char[] szNewValue)
{
    for (int i = 0; i < CVAR_COUNT; i++)
    {
        if (g_cvCvars[i] == cv)
        {
            strcopy(g_szCvarValues[i], sizeof g_szCvarValues[], szNewValue);
            break;
        }
    }
}

public void OnClientPostAdminCheck(int iClient)
{
    if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
        return;
    }

    if (g_bWasConnected[iClient]) {
        return;
    }

    g_bWasShowed[iClient] = false;
    g_bWasConnected[iClient] = true;

    QueryClientConVars(iClient);
}

public void OnClientSettingsChanged(int iClient)
{
    if (g_bOnlyOnConnect) {
        return;
    }

    if (IsClientInGame(iClient)) {
        QueryClientConVars(iClient);
    }
}

void QueryClientConVars(int iClient)
{
    for (int i = 0; i < CVAR_COUNT; i++)
    {
        QueryClientConVar(iClient, g_szCheckCvars[i], ChangeClientCvar);
    }
}

void ChangeClientCvar(QueryCookie cookie, int iClient, ConVarQueryResult result, const char[] szName, const char[] szValue)
{
    bool bNeedSend = false;

    for (int i = 0; i < CVAR_COUNT; i++)
    {
        if (!StrEqual(g_szCheckCvars[i], szName, true)) {
            continue;
        }

        if (!StrEqual(g_szCvarValues[i], szValue, true))
        {
            bNeedSend = true;
            break;
        }
    }

    if (bNeedSend || (!g_bWasShowed[iClient] && g_bAlwaysShowMotd))
    {
        SendClientCmd(
            iClient, 
            "cl_interp %s;rate %s;cl_cmdrate %s;cl_updaterate %s;motd_confirm", 
            g_szCvarValues[Cvar_Lerp], 
            g_szCvarValues[Cvar_Rate], 
            g_szCvarValues[Cvar_CmdRate], 
            g_szCvarValues[Cvar_UpdateRate]
        );
        g_bWasShowed[iClient] = true;
    }
}

void SendClientCmd(int iClient, const char[] szCmd, any ...)
{
    char szFormatCmd[192];
    VFormat(szFormatCmd, sizeof szFormatCmd, szCmd, 3);

    KeyValues kv = CreateKeyValues("data");
    kv.SetString("title", g_szTitle);
    kv.SetString("type", "2");
    kv.SetString("msg", g_szMessage);
    kv.SetString("cmd", szFormatCmd);
    ShowVGUIPanel(iClient, "info", kv);

    delete kv;
}
