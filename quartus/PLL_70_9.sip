set_global_assignment -entity "PLL_70_9" -library "lib_PLL_70_9" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_70_9" -library "lib_PLL_70_9" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_70_9" -library "lib_PLL_70_9" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_70_9" -name SPD_FILE [file join $::quartus(sip_path) "PLL_70_9.spd"]

set_global_assignment -library "lib_PLL_70_9" -name MISC_FILE [file join $::quartus(sip_path) "PLL_70_9_sim/PLL_70_9.vho"]
