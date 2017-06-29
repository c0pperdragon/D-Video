create_clock -period 20.000 -name clk50 [get_ports {CLK50}]
create_clock -period 200.000 -name clkpal [get_ports {GPIO[0]}]
create_clock -period 200.000 -name clkatari [get_ports {GPIO[2]}]
derive_pll_clocks

