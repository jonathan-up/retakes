#include <amxmodx>
#include <amxmisc>
#include <cvars>
#include <engine>
#include <reapi>

#define PLUGIN "Retakes"
#define AUTHOR "ALGHTRYER"
#define VERSION "1.2"

#define TASK_BOMB_TIMER 652450
#define TASK_BOMB_NOT_PLANT 773
#define CLASSNAME_RETAKES_SPAWN_T "info_player_retakes_t"
#define CLASSNAME_RETAKES_SPAWN_CT "info_player_retakes_ct"

enum _:PlayerData
{
    Player_Kills,
    Player_Deaths,
    Player_Money
}

new g_cvarMpFreezetime;
new g_cvarMpRoundtime;
new g_cvarMpTimelimit;
new g_cvarMpLimitTeams;
new g_cvarMpAutoTeamBalance;
new g_cvarMpc4timer;
new g_cvarNextMap;
new g_cvarRestartRound;
new g_cvarMpBuyTime;
new g_cvarEnable;
new cvarhook:g_hEnableCvarHook;

new g_cvarTTwins;
new g_cvarRounds;
new g_cvarBuyTime;
new g_cvarAutoPlant;
new g_cvarBuyZone;
new g_cvarInfoHud;
new g_cvarSwapCt;
new g_cvarSwapT;
new g_cvarHudc4Timer;
new g_cvarPrefix;
new g_prefix[32];

new g_roundWin;
new g_round;

new g_c4timer;

new g_syncMsg;
new g_c4SyncMsg;
new g_syncInfoHud;

new bool:g_bombSite;
new bool:g_roundRestore;
new bool:g_isBombPlanted;
new bool:g_isRoundEnd;
new bool:g_isRoundRestart;
new bool:g_onCtWinRound;
new bool:g_onTeWinRound;
new bool:g_isBomb;

new g_ePlayerData[33][PlayerData];
new bool:g_savePlayerData[33];

new g_msgStatusIcon;
new MessageHook:g_hStatusIconMsgHook;

new HookChain:g_hRoundEndHook;
new HookChain:g_hRestartRoundHook;
new HookChain:g_hRoundFreezeEndHook;
new HookChain:g_hMakeBomberHook;
new HookChain:g_hPlantBombHook;
new HookChain:g_hDefuseBombEndHook;
new HookChain:g_hExplodeBombHook;
new HookChain:g_hPlayerSpawnHook;
new HookChain:g_hDropPlayerItemHook;
new HookChain:g_hEntSelectSpawnPointHook;

