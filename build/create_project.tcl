# ============================================================
#  Rebuild the Vivado project from RTL sources (no .xpr required)
#  Usage: vivado -mode batch -source build/create_project.tcl
# ============================================================
set origin_dir [file normalize [file dirname [info script]]/..]
set src_dir    "$origin_dir/src"
set ip_dir     "$origin_dir/src/ip"
set proj_dir   "$origin_dir/board"

create_project v1020 $proj_dir -part xc7a35tcpg236-1 -force

# RTL sources
add_files -norecurse [glob -directory $src_dir *.v]

# Constraints
add_files -fileset constrs_1 -norecurse "$src_dir/ov7725_color_tracking.xdc"

# IP configurations (Vivado regenerates clk_wiz_0 / blk_mem_gen_0 output products)
add_files -norecurse [glob -directory $ip_dir */*.xci]

set_property top design_1 [current_fileset]
update_compile_order -fileset sources_1
puts "Project created at: $proj_dir"
