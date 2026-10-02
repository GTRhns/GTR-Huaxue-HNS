#if defined _semiclip_system_included
  #endinput
#endif
#define _semiclip_system_included

/*
 * ============================================================================
 *  SemiclipSystem 接口 (semiclip_system.inc)
 *  ----------------------------------------------------------------------------
 *  由独立插件 SemiclipSystem.sma 提供, 供其它插件绑定使用。
 *
 *  注意:
 *  - 若插件未加载, 直接调用下面 natives 会被 AMXX 判定为不可解析并可能导致宿主
 *    插件启动异常。想"可选依赖"只需调用 stock semclip_apply() —— 它内部用
 *    callfunc 探测插件是否存在, 不存在时返回 0 且不会产生 required-native 绑定。
 *
 *  直接请求 (强依赖):
 *      semclip_set_mode(SEMICLIP_SAME);
 *      new m = semclip_get_mode();
 *  可选调用 (弱依赖, 推荐给比赛系统这类不强制依赖的插件):
 *      semclip_apply(SEMICLIP_SAME);
 * ============================================================================
 */

#define SEMICLIP_PLUGIN_FILE "SemiclipSystem.amxx"

enum SEMICLIP_MODE
{
    SEMICLIP_OFF  = 0,     // 关闭穿透
    SEMICLIP_SAME = 1,     // 仅同队可穿透 (半透明队友)
    SEMICLIP_ALL  = 2      // 全员可穿透
}

/*
 * 设置穿透模式。
 * @param iMode  SEMICLIP_MODE 值
 * @return       1 成功
 */
native semclip_set_mode(iMode);

/*
 * 获取当前穿透模式。
 * @return SEMICLIP_MODE 值
 */
native SEMICLIP_MODE:semclip_get_mode();

/* 便捷封装: 关闭穿透 */
stock semclip_off()
{
    return semclip_set_mode(_:SEMICLIP_OFF);
}

/* 便捷封装: 开启穿透 */
stock semclip_on(bool:bEnemy = false)
{
    return semclip_set_mode(bEnemy ? _:SEMICLIP_ALL : _:SEMICLIP_SAME);
}

/*
 * 可选依赖调用: 插件存在时经 callfunc 调用 semclip_set_mode, 否则返回 0。
 * 适合"装了就用, 没装就降级"的宿主插件。
 */
stock semclip_apply(iMode)
{
    new iPlugin = find_plugin_byfile(SEMICLIP_PLUGIN_FILE);
    if (iPlugin == -1)
        return 0;

    new iFunc = get_func_id("SemiClipSetModeForward", iPlugin);
    if (iFunc == -1)
        return 0;

    callfunc_begin_i(iFunc, iPlugin);
    callfunc_push_int(iMode);
    callfunc_end();

    return 1;
}