new g_lastRetakeSpawnT;
new g_lastRetakeSpawnCT;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_cvar("retakes_version", VERSION, FCVAR_SERVER|FCVAR_UNLOGGED);
    g_cvarEnable = register_cvar("retakes_enable", "1");

    g_hRoundEndHook = RegisterHookChain(RG_RoundEnd, "RG_RoundEnd_Post", .post = true);
    g_hRestartRoundHook = RegisterHookChain(RG_CSGameRules_RestartRound, "RG_CSGameRules_RestartRound_Post", .post = true);
    g_hRoundFreezeEndHook = RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "RG_CSGameRules_OnRoundFreezeEnd_Post", .post = true);
    g_hMakeBomberHook = RegisterHookChain(RG_CBasePlayer_MakeBomber, "RG_CBasePlayer_MakeBomber_Post", .post = true);
    g_hPlantBombHook = RegisterHookChain(RG_PlantBomb, "RG_PlantBomb_Post", .post = true);
    g_hDefuseBombEndHook = RegisterHookChain(RG_CGrenade_DefuseBombEnd, "RG_CGrenade_DefuseBombEnd_Post", .post = true);
    g_hExplodeBombHook = RegisterHookChain(RG_CGrenade_ExplodeBomb, "RG_CGrenade_ExplodeBomb_Post", .post = true);
    g_hStatusIconMsgHook = RegisterMessage(get_user_msgid("StatusIcon"), "StatusIcon_Pre", .post = false);

    g_hPlayerSpawnHook = RegisterHookChain(RG_CBasePlayer_Spawn, "RG_CBasePlayer_Spawn_Post", .post = true);
    g_hDropPlayerItemHook = RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "RG_CBasePlayer_DropPlayerItem_Pre", .post = false);
    g_hEntSelectSpawnPointHook = RegisterHookChain(RG_CBasePlayer_EntSelectSpawnPoint, "RG_CBasePlayer_EntSelectSpawnPoint_Pre", .post = false);
    g_hEnableCvarHook = hook_cvar_change(g_cvarEnable, "cvar_change_retakes_enable");

    g_msgStatusIcon = get_user_msgid("StatusIcon");

    g_cvarMpFreezetime = get_cvar_pointer("mp_freezetime");
    g_cvarMpRoundtime = get_cvar_pointer("mp_roundtime");
    g_cvarMpTimelimit = get_cvar_pointer("mp_timelimit");
    g_cvarMpLimitTeams = get_cvar_pointer("mp_limitteams");
    g_cvarMpAutoTeamBalance = get_cvar_pointer("mp_autoteambalance");
    g_cvarRestartRound = get_cvar_pointer("sv_restartround");
    g_cvarMpBuyTime = get_cvar_pointer("mp_buytime");
    g_cvarMpc4timer = get_cvar_pointer("mp_c4timer");
    g_cvarNextMap = get_cvar_pointer("amx_nextmap");

    g_cvarRounds = register_cvar("retakes_rounds", "15");
    g_cvarTTwins = register_cvar("retakes_rowwin", "3");
    g_cvarPrefix = register_cvar("retakes_prefix", "!g[RETAKES]");
    g_cvarAutoPlant = register_cvar("retakes_autoplant", "1");
    g_cvarBuyZone = register_cvar("retakes_buyzone", "1");
    g_cvarInfoHud = register_cvar("retakes_infohud", "1");
    g_cvarBuyTime = register_cvar("retakes_buytime", "5");
    g_cvarSwapCt = register_cvar("retakes_swapct", "1");
    g_cvarSwapT = register_cvar("retakes_swapt", "1");
    g_cvarHudc4Timer = register_cvar("retakes_hudc4timer", "1");

    get_pcvar_string(g_cvarPrefix, g_prefix, charsmax(g_prefix));

    g_syncMsg = CreateHudSyncObj();
    g_c4SyncMsg = CreateHudSyncObj();
    g_syncInfoHud = CreateHudSyncObj();

    register_clcmd("fullupdate", "clcmd_fullupdate");

}

public plugin_cfg()
{
    set_retakes_hooks_enabled(is_retakes_enabled());

    if (!is_retakes_enabled())
    {
        g_isBombPlanted = false;
        g_c4timer = -1;
        remove_retake_spawn_spots();
        g_lastRetakeSpawnT = 0;
        g_lastRetakeSpawnCT = 0;
        remove_task(TASK_BOMB_TIMER);
        remove_task(TASK_BOMB_NOT_PLANT);
        return;
    }

    read_spawns();

    set_pcvar_float(g_cvarMpRoundtime, 1.00);
    set_pcvar_num(g_cvarMpTimelimit, 0);
    set_pcvar_num(g_cvarMpLimitTeams, 5);
    set_pcvar_num(g_cvarMpAutoTeamBalance, 1);
    set_pcvar_num(g_cvarMpc4timer, 40);
    set_pcvar_float(g_cvarMpBuyTime, 1.5);

    if (get_pcvar_num(g_cvarBuyZone))
    {
        unlock_buyzone();
        set_pcvar_num(g_cvarMpFreezetime, 5);
    }
    else
    {
        set_pcvar_num(g_cvarMpFreezetime, 1);
    }

    if (get_pcvar_num(g_cvarInfoHud))
    {
        set_task(1.0, "task_info_hud", _, _, _, "b");
    }
    set_pcvar_num(g_cvarRestartRound, 1);
}

public plugin_natives()
{
    register_library("retakes");
    register_native("isRetakes", "native_is_retakes");
    register_native("Rounds", "native_rounds");
}

public native_is_retakes(plugin, params)
{
    return is_retakes_enabled();
}

public native_rounds(plugin, params)
{
    return g_round;
}

stock bool:is_retakes_enabled()
{
    return g_cvarEnable && get_pcvar_num(g_cvarEnable);
}

