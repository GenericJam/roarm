# Roarm

An Elixir library for controlling Waveshare RoArm robot arms using Circuits.UART for serial communication. This library replicates the functionality of the official [Waveshare RoArm SDK](https://github.com/waveshareteam/waveshare_roarm_sdk) in idiomatic Elixir.

## Supported Hardware

This library is designed for the **Waveshare RoArm-M2-S** and compatible robot arms:

- **[RoArm-M2-S](https://www.waveshare.com/wiki/RoArm-M2-S)** - 4-DOF desktop robotic arm with ESP32 controller
- **RoArm-M2-Pro** - Enhanced version with improved servos
- **RoArm-M3** - 6-DOF model with wrist rotation
- **RoArm-M3-Pro** - Professional version with high-torque servos

**Key Features:**
- High-torque serial bus servos
- ESP32-based controller with dual USB-C ports
- Gripper with LED lighting
- 12V power supply (7-12.6V working range)
- Serial communication at 115200 baud

## Features

- **Serial Communication**: Full UART communication support using Circuits.UART
- **Robot Control**: Position and joint-based movement control
- **Hardware Features**: LED control, torque lock, and status monitoring
- **Concurrent Design**: GenServer-based architecture for reliable concurrent robot control
- **Multiple Models**: Support for RoArm-M2, RoArm-M2-Pro, RoArm-M3, and RoArm-M3-Pro
- **Interactive Demo**: Built-in demo and testing utilities

## Installation

Add `roarm` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:roarm, "~> 0.1.0"}
  ]
end
```

## Hardware Requirements

- Waveshare RoArm robot arm (M2/M3 series)
- USB-to-Serial adapter or direct serial connection
- Power supply for the robot arm

## Quick Start

```elixir
# Start a registry with the name of the module
{:ok, _} = Registry.start_link(keys: :unique, name: Roarm.Registry)
# Start the robot with your configuration
{:ok, _pid} = Roarm.start_robot(robot_type: :roarm_m2, port: "/dev/cu.usbserial-110", baudrate: 115200)

# Move to a specific position
Roarm.Robot.move_to_position(%{x: 100.0, y: 0.0, z: 150.0, t: 0.0})

# Control individual joints with convenience functions
Roarm.Robot.move_base(45.0)      # Move base joint to 45 degrees
Roarm.Robot.move_shoulder(-30.0) # Move shoulder joint to -30 degrees
Roarm.Robot.move_elbow(90.0)     # Move elbow joint to 90 degrees
Roarm.Robot.move_wrist(0.0)      # Move wrist joint to 0 degrees

# Control RGB LED color (0-255)
Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})

# Control gripper-mounted LED brightness
Roarm.Robot.led_on(200)  # Set brightness to 200/255

# Return to home position
Roarm.Robot.home()

