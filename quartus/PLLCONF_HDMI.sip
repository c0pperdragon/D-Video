set_global_assignment -entity "PLLCONF_HDMI" -library "lib_PLLCONF_HDMI" -name IP_TOOL_NAME "altera_pll_reconfig"
set_global_assignment -entity "PLLCONF_HDMI" -library "lib_PLLCONF_HDMI" -name IP_TOOL_VERSION "16.0"
set_global_assignment -entity "PLLCONF_HDMI" -library "lib_PLLCONF_HDMI" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLLCONF_HDMI" -name SPD_FILE [file join $::quartus(sip_path) "PLLCONF_HDMI.spd"]

set_global_assignment -library "lib_PLLCONF_HDMI" -name MISC_FILE [file join $::quartus(sip_path) "PLLCONF_HDMI_sim/PLLCONF_HDMI.vhd"]
set_global_assignment -library "lib_PLLCONF_HDMI" -name MISC_FILE [file join $::quartus(sip_path) "PLLCONF_HDMI_sim/altera_pll_reconfig/altera_pll_reconfig_top.v"]
set_global_assignment -library "lib_PLLCONF_HDMI" -name MISC_FILE [file join $::quartus(sip_path) "PLLCONF_HDMI_sim/altera_pll_reconfig/altera_pll_reconfig_core.v"]