stock set_retakes_hooks_enabled(bool:enabled)
{
    if (enabled)
    {
        EnableHookChain(g_hRoundEndHook);
        EnableHookChain(g_hRestartRoundHook);
        EnableHookChain(g_hRoundFreezeEndHook);
        EnableHookChain(g_hMakeBomberHook);
        EnableHookChain(g_hPlantBombHook);
        EnableHookChain(g_hDefuseBombEndHook);
        EnableHookChain(g_hExplodeBombHook);
        EnableHookChain(g_hPlayerSpawnHook);
        EnableHookChain(g_hDropPlayerItemHook);
        EnableHookChain(g_hEntSelectSpawnPointHook);
        EnableHookMessage(g_hStatusIconMsgHook);
    }
    else
    {
        DisableHookChain(g_hRoundEndHook);
        DisableHookChain(g_hRestartRoundHook);
        DisableHookChain(g_hRoundFreezeEndHook);
        DisableHookChain(g_hMakeBomberHook);
        DisableHookChain(g_hPlantBombHook);
        DisableHookChain(g_hDefuseBombEndHook);
        DisableHookChain(g_hExplodeBombHook);
        DisableHookChain(g_hPlayerSpawnHook);
        DisableHookChain(g_hDropPlayerItemHook);
        DisableHookChain(g_hEntSelectSpawnPointHook);
        DisableHookMessage(g_hStatusIconMsgHook);
    }
}

public cvar_change_retakes_enable(pcvar, const old_value[], const new_value[])
{
    new bool:enabled = str_to_num(new_value) != 0;
    set_retakes_hooks_enabled(enabled);

    if (enabled)
    {
        read_spawns();
        set_pcvar_num(g_cvarRestartRound, 1);
    }
    else
    {
        g_isBombPlanted = false;
        g_c4timer = -1;
        remove_retake_spawn_spots();
        g_lastRetakeSpawnT = 0;
        g_lastRetakeSpawnCT = 0;
        remove_task(TASK_BOMB_TIMER);
        remove_task(TASK_BOMB_NOT_PLANT);
    }
}

public event_round_start()
{
    g_c4timer = -1;
    remove_task(TASK_BOMB_TIMER);
    g_isBombPlanted = false;

    new players[32], num, numT, numCT, iPlayer;
    new szNextMap[64] = "未设置";
    get_players(players, num);

    set_hudmessage(0, 212, 255, -1.0, 0.28, 0, 6.0, 6.0);

    for (new i = 0; i < num; i++)
    {
        iPlayer = players[i];
        new TeamName:team = get_member(iPlayer, m_iTeam);

        switch (team)
        {
            case TEAM_TERRORIST:
            {
                numT++;
                ShowSyncHudMsg(iPlayer, g_syncMsg, "防守点位 %s", g_bombSite ? "B" : "A");
            }
            case TEAM_CT:
            {
                numCT++;
                ShowSyncHudMsg(iPlayer, g_syncMsg, "回防点位 %s", g_bombSite ? "B" : "A");
            }
        }
    }

    if (g_cvarNextMap)
    {
        get_pcvar_string(g_cvarNextMap, szNextMap, charsmax(szNextMap));
    }

    g_round++;
    g_roundRestore = true;

    g_isRoundEnd = true;
    g_isRoundRestart = true;
    g_onCtWinRound = true;
    g_onTeWinRound = true;

    if (get_pcvar_num(g_cvarAutoPlant) == 0)
    {
        g_isBomb = true;
    }

    ClientPrintColor(0, "%s 回防点位 %s : %d 名T vs %d 名CT", g_prefix, g_bombSite ? "B" : "A", numT, numCT);
    ClientPrintColor(0, "%s 回合: %d/%d | 下一张地图: %s", g_prefix, g_round, get_pcvar_num(g_cvarRounds), szNextMap);

    if (get_pcvar_num(g_cvarBuyZone))
    {
        ClientPrintColor(0, "%s 你有 %d 秒购买时间！", g_prefix, get_pcvar_num(g_cvarBuyTime));
    }

    if (g_round == get_pcvar_num(g_cvarRounds))
    {
        if (g_cvarNextMap && szNextMap[0])
        {
            server_cmd("changelevel %s", szNextMap);
        }
        else
        {
            server_print("[RETAKES] 未找到 amx_nextmap，已跳过自动换图。");
        }
    }
}

public log_when_round_start()
{
    if (task_exists(TASK_BOMB_NOT_PLANT))
    {
        remove_task(TASK_BOMB_NOT_PLANT);
    }
    set_task(10.0, "task_bomb_not_plant", TASK_BOMB_NOT_PLANT);
}

