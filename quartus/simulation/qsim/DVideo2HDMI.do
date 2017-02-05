onerror {exit -code 1}
vlib work
vlog -work work DVideo2HDMI.vo
vlog -work work Atan2Test.vwf.vt
vsim -novopt -c -t 1ps -L cyclonev_ver -L altera_ver -L altera_mf_ver -L 220model_ver -L sgate_ver -L altera_lnsim_ver work.C642HDMI_vlg_vec_tst -voptargs="+acc"
vcd file -direction DVideo2HDMI.msim.vcd
vcd add -internal C642HDMI_vlg_vec_tst/*
vcd add -internal C642HDMI_vlg_vec_tst/i1/*
run -all
quit -f
