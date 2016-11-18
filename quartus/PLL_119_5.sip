set_global_assignment -entity "PLL_119_5" -library "lib_PLL_119_5" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_119_5" -library "lib_PLL_119_5" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_119_5" -library "lib_PLL_119_5" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_119_5" -name SPD_FILE [file join $::quartus(sip_path) "PLL_119_5.spd"]

set_global_assignment -library "lib_PLL_119_5" -name MISC_FILE [file join $::quartus(sip_path) "PLL_119_5_sim/PLL_119_5.vho"]
