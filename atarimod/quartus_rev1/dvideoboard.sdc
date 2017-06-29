create_clock -period 20.000 -name clk50 [get_ports {CLK50}]
create_clock -period 200.000 -name clkatari [get_ports {INPUTS[3]}]
create_clock -period 200.000 -name clkref [get_ports {INPUTS29}]
create_generated_clock -name clkhdmi -source {part1|pixelclockgenerator|altpll_component|auto_generated|pll1|inclk[0]} -multiply_by 30 -phase 11.25 {part1|pixelclockgenerator|altpll_component|auto_generated|pll1|clk[0]}

# set_output_delay -clock clkhdmi -max 0.5 [get_ports {adv7511_clk}]
# set_output_delay -clock clkhdmi -min 0 [get_ports {adv7511_clk}]
#set_output_delay -clock clkhdmi 1 [get_ports {adv7511_hs}]
# set_output_delay -clock clkhdmi -min 2 [get_ports {adv7511_hs}]
#set_output_delay -clock clkhdmi 1 [get_ports {adv7511_vs}]
# set_output_delay -clock clkhdmi -min 2 [get_ports {adv7511_vs}]
#set_output_delay -clock clkhdmi 1 [get_ports {adv7511_de}]
# set_output_delay -clock clkhdmi -min 2 [get_ports {adv7511_de}]
#set_output_delay -clock clkhdmi 1 [get_ports {adv7511_d}]
# set_output_delay -clock clkhdmi -min 0 [get_ports {adv7511_d}]

derive_clock_uncertainty
