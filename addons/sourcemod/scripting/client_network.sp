#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>


public Plugin myinfo =
{
    name        = "ClientNetwork",
    author      = "Lomaka [Edited by Dosergen], TouchMe",
    description = "Automatically corrects network settings",
    version     = "build_0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_client_network"
}


ConVar
    g_cvMode = null,
    g_cvMessage = null,
    g_cvLerp = null,
    g_cvRate = null,
    g_cvCmdRate = null,
    g_cvUpdateRate = null
;

bool g_bLateLoad = false;
bool g_bOnlyOnConnect = false;

char
    g_szLerp[8],
    g_szRate[8],
    g_szCmdRate[8],
    g_szUpdateRate[8]
;


/**
 * Called before OnPluginStart.
 *
 * @param myself            Handle to the plugin.
 * @param late              Whether or not the plugin was loaded "late" (after map load).
 * @param error             Error message buffer in case load failed.
 * @param err_max           Maximum number of characters for error message buffer.
 * @return                  APLRes_Success | APLRes_SilentFailure.
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
    g_cvMode       = CreateConVar("sm_cn_only_on_connect", "1", "Client lerp", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvMessage    = CreateConVar("sm_cn_message",    "",       "Motd message", FCVAR_NOTIFY);
    g_cvLerp       = CreateConVar("sm_cl_interp",     "0.0",    "Client lerp", FCVAR_NOTIFY, true, 0.0, true, 0.1);
    g_cvRate       = CreateConVar("sm_rate",          "100000", "Client rate", FCVAR_NOTIFY, true, 30.0, true, 128000.0);
    g_cvCmdRate    = CreateConVar("sm_cl_cmdrate",    "100",    "Client cmdrate", FCVAR_NOTIFY, true, 30.0, true, 128.0);
    g_cvUpdateRate = CreateConVar("sm_cl_updaterate", "100",    "Client updaterate", FCVAR_NOTIFY, true, 30.0, true, 128.0);

    g_bOnlyOnConnect = g_cvMode.BoolValue;
    g_cvLerp.GetString(g_szLerp, sizeof(g_szLerp));
    g_cvRate.GetString(g_szRate, sizeof(g_szRate));
    g_cvCmdRate.GetString(g_szCmdRate, sizeof(g_szCmdRate));
    g_cvUpdateRate.GetString(g_szUpdateRate, sizeof(g_szUpdateRate));

    if (g_bLateLoad)
    {
        for (int iClient = 1; iClient <= MaxClients; iClient++)
        {
            OnClientPostAdminCheck(iClient);
        }
    }
}

public void OnClientPostAdminCheck(int iClient)
{
    if (IsClientInGame(iClient) && !IsFakeClient(iClient)) {
        QueryClientConVars(iClient);
    }
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
        SendClientCmd(iClient, "cl_interp %s;rate %s;cl_cmdrate %s;cl_updaterate %s", g_szLerp, g_szRate, g_szCmdRate, g_szUpdateRate);
    }
}

void SendClientCmd(int iClient, const char[] szCmd, any ...)
{
    char szFormatCmd[192];
    VFormat(szFormatCmd, sizeof(szFormatCmd), szCmd, 3);

    char szMessage[512];
    g_cvMessage.GetString(szMessage, sizeof(szMessage));

    KeyValues kv = CreateKeyValues("data");
    kv.SetString("title", "Update network settings");
    kv.SetString("type", "2");
    kv.SetString("msg", szMessage);
    kv.SetString("cmd", szFormatCmd);
    ShowVGUIPanel(iClient, "info", kv);
    delete kv;
}
