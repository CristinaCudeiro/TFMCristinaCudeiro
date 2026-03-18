transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vcom -93 -work work {C:/Users/Usuario/Desktop/TFM/FPGA/RegistroTipoD.vhd}
vcom -93 -work work {C:/Users/Usuario/Desktop/TFM/FPGA/Comunicacion_I2C.vhd}
vcom -93 -work work {C:/Users/Usuario/Desktop/TFM/FPGA/Acelerometro.vhd}

vcom -93 -work work {C:/Users/Usuario/Desktop/TFM/FPGA/simulacion.vhd}

vsim -t 1ps -L altera -L lpm -L sgate -L altera_mf -L altera_lnsim -L fiftyfivenm -L rtl_work -L work -voptargs="+acc"  simulacion

add wave *
view structure
view signals
run -all