# Enable/disable torque lock
Roarm.Robot.set_torque_lock(true)
```

## Complete API Reference

The RoArm protocol uses JSON commands where **"T"** represents the **Type** of command. All commands can be sent using `Roarm.Robot.send_custom_command/1` for maximum flexibility.

### Movement Commands

- **Home Position** (T:100)
  - **Purpose**: Move robot to initialization/home position
  - **Variables**: None required
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: `Roarm.Robot.home()`
  - **JSON Examples**:
    ```json
    {"T": 100}
    ```

- **Direct Position Control** (T:1041)
  - **Purpose**: Move robot end effector to specific coordinates
  - **Variables**:
    - `x` - X-coordinate in millimeters (-500.0 to +500.0)
    - `y` - Y-coordinate in millimeters (-500.0 to +500.0)
    - `z` - Z-coordinate in millimeters (0.0 to +500.0)
    - `t` - Tool angle in degrees (-180.0 to +180.0, default: 0.0)
    - `spd` - Movement speed (1 to 4096, default: 1000)
    - `acc` - Acceleration (1 to 254, default: 100)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: `Roarm.Robot.move_to_position/1`
  - **JSON Examples**:
    ```json
    {"T": 1041, "x": -500.0, "y": -500.0, "z": 0.0, "t": -180.0, "spd": 1, "acc": 1}
    {"T": 1041, "x": 200.0, "y": 100.0, "z": 150.0, "t": 0.0, "spd": 1000, "acc": 100}
    {"T": 1041, "x": 500.0, "y": 500.0, "z": 500.0, "t": 180.0, "spd": 4096, "acc": 254}
    ```

- **Single Joint Control (Degrees)** (T:121)
  - **Purpose**: Control individual joint in degrees
  - **Variables**:
    - `joint` - Joint number (1-4 for M2, 1-6 for M3)
    - `angle` - Target angle in degrees (-180 to +180)
    - `spd` - Movement speed (1 to 4096, default: 1000)
  - **Joint Mapping**: 1=Base, 2=Shoulder, 3=Elbow, 4=Wrist, 5=Wrist-X (M3), 6=Wrist-Y (M3)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Functions**: `Roarm.Robot.move_joint/3`, `Roarm.Robot.move_base/2`, `Roarm.Robot.move_shoulder/2`, `Roarm.Robot.move_elbow/2`, `Roarm.Robot.move_wrist/2`, `Roarm.Robot.move_wrist_x/2`, `Roarm.Robot.move_wrist_y/2`
  - **JSON Examples**:
    ```json
    {"T": 121, "joint": 1, "angle": -180, "spd": 1}
    {"T": 121, "joint": 2, "angle": 45, "spd": 1000}
    {"T": 121, "joint": 4, "angle": 180, "spd": 4096}
    ```

- **All Joints Control (Degrees)** (T:122)
  - **Purpose**: Control multiple joints simultaneously in degrees
  - **Variables**:
    - `b` - Base joint angle in degrees (-180.0 to +180.0, default: 0.0)
    - `s` - Shoulder joint angle in degrees (-180.0 to +180.0, default: 0.0)
    - `e` - Elbow joint angle in degrees (-180.0 to +180.0, default: 0.0)
    - `h` - Hand/Wrist joint angle in degrees (-180.0 to +180.0, default: 0.0)
    - `w` - Wrist joint angle in degrees, M3 only (-180.0 to +180.0, default: 0.0)
    - `g` - Gripper joint angle in degrees, M3 only (-180.0 to +180.0, default: 0.0)
    - `spd` - Movement speed (1 to 4096, default: 1000)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: `Roarm.Robot.move_joints/1`
  - **JSON Examples**:
    ```json
    {"T": 122, "b": -180.0, "s": -180.0, "e": -180.0, "h": -180.0, "spd": 1}
    {"T": 122, "b": 30.0, "s": 45.0, "e": -30.0, "h": 15.0, "spd": 1000}
    {"T": 122, "b": 180.0, "s": 180.0, "e": 180.0, "h": 180.0, "w": 180.0, "g": 180.0, "spd": 4096}
    ```

- **Single Joint Control (Radians)** (T:101)
  - **Purpose**: Control individual joint in radians
  - **Variables**:
    - `joint` - Joint number (1 to 6)
    - `radian` - Target angle in radians (-3.14159 to +3.14159)
    - `spd` - Movement speed (1 to 4096, default: 1000)
  - **Joint Mapping**: 1=Base, 2=Shoulder, 3=Elbow, 4=Wrist, 5=Wrist-X (M3), 6=Wrist-Y (M3)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 101, "joint": 1, "radian": -3.14159, "spd": 1}
    {"T": 101, "joint": 2, "radian": 0.785, "spd": 1000}
    {"T": 101, "joint": 6, "radian": 3.14159, "spd": 4096}
    ```