public RG_RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    switch (status)
    {
        case WINSTATUS_CTS:
        {
            event_end_round();
            event_on_ct_win();
        }
        case WINSTATUS_TERRORISTS:
        {
            event_end_round();
            event_on_te_win();
        }
        case WINSTATUS_DRAW:
        {
            event_end_round();
        }
    }

    // Game commence / restart previously listened via TextMsg.
    if (event == ROUND_GAME_COMMENCE || event == ROUND_GAME_RESTART)
    {
        event_restart_game();
    }

    return HC_CONTINUE;
}

public RG_CSGameRules_RestartRound_Post()
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    event_round_start();
    return HC_CONTINUE;
}

public RG_CSGameRules_OnRoundFreezeEnd_Post()
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    log_when_round_start();
    return HC_CONTINUE;
}

public RG_CBasePlayer_MakeBomber_Post(const player)
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    if (get_pcvar_num(g_cvarAutoPlant))
    {
        return HC_CONTINUE;
    }

    if (!is_user_connected(player))
    {
        return HC_CONTINUE;
    }

    if (rg_has_item_by_name(player, "weapon_c4"))
    {
        engclient_cmd(player, "weapon_c4");
        client_print(player, print_center, "PLANT A BOMB!!!^rPLANT A BOMB!!!^rPLANT A BOMB!!!");
        ClientPrintColor(player, "%s 快去下包！！！", g_prefix);
        ClientPrintColor(player, "%s 快去下包！！！", g_prefix);
        ClientPrintColor(player, "%s 快去下包！！！", g_prefix);
    }

    return HC_CONTINUE;
}

public RG_PlantBomb_Post(const index, Float:vecStart[3], Float:vecVelocity[3])
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    log_bomb_planted();
    return HC_CONTINUE;
}

public RG_CGrenade_DefuseBombEnd_Post(const this, const player, bool:bDefused)
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    if (bDefused)
    {
        log_bomb_defused();
    }
    return HC_CONTINUE;
}

public RG_CGrenade_ExplodeBomb_Post(const this, tracehandle, const bitsDamageType)
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    log_bomb_explode();
    return HC_CONTINUE;
}

public task_info_hud()
{
    if (!is_retakes_enabled())
    {
        return;
    }

    set_hudmessage(0, 212, 255, 0.57, 0.05, _, _, 1.0, _, _, 1);
    ShowSyncHudMsg(0, g_syncInfoHud, "点位 : %s", g_bombSite ? "B" : "A");
}

public task_bomb_not_plant()
{
    if (!is_retakes_enabled())
    {
        return;
    }

    if (!g_isBombPlanted)
    {
        set_pcvar_num(g_cvarRestartRound, 1);
    }

    if (task_exists(TASK_BOMB_NOT_PLANT))
    {
        remove_task(TASK_BOMB_NOT_PLANT);
    }
}

public event_end_round()
{
    g_c4timer = -1;
    remove_task(TASK_BOMB_TIMER);

    if (!g_isRoundEnd)
    {
        return;
    }

    g_bombSite = !g_bombSite;
    read_spawns();
    g_isRoundEnd = false;
}

public event_restart_game()
{
    if (task_exists(TASK_BOMB_NOT_PLANT))
    {
        remove_task(TASK_BOMB_NOT_PLANT);
    }

    g_c4timer = -1;
    remove_task(TASK_BOMB_TIMER);

    if (!g_isRoundRestart)
    {
        return;
    }

    if (g_roundRestore)
    {
        g_round--;
        g_roundRestore = false;
    }

    new iPlayers[32], iNum;
    get_players(iPlayers, iNum);

    for (new i = 0; i < iNum; i++)
    {
        g_savePlayerData[iPlayers[i]] = true;
    }

    g_isRoundRestart = false;
}

public event_on_ct_win()
{
    if (!g_onCtWinRound)
    {
        return;
    }

    if (get_pcvar_num(g_cvarSwapCt))
    {
        g_roundWin = 0;
        swap_teams();
        ClientPrintColor(0, "%s CT 获胜，正在交换阵营！", g_prefix);
        g_onCtWinRound = false;
    }
}

public event_on_te_win()
{
    if (!g_onTeWinRound)
    {
        return;
    }

    if (get_pcvar_num(g_cvarSwapT))
    {
        g_roundWin++;
        if (g_roundWin == get_pcvar_num(g_cvarTTwins))
        {
            swap_teams();
            ClientPrintColor(0, "%s T 连胜 %d 局，正在交换阵营！", g_prefix, g_roundWin);
            g_roundWin = 0;
        }
        g_onTeWinRound = false;
    }
}

