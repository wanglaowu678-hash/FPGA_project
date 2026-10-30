# ============================================================
#  从 RTL 源码重建 Vivado 工程（不依赖 .xpr）
#  用法：vivado -mode batch -source scripts/create_project.tcl
# ============================================================
set origin_dir [file normalize [file dirname [info script]]/..]
set src_dir    "$origin_dir/v_1020/srcs"
set ip_dir     "$origin_dir/v_1020/v1020.srcs/sources_1/ip"
set proj_dir   "$origin_dir/vivado"

create_project FPGA_project $proj_dir -part xc7a35tcpg236-1 -force

# 所有 Verilog 源文件
add_files -norecurse [glob -directory $src_dir *.v]

# 约束
add_files -fileset constrs_1 -norecurse "$src_dir/ov7725colorbracking.xdc"

# IP 配置（Vivado 会据此生成 clk_wiz_0 / blk_mem_gen_0 的输出产物）
add_files -norecurse [glob -directory $ip_dir */*.xci]

set_property top design_1 [current_fileset]
update_compile_order -fileset sources_1
puts "Project created at: $proj_dir"
