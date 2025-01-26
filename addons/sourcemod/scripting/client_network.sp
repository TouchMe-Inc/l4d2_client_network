#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = {
    name        = "ClientNetwork",
    author      = "Lomaka [Edited by Dosergen], TouchMe",
    description = "Automatically corrects network settings",
    version     = "build_0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_client_network"
}


bool g_bLateLoad = false;

/* sm_cn_only_on_connect */
ConVar g_cvOnlyOnConnect = null;
bool g_bOnlyOnConnect = false;

/* sm_cn_title */
ConVar g_cvTitle = null;
char g_szTitle[128];

/* sm_cn_message */
ConVar g_cvMessage = null;
char g_szMessage[512];

/* sm_cn_cl_interp */
ConVar g_cvLerp = null;
char g_szLerp[8];

/* sm_cn_rate */
ConVar g_cvRate = null;
char g_szRate[8];

/* sm_cn_cl_cmdrate */
ConVar g_cvCmdRate = null;
char g_szCmdRate[8];

/* sm_cn_cl_updaterate */
ConVar g_cvUpdateRate = null;
char g_szUpdateRate[8];

bool g_bWasConnected[MAXPLAYERS + 1];

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
    g_cvOnlyOnConnect = CreateConVar("sm_cn_only_on_connect", "1",                       "..",                FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvTitle         = CreateConVar("sm_cn_title",           "Update network settings", "Motd title",        FCVAR_NOTIFY);
    g_cvMessage       = CreateConVar("sm_cn_message",         "",                        "Motd message",      FCVAR_NOTIFY);
    g_cvLerp          = CreateConVar("sm_cn_cl_interp",       "0.0",                     "Client lerp",       FCVAR_NOTIFY, true, 0.0, true, 0.1);
    g_cvRate          = CreateConVar("sm_cn_rate",            "100000",                  "Client rate",       FCVAR_NOTIFY, true, 30.0, true, 128000.0);
    g_cvCmdRate       = CreateConVar("sm_cn_cl_cmdrate",      "100",                     "Client cmdrate",    FCVAR_NOTIFY, true, 30.0, true, 128.0);
    g_cvUpdateRate    = CreateConVar("sm_cn_cl_updaterate",   "100",                     "Client updaterate", FCVAR_NOTIFY, true, 30.0, true, 128.0);

    HookConVarChange(g_cvOnlyOnConnect, OnConVarChange_OnlyOnConnect);
    HookConVarChange(g_cvTitle,         OnConVarChange_Title);
    HookConVarChange(g_cvMessage,       OnConVarChange_Message);
    HookConVarChange(g_cvLerp,          OnConVarChange_Lerp);
    HookConVarChange(g_cvRate,          OnConVarChange_Rate);
    HookConVarChange(g_cvCmdRate,       OnConVarChange_CmdRate);
    HookConVarChange(g_cvUpdateRate,    OnConVarChange_UpdateRate);

    g_bOnlyOnConnect = GetConVarBool(g_cvOnlyOnConnect);
    GetConVarString(g_cvTitle, g_szTitle, sizeof g_szTitle);
    GetConVarString(g_cvMessage, g_szMessage, sizeof g_szMessage);
    GetConVarString(g_cvLerp, g_szLerp, sizeof g_szLerp);
    GetConVarString(g_cvRate, g_szRate, sizeof g_szRate);
    GetConVarString(g_cvCmdRate, g_szCmdRate, sizeof g_szCmdRate);
    GetConVarString(g_cvUpdateRate, g_szUpdateRate, sizeof g_szUpdateRate);

    if (g_bLateLoad)
    {
        for (int iClient = 1; iClient <= MaxClients; iClient++)
        {
            OnClientPostAdminCheck(iClient);
        }
    }
}

void OnConVarChange_OnlyOnConnect(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bOnlyOnConnect = GetConVarBool(cv);
}

void OnConVarChange_Title(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    GetConVarString(cv, g_szTitle, sizeof g_szTitle);
}

void OnConVarChange_Message(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    GetConVarString(cv, g_szMessage, sizeof g_szMessage);
}

void OnConVarChange_Lerp(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    GetConVarString(cv, g_szLerp, sizeof g_szLerp);
}

void OnConVarChange_Rate(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    GetConVarString(cv, g_szRate, sizeof g_szRate);
}

void OnConVarChange_CmdRate(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    GetConVarString(cv, g_szCmdRate, sizeof g_szCmdRate);
}

void OnConVarChange_UpdateRate(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    GetConVarString(cv, g_szUpdateRate, sizeof g_szUpdateRate);
}

public void OnClientPostAdminCheck(int iClient)
{
    if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
        return;
    }

    if (g_bWasConnected[iClient]) {
        return;
    }

    QueryClientConVars(iClient);

    g_bWasConnected[iClient] = true;
}

public void OnClientDisconnect(int iClient)
{
    if (!IsFakeClient(iClient)) {
        return;
    }

    g_bWasConnected[iClient] = false;
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
    QueryClientConVar(iClient, "cl_interp", ChangeClientCv);
    QueryClientConVar(iClient, "rate", ChangeClientCv);
    QueryClientConVar(iClient, "cl_cmdrate", ChangeClientCv);
    QueryClientConVar(iClient, "cl_updaterate", ChangeClientCv);
}

void ChangeClientCv(QueryCookie cookie, int iClient, ConVarQueryResult result, const char[] szName, const char[] szValue)
{
    if ((StrEqual(szName, "cl_interp", true)    && !StrEqual(g_szLerp, szValue, true))
    || (StrEqual(szName, "rate", true)          && !StrEqual(g_szRate, szValue, true))
    || (StrEqual(szName, "cl_cmdrate", true)    && !StrEqual(g_szCmdRate, szValue, true))
    || (StrEqual(szName, "cl_updaterate", true) && !StrEqual(g_szUpdateRate, szValue, true)))
    {
        SendClientCmd(iClient, "cl_interp %s;rate %s;cl_cmdrate %s;cl_updaterate %s;motd_confirm", g_szLerp, g_szRate, g_szCmdRate, g_szUpdateRate);
    } 
}

void SendClientCmd(int iClient, const char[] szCmd, any ...)
{
    char szFormatCmd[192];
    VFormat(szFormatCmd, sizeof(szFormatCmd), szCmd, 3);

    KeyValues kv = CreateKeyValues("data");
    kv.SetString("title", g_szTitle);
    kv.SetString("type", "2");
    kv.SetString("msg", g_szMessage);
    kv.SetString("cmd", szFormatCmd);
    ShowVGUIPanel(iClient, "info", kv);
    delete kv;
}
