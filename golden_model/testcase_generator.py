"""
Testcase Generator for Elevator Controller (FAP201 Project)
Author: FAP201 Student
Description:
    Generates deterministic directed scenarios and randomized stress test vectors.
    Outputs stimulus file for RTL testbench and Golden Model.
"""

import random

class TestcaseGenerator:
    def __init__(self, seed=42):
        random.seed(seed)
        self.vectors = []  # List of tuples: (rst_n, req_btn, door_sensor, emergency_btn, comment)

    def add_step(self, rst_n=1, req_btn=0, door_sensor=0, emergency_btn=0, comment=""):
        self.vectors.append((rst_n, req_btn, door_sensor, emergency_btn, comment))

    def idle_cycles(self, n=5, comment="Idle"):
        for i in range(n):
            self.add_step(rst_n=1, req_btn=0, door_sensor=0, emergency_btn=0, comment=f"{comment} (cycle {i+1}/{n})")

    def generate_all(self):
        """Build full test suite with multiple comprehensive scenarios"""
        self.vectors.clear()

        # =========================================================================
        # Scenario 1: Initial Reset
        # =========================================================================
        for _ in range(5):
            self.add_step(rst_n=0, req_btn=0, door_sensor=0, emergency_btn=0, comment="Apply Active-Low Reset")
        self.idle_cycles(5, comment="Post-Reset Stabilization")

        # =========================================================================
        # Scenario 2: Single floor call from F1 to F3
        # =========================================================================
        # Press button for Floor 3 (bit 2 -> 4) for 2 cycles
        self.add_step(rst_n=1, req_btn=4, comment="Press button for Floor 3")
        self.add_step(rst_n=1, req_btn=4, comment="Hold button Floor 3")
        # Wait for travel: F1 -> F2 (10 ticks) -> F3 (10 ticks) + Door Open (10 ticks) + Door Close (4 ticks) + margin
        self.idle_cycles(35, comment="Wait travel F1 -> F3 and door cycle")

        # =========================================================================
        # Scenario 3: Call current floor (F3) while IDLE
        # =========================================================================
        self.add_step(rst_n=1, req_btn=4, comment="Press button for current Floor 3 (Instant Door Open)")
        self.idle_cycles(20, comment="Wait door open/close at Floor 3")

        # =========================================================================
        # Scenario 4: Multiple calls in same direction (LOOK algorithm: F3 to F1 and F2)
        # Elevator is at F3. Calls come in for F1 (bit 0=1) and F2 (bit 1=2)
        # =========================================================================
        self.add_step(rst_n=1, req_btn=1 | 2, comment="Call Floor 1 & Floor 2 simultaneously while at F3")
        # Should stop at F2 first, open/close door, then go down to F1, open/close door
        self.idle_cycles(45, comment="Wait elevator serve F2 then F1")

        # =========================================================================
        # Scenario 5: Multiple calls going UP (From F1 to F2, F3, F4)
        # =========================================================================
        self.add_step(rst_n=1, req_btn=2 | 4 | 8, comment="At F1, request F2, F3, and F4")
        self.idle_cycles(70, comment="Wait elevator serve F2, F3, then F4 in sequence")

        # =========================================================================
        # Scenario 6: Safety Obstacle Detection (Anti-Pinch Door Sensor)
        # At F4, call F4 to open door, then trigger door_sensor when closing
        # =========================================================================
        self.add_step(rst_n=1, req_btn=8, comment="At F4, open door")
        self.idle_cycles(10, comment="Wait door open time")
        # During door close (after 10 open ticks), trigger obstacle sensor
        self.idle_cycles(2, comment="Door begins closing")
        self.add_step(rst_n=1, req_btn=0, door_sensor=1, comment="OBSTACLE DETECTED! Sensor active")
        self.add_step(rst_n=1, req_btn=0, door_sensor=1, comment="Hold obstacle sensor")
        self.idle_cycles(25, comment="Wait door re-open and safely close after obstacle removed")

        # =========================================================================
        # Scenario 7: Emergency Stop Button
        # Request F1 while at F4 -> While moving down, press emergency button
        # =========================================================================
        self.add_step(rst_n=1, req_btn=1, comment="Request F1 while at F4")
        self.idle_cycles(6, comment="Moving down...")
        self.add_step(rst_n=1, req_btn=0, emergency_btn=1, comment="EMERGENCY STOP PRESSED!")
        self.add_step(rst_n=1, req_btn=0, emergency_btn=1, comment="Hold emergency stop")
        self.idle_cycles(15, comment="In emergency state")
        self.add_step(rst_n=1, req_btn=0, emergency_btn=0, comment="Release emergency stop")
        self.idle_cycles(10, comment="System returns to normal IDLE")

        # =========================================================================
        # Scenario 8: Randomized Stress Testing (250 random cycles)
        # =========================================================================
        for i in range(250):
            # 8% chance to press a random floor button
            rand_btn = 0
            if random.random() < 0.08:
                rand_btn = 1 << random.randint(0, 3)

            # 2% chance to trigger obstacle sensor
            rand_sensor = 1 if random.random() < 0.02 else 0

            # 1% chance to tap emergency button
            rand_emerg = 1 if random.random() < 0.01 else 0

            self.add_step(rst_n=1, req_btn=rand_btn, door_sensor=rand_sensor,
                          emergency_btn=rand_emerg, comment=f"Random Stress cycle {i+1}")

        # Finish simulation with idle drain cycles
        self.idle_cycles(40, comment="Final idle drain cycles to complete pending movements")

        return self.vectors

    def export_stimulus_file(self, filepath):
        """Write test vectors to stimulus.txt for RTL testbench ($fscanf)"""
        with open(filepath, "w") as f:
            f.write("# Format: <rst_n> <req_btn[3:0]> <door_sensor> <emergency_btn>\n")
            for rst_n, req_btn, door_sensor, emergency_btn, _ in self.vectors:
                f.write(f"{rst_n} {req_btn} {door_sensor} {emergency_btn}\n")
        print(f"[SUCCESS] Exported {len(self.vectors)} stimulus vectors to '{filepath}'")
