set_global_assignment -entity "PLL_500" -library "lib_PLL_500" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_500" -library "lib_PLL_500" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_500" -library "lib_PLL_500" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_500" -name SPD_FILE [file join $::quartus(sip_path) "PLL_500.spd"]

set_global_assignment -library "lib_PLL_500" -name MISC_FILE [file join $::quartus(sip_path) "PLL_500_sim/PLL_500.vho"]
