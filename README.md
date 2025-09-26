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

# Control individual joints
Roarm.Robot.move_joints(%{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0})

# Control RGB LED color (0-255)
Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})

# Control gripper-mounted LED brightness
Roarm.Robot.led_on(200)  # Set brightness to 200/255

# Return to home position
Roarm.Robot.home()

# Enable/disable torque lock
Roarm.Robot.set_torque_lock(true)
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

## Complete Command Reference

### Command Type Overview

The RoArm protocol uses JSON commands where **"T"** represents the **Type** of command. Here's the complete reference of all command types:

| Type | Command Name | Category | Description |
|------|--------------|----------|-------------|
| **100** | `CMD_HOME` | Movement | Move to home/initialization position |
| **101** | `CMD_JOINT_RADIAN_CTRL` | Movement | Control single joint in radians |
| **102** | `CMD_JOINTS_RADIAN_CTRL` | Movement | Control all joints in radians |
| **104** | `CMD_POSE_CTRL` | Movement | Pose control with orientation (M3) |
| **105** | `CMD_FEEDBACK_GET` | System | Get current position and status |
| **108** | `CMD_SET_JOINT_PID` | Control | Set PID parameters for joint |
| **109** | `CMD_RESET_PID` | Control | Reset PID parameters to defaults |
| **112** | `CMD_DYNAMIC_ADAPTATION` | Control | Dynamic External Force Adaptation (DEFA) |
| **114** | `CMD_LED_CTRL` | Hardware | LED/Gripper control |
| **121** | `CMD_JOINT_ANGLE_CTRL` | Movement | Control single joint in degrees |
| **122** | `CMD_JOINTS_ANGLE_CTRL` | Movement | Control all joints in degrees |
| **200** | `CMD_SCAN_FILES` | FileSystem | List files in flash memory |
| **201** | `CMD_CREATE_FILE` | FileSystem | Create new file in flash |
| **210** | `CMD_TORQUE_CTRL` | Control | Enable/disable torque lock |
| **220** | `CMD_CREATE_MISSION` | Mission | Create new mission file |
| **222** | `CMD_APPEND_STEP_JSON` | Mission | Add JSON command to mission |
| **222** | `CMD_GRIPPER_MODE_SET` | Hardware | Gripper control (M3 only) |
| **223** | `CMD_APPEND_STEP_FB` | Mission | Add current position to mission |
| **224** | `CMD_APPEND_DELAY` | Mission | Add delay to mission |
| **242** | `CMD_MISSION_PLAY` | Mission | Play/execute mission file |
| **401** | `CMD_WIFI_ON_BOOT` | WiFi | Set WiFi mode on boot |
| **402** | `CMD_WIFI_AP_SET` | WiFi | Configure Access Point settings |
| **403** | `CMD_WIFI_STA_SET` | WiFi | Configure Station mode settings |
| **502** | `CMD_MIDDLE_SET` | Movement | Set joints to middle position |
| **605** | `CMD_ECHO_SET` | System | Enable/disable command echo |
| **1041** | `CMD_XYZT_DIRECT_CTRL` | Movement | Direct position control |

### Command Categories

- **Movement** (100-122, 502, 1041): Joint and position control
- **Control** (108-112, 210): PID, torque, and force control
- **Hardware** (114, 222): LED and gripper control
- **System** (105, 605): Status and configuration
- **Mission** (220-242): Task recording and playback
- **FileSystem** (200-201): Flash memory operations
- **WiFi** (401-403): Wireless configuration

**Total Command Types: 25** (covering all robot functions)

### Parameter Reference

The RoArm protocol uses abbreviated parameter names. Here's the complete reference:

#### Joint Parameters
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`b`** | **Base** | Base joint (rotation around vertical axis) | -180° to +180° | degrees/radians |
| **`s`** | **Shoulder** | Shoulder joint (upper arm vertical movement) | -180° to +180° | degrees/radians |
| **`e`** | **Elbow** | Elbow joint (forearm bending) | -180° to +180° | degrees/radians |
| **`h`** | **Hand/Wrist** | Hand/wrist joint (end effector rotation) | -180° to +180° | degrees/radians |
| **`w`** | **Wrist** | Wrist joint (M3 only - additional rotation) | -180° to +180° | degrees/radians |
| **`g`** | **Gripper** | Gripper joint (M3 only - open/close) | 0.0 to 1.5 | radians |