stock swap_teams()
{
    new iPlayers[32], iNum;
    get_players(iPlayers, iNum);

    for (new i = 0; i < iNum; i++)
    {
        new iPlayer = iPlayers[i];
        new TeamName:team = get_member(iPlayer, m_iTeam);

        switch (team)
        {
            case TEAM_TERRORIST:
                rg_set_user_team(iPlayer, TEAM_CT);
            case TEAM_CT:
                rg_set_user_team(iPlayer, TEAM_TERRORIST);
        }
    }
}

stock read_spawns()
{
    new szMap[32], szConfigDir[128], szMapFile[256];

    get_configsdir(szConfigDir, charsmax(szConfigDir));
    get_mapname(szMap, charsmax(szMap));

    if (g_bombSite)
        formatex(szMapFile, charsmax(szMapFile), "%s/retakes/%s.spawns_b.cfg", szConfigDir, szMap);
    else
        formatex(szMapFile, charsmax(szMapFile), "%s/retakes/%s.spawns_a.cfg", szConfigDir, szMap);

    if (!file_exists(szMapFile))
    {
        return 0;
    }

    remove_retake_spawn_spots();
    g_lastRetakeSpawnT = 0;
    g_lastRetakeSpawnCT = 0;

    new ent;
    new Data[128], len, line = 0;
    new team[8], p_origin[3][8], p_angles[3][8];
    new Float:origin[3], Float:angles[3];

    while ((line = read_file(szMapFile, line, Data, 127, len)) != 0)
    {
        if (strlen(Data) < 2)
            continue;

        parse(Data, team, 7, p_origin[0], 7, p_origin[1], 7, p_origin[2], 7, p_angles[0], 7, p_angles[1], 7, p_angles[2], 7);

        origin[0] = str_to_float(p_origin[0]);
        origin[1] = str_to_float(p_origin[1]);
        origin[2] = str_to_float(p_origin[2]);
        angles[0] = str_to_float(p_angles[0]);
        angles[1] = str_to_float(p_angles[1]);
        angles[2] = str_to_float(p_angles[2]);

        if (equali(team, "T"))
        {
            ent = create_retake_spawn_spot(origin, angles, TEAM_TERRORIST);
            if (!is_nullent(ent))
                g_lastRetakeSpawnT = ent;
        }
        else if (equali(team, "CT"))
        {
            ent = create_retake_spawn_spot(origin, angles, TEAM_CT);
            if (!is_nullent(ent))
                g_lastRetakeSpawnCT = ent;
        }
    }
    return 1;
}

stock remove_retake_spawn_spots()
{
    new ent = 0;
    while ((ent = rg_find_ent_by_class(ent, CLASSNAME_RETAKES_SPAWN_T)))
    {
        if (!is_nullent(ent))
        {
            rg_remove_entity(ent);
        }
    }

    ent = 0;
    while ((ent = rg_find_ent_by_class(ent, CLASSNAME_RETAKES_SPAWN_CT)))
    {
        if (!is_nullent(ent))
        {
            rg_remove_entity(ent);
        }
    }
}

stock create_retake_spawn_spot(const Float:origin[3], const Float:angles[3], TeamName:team)
{
    new ent = rg_create_entity("info_target", true);
    if (is_nullent(ent))
    {
        return NULLENT;
    }

    set_entvar(ent, var_origin, origin);
    set_entvar(ent, var_angles, angles);
    set_entvar(ent, var_v_angle, angles);
    set_entvar(ent, var_classname, team == TEAM_CT ? CLASSNAME_RETAKES_SPAWN_CT : CLASSNAME_RETAKES_SPAWN_T);

    return ent;
}

