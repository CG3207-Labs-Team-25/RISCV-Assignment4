set dbg_root [file normalize [file join [file dirname [info script]] ..]]
set dbg_out [file join $dbg_root temp debugger-vivado]
file mkdir $dbg_out

proc debugger_project {} {
    global dbg_root
    if {![llength [get_projects -quiet]]} {
        open_project [file join $dbg_root RISCV-CPU.xpr]
    } elseif {[file normalize [get_property DIRECTORY [current_project]]] ne $dbg_root} {
        error "Open RISCV-CPU.xpr from this checkout in a fresh Vivado session."
    }
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
}

proc debugger_behavioral {} {
    global dbg_root dbg_out
    debugger_project
    set dbg_sim [get_filesets sim_1]
    set dbg_top_saved [get_property TOP $dbg_sim]
    set dbg_options_saved [get_property xsim.simulate.xsim.more_options $dbg_sim]
    set dbg_runtime_saved [get_property xsim.simulate.runtime $dbg_sim]
    set_property -name xsim.simulate.xsim.more_options -value [format {-testplusarg "PREVIEW_DIR=%s"} $dbg_out] -objects $dbg_sim
    set_property xsim.simulate.runtime 2ms $dbg_sim
    set dbg_tests {
        {test_BranchPrediction {ALL BRANCH PREDICTOR TESTS PASSED}}
        {test_Wrapper_Prediction {ALL CPU BRANCH PREDICTION TESTS PASSED}}
        {test_StepController {ALL BUTTON STEP TESTS PASSED}}
        {test_Wrapper_Stepping {ALL CPU STEPPING TESTS PASSED}}
        {test_DebugState {ALL PIPELINE DEBUG STATE TESTS PASSED}}
        {test_DebugSnapshot {ALL DEBUG SNAPSHOT TESTS PASSED}}
        {test_BranchTrace {ALL BRANCH FLUSH CAPTURE TESTS PASSED}}
        {test_PipelineDisplay {ALL OLED PIPELINE DISPLAY TESTS PASSED}}
        {test_PipelineDebugger {ALL INTERACTIVE PIPELINE DEBUGGER TESTS PASSED}}
        {test_Debugger_PostSynth {ALL DEBUGGER PORT-LEVEL TESTS PASSED}}
        {test_Wrapper_BF {ALL BASIC FUNCTIONALITY TESTS PASSED}}
        {test_Wrapper_assigned {ALL ASSIGNED-INSTRUCTION TESTS PASSED}}
        {test_Wrapper_Demo {ALL FPGA DEMO TESTS PASSED}}
        {test_Wrapper_LoadStore {ALL LOAD/STORE TESTS PASSED}}
        {test_MCycle {ALL TESTS PASSED}}
        {test_MCycle_post_synth {ALL RTL EVALUATION TESTS PASSED}}
    }
    set dbg_failed [catch {
        foreach dbg_test $dbg_tests {
            lassign $dbg_test dbg_top dbg_pass
            set_property TOP $dbg_top $dbg_sim
            set dbg_start [clock seconds]
            launch_simulation -simset sim_1 -mode behavioral
            close_sim
            set dbg_logtext ""
            set dbg_simdir [file join $dbg_root RISCV-CPU.sim sim_1 behav xsim]
            foreach dbg_log [glob -nocomplain -directory $dbg_simdir *.log] {
                if {[file mtime $dbg_log] >= $dbg_start} {
                    set dbg_fd [open $dbg_log r]
                    append dbg_logtext [read $dbg_fd]
                    close $dbg_fd
                }
            }
            set dbg_fd [open [file join $dbg_out ${dbg_top}.log] w]
            puts $dbg_fd $dbg_logtext
            close $dbg_fd
            if {[string first $dbg_pass $dbg_logtext] < 0 ||
                [regexp {FATAL:|FAIL:} $dbg_logtext]} {
                error "$dbg_top did not pass; see $dbg_out"
            }
        }
    } dbg_error]
    catch {close_sim}
    set_property TOP $dbg_top_saved $dbg_sim
    set_property -name xsim.simulate.xsim.more_options -value $dbg_options_saved -objects $dbg_sim
    set_property xsim.simulate.runtime $dbg_runtime_saved $dbg_sim
    if {$dbg_failed} {error $dbg_error}
    puts "ALL VIVADO BEHAVIORAL DEBUGGER CHECKS PASSED"
}

