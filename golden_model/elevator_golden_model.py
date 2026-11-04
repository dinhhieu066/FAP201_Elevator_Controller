"""
Elevator Controller Golden Model (FAP201 Project)
Author: FAP201 Student
Description:
    Cycle-accurate behavioral Golden Model of a 4-Floor Elevator Controller.
    Implements the LOOK/SCAN elevator scheduling algorithm, door control,
    obstacle safety detection, and emergency stop features.
"""

class ElevatorState:
    IDLE         = 0  # 3'b000: Stopped at floor, door closed, waiting
    MOVING_UP    = 1  # 3'b001: Elevator traveling upwards
    MOVING_DOWN  = 2  # 3'b010: Elevator traveling downwards
    DOOR_OPEN    = 3  # 3'b011: Door is fully open at floor
    DOOR_CLOSING = 4  # 3'b100: Door is closing
    EMERGENCY    = 5  # 3'b101: Emergency stop active

    NAME_MAP = {
        0: "IDLE",
        1: "MOVING_UP",
        2: "MOVING_DOWN",
        3: "DOOR_OPEN",
        4: "DOOR_CLOSING",
        5: "EMERGENCY"
    }

class Direction:
    IDLE = 0  # 2'b00
    UP   = 1  # 2'b01
    DOWN = 2  # 2'b10

