======================================================
 SemiclipSystem v1.0.0 - 半透明穿人/穿透 独立插件
 （由 HNSRU 内嵌 Semiclip 逻辑剥离而成）
======================================================

一、文件清单
----------------------------
addons/amxmodx/scripting/SemiclipSystem.sma   -- 插件源码
addons/amxmodx/scripting/include/semiclip_system.inc  -- 独立接口 (INC)
addons/amxmodx/data/lang/SemiclipSystem.txt  -- 多语言 (cn/en/ru)

二、安装步骤
----------------------------
1. 把 SemiclipSystem.sma 放到
     addons/amxmodx/scripting/
   把 semiclip_system.inc 放到
     addons/amxmodx/scripting/include/
   把 SemiclipSystem.txt 放到
     addons/amxmodx/data/lang/

2. 用 amxxpc 编译 SemiclipSystem.sma 生成 SemiclipSystem.amxx
   (或官方 amxx 编译脚本)

3. 在 addons/amxmodx/plugins/plugins.ini 中加入一行 (建议在
   HnsMatchSystem 之前加载):
     SemiclipSystem.amxx

4. 重启服务器或 amxx plugins load SemiclipSystem.amxx

三、模式说明
----------------------------
  SEMICLIP_OFF  = 0  关闭
  SEMICLIP_SAME = 1  仅同队可穿透 (半透明队友)
  SEMICLIP_ALL  = 2  全员可穿透

四、命令
----------------------------
  管理员:
    say /semiclip          循环切换 关->同队->全员->关
    服务器控制台:
    semclip_system_set <0|1|2>
  兼容旧 HNSRU 接口:
    semclip_option semiclip 1
    semclip_option team 0|3
    semclip_option time <秒>

五、给其它插件接入 (标准接口)
----------------------------
  在插件里:
    #include <semiclip_system>

  (1) 强依赖:
      semclip_set_mode(SEMICLIP_SAME);   // 仅同队
      semclip_set_mode(SEMICLIP_ALL);    // 全员
      semclip_off();                     // 关闭
      new m = semclip_get_mode();

  (2) 弱依赖 (推荐, 插件未加载自动降级返回 0):
      semclip_apply(SEMICLIP_SAME);

  接管点改造示例 (HnsMatchSystem utils.inc):
      stock set_semiclip(opt, bool:enemy = false) {
          if (semclip_apply(enemy ? _:SEMICLIP_ALL
                                  : (opt == SEMICLIP_OFF ? _:SEMICLIP_OFF
                                                          : _:SEMICLIP_SAME)))
              return;
          server_cmd("semiclip_option semiclip %d", opt == SEMICLIP_OFF ? 0 : 1);
          server_cmd("semiclip_option team %d", enemy ? 3 : 0);
          server_cmd("semiclip_option time 0");
      }
======================================================