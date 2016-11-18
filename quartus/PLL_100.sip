set_global_assignment -entity "PLL_100" -library "lib_PLL_100" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_100" -library "lib_PLL_100" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_100" -library "lib_PLL_100" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_100" -name SPD_FILE [file join $::quartus(sip_path) "PLL_100.spd"]

set_global_assignment -library "lib_PLL_100" -name MISC_FILE [file join $::quartus(sip_path) "PLL_100_sim/PLL_100.vho"]