#### Position Parameters
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`x`** | **X-Coordinate** | Left/right position | -500 to +500 | millimeters |
| **`y`** | **Y-Coordinate** | Forward/backward position | -500 to +500 | millimeters |
| **`z`** | **Z-Coordinate** | Up/down position | 0 to +500 | millimeters |
| **`t`** | **Tool/Theta** | Tool angle (end effector orientation) | -π to +π | radians |

#### Orientation Parameters (M3 Pose Control)
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`roll`** | **Roll** | Rotation around X-axis | -π to +π | radians |
| **`pitch`** | **Pitch** | Rotation around Y-axis | -π to +π | radians |
| **`yaw`** | **Yaw** | Rotation around Z-axis | -π to +π | radians |

#### Control Parameters
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`spd`** | **Speed** | Movement speed | 1-4096 | steps/second |
| **`acc`** | **Acceleration** | Movement acceleration | 1-254 | steps/s² |
| **`joint`** | **Joint ID** | Joint identifier for single joint control | 1-4 (M2), 1-6 (M3) | number |
| **`radian`** | **Radian** | Joint angle in radians | -π to +π | radians |
| **`angle`** | **Angle** | Joint angle in degrees | -180° to +180° | degrees |

#### System Parameters
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`mode`** | **Mode** | Operation mode (varies by command) | 0-3 | number |
| **`cmd`** | **Command** | Sub-command identifier | 0-1 | number |
| **`led`** | **LED** | LED brightness/gripper control | 0-255 | brightness |
| **`r`**, **`g`**, **`b`** | **Red, Green, Blue** | RGB color values | 0-255 | color value |

#### PID Parameters
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`p`** | **Proportional** | PID proportional gain | 0-100 | gain |
| **`i`** | **Integral** | PID integral gain | 0-100 | gain |
| **`d`** | **Derivative** | PID derivative gain | 0-100 | gain |

#### Mission Parameters
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`name`** | **Name** | Mission/file name | - | string |
| **`intro`** | **Introduction** | Mission description | - | string |
| **`delay`** | **Delay** | Pause duration | 0-60000 | milliseconds |
| **`times`** | **Times** | Repeat count | 1-∞ (-1=infinite) | number |
| **`loop`** | **Loop** | Loop count | 0-∞ (0=infinite) | number |

#### WiFi Parameters
| Parameter | Full Name | Description | Range | Units |
|-----------|-----------|-------------|--------|-------|
| **`ssid`** | **SSID** | Network name | - | string |
| **`password`** | **Password** | Network password | - | string |
| **`echo`** | **Echo** | Command echo enable/disable | 0-1 | boolean |

### Joint Layout Reference

#### RoArm-M2 (4-DOF)
```
     [h] Hand/Wrist
        |
    [e] Elbow
        |
   [s] Shoulder
        |
    [b] Base (rotates entire arm)
```

#### RoArm-M3 (5+1-DOF)
```
  [g] Gripper
      |
   [w] Wrist
      |
   [h] Hand
      |
  [e] Elbow
      |
 [s] Shoulder
      |
  [b] Base (rotates entire arm)
```

### 🤖 Movement Control Commands

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **1041** | `CMD_XYZT_DIRECT_CTRL` | Direct position control | `x`, `y`, `z`, `t`, `spd`, `acc` | M2, M3 |
| **101** | `CMD_JOINT_RADIAN_CTRL` | Single joint control (radians) | `joint`, `radian`, `spd` | M2, M3 |
| **102** | `CMD_JOINTS_RADIAN_CTRL` | All joints control (radians) | `b`, `s`, `e`, `h`, `w`, `g`, `spd` | M2, M3 |
| **121** | `CMD_JOINT_ANGLE_CTRL` | Single joint control (degrees) | `joint`, `angle`, `spd` | M2, M3 |
| **122** | `CMD_JOINTS_ANGLE_CTRL` | All joints control (degrees) | `b`, `s`, `e`, `h`, `w`, `g`, `spd` | M2, M3 |
| **104** | `CMD_POSE_CTRL` | Pose control with orientation | `x`, `y`, `z`, `roll`, `pitch`, `yaw` | M3 |

### ⚙️ System Control Commands

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **100** | `CMD_HOME` | Move to home position | None | M2, M3 |
| **105** | `CMD_FEEDBACK_GET` | Get current position/status | None | M2, M3 |
| **210** | `CMD_TORQUE_CTRL` | Enable/disable torque lock | `cmd` (0=off, 1=on) | M2, M3 |
| **112** | `CMD_DYNAMIC_ADAPTATION` | Dynamic force adaptation | `mode`, joint torque limits | M2, M3 |
| **502** | `CMD_MIDDLE_SET` | Set joints to middle position | None | M2, M3 |

### 🔧 End Effector & LED Commands

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **114** | `CMD_LED_CTRL` | LED/Gripper control | `led` (0-255) or `r`, `g`, `b` | M2, M3 |
| **222** | `CMD_GRIPPER_MODE_SET` | Gripper control (M3 only) | `mode`, `angle` | M3 |

### 🎯 Mission/Task Commands

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **220** | `CMD_CREATE_MISSION` | Create new mission file | `name`, `intro` | M2-S, M3 |
| **222** | `CMD_APPEND_STEP_JSON` | Add JSON command to mission | `mission`, `command` | M2-S, M3 |
| **223** | `CMD_APPEND_STEP_FB` | Add current position to mission | `mission`, `spd` | M2-S, M3 |
| **224** | `CMD_APPEND_DELAY` | Add delay to mission | `mission`, `delay` | M2-S, M3 |
| **242** | `CMD_MISSION_PLAY` | Play mission file | `mission`, `loop`, `times` | M2-S, M3 |

### ⚡ PID Control Commands

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **108** | `CMD_SET_JOINT_PID` | Set joint PID parameters | `joint`, `p`, `i`, `d` | M2, M3 |
| **109** | `CMD_RESET_PID` | Reset PID to defaults | None | M2, M3 |

### 📁 File System Commands

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **200** | `CMD_SCAN_FILES` | List files in flash memory | None | M2-S, M3 |
| **201** | `CMD_CREATE_FILE` | Create new file | `name`, `content` | M2-S, M3 |

### 📡 WiFi Configuration Commands

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **401** | `CMD_WIFI_ON_BOOT` | Set WiFi boot mode | `mode` (0-3) | M2-S, M3 |
| **402** | `CMD_WIFI_AP_SET` | Configure AP settings | `ssid`, `password` | M2-S, M3 |
| **403** | `CMD_WIFI_STA_SET` | Configure station settings | `ssid`, `password` | M2-S, M3 |

### 🔧 System Configuration

| T-Code | Command | Description | Parameters | Models |
|--------|---------|-------------|------------|--------|
| **605** | `CMD_ECHO_SET` | Enable/disable command echo | `echo` (0/1) | M2, M3 |

## Complete Command Examples

This section shows every available command with both the high-level Elixir function and the corresponding raw JSON command.

### 🤖 Basic Movement Commands

#### Home Position (T:100)
```elixir
# High-level function
Roarm.Robot.home()

# Raw command equivalent
Roarm.Robot.send_custom_command(~s({"T": 100}))
```

#### Joint Control in Degrees (T:122)
```elixir
# High-level function
Roarm.Robot.move_joints(%{j1: 30, j2: 45, j3: -30, j4: 15})

# Raw command equivalent
Roarm.Robot.send_custom_command(~s({"T": 122, "b": 30, "s": 45, "e": -30, "h": 15, "spd": 1000}))
```

#### Single Joint Control (T:121)
```elixir
# Raw command (no high-level function)
Roarm.Robot.send_custom_command(~s({"T": 121, "joint": 1, "angle": 45, "spd": 2000}))
# Moves joint 1 (base) to 45 degrees at speed 2000
```

#### Position Control (T:1041)
```elixir
# High-level function
Roarm.Robot.move_to_position(%{x: 200, y: 100, z: 150, t: 0})

# Raw command equivalent
Roarm.Robot.send_custom_command(~s({"T": 1041, "x": 200, "y": 100, "z": 150, "t": 0, "spd": 1000}))
```

#### Joint Control in Radians (T:102)
```elixir
# Raw command (no high-level function)
Roarm.Robot.send_custom_command(~s({"T": 102, "b": 0.5, "s": 0.8, "e": -0.5, "h": 0.0, "spd": 1000}))
# All joint positions in radians
```

### 📊 System Information Commands

#### Get Current Position/Status (T:105)
```elixir
# High-level function
{:ok, position} = Roarm.Robot.get_position()

# Raw command equivalent
Roarm.Robot.send_custom_command(~s({"T": 105}))
```

### ⚙️ System Control Commands

#### Torque Control (T:210)
```elixir
# High-level functions
Roarm.Robot.set_torque_enabled(false)  # Disable torque (free movement)
Roarm.Robot.set_torque_enabled(true)   # Enable torque (lock joints)

# Raw command equivalents
Roarm.Robot.send_custom_command(~s({"T": 210, "cmd": 0}))  # Disable
Roarm.Robot.send_custom_command(~s({"T": 210, "cmd": 1}))  # Enable
```

#### Set Middle Position (T:502)
```elixir
# Raw command (no high-level function)
Roarm.Robot.send_custom_command(~s({"T": 502}))
# Moves all joints to their middle positions
```

### 💡 LED Control Commands

#### LED Brightness Control (T:114)
```elixir
# High-level functions
Roarm.Robot.led_on()           # Full brightness (255)
Roarm.Robot.led_on(128)        # Half brightness
Roarm.Robot.led_off()          # Turn off

# Raw command equivalents
Roarm.Robot.send_custom_command(~s({"T": 114, "led": 255}))  # Full brightness
Roarm.Robot.send_custom_command(~s({"T": 114, "led": 128}))  # Half brightness
Roarm.Robot.send_custom_command(~s({"T": 114, "led": 0}))    # Off
```

#### RGB LED Control (T:114)
```elixir
# High-level function
Roarm.Robot.set_led(%{r: 255, g: 100, b: 0})  # Orange color

# Raw command equivalent
Roarm.Robot.send_custom_command(~s({"T": 114, "r": 255, "g": 100, "b": 0}))
```

### 🎯 Teaching & Mission Commands

#### Mission Creation & Control
```elixir
# High-level functions
Roarm.Robot.create_mission("demo", "Demo mission")
Roarm.Robot.add_mission_step("demo", 0.25)
Roarm.Robot.add_mission_delay("demo", 2000)
Roarm.Robot.play_mission("demo", 3)

# Raw command equivalents
Roarm.Robot.send_custom_command(~s({"T": 220, "name": "demo", "intro": "Demo mission"}))
Roarm.Robot.send_custom_command(~s({"T": 223, "mission": "demo", "spd": 0.25}))
Roarm.Robot.send_custom_command(~s({"T": 224, "mission": "demo", "delay": 2000}))
Roarm.Robot.send_custom_command(~s({"T": 242, "name": "demo", "times": 3}))
```

#### Drag Teaching
```elixir
# High-level functions
Roarm.Robot.drag_teach_start("movement.json", sample_rate: 50)
# ... manually move the robot ...
{:ok, samples} = Roarm.Robot.drag_teach_stop()
Roarm.Robot.drag_teach_replay("movement.json")

# Internally uses T:210 for torque control plus recording logic
```

### 🔧 Advanced Control Commands

#### PID Control (T:108)
```elixir
# Raw command (no high-level function)
Roarm.Robot.send_custom_command(~s({"T": 108, "joint": 1, "p": 16, "i": 0, "d": 1}))
# Set PID parameters for joint 1 (base): P=16, I=0, D=1
```

#### Dynamic External Force Adaptation (T:112)
```elixir
# Raw command (no high-level function)
Roarm.Robot.send_custom_command(~s({"T": 112, "mode": 1, "b": 60, "s": 110, "e": 50, "h": 50}))
# Enable force adaptation with torque limits per joint
# mode: 0=disable, 1=enable
# b,s,e,h: torque limits for base, shoulder, elbow, hand (0-1000)
```

### 🎮 M3 Gripper Commands (6-DOF Models Only)

#### Gripper Control (T:222)
```elixir
# Raw commands (no high-level functions yet)
Roarm.Robot.send_custom_command(~s({"T": 222, "mode": 1, "angle": 50}))   # Open gripper 50%
Roarm.Robot.send_custom_command(~s({"T": 222, "mode": 0, "angle": 0}))    # Close gripper
Roarm.Robot.send_custom_command(~s({"T": 222, "mode": 1, "angle": 100}))  # Fully open
```

### 🚀 Quick Action Examples

#### Speed Control Examples
```elixir
# Slow movement (speed 500)
Roarm.Robot.send_custom_command(~s({"T": 122, "b": 45, "s": 30, "e": -15, "h": 0, "spd": 500}))

# Fast movement (speed 4096 - maximum)
Roarm.Robot.send_custom_command(~s({"T": 122, "b": 45, "s": 30, "e": -15, "h": 0, "spd": 4096}))

# With acceleration control
Roarm.Robot.send_custom_command(~s({"T": 1041, "x": 200, "y": 0, "z": 150, "t": 0, "spd": 2000, "acc": 1000}))
```

#### Open Hand 75% Quickly (Your Original Question!)
```elixir
# Using single joint control for maximum speed
Roarm.Robot.send_custom_command(~s({"T": 121, "joint": 4, "angle": 135, "spd": 4096}))

# What it does:
# T:121 = single joint control in degrees
# joint: 4 = hand/wrist joint (the 4th joint)
# angle: 135 = 75% of 180° range (0.75 × 180 = 135°)
# spd: 4096 = maximum speed
```

#### Pick and Place Sequence
```elixir
# Move to position above object
Roarm.Robot.move_to_position(%{x: 150, y: 100, z: 200, t: 0})

# Lower to object
Roarm.Robot.move_to_position(%{x: 150, y: 100, z: 100, t: 0})

# Close gripper (M3 only)
Roarm.Robot.send_custom_command(~s({"T": 222, "mode": 0, "angle": 0}))

# Lift object
Roarm.Robot.move_to_position(%{x: 150, y: 100, z: 200, t: 0})

# Move to drop location
Roarm.Robot.move_to_position(%{x: 200, y: 200, z: 200, t: 0})

# Lower and release
Roarm.Robot.move_to_position(%{x: 200, y: 200, z: 100, t: 0})
Roarm.Robot.send_custom_command(~s({"T": 222, "mode": 1, "angle": 100}))

# Return home
Roarm.Robot.home()
```

#### LED Light Show
```elixir
# Cycle through colors
Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})    # Red
:timer.sleep(1000)
Roarm.Robot.set_led(%{r: 0, g: 255, b: 0})    # Green
:timer.sleep(1000)
Roarm.Robot.set_led(%{r: 0, g: 0, b: 255})    # Blue
:timer.sleep(1000)
Roarm.Robot.led_off()                          # Off
```

## Robot Model Differences

- **RoArm-M2**: 4 joints (base, shoulder, elbow, hand)
- **RoArm-M3**: 6 joints (adds wrist + gripper)
- **Pro models**: Enhanced versions with better precision
- **M2-S/M3**: Support flash storage and mission files

## Elixir Library Functions

The library provides high-level Elixir functions that wrap these low-level commands:

### Basic Movement
```elixir
Roarm.Robot.home()                                    # T:100
Roarm.Robot.move_joints(%{j1: 30, j2: 45, j3: -30, j4: 0})  # T:122
Roarm.Robot.move_to_position(%{x: 200, y: 100, z: 150, t: 0}) # T:1041
```

### LED Control (Gripper-Mounted)
```elixir
Roarm.Robot.led_on()                                 # T:114 with led=255
Roarm.Robot.led_off()                                # T:114 with led=0
Roarm.Robot.led(:on, 128)                           # T:114 with led=128
```

### Teaching & Missions
```elixir
Roarm.Robot.drag_teach_start("movement.json")        # T:210 + recording
Roarm.Robot.create_mission("demo", "Demo mission")   # T:220
Roarm.Robot.add_mission_step("demo", 0.25)           # T:223
Roarm.Robot.play_mission("demo", 3)                  # T:242
```

### System Control
```elixir
Roarm.Robot.set_torque_enabled(false)               # T:210 with cmd=0
Roarm.Robot.get_position()                           # T:105
Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})         # T:114 with RGB
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/roarm>.

