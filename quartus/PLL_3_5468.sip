set_global_assignment -entity "PLL_3_5468" -library "lib_PLL_3_5468" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_3_5468" -library "lib_PLL_3_5468" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_3_5468" -library "lib_PLL_3_5468" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_3_5468" -name SPD_FILE [file join $::quartus(sip_path) "PLL_3_5468.spd"]

set_global_assignment -library "lib_PLL_3_5468" -name MISC_FILE [file join $::quartus(sip_path) "PLL_3_5468_sim/PLL_3_5468.vho"]