class ElevatorGoldenModel:
    def __init__(self, num_floors=4, move_ticks=10, door_open_ticks=10, door_close_ticks=4):
        self.num_floors = num_floors
        self.move_ticks = move_ticks
        self.door_open_ticks = door_open_ticks
        self.door_close_ticks = door_close_ticks

        self.reset()

    def reset(self):
        """Reset elevator to default initial state (Floor 1, IDLE, door closed)"""
        self.current_floor = 0        # 0 = Floor 1, 1 = Floor 2, 2 = Floor 3, 3 = Floor 4
        self.state = ElevatorState.IDLE
        self.direction = Direction.IDLE
        self.door_open = 0            # 0: Closed, 1: Open
        self.pending_requests = [False] * self.num_floors
        self.timer = 0
        self.target_floor = 0

    def _has_requests_above(self, floor):
        """Check if any floor above the specified floor has a pending request"""
        return any(self.pending_requests[f] for f in range(floor + 1, self.num_floors))

    def _has_requests_below(self, floor):
        """Check if any floor below the specified floor has a pending request"""
        return any(self.pending_requests[f] for f in range(0, floor))

    def _decide_direction_from_idle(self):
        """Decide next action when elevator is in IDLE state"""
        # If request at current floor
        if self.pending_requests[self.current_floor]:
            return ElevatorState.DOOR_OPEN, Direction.IDLE
        
        # Check requests above
        if self._has_requests_above(self.current_floor):
            return ElevatorState.MOVING_UP, Direction.UP
        
        # Check requests below
        if self._has_requests_below(self.current_floor):
            return ElevatorState.MOVING_DOWN, Direction.DOWN

        return ElevatorState.IDLE, Direction.IDLE

    def step(self, req_btn, door_sensor, emergency_btn, rst_n):
        """
        Execute one clock cycle.
        
        Inputs:
            req_btn (int): 4-bit integer bitmask of floor request buttons (bit 0=F1, bit 1=F2, ...)
            door_sensor (int): 1 if obstacle detected while door closing
            emergency_btn (int): 1 if emergency stop pressed
            rst_n (int): Active-low synchronous reset
            
        Returns:
            dict containing output signals matching RTL outputs
        """
        if rst_n == 0:
            self.reset()
            return self.get_outputs()

        # Latch new incoming button requests
        for f in range(self.num_floors):
            if (req_btn >> f) & 1:
                self.pending_requests[f] = True

        # Handle Emergency Button
        if emergency_btn:
            self.state = ElevatorState.EMERGENCY
            self.door_open = 1
            self.direction = Direction.IDLE
            self.timer = 0
            # Clear requests during emergency for safety
            self.pending_requests = [False] * self.num_floors
            return self.get_outputs()

        # State Machine Transition Logic
        if self.state == ElevatorState.EMERGENCY:
            # Remain in emergency until reset or emergency released
            if not emergency_btn:
                self.state = ElevatorState.IDLE
                self.door_open = 0
                self.timer = 0

        elif self.state == ElevatorState.IDLE:
            self.door_open = 0
            self.timer = 0
            next_state, next_dir = self._decide_direction_from_idle()
            self.state = next_state
            self.direction = next_dir
            if self.state == ElevatorState.DOOR_OPEN:
                self.pending_requests[self.current_floor] = False
                self.timer = 0

        elif self.state == ElevatorState.MOVING_UP:
            self.door_open = 0
            self.direction = Direction.UP
            if self.timer < self.move_ticks - 1:
                self.timer += 1
            else:
                # Arrived at next floor above
                self.current_floor += 1
                self.timer = 0
                
                # Check if current floor needs service
                if self.pending_requests[self.current_floor]:
                    self.pending_requests[self.current_floor] = False
                    self.state = ElevatorState.DOOR_OPEN
                elif not self._has_requests_above(self.current_floor):
                    # No more calls above
                    if self._has_requests_below(self.current_floor):
                        self.state = ElevatorState.MOVING_DOWN
                        self.direction = Direction.DOWN
                    else:
                        self.state = ElevatorState.IDLE
                        self.direction = Direction.IDLE
                # else continues MOVING_UP

        elif self.state == ElevatorState.MOVING_DOWN:
            self.door_open = 0
            self.direction = Direction.DOWN
            if self.timer < self.move_ticks - 1:
                self.timer += 1
            else:
                # Arrived at next floor below
                self.current_floor -= 1
                self.timer = 0
                
                # Check if current floor needs service
                if self.pending_requests[self.current_floor]:
                    self.pending_requests[self.current_floor] = False
                    self.state = ElevatorState.DOOR_OPEN
                elif not self._has_requests_below(self.current_floor):
                    # No more calls below
                    if self._has_requests_above(self.current_floor):
                        self.state = ElevatorState.MOVING_UP
                        self.direction = Direction.UP
                    else:
                        self.state = ElevatorState.IDLE
                        self.direction = Direction.IDLE
                # else continues MOVING_DOWN

        elif self.state == ElevatorState.DOOR_OPEN:
            self.door_open = 1
            # Re-press current floor button resets door timer
            if (req_btn >> self.current_floor) & 1:
                self.timer = 0

            if self.timer < self.door_open_ticks - 1:
                self.timer += 1
            else:
                self.state = ElevatorState.DOOR_CLOSING
                self.timer = 0

        elif self.state == ElevatorState.DOOR_CLOSING:
            # Obstacle detected or current floor button pressed -> Re-open door immediately
            if door_sensor or ((req_btn >> self.current_floor) & 1):
                self.state = ElevatorState.DOOR_OPEN
                self.door_open = 1
                self.timer = 0
            else:
                if self.timer < self.door_close_ticks - 1:
                    self.timer += 1
                else:
                    # Door is now fully closed
                    self.door_open = 0
                    self.timer = 0
                    
                    # Decide next direction using LOOK algorithm
                    if self.direction == Direction.UP:
                        if self._has_requests_above(self.current_floor):
                            self.state = ElevatorState.MOVING_UP
                        elif self._has_requests_below(self.current_floor):
                            self.state = ElevatorState.MOVING_DOWN
                            self.direction = Direction.DOWN
                        else:
                            self.state = ElevatorState.IDLE
                            self.direction = Direction.IDLE
                    elif self.direction == Direction.DOWN:
                        if self._has_requests_below(self.current_floor):
                            self.state = ElevatorState.MOVING_DOWN
                        elif self._has_requests_above(self.current_floor):
                            self.state = ElevatorState.MOVING_UP
                            self.direction = Direction.UP
                        else:
                            self.state = ElevatorState.IDLE
                            self.direction = Direction.IDLE
                    else:
                        next_state, next_dir = self._decide_direction_from_idle()
                        self.state = next_state
                        self.direction = next_dir

        return self.get_outputs()

    def get_outputs(self):
        """Pack internal state into standard signal format matching RTL ports"""
        pending_mask = 0
        for f in range(self.num_floors):
            if self.pending_requests[f]:
                pending_mask |= (1 << f)

        return {
            "current_floor": self.current_floor, # 0..3 (representing F1..F4)
            "state": self.state,                 # 0..5 (ElevatorState enum)
            "door_open": self.door_open,         # 0 or 1
            "direction": self.direction,         # 0: IDLE, 1: UP, 2: DOWN
            "pending_req": pending_mask          # 4-bit mask
        }