- **All Joints Control (Radians)** (T:102)
  - **Purpose**: Control multiple joints simultaneously in radians
  - **Variables**:
    - `b` - Base joint angle in radians (-3.14159 to +3.14159, default: 0.0)
    - `s` - Shoulder joint angle in radians (-3.14159 to +3.14159, default: 0.0)
    - `e` - Elbow joint angle in radians (-3.14159 to +3.14159, default: 0.0)
    - `h` - Hand/Wrist joint angle in radians (-3.14159 to +3.14159, default: 0.0)
    - `w` - Wrist joint angle in radians, M3 only (-3.14159 to +3.14159, default: 0.0)
    - `g` - Gripper joint angle in radians, M3 only (-3.14159 to +3.14159, default: 0.0)
    - `spd` - Movement speed (1 to 4096, default: 1000)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 102, "b": -3.14159, "s": -3.14159, "e": -3.14159, "h": -3.14159, "spd": 1}
    {"T": 102, "b": 0.5, "s": 0.8, "e": -0.5, "h": 0.0, "spd": 1000}
    {"T": 102, "b": 3.14159, "s": 3.14159, "e": 3.14159, "h": 3.14159, "w": 3.14159, "g": 3.14159, "spd": 4096}
    ```

- **Pose Control with Orientation** (T:104)
  - **Purpose**: Control position with full 6DOF orientation (M3 only)
  - **Variables**:
    - `x` - X-coordinate in millimeters (-500 to +500)
    - `y` - Y-coordinate in millimeters (-500 to +500)
    - `z` - Z-coordinate in millimeters (0 to +500)
    - `roll` - Roll rotation in radians (-π to +π)
    - `pitch` - Pitch rotation in radians (-π to +π)
    - `yaw` - Yaw rotation in radians (-π to +π)
  - **Supported Models**: M3, M3-Pro only
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 104, "x": -500, "y": -500, "z": 0, "roll": -3.14, "pitch": -3.14, "yaw": -3.14}
    {"T": 104, "x": 200, "y": 100, "z": 150, "roll": 0, "pitch": 0, "yaw": 0}
    {"T": 104, "x": 500, "y": 500, "z": 500, "roll": 3.14, "pitch": 3.14, "yaw": 3.14}
    ```

- **Set Middle Position** (T:502)
  - **Purpose**: Move all joints to their middle/neutral positions
  - **Variables**: None required
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 502}
    ```

### System Control Commands

- **Get Current Position/Status** (T:105)
  - **Purpose**: Query robot's current position, joint angles, and status
  - **Variables**: None required
  - **Returns**: Position data including joints and coordinates
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Functions**: `Roarm.Robot.get_position/0`, `Roarm.Robot.get_joints/0`
  - **JSON Examples**:
    ```json
    {"T": 105}
    ```

- **Torque Control** (T:210)
  - **Purpose**: Enable or disable joint torque (lock/unlock joints)
  - **Variables**:
    - `cmd` - Command (0=disable torque/free movement, 1=enable torque/lock joints)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Functions**: `Roarm.Robot.set_torque_enabled/1`, `Roarm.Robot.set_torque_lock/1`
  - **JSON Examples**:
    ```json
    {"T": 210, "cmd": 0}
    {"T": 210, "cmd": 1}
    ```

- **Dynamic External Force Adaptation** (T:112)
  - **Purpose**: Enable adaptive torque control for external force handling
  - **Variables**:
    - `mode` - Operation mode (0=disable, 1=enable)
    - `b` - Base joint force threshold (0 to 1000, default: 500)
    - `s` - Shoulder joint force threshold (0 to 1000, default: 500)
    - `e` - Elbow joint force threshold (0 to 1000, default: 500)
    - `h` - Wrist joint force threshold (0 to 1000, default: 500)
    - `w` - Additional joint force threshold (0 to 1000, default: 500)
    - `g` - Additional joint force threshold (0 to 1000, default: 500)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 112, "mode": 0}
    {"T": 112, "mode": 1, "b": 0, "s": 0, "e": 0, "h": 0, "w": 0, "g": 0}
    {"T": 112, "mode": 1, "b": 1000, "s": 1000, "e": 1000, "h": 1000, "w": 1000, "g": 1000}
    ```

- **Command Echo Control** (T:605)
  - **Purpose**: Enable or disable command echo responses
  - **Variables**:
    - `echo` - Echo setting (0=disable, 1=enable)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 605, "echo": 0}
    {"T": 605, "echo": 1}
    ```

### LED and Hardware Control Commands

- **LED Control** (T:114)
  - **Purpose**: Control gripper-mounted LED brightness or RGB color
  - **Variables**:
    - `led` - LED brightness (0 to 255, default: 255)
    - `r` - Red component (0 to 255, default: 0)
    - `g` - Green component (0 to 255, default: 0)
    - `b` - Blue component (0 to 255, default: 0)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Functions**: `Roarm.Robot.led_on/1`, `Roarm.Robot.led_off/0`, `Roarm.Robot.set_led/1`
  - **JSON Examples**:
    ```json
    {"T": 114, "led": 0, "r": 0, "g": 0, "b": 0}
    {"T": 114, "led": 128, "r": 128, "g": 128, "b": 128}
    {"T": 114, "led": 255, "r": 255, "g": 0, "b": 0}
    {"T": 114, "led": 255, "r": 0, "g": 255, "b": 0}
    {"T": 114, "led": 255, "r": 255, "g": 255, "b": 255}
    ```

- **Gripper Control (M3 Models)** (T:222)
  - **Purpose**: Control gripper opening/closing on M3 models
  - **Variables**:
    - `mode` - Gripper mode (0=position mode, 1=force mode)
    - `angle` - Gripper angle/force (0 to 100, 0=closed/min force, 100=open/max force)
  - **Supported Models**: M3, M3-Pro only
  - **Elixir Functions**: `Roarm.Robot.gripper_control/1`, `Roarm.Robot.gripper_open/0`, `Roarm.Robot.gripper_close/0`
  - **JSON Examples**:
    ```json
    {"T": 222, "mode": 0, "angle": 0}
    {"T": 222, "mode": 0, "angle": 50}
    {"T": 222, "mode": 1, "angle": 100}
    ```

### PID Control Commands

- **Set Joint PID Parameters** (T:108)
  - **Purpose**: Configure PID control parameters for specific joint
  - **Variables**:
    - `joint` - Joint number (1-4 for M2, 1-6 for M3)
    - `p` - Proportional gain (0 to 100)
    - `i` - Integral gain (0 to 100)
    - `d` - Derivative gain (0 to 100)
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 108, "joint": 1, "p": 0, "i": 0, "d": 0}
    {"T": 108, "joint": 2, "p": 16, "i": 0, "d": 1}
    {"T": 108, "joint": 4, "p": 100, "i": 100, "d": 100}
    ```

- **Reset PID to Defaults** (T:109)
  - **Purpose**: Reset all PID parameters to factory defaults
  - **Variables**: None required
  - **Supported Models**: M2, M3, M2-Pro, M3-Pro
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 109}
    ```

### Mission and Task Commands

- **Create Mission** (T:220)
  - **Purpose**: Create a new mission file for recording sequences
  - **Variables**:
    - `name` - Mission name (string, any length)
    - `intro` - Mission description (string, optional)
  - **Supported Models**: M2-S, M3 (models with flash storage)
  - **Elixir Function**: `Roarm.Robot.create_mission/2`
  - **JSON Examples**:
    ```json
    {"T": 220, "name": "", "intro": ""}
    {"T": 220, "name": "demo", "intro": "Demo mission"}
    {"T": 220, "name": "pick_and_place_sequence", "intro": "Complex pick and place operation with multiple waypoints"}
    ```

- **Append JSON Command to Mission** (T:222)
  - **Purpose**: Add a custom JSON command to existing mission
  - **Variables**:
    - `mission` - Mission name (string)
    - `command` - JSON command to add (string)
  - **Supported Models**: M2-S, M3 (models with flash storage)
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 222, "mission": "demo", "command": "{\"T\": 100}"}
    {"T": 222, "mission": "demo", "command": "{\"T\": 122, \"b\": 45, \"s\": 30, \"e\": -15, \"h\": 0}"}
    ```

- **Append Current Position to Mission** (T:223)
  - **Purpose**: Record current robot position as mission step
  - **Variables**:
    - `mission` - Mission name (string, required)
    - `spd` - Movement speed for this step (0.1 to 1.0, default: 0.25)
  - **Supported Models**: M2-S, M3 (models with flash storage)
  - **Elixir Function**: `Roarm.Robot.add_mission_step/2`
  - **JSON Examples**:
    ```json
    {"T": 223, "mission": "demo", "spd": 0.1}
    {"T": 223, "mission": "demo", "spd": 0.25}
    {"T": 223, "mission": "demo", "spd": 1.0}
    ```

- **Append Delay to Mission** (T:224)
  - **Purpose**: Add a pause/delay to mission sequence
  - **Variables**:
    - `mission` - Mission name (string)
    - `delay` - Delay duration in milliseconds (0 to 60000)
  - **Supported Models**: M2-S, M3 (models with flash storage)
  - **Elixir Function**: `Roarm.Robot.add_mission_delay/2`
  - **JSON Examples**:
    ```json
    {"T": 224, "mission": "demo", "delay": 0}
    {"T": 224, "mission": "demo", "delay": 2000}
    {"T": 224, "mission": "demo", "delay": 60000}
    ```

- **Play Mission** (T:242)
  - **Purpose**: Execute a recorded mission sequence
  - **Variables**:
    - `name` - Mission name (string, required)
    - `times` - Number of repetitions (1 to 1000, default: 1)
  - **Supported Models**: M2-S, M3 (models with flash storage)
  - **Elixir Function**: `Roarm.Robot.play_mission/2`
  - **JSON Examples**:
    ```json
    {"T": 242, "name": "demo", "times": 1}
    {"T": 242, "name": "demo", "times": 5}
    {"T": 242, "name": "demo", "times": 1000}
    ```

### File System Commands

- **Scan Files** (T:200)
  - **Purpose**: List all files stored in robot's flash memory
  - **Variables**: None required
  - **Returns**: List of stored files
  - **Supported Models**: M2-S, M3 (models with flash storage)
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 200}
    ```

- **Create File** (T:201)
  - **Purpose**: Create new file in robot's flash memory
  - **Variables**:
    - `name` - File name (string)
    - `content` - File content (string)
  - **Supported Models**: M2-S, M3 (models with flash storage)
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 201, "name": "", "content": ""}
    {"T": 201, "name": "config.txt", "content": "robot_config_data"}
    {"T": 201, "name": "very_long_filename_with_lots_of_content.json", "content": "extensive file content with lots of data and configuration parameters"}
    ```

### WiFi Configuration Commands

- **WiFi Boot Mode** (T:401)
  - **Purpose**: Set WiFi mode on robot startup
  - **Variables**:
    - `mode` - WiFi mode (0=off, 1=STA, 2=AP, 3=STA+AP)
  - **Supported Models**: M2-S, M3 (models with WiFi)
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 401, "mode": 0}
    {"T": 401, "mode": 1}
    {"T": 401, "mode": 2}
    {"T": 401, "mode": 3}
    ```

- **Configure Access Point** (T:402)
  - **Purpose**: Set robot as WiFi access point
  - **Variables**:
    - `ssid` - Access point name (string)
    - `password` - Access point password (string, minimum 8 characters)
  - **Supported Models**: M2-S, M3 (models with WiFi)
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 402, "ssid": "", "password": ""}
    {"T": 402, "ssid": "RoARM_AP", "password": "12345678"}
    {"T": 402, "ssid": "MyRobotAccessPoint", "password": "very_secure_password_123"}
    ```

- **Configure Station Mode** (T:403)
  - **Purpose**: Connect robot to existing WiFi network
  - **Variables**:
    - `ssid` - Network name (string)
    - `password` - Network password (string)
  - **Supported Models**: M2-S, M3 (models with WiFi)
  - **Elixir Function**: None (use `send_custom_command/1`)
  - **JSON Examples**:
    ```json
    {"T": 403, "ssid": "", "password": ""}
    {"T": 403, "ssid": "HomeWiFi", "password": "wifipassword"}
    {"T": 403, "ssid": "CorporateNetwork_5GHz", "password": "complex_enterprise_password_123"}
    ```

## Robot Model Differences

- **RoArm-M2**: 4 joints (base, shoulder, elbow, hand/wrist), gripper controlled via joint 4
- **RoArm-M2-Pro**: Enhanced M2 with improved servos and precision
- **RoArm-M2-S**: M2 with flash storage for missions and file operations
- **RoArm-M3**: 6 joints (base, shoulder, elbow, hand, wrist, gripper), dedicated gripper control
- **RoArm-M3-Pro**: Enhanced M3 with high-torque servos and improved precision

### Joint Layout Reference

#### RoArm-M2 (4-DOF)
```
     [4] Hand/Wrist + Gripper
            |
        [3] Elbow
            |
       [2] Shoulder
            |
        [1] Base (rotates entire arm)
```

#### RoArm-M3 (6-DOF)
```
      [6] Gripper
          |
       [5] Wrist
          |
       [4] Hand
          |
      [3] Elbow
          |
     [2] Shoulder
          |
      [1] Base (rotates entire arm)
```

## Convenience Functions

The library provides semantic convenience functions that map to the underlying joint numbers:

```elixir
# Instead of remembering joint numbers:
Roarm.Robot.move_joint(1, 45.0)    # Base
Roarm.Robot.move_joint(2, -30.0)   # Shoulder
Roarm.Robot.move_joint(3, 90.0)    # Elbow
Roarm.Robot.move_joint(4, 0.0)     # Wrist

# Use semantic names:
Roarm.Robot.move_base(45.0)        # Joint 1
Roarm.Robot.move_shoulder(-30.0)   # Joint 2
Roarm.Robot.move_elbow(90.0)       # Joint 3
Roarm.Robot.move_wrist(0.0)        # Joint 4

# Extended models (M3):
Roarm.Robot.move_wrist_x(15.0)     # Joint 5
Roarm.Robot.move_wrist_y(-20.0)    # Joint 6
```

## Common Usage Examples

### Basic Movement Sequence
```elixir
# Start from home
Roarm.Robot.home()

# Move to pickup position
Roarm.Robot.move_to_position(%{x: 150, y: 100, z: 100, t: 0})

# Close gripper (works for all models)
Roarm.Robot.gripper_close()

# Lift object
Roarm.Robot.move_to_position(%{x: 150, y: 100, z: 200, t: 0})

# Move to drop location
Roarm.Robot.move_to_position(%{x: 200, y: 200, z: 100, t: 0})

# Release object
Roarm.Robot.gripper_open()

# Return home
Roarm.Robot.home()
```

### Custom Command Examples
```elixir
# Slow precise movement
Roarm.Robot.send_custom_command(~s({"T": 122, "b": 45, "s": 30, "e": -15, "h": 0, "spd": 500}))

# Maximum speed movement
Roarm.Robot.send_custom_command(~s({"T": 121, "joint": 1, "angle": 90, "spd": 4096}))

# Enable force adaptation
Roarm.Robot.send_custom_command(~s({"T": 112, "mode": 1, "b": 60, "s": 110, "e": 50, "h": 50}))

# Create and play a mission
Roarm.Robot.send_custom_command(~s({"T": 220, "name": "test", "intro": "Test sequence"}))
Roarm.Robot.send_custom_command(~s({"T": 223, "mission": "test", "spd": 0.5}))
Roarm.Robot.send_custom_command(~s({"T": 242, "name": "test", "times": 3}))
```

## Interactive Demo

Run the interactive demo to test your robot setup:

```elixir
# Start the interactive demo
Roarm.Demo.interactive_demo()

# Or run specific tests
Roarm.Demo.test_connection("/dev/ttyUSB0")
Roarm.Demo.full_test_suite("/dev/ttyUSB0")
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/roarm>.