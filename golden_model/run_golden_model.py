"""
Run Golden Model & Generate Testcases (FAP201 Project)
Author: FAP201 Student
Description:
    Runs the testcase generator, executes the cycle-accurate Golden Model,
    and outputs both stimulus.txt and golden_output.txt to the testbench folder.
"""

import os
from elevator_golden_model import ElevatorGoldenModel, ElevatorState, Direction
from testcase_generator import TestcaseGenerator

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.abspath(os.path.join(base_dir, ".."))
    tb_dir = os.path.join(project_dir, "testbench")
    os.makedirs(tb_dir, exist_ok=True)

    stimulus_path = os.path.join(tb_dir, "stimulus.txt")
    golden_output_path = os.path.join(tb_dir, "golden_output.txt")
    summary_report_path = os.path.join(base_dir, "golden_simulation_summary.txt")

    print("=========================================================================")
    print("        FAP201 - ELEVATOR CONTROLLER GOLDEN MODEL GENERATOR              ")
    print("=========================================================================")

    # 1. Generate Testcase Stimuli
    generator = TestcaseGenerator(seed=2024)
    vectors = generator.generate_all()
    generator.export_stimulus_file(stimulus_path)

    # 2. Simulate with Golden Model
    model = ElevatorGoldenModel(num_floors=4, move_ticks=10, door_open_ticks=10, door_close_ticks=4)
    
    golden_results = []
    state_counts = {name: 0 for name in ElevatorState.NAME_MAP.values()}

    with open(golden_output_path, "w") as f_out:
        f_out.write("# Format: <current_floor[1:0]> <state[2:0]> <door_open> <direction[1:0]> <pending_req[3:0]>\n")
        
        for cycle, (rst_n, req_btn, door_sensor, emergency_btn, comment) in enumerate(vectors):
            out = model.step(req_btn, door_sensor, emergency_btn, rst_n)
            golden_results.append(out)

            st_name = ElevatorState.NAME_MAP[out["state"]]
            state_counts[st_name] += 1

            # Format line matching Verilog testbench expectation:
            # floor state door_open direction pending_req
            line = f"{out['current_floor']} {out['state']} {out['door_open']} {out['direction']} {out['pending_req']}\n"
            f_out.write(line)

    print(f"[SUCCESS] Exported {len(golden_results)} golden output cycles to '{golden_output_path}'")

    # 3. Generate Statistics & Summary
    summary = []
    summary.append("=========================================================================")
    summary.append("               GOLDEN MODEL SIMULATION SUMMARY REPORT                    ")
    summary.append("=========================================================================")
    summary.append(f"Total Simulation Cycles: {len(golden_results)}")
    summary.append(f"Number of Floors: 4 (Floor 1 to Floor 4)")
    summary.append(f"Timing Parameters: Move=10 ticks, DoorOpen=10 ticks, DoorClose=4 ticks\n")
    summary.append("State Distribution:")
    for st_name, count in state_counts.items():
        pct = (count / len(golden_results)) * 100
        summary.append(f"  - {st_name:12s}: {count:5d} cycles ({pct:5.2f}%)")

    summary.append("\nFirst 10 cycles sample:")
    for c in range(min(10, len(golden_results))):
        rst_n, req, ds, em, cmt = vectors[c]
        out = golden_results[c]
        st_name = ElevatorState.NAME_MAP[out["state"]]
        summary.append(f"  Cycle {c:3d}: rst={rst_n} req={req:04b} -> Floor={out['current_floor']+1} State={st_name:10s} Door={out['door_open']} Dir={out['direction']}")

    summary_text = "\n".join(summary)
    print("\n" + summary_text)

    with open(summary_report_path, "w", encoding="utf-8") as f_sum:
        f_sum.write(summary_text + "\n")

    print(f"\n[INFO] Summary saved to '{summary_report_path}'")
    print("=========================================================================")

if __name__ == "__main__":
    main()