proc debugger_build {} {
    global dbg_out
    debugger_project
    set_property TOP TOP [get_filesets sources_1]
    set_property GENERIC {DEBUGGER_ENABLE=true} [get_filesets sources_1]
    set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
    reset_run synth_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        error "Implementation did not complete: [get_property STATUS [get_runs impl_1]]"
    }
    open_run impl_1
    report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -file [file join $dbg_out timing.rpt]
    report_clocks -file [file join $dbg_out clocks.rpt]
    report_clock_interaction -file [file join $dbg_out clock-interaction.rpt]
    report_cdc -details -file [file join $dbg_out cdc.rpt]
    report_drc -file [file join $dbg_out drc.rpt]
    report_methodology -file [file join $dbg_out methodology.rpt]
    foreach dbg_type {max min} {
        set dbg_path [get_timing_paths -quiet -delay_type $dbg_type -max_paths 1]
        if {![llength $dbg_path] || [get_property SLACK $dbg_path] < 0} {
            error "Timing requires review ($dbg_type); see $dbg_out"
        }
    }
    puts "Build completed. Review timing, unconstrained I/O, CDC, and DRC reports before board testing."
}

proc debugger_postsynth {} {
    global dbg_root dbg_out
    if {[llength [get_projects -quiet]]} {
        error "Run postsynth in a fresh Vivado batch session."
    }
    set dbg_post [file join $dbg_out postsynth]
    file mkdir $dbg_post
    cd [file join $dbg_root asm_mem]
    create_project -in_memory -part xc7a100tcsg324-1
    foreach dbg_source [glob -directory [file join $dbg_root RISCV-CPU.srcs sources_1 new] *.v] {
        read_verilog [list $dbg_source]
    }
    read_verilog [list [file join $dbg_root RISCV-CPU.srcs sources_1 imports verilog MCycle.v]]
    synth_design -top Wrapper -part xc7a100tcsg324-1 -no_iobuf -generic {IROM_FILE="Debugger_IROM.mem" DMEM_FILE="Debugger_DMEM.mem"}
    create_clock -period 40.000 [get_ports CLK]
    write_verilog -force -mode funcsim [file join $dbg_post debugger_funcsim.v]
    write_checkpoint -force [file join $dbg_post debugger_synth.dcp]
    report_utilization -file [file join $dbg_post utilization.rpt]
    cd $dbg_post
    set dbg_bin [file join $::env(XILINX_VIVADO) bin]
    exec [file join $dbg_bin xvlog] -d DEBUGGER_NETLIST debugger_funcsim.v \
        [file join $dbg_root RISCV-CPU.srcs sim_1 new test_Debugger_PostSynth.v] \
        [file join $::env(XILINX_VIVADO) data verilog src glbl.v] > compile.log 2>@1
    exec [file join $dbg_bin xelab] -relax -L unisims_ver -L unimacro_ver -L secureip \
        test_Debugger_PostSynth glbl -s debugger_post > elaborate.log 2>@1
    exec [file join $dbg_bin xsim] debugger_post -runall -log debugger_post.log > simulate.log 2>@1
    set dbg_fd [open debugger_post.log r]
    set dbg_text [read $dbg_fd]
    close $dbg_fd
    if {[string first "ALL DEBUGGER PORT-LEVEL TESTS PASSED" $dbg_text] < 0 ||
        [regexp {FATAL:|FAIL:} $dbg_text]} {
        error "Post-synthesis simulation did not pass; see $dbg_post"
    }
    puts "ALL POST-SYNTHESIS DEBUGGER CHECKS PASSED"
}

if {[info exists argv] && [llength $argv]} {
    switch -- [lindex $argv 0] {
        behavioral {debugger_behavioral}
        build {debugger_build}
        postsynth {debugger_postsynth}
        default {error "Use behavioral, build, or postsynth."}
    }
}
