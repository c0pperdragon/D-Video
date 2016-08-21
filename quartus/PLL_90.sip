set_global_assignment -entity "PLL_90" -library "lib_PLL_90" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_90" -library "lib_PLL_90" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_90" -library "lib_PLL_90" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_90" -name SPD_FILE [file join $::quartus(sip_path) "PLL_90.spd"]

set_global_assignment -library "lib_PLL_90" -name MISC_FILE [file join $::quartus(sip_path) "PLL_90_sim/PLL_90.vho"]