stock get_retake_spawn_spot(TeamName:team)
{
    new ent = 0;

    if (team == TEAM_TERRORIST)
    {
        while ((ent = rg_find_ent_by_class(g_lastRetakeSpawnT, CLASSNAME_RETAKES_SPAWN_T)))
        {
            if (!is_nullent(ent))
            {
                g_lastRetakeSpawnT = ent;
                return ent;
            }
        }

        g_lastRetakeSpawnT = 0;
        while ((ent = rg_find_ent_by_class(g_lastRetakeSpawnT, CLASSNAME_RETAKES_SPAWN_T)))
        {
            if (!is_nullent(ent))
            {
                g_lastRetakeSpawnT = ent;
                return ent;
            }
        }
    }
    else if (team == TEAM_CT)
    {
        while ((ent = rg_find_ent_by_class(g_lastRetakeSpawnCT, CLASSNAME_RETAKES_SPAWN_CT)))
        {
            if (!is_nullent(ent))
            {
                g_lastRetakeSpawnCT = ent;
                return ent;
            }
        }

        g_lastRetakeSpawnCT = 0;
        while ((ent = rg_find_ent_by_class(g_lastRetakeSpawnCT, CLASSNAME_RETAKES_SPAWN_CT)))
        {
            if (!is_nullent(ent))
            {
                g_lastRetakeSpawnCT = ent;
                return ent;
            }
        }
    }

    return NULLENT;
}

public RG_CBasePlayer_EntSelectSpawnPoint_Pre(const this)
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    new TeamName:team = get_member(this, m_iTeam);
    if (!(team == TEAM_CT || team == TEAM_TERRORIST))
    {
        return HC_CONTINUE;
    }

    new ent = get_retake_spawn_spot(team);
    if (is_nullent(ent))
    {
        return HC_CONTINUE;
    }

    SetHookChainReturn(ATYPE_INTEGER, ent);
    return HC_SUPERCEDE;
}

public RG_CBasePlayer_Spawn_Post(const id)
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    if (!is_user_alive(id))
    {
        return HC_CONTINUE;
    }

    if (task_exists(id))
    {
        remove_task(id);
    }

    if (get_pcvar_num(g_cvarAutoPlant))
    {
        set_task(get_pcvar_float(g_cvarMpFreezetime), "task_c4_strip", id);
    }

    if (g_savePlayerData[id])
    {
        set_entvar(id, var_frags, g_ePlayerData[id][Player_Kills]);
        set_member(id, m_iDeaths, g_ePlayerData[id][Player_Deaths]);
        rg_add_account(id, g_ePlayerData[id][Player_Money], AS_SET);
        g_savePlayerData[id] = false;
    }
    else
    {
        g_ePlayerData[id][Player_Kills] = get_user_frags(id);
        g_ePlayerData[id][Player_Deaths] = get_user_deaths(id);
        g_ePlayerData[id][Player_Money] = get_member(id, m_iAccount);
    }

    event_draw_buyzone_icon(id);

    return HC_CONTINUE;
}

public event_draw_buyzone_icon(id)
{
    if (is_user_alive(id) && get_pcvar_num(g_cvarBuyZone))
    {
        message_begin(MSG_ONE, g_msgStatusIcon, _, id);
        write_byte(1<<0);
        write_string("buyzone");
        write_byte(0);
        write_byte(160);
        write_byte(0);
        message_end();
    }
}

public clcmd_fullupdate()
{
    return PLUGIN_HANDLED;
}

public task_c4_strip(id)
{
    if (!is_retakes_enabled())
    {
        return;
    }

    if (!is_user_alive(id))
    {
        return;
    }

    if (rg_has_item_by_name(id, "weapon_c4"))
    {
        rg_remove_item(id, "weapon_c4", true);
        rg_set_user_bpammo(id, WEAPON_C4, 0);
        bomb_plant(id);
    }
}

public bomb_plant(player)
{
    if (!is_retakes_enabled())
    {
        return;
    }

    new Float:origin[3];
    get_entvar(player, var_origin, origin);
    origin[0] += 30.0;

    rg_plant_bomb(player, origin);

    client_print(0, print_center, "#Cstrike_TitlesTXT_Bomb_Planted");
    client_cmd(0, "spk sound/radio/bombpl.wav");

    g_isBombPlanted = true;

    if (get_pcvar_num(g_cvarHudc4Timer))
    {
        g_c4timer = get_pcvar_num(g_cvarMpc4timer);
        task_disp_time();
        set_task(1.0, "task_disp_time", TASK_BOMB_TIMER, "", 0, "b");
    }
}

