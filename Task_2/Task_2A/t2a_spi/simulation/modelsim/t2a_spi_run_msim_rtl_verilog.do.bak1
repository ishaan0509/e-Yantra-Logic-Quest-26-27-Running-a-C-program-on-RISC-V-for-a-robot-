transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/raina/Downloads/lq_1746_task2a/t2a_spi/code {C:/Users/raina/Downloads/lq_1746_task2a/t2a_spi/code/t2a_spi.v}

vlog -vlog01compat -work work +incdir+C:/Users/raina/Downloads/lq_1746_task2a/t2a_spi/.test {C:/Users/raina/Downloads/lq_1746_task2a/t2a_spi/.test/tb.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  tb

add wave *
view structure
view signals
run 12 us
