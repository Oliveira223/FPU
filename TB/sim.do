if {[file isdirectory work]} {vdel -all -lib work}
vlib work
vmap work work

vlog -work work ../HDL/fpu.sv

vlog -work work fpu_tb.sv
vsim -voptargs=+acc work.fpu_tb

quietly set StdArithNoWarnings 1
quietly set StdVitalGlitchNoWarnings 1

do wave.do
run -all