public log_msg_plant_bomb()
{
    if (get_pcvar_num(g_cvarAutoPlant))
        return;

    new szLogUser[80], szName[32];
    read_logargv(0, szLogUser, charsmax(szLogUser));
    parse_loguser(szLogUser, szName, charsmax(szName));

    new id = get_user_index(szName);

    if (rg_has_item_by_name(id, "weapon_c4"))
    {
        engclient_cmd(id, "weapon_c4");
        client_print(id, print_center, "PLANT A BOMB!!!^rPLANT A BOMB!!!^rPLANT A BOMB!!!");
        ClientPrintColor(id, "%s 快去下包！！！", g_prefix);
        ClientPrintColor(id, "%s 快去下包！！！", g_prefix);
        ClientPrintColor(id, "%s 快去下包！！！", g_prefix);
    }
}

public log_bomb_planted()
{
    if (!g_isBomb)
        return;

    g_isBombPlanted = true;
    if (get_pcvar_num(g_cvarHudc4Timer))
    {
        g_c4timer = get_pcvar_num(g_cvarMpc4timer);
        task_disp_time();
        set_task(1.0, "task_disp_time", TASK_BOMB_TIMER, "", 0, "b");
    }
    g_isBomb = false;
}

public log_bomb_defused()
{
    if (g_isBombPlanted)
    {
        remove_task(TASK_BOMB_TIMER);
        g_isBombPlanted = false;
    }
}

public log_bomb_explode()
{
    if (g_isBombPlanted)
    {
        remove_task(TASK_BOMB_TIMER);
        g_isBombPlanted = false;
    }
}

public task_disp_time()
{
    if (!g_isBombPlanted)
    {
        remove_task(TASK_BOMB_TIMER);
        return;
    }

    if (g_c4timer >= 0)
    {
        if (g_c4timer > 13)
            set_hudmessage(0, 150, 0, -1.0, 0.80, 0, 1.0, 1.0, 0.01, 0.01, -1);
        else if (g_c4timer > 7)
            set_hudmessage(150, 150, 0, -1.0, 0.80, 0, 1.0, 1.0, 0.01, 0.01, -1);
        else
            set_hudmessage(150, 0, 0, -1.0, 0.80, 0, 1.0, 1.0, 0.01, 0.01, -1);

        ShowSyncHudMsg(0, g_c4SyncMsg, "C4: %d", g_c4timer);
        g_c4timer--;
    }
}

public client_command(client)
{
    return PLUGIN_CONTINUE;
}

public plugin_end()
{
    if (g_hEnableCvarHook)
    {
        disable_cvar_hook(g_hEnableCvarHook);
    }
}

public client_disconnected(id)
{
    if (task_exists(id))
    {
        remove_task(id);
    }
}

public RG_CBasePlayer_DropPlayerItem_Pre(const this, const pszItemName[])
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    if (equali(pszItemName, "weapon_c4"))
    {
        SetHookChainReturn(ATYPE_EDICT, 0);
        return HC_SUPERCEDE;
    }
    return HC_CONTINUE;
}

public unlock_buyzone()
{
    new Float:bMin[3] = {-8191.0, -8191.0, -8191.0};
    new Float:bMax[3] = {8191.0, 8191.0, 8191.0};

    new buyZone = create_entity("func_buyzone");
    DispatchKeyValue(buyZone, "team", "0");
    DispatchSpawn(buyZone);
    entity_set_size(buyZone, bMin, bMax);
}

public StatusIcon_Pre(msg_id, msg_dest, msg_entity)
{
    if (!is_retakes_enabled())
    {
        return HC_CONTINUE;
    }

    if (get_pcvar_num(g_cvarBuyZone) == 0)
    {
        static szIcon[8];
        GetMessageData(MsgArg, 2, szIcon, charsmax(szIcon));
        if (equal(szIcon, "buyzone"))
        {
            if (GetMessageData(MsgArg, 1))
            {
                return HC_SUPERCEDE;
            }
        }
        return HC_CONTINUE;
    }
    return HC_CONTINUE;
}

stock ClientPrintColor(id, const string[], any:...)
{
    new szMsg[190];
    vformat(szMsg, charsmax(szMsg), string, 3);

    replace_all(szMsg, charsmax(szMsg), "!n", "^1");
    replace_all(szMsg, charsmax(szMsg), "!t", "^3");
    replace_all(szMsg, charsmax(szMsg), "!g", "^4");

    static msgSayText = 0;
    static fakeUser;

    if (!msgSayText)
    {
        msgSayText = get_user_msgid("SayText");
        fakeUser = get_maxplayers() + 1;
    }

    message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, _, id);
    write_byte(id ? id : fakeUser);
    write_string(szMsg);
    message_end();
}
