# ============================================================================
# AXI4 Verification Environment - Master Run Script (QuestaSim)
# ============================================================================

# 0. Configuration Switch
# 1: Opens GUI, loads waves, enables assertion debugging.
# 0: Runs in batch mode for regressions.
set DEBUG_MODE 1

# 1. Cleanup and Library Setup
if {[file exists work]} { vdel -all }
vlib work

# 2. Compile Phase 
vlog param_pkg.sv axi4_interface.sv axi4_class.sv my_TB.sv TOP_axi4.sv
vlog +cover=sbcetf my_axi4.sv my_axi4_memory.sv

# 3. Execution Branch
if {$DEBUG_MODE == 1} {
    puts "--- Running in DEBUG MODE (GUI + Waves + Coverage + SVA) ---"
    
    # -assertcover forces SVA data into the database
    vsim -coverage -assertdebug -assertcover -voptargs="+acc +cover=sbcetf" work.TOP_axi4 -do {
        
        # 1. Add Waves
        add wave -color Yellow -itemcolor Yellow /TOP_axi4/axi_inf/ACLK
        add wave -group "AXI_BUS" /TOP_axi4/axi_inf/*
        add wave -divider "SVA_CHECKERS"
        add wave -assert /TOP_axi4/axi_inf/*
        add wave -divider "TB_MONITOR"
        add wave -radix decimal /TOP_axi4/TB/operation
        add wave /TOP_axi4/TB/flag
        add wave -divider "DUT_INTERNAL"
        add wave /TOP_axi4/dut/*

        # 2. Open Assertion Tracking Window
        view assertions

        # 3. Load saved wave format if it exists
        if {[file exists wave.do]} { 
            puts "Loading saved wave format..."
            do wave.do 
        }

        # 4. Save coverage database when simulation ends
        coverage save -onexit cov.ucdb;
        
        # 5. Run the simulation
        run -all;
        
        # 6. Auto-generate the Master Text Report (Code + CVG + Assertions)
        coverage report -detail -cvg -assert -file full_coverage_report.txt
        puts "--- Text Coverage Report Generated: full_coverage_report.txt ---"
    }

} else {
    puts "--- Running in REGRESSION MODE ---"
    
    set seed [expr {int(rand() * 1000000)}]
    vsim -c -voptargs="+acc +cover=sbcetf" -coverage -assertcover work.TOP_axi4 -sv_seed $seed -do "
        coverage save -onexit cov.ucdb;
        run -all;
        quit -sim; 
    "
    # Generate the Master Text Report in batch mode
    vcover report cov.ucdb -detail -cvg -assert -file full_coverage_report.txt
    puts "--- Regression Complete. Report Generated: full_coverage_report.txt ---"
}