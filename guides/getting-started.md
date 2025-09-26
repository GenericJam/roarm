# Getting Started

Welcome to RoArm Elixir! This guide will help you get up and running with controlling your Waveshare RoArm robot arm using Elixir.

## Prerequisites

- Elixir 1.18 or later
- A Waveshare RoArm robot arm (M2, M2-Pro, M3, or M3-Pro)
- USB-C cable for connection
- 12V 5A power supply

## Installation

Add `roarm` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:roarm, "~> 0.1.0"}
  ]
end
```

## Configuration

Configure Roarm in your `config/config.exs` file:

```elixir
config :roarm,
  port: "/dev/cu.usbserial-110",
  baudrate: 115200,
  robot_type: :roarm_m2,
  timeout: 5000
```

Available configuration options:
- `:port` - Serial port path (e.g., "/dev/ttyUSB0", "/dev/cu.usbserial-110")
- `:baudrate` - Communication speed (default: 115200)
- `:robot_type` - Type of robot (:roarm_m2, :roarm_m2_pro, :roarm_m3, :roarm_m3_pro)
- `:communication_server_name` - Name for communication server (default: Roarm.Communication)
- `:robot_server_name` - Name for robot server (default: Roarm.Robot)
- `:timeout` - Default timeout for operations in milliseconds (default: 5000)

## Quick Start

### 1. Using Configuration (Recommended)

```elixir
# With configuration - just start the robot
{:ok, _pid} = Roarm.start_robot()

# Robot is automatically connected and ready to use
Roarm.Robot.move_to_position(%{x: 100.0, y: 0.0, z: 150.0, t: 0.0})
```

### 2. Manual Setup (Advanced)

```elixir
# Start a robot controller with specific options (overrides config)
{:ok, pid} = Roarm.start_robot([
  robot_type: :roarm_m3,           # Override config robot type
  port: "/dev/ttyUSB0"            # Override config port
])

# Robot is automatically connected
Roarm.Robot.home()
```

### 3. Basic Movement

```elixir
# Move to home position
{:ok, _response} = Roarm.Robot.home()

# Move individual joints (in degrees)
{:ok, _response} = Roarm.Robot.move_joints(%{
  j1: 45.0,   # Base rotation
  j2: 30.0,   # Shoulder
  j3: -45.0,  # Elbow
  j4: 0.0     # Wrist
})

# Move to a specific position (in mm)
{:ok, _response} = Roarm.Robot.move_to_position(%{
  x: 150.0,
  y: 0.0,
  z: 200.0,
  t: 0.0  # Tool angle
})
```

### 4. LED Control

```elixir
# Turn on the gripper LED
{:ok, _response} = Roarm.Robot.led_on(200)

# Turn off the LED
{:ok, _response} = Roarm.Robot.led_off()

# Set custom RGB color
{:ok, _response} = Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})
```

### 5. Advanced Commands with Validation

The library includes comprehensive command validation with automatic range clamping and symbolic values:

```elixir
# Use symbolic values for parameters
{:ok, _response} = Roarm.Robot.send_valid_command(%{
  t: 121,        # Single joint control
  joint: 1,      # Joint number
  angle: :max,   # Symbolic value (automatically resolves to 180.0)
  spd: :mid      # Symbolic value (automatically resolves to middle speed)
})

# Values are automatically clamped to valid ranges
{:ok, _response} = Roarm.Robot.send_valid_command(%{
  t: 121,
  joint: 1,
  angle: 45.0,
  spd: 9999      # Will be clamped to maximum speed (4096)
})
```

## Error Handling

Always handle errors when working with hardware:

```elixir
case Roarm.Robot.move_joints(%{j1: 45.0, j2: 30.0}) do
  {:ok, response} ->
    Logger.info("Movement successful: #{response}")

  {:error, :not_connected} ->
    Logger.info("Robot is not connected")

  {:error, reason} ->
    Logger.info("Error: #{inspect(reason)}")
end
```

## Multiple Robots

You can control multiple robots simultaneously:

```elixir
# Start multiple robots
{:ok, _} = Roarm.Robot.start_link([
  name: :robot1,
  robot_type: :roarm_m2,
  port: "/dev/ttyUSB0"
])

{:ok, _} = Roarm.Robot.start_link([
  name: :robot2,
  robot_type: :roarm_m3,
  port: "/dev/ttyUSB1"
])

# Control specific robots
Roarm.Robot.home(server_name: :robot1)
Roarm.Robot.home(server_name: :robot2)
```

## Next Steps

- Check out the [Hardware Setup](hardware-setup.html) guide for connection details
- Explore the [Command Reference](commands.html) for all available commands
- See the module documentation for detailed API information

## Troubleshooting

**Connection Issues:**
- Ensure the power switch on the robot base is ON
- Use the correct USB-C port (middle port for ESP32 communication)
- Check that your port path is correct using `Roarm.Communication.list_ports()`

**Command Failures:**
- Verify the robot is connected with `Roarm.Robot.connected?()`
- Check that torque is enabled for movement commands
- Ensure your command parameters are within valid ranges