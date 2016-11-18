set_global_assignment -entity "PLL_HDMI" -library "lib_PLL_HDMI" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_HDMI" -library "lib_PLL_HDMI" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLL_HDMI" -library "lib_PLL_HDMI" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_HDMI" -name SPD_FILE [file join $::quartus(sip_path) "PLL_HDMI.spd"]

set_global_assignment -library "lib_PLL_HDMI" -name MISC_FILE [file join $::quartus(sip_path) "PLL_HDMI_sim/PLL_HDMI.vho"]
