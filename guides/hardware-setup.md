# Hardware Setup

This guide covers the physical setup and connection of your Waveshare RoArm robot arm.

## Supported Models

RoArm Elixir supports the following Waveshare robot arm models:

| Model | DOF | Features |
|-------|-----|----------|
| RoArm-M2 | 4 | Basic model with gripper and LED |
| RoArm-M2-Pro | 4 | Enhanced version with improved servos |
| RoArm-M3 | 6 | Advanced model with wrist rotation |
| RoArm-M3-Pro | 6 | Professional version with high-torque servos |

## Physical Setup

### 1. Power Connection

1. **Power Supply**: Use a 12V 5A DC power adapter (included)
2. **Power Port**: Connect to the DC power jack on the driver board
3. **Power Switch**: Locate the power switch on the base of the robot
   - **ON Position**: Robot is powered and operational
   - **OFF Position**: Robot is powered down

> ⚠️ **Important**: Always ensure the power switch is in the **ON** position before attempting communication.

### 2. USB Connection

The RoArm has **two USB-C ports** - it's crucial to use the correct one:

#### ✅ Correct Port (Middle USB-C)
- **Location**: Middle of the driver board
- **Purpose**: ESP32 communication interface
- **Use for**: Serial communication with your computer
- **Baud Rate**: 115200

#### ❌ Wrong Port (Edge USB-C)
- **Location**: Edge of the driver board
- **Purpose**: Radar communication (if equipped)
- **Do not use**: For robot arm control

### 3. Connection Steps

1. Connect the 12V power adapter to the DC port
2. Turn the power switch to **ON**
3. Connect USB-C cable to the **middle USB-C port**
4. Connect the other end to your computer
5. The device should appear as a serial port:
   - **macOS**: `/dev/cu.usbserial-*` or `/dev/tty.usbserial-*`
   - **Linux**: `/dev/ttyUSB*` or `/dev/ttyACM*`
   - **Windows**: `COM*`

## Port Detection

### Finding Your Robot's Port

```elixir
# List all available serial ports
ports = Roarm.Communication.list_ports()
IO.inspect(ports)

# On macOS, look for something like:
# %{"/dev/cu.usbserial-110" => %{...}}

# On Linux, look for something like:
# %{"/dev/ttyUSB0" => %{...}}
```

### Device Recognition

When properly connected, you should see:
- **macOS**: Device appears in System Information under USB
- **Linux**: `lsusb` shows "CP210x UART Bridge" or similar
- **Windows**: Device Manager shows "Silicon Labs CP210x USB to UART Bridge"

## Testing Connection

Use the built-in test function to verify your setup:

```elixir
# Test connection (replace with your port)
case Roarm.test_connection("/dev/cu.usbserial-110") do
  {:ok, position} ->
    Logger.info("✅ Connection successful!")
    IO.inspect(position)

  {:error, reason} ->
    Logger.info("❌ Connection failed: #{inspect(reason)}")
end
```

## Troubleshooting

### Common Issues

#### "Port not found" or "Connection refused"

**Causes:**
- Wrong USB-C port (using edge port instead of middle port)
- Power switch is OFF
- USB cable issue
- Driver problems

**Solutions:**
1. Verify you're using the **middle USB-C port**
2. Check power switch is **ON**
3. Try a different USB-C cable
4. Restart the robot (power OFF → wait 5 seconds → power ON)

#### "Permission denied" (Linux/macOS)

```bash
# Add your user to the dialout group (Linux)
sudo usermod -a -G dialout $USER

# Or temporarily change permissions
sudo chmod 666 /dev/ttyUSB0
```

#### Device not recognized

**Windows:**
1. Install CP210x USB to UART Bridge VCP Drivers
2. Download from Silicon Labs website
3. Restart computer after installation

**macOS:**
- Drivers usually install automatically
- If issues persist, install CP210x VCP drivers manually

**Linux:**
- Most distributions include drivers by default
- For older systems: `sudo apt-get install linux-modules-extra-$(uname -r)`

### Verification Checklist

- [ ] Power adapter connected to DC port
- [ ] Power switch in ON position
- [ ] USB-C cable connected to **middle port** (not edge port)
- [ ] Device appears in system's port list
- [ ] No permission issues with serial port access
- [ ] Baud rate set to 115200

## Multiple Robot Setup

For controlling multiple robots simultaneously:

```elixir
# Start separate communication channels
{:ok, _} = Roarm.Communication.start_link(name: :comm1)
{:ok, _} = Roarm.Communication.start_link(name: :comm2)

# Connect each robot to its own communication channel
Roarm.Communication.connect("/dev/ttyUSB0", server_name: :comm1)
Roarm.Communication.connect("/dev/ttyUSB1", server_name: :comm2)

# Start robot controllers
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
```

## Safety Considerations

> ⚠️ **Safety First**

- Always ensure adequate workspace around the robot
- Keep fingers and objects clear of the robot's range of motion
- Use the emergency stop (power switch) if needed
- Start with slow movements when testing
- Ensure the robot is properly secured to the work surface

## Next Steps

Once your hardware is properly connected:
1. Follow the [Getting Started](getting-started.html) guide for basic usage
2. Explore the [Command Reference](commands.html) for advanced features
3. Check out the demo functions for interactive control