set_global_assignment -entity "PLL_226" -library "lib_PLL_226" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_226" -library "lib_PLL_226" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_226" -library "lib_PLL_226" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_226" -name SPD_FILE [file join $::quartus(sip_path) "PLL_226.spd"]

set_global_assignment -library "lib_PLL_226" -name MISC_FILE [file join $::quartus(sip_path) "PLL_226_sim/PLL_226.vho"]
