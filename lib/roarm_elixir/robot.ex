defmodule Roarm.Robot do
  @moduledoc """
  Core robot control module for Waveshare RoArm robot arms.

  Provides high-level functions for controlling robot movement, positioning,
  and features while handling the underlying communication protocol.
  """

  use GenServer
  require Logger
  alias Roarm.Communication
  alias Roarm.Config

  @type robot_type :: :roarm_m2 | :roarm_m2_pro | :roarm_m3 | :roarm_m3_pro

  @type position :: %{x: float(), y: float(), z: float(), t: float()}

  @type joints :: %{j1: float(), j2: float(), j3: float(), j4: float()}

  @type rgb :: %{r: integer(), g: integer(), b: integer()}

  defstruct [
    :robot_type,
    :port,
    :baudrate,
    :connected,
    :current_position,
    :current_joints,
    :torque_locked,
    :teaching_active,
    :teaching_task,
    :teaching_data,
    :teaching_filename
  ]

  # Client API

  @doc """
  Start a new robot control process.

  ## Options
    - `:robot_type` - Type of robot (default: from config or :roarm_m2)
    - `:port` - Serial port path (default: from config)
    - `:baudrate` - Communication speed (default: from config or 115200)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    registry_name = {:via, Registry, {Roarm.registry_name(), name}}
    GenServer.start_link(__MODULE__, opts, name: registry_name)
  end

  # Helper function to resolve server name to PID via registry
  defp resolve_server(name) when is_atom(name) do
    case Registry.lookup(Roarm.registry_name(), name) do
      [{pid, _}] -> pid
      [] -> name  # Fallback to atom for backwards compatibility
    end
  end
  defp resolve_server(pid) when is_pid(pid), do: pid

  @doc """
  Connect to the robot arm.

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Examples
      Roarm.Robot.connect()
      Roarm.Robot.connect(server_name: :robot1)
  """
  @doc group: :connection
  def connect(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :connect)
  end

  @doc """
  Disconnect from the robot arm.

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Examples
      Roarm.Robot.disconnect()
      Roarm.Robot.disconnect(server_name: :robot1)
  """
  @doc group: :connection
  def disconnect(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :disconnect)
  end

  @doc """
  Move the robot to a specific position.

  Supports partial position updates - only specify the coordinates you want to change,
  and the robot will maintain its current values for unspecified coordinates.

  ## Parameters
    - `position` - Target position map with the following coordinates (all in mm except t):
      - `:x` - X coordinate (-500.0 to 500.0 mm)
      - `:y` - Y coordinate (-500.0 to 500.0 mm)
      - `:z` - Z coordinate (0.0 to 500.0 mm)
      - `:t` - Tool rotation angle (-180.0 to 180.0 degrees)
               Represents the rotation angle of the EoAT (End of Arm Tooling)
               Can be partial - e.g., %{y: 50.0} will only change Y coordinate
    - `opts` - Optional parameters:
      - `:speed` - Movement speed (1-4096, default: 1000)
      - `:acceleration` - Movement acceleration (1-254, default: 100)
      - `:timeout` - Command timeout in milliseconds (default: 8000)
      - `:server_name` - Robot server name (default: __MODULE__)

  ## Examples
      # Move to complete position
      Roarm.Robot.move_to_position(%{x: 100.0, y: 0.0, z: 150.0, t: 0.0})

      # Partial update - only change Y and Z, maintain current X and T
      Roarm.Robot.move_to_position(%{y: 50.0, z: 200.0})

      # Single coordinate update
      Roarm.Robot.move_to_position(%{x: 75.0})

      # With custom speed and acceleration
      Roarm.Robot.move_to_position(%{x: 200.0, z: 300.0}, speed: 2000, acceleration: 150)
  """
  @doc group: :movement
  def move_to_position(position, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    speed = Keyword.get(opts, :speed, 1000)
    acceleration = Keyword.get(opts, :acceleration, 100)
    timeout = Keyword.get(opts, :timeout, 8000)

    # Get current position and merge with requested changes
    target_position = case get_position(server_name: server) do
      {:ok, current_position} ->
        Map.merge(current_position, position)

      {:error, _} ->
        # If we can't get current position, use defaults for missing values
        default_position = %{x: 0.0, y: 0.0, z: 100.0, t: 0.0}
        Map.merge(default_position, position)
    end

    # Build JSON command directly due to parameter name collision
    json_command = Jason.encode!(%{
      "T" => 1041,
      "x" => target_position.x,
      "y" => target_position.y,
      "z" => target_position.z,
      "t" => target_position.t,
      "spd" => max(1, min(speed, 4096)),      # Clamp speed
      "acc" => max(1, min(acceleration, 254))  # Clamp acceleration
    })

    send_custom_command(json_command, server_name: server, timeout: timeout)
  end

  @doc """
  Move individual joints to specific angles.

  Supports partial joint updates - only specify the joints you want to change,
  and the robot will maintain its current values for unspecified joints.

  ## Parameters
    - `joints` - Joint angles map with the following joints (all in degrees):
      - `:j1` - Base joint (-180.0 to 180.0°) - controls rotation around vertical axis
      - `:j2` - Shoulder joint (-180.0 to 180.0°) - controls arm lift/lower
      - `:j3` - Elbow joint (-180.0 to 180.0°) - controls forearm angle
      - `:j4` - Wrist joint (-180.0 to 180.0°) - controls end effector rotation
      - `:j5` - Additional joint (-180.0 to 180.0°) - for extended robot models
      - `:j6` - Additional joint (-180.0 to 180.0°) - for extended robot models
                Can be partial - e.g., %{j1: 45.0} will only change joint 1
    - `opts` - Optional parameters:
      - `:speed` - Movement speed (1-4096, default: 1000)
      - `:timeout` - Command timeout in milliseconds (default: from config)
      - `:server_name` - Robot server name (default: __MODULE__)

  ## Examples
      # Move all primary joints
      Roarm.Robot.move_joints(%{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0})

      # Partial update - only change j1 and j3, maintain current j2 and j4
      Roarm.Robot.move_joints(%{j1: 30.0, j3: -45.0})

      # Single joint update
      Roarm.Robot.move_joints(%{j2: 90.0})

      # With custom speed
      Roarm.Robot.move_joints(%{j1: 45.0, j4: -30.0}, speed: 2000)
  """
  @doc group: :movement
  def move_joints(joints, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    speed = Keyword.get(opts, :speed, 1000)
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())

    # Get current joint angles and merge with requested changes
    target_joints = case get_joints(server_name: server) do
      {:ok, current_joints} ->
        Map.merge(current_joints, joints)

      {:error, _} ->
        # If we can't get current joints, use defaults for missing values
        default_joints = %{j1: 0.0, j2: 0.0, j3: 0.0, j4: 0.0, j5: 0.0, j6: 0.0}
        Map.merge(default_joints, joints)
    end

    # Convert from j1,j2,j3,j4 format to b,s,e,h format
    command = %{
      t: 122,
      b: target_joints.j1,
      s: target_joints.j2,
      e: target_joints.j3,
      h: target_joints.j4,
      w: Map.get(target_joints, :j5, 0.0),
      g: Map.get(target_joints, :j6, 0.0),
      spd: speed
    }

    send_valid_command(command, server_name: server, timeout: timeout)
  end

  @doc """
  Move the robot to its home position.

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)
    - `:timeout` - Command timeout in milliseconds (default: from config or 5000)

  ## Examples
      {:ok, response} = Roarm.Robot.home()
      {:ok, response} = Roarm.Robot.home(server_name: :robot1, timeout: 10000)
  """
  @doc group: :movement
  def home(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())
    send_valid_command(%{t: 100}, server_name: server, timeout: timeout)
  end

  @doc """
  Get the current position of the robot.

  Returns the robot's current XYZ position and tool angle.

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Returns
    - `{:ok, %{x: float, y: float, z: float, t: float}}` - Current position
    - `{:error, reason}` - Error occurred

  ## Examples
      {:ok, position} = Roarm.Robot.get_position()
      {:ok, %{x: 150.0, y: 0.0, z: 200.0, t: 0.0}} = Roarm.Robot.get_position()
  """
  @doc group: :movement
  def get_position(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :get_position)
  end

  @doc """
  Get the current joint angles.

  Returns the robot's current joint angles in degrees.

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Returns
    - `{:ok, %{j1: float, j2: float, j3: float, j4: float}}` - Current joint angles
    - `{:error, reason}` - Error occurred

  ## Examples
      {:ok, joints} = Roarm.Robot.get_joints()
      {:ok, %{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0}} = Roarm.Robot.get_joints()
  """
  @doc group: :movement
  def get_joints(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :get_joints)
  end

  @doc """
  Enable or disable torque lock.
  """
  def set_torque_lock(enabled, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:set_torque_lock, enabled})
  end

  @doc """
  Control the robot's LED.

  ## Parameters
    - `color` - RGB color as %{r: integer, g: integer, b: integer} (0-255 each)

  ## Example
      Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})  # Red
  """
  def set_led(color, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:set_led, color})
  end

  @doc """
  Control the LED mounted on the gripper with simple on/off commands.

  ## Parameters
    - `action` - :on or :off
    - `value` - LED brightness (0-255, where 0=off, 255=full brightness)
    - `opts` - Options including :server_name

  ## Examples
      Roarm.Robot.led(:on, 200)                    # Set LED brightness to 200/255
      Roarm.Robot.led(:off, 50)                    # Set LED brightness to 50/255 (dim)
      Roarm.Robot.led(:on)                         # LED at full brightness (255)
      Roarm.Robot.led(:off)                        # LED completely off (0)
      Roarm.Robot.led(:on, 200, server_name: :robot1) # Control specific robot
  """
  def led(action, value \\ nil, opts \\ []) when action in [:on, :off] do
    server = Keyword.get(opts, :server_name, __MODULE__)
    # Set default values based on action
    led_value = case {action, value} do
      {:on, nil} -> 255     # Full brightness by default
      {:off, nil} -> 0      # Completely off by default
      {:on, val} when is_integer(val) -> clamp(val, 0, 255)
      {:off, val} when is_integer(val) -> clamp(val, 0, 255)
    end

    GenServer.call(resolve_server(server), {:led_control, led_value})
  end

  @doc """
  Turn on the gripper LED to specified brightness (0-255).

  ## Parameters
    - `brightness` - LED brightness level (0-255, default: 255)

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)
    - `:timeout` - Command timeout in milliseconds (default: from config or 5000)

  ## Examples
      {:ok, response} = Roarm.Robot.led_on(200)
      {:ok, response} = Roarm.Robot.led_on()  # Full brightness
      {:ok, response} = Roarm.Robot.led_on(200, server_name: :robot1)
  """
  @doc group: :led
  def led_on(brightness \\ 255, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())
    send_valid_command(%{t: 114, led: brightness}, server_name: server, timeout: timeout)
  end

  @doc """
  Turn off the gripper LED.

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)
    - `:timeout` - Command timeout in milliseconds (default: from config or 5000)

  ## Examples
      {:ok, response} = Roarm.Robot.led_off()
      {:ok, response} = Roarm.Robot.led_off(server_name: :robot1)
  """
  @doc group: :led
  def led_off(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())
    send_valid_command(%{t: 114, led: 0}, server_name: server, timeout: timeout)
  end

  @doc """
  Start drag teach mode - disables torque so you can manually move the arm.

  ## Parameters
    - `filename` - Path to save the recorded movement data

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)
    - `:sample_rate` - Recording frequency in milliseconds (default: 100)

  ## Examples
      {:ok, response} = Roarm.Robot.drag_teach_start("my_movement.json")
      {:ok, response} = Roarm.Robot.drag_teach_start("precise.json", sample_rate: 50)
  """
  @doc group: :teaching
  def drag_teach_start(filename, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:drag_teach_start, filename, opts})
  end

  @doc """
  Stop drag teach recording and save the data.

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Returns
    - `{:ok, num_samples}` - Number of recorded samples
    - `{:error, reason}` - Error occurred

  ## Examples
      {:ok, 150} = Roarm.Robot.drag_teach_stop()
  """
  @doc group: :teaching
  def drag_teach_stop(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :drag_teach_stop)
  end

  @doc """
  Replay a recorded drag teach movement.

  ## Parameters
    - `filename` - Path to the recorded movement file

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)
    - `:speed_multiplier` - Playback speed multiplier (default: 1.0)

  ## Examples
      {:ok, response} = Roarm.Robot.drag_teach_replay("my_movement.json")
      {:ok, response} = Roarm.Robot.drag_teach_replay("fast.json", speed_multiplier: 2.0)
  """
  @doc group: :teaching
  def drag_teach_replay(filename, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:drag_teach_replay, filename, opts})
  end

  @doc """
  Enable or disable torque on all joints.

  ## Parameters
    - `enabled` - true to enable torque (lock joints), false to disable (allow manual movement)
    - `opts` - Options including :server_name and :timeout
  """
  def set_torque_enabled(enabled, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())
    cmd = if enabled, do: 1, else: 0
    send_valid_command(%{t: 210, cmd: cmd}, server_name: server, timeout: timeout)
  end

  @doc """
  Create a new step recording mission.

  ## Parameters
    - `name` - Mission name/identifier
    - `description` - Optional description of the mission (default: "")

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Examples
      {:ok, response} = Roarm.Robot.create_mission("pickup_sequence")
      {:ok, response} = Roarm.Robot.create_mission("complex_task", "Multi-step operation")
  """
  @doc group: :missions
  def create_mission(name, description \\ "", opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:create_mission, name, description})
  end

  @doc """
  Add current position as a step to the mission.

  ## Parameters
    - `name` - Mission name
    - `speed` - Movement speed for this step (0.1-1.0, default: 0.25)

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Examples
      {:ok, response} = Roarm.Robot.add_mission_step("pickup_sequence")
      {:ok, response} = Roarm.Robot.add_mission_step("fast_moves", 0.8)
  """
  @doc group: :missions
  def add_mission_step(name, speed \\ 0.25, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:add_mission_step, name, speed})
  end

  @doc """
  Add a delay step to the mission.

  ## Parameters
    - `name` - Mission name
    - `delay_ms` - Delay in milliseconds
    - `opts` - Options including :server_name
  """
  def add_mission_delay(name, delay_ms, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:add_mission_delay, name, delay_ms})
  end

  @doc """
  Play/execute a recorded mission.

  ## Parameters
    - `name` - Mission name
    - `times` - Number of times to repeat (1-1000, default: 1)

  ## Options
    - `:server_name` - Name of the robot process (default: `__MODULE__`)

  ## Examples
      {:ok, response} = Roarm.Robot.play_mission("pickup_sequence")
      {:ok, response} = Roarm.Robot.play_mission("loop_task", 5)
  """
  @doc group: :missions
  def play_mission(name, times \\ 1, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:play_mission, name, times})
  end

  @doc """
  Send a validated command to the robot.

  Takes a command map with atom or string keys, validates all parameters,
  applies range limits and symbolic values (:min, :mid, :max), then sends
  the command to the robot.

  ## Examples
      # Single joint control with validation
      Robot.send_valid_command(%{t: 121, joint: 4, angle: 90, spd: :max})

      # Position control with clamping
      Robot.send_valid_command(%{t: 1041, x: 200, y: 100, z: 150, spd: 5000})  # spd clamped to 4096

      # LED control with symbolic values
      Robot.send_valid_command(%{t: 114, led: :max, r: 255, g: 0, b: 0})

      # With custom server and timeout
      Robot.send_valid_command(%{t: 100}, server_name: :robot1, timeout: 10000)
  """
  def send_valid_command(command_map, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())
    case Roarm.CommandValidator.validate_command(command_map) do
      {:ok, validated_command} ->
        json_command = Roarm.CommandValidator.to_json(validated_command)
        GenServer.call(resolve_server(server), {:custom_command, json_command, timeout})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Send a custom JSON command string to the robot (bypass validation).

  For direct control when you need to send raw commands.
  """
  def send_custom_command(command, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())
    GenServer.call(resolve_server(server), {:custom_command, command, timeout})
  end

  @doc """
  Check if the robot is connected.
  """
  def connected?(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :connected?)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    robot_type = Keyword.get(opts, :robot_type, Config.get_robot_type())
    port = Keyword.get(opts, :port, Config.get(:port))
    baudrate = Keyword.get(opts, :baudrate, Config.get_baudrate())

    state = %__MODULE__{
      robot_type: robot_type,
      port: port,
      baudrate: baudrate,
      connected: false,
      torque_locked: false,
      teaching_active: false,
      teaching_task: nil,
      teaching_data: [],
      teaching_filename: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:connect, _from, state) do
    if state.port do
      case Communication.connect(state.port, baudrate: state.baudrate) do
        :ok ->
          Logger.info("Robot connected successfully")
          {:reply, :ok, %{state | connected: true}}

        {:error, reason} ->
          Logger.error("Failed to connect robot: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :no_port_specified}, state}
    end
  end

  @impl true
  def handle_call(:disconnect, _from, state) do
    case Communication.disconnect() do
      :ok ->
        {:reply, :ok, %{state | connected: false}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:move_to_position, position, _opts}, _from, state) do
    if state.connected do
      command = build_position_command(position)

      case Communication.send_command(command) do
        {:ok, response} ->
          new_state = %{state | current_position: position}
          {:reply, {:ok, response}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:move_joints, joints, _opts}, _from, state) do
    if state.connected do
      command = build_joints_command(joints)

      case Communication.send_command(command) do
        {:ok, response} ->
          new_state = %{state | current_joints: joints}
          {:reply, {:ok, response}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:home, _from, state) do
    if state.connected do
      command = build_home_command()

      case Communication.send_command(command) do
        {:ok, response} ->
          home_position = %{x: 0.0, y: 0.0, z: 0.0, t: 0.0}
          home_joints = %{j1: 0.0, j2: 0.0, j3: 0.0, j4: 0.0}
          new_state = %{state | current_position: home_position, current_joints: home_joints}
          {:reply, {:ok, response}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    if state.connected do
      command = build_get_position_command()

      case Communication.send_command(command) do
        {:ok, response} ->
          case parse_position_response(response) do
            {:ok, position} ->
              new_state = %{state | current_position: position}
              {:reply, {:ok, position}, new_state}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:get_joints, _from, state) do
    if state.connected do
      command = build_get_joints_command()

      case Communication.send_command(command) do
        {:ok, response} ->
          case parse_joints_response(response) do
            {:ok, joints} ->
              new_state = %{state | current_joints: joints}
              {:reply, {:ok, joints}, new_state}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:set_torque_lock, enabled}, _from, state) do
    if state.connected do
      command = build_torque_lock_command(enabled)

      case Communication.send_command(command) do
        {:ok, response} ->
          new_state = %{state | torque_locked: enabled}
          {:reply, {:ok, response}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:set_led, color}, _from, state) do
    if state.connected do
      command = build_led_command(color)

      case Communication.send_command(command) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:led_control, value}, _from, state) do
    if state.connected do
      command = build_led_brightness_command(value)

      case Communication.send_command(command) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:custom_command, command}, _from, state) do
    handle_call({:custom_command, command, Config.get_timeout()}, nil, state)
  end

  @impl true
  def handle_call({:custom_command, command, timeout}, _from, state) do
    if state.connected do
      case Communication.send_command(command, timeout: timeout) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:drag_teach_start, filename, opts}, _from, state) do
    if state.connected and not state.teaching_active do
      sample_rate = Keyword.get(opts, :sample_rate, 100)

      # Disable torque to allow manual movement
      case set_torque_command(false) |> send_robot_command() do
        {:ok, _} ->
          # Start recording task
          parent = self()
          task = Task.async(fn ->
            teaching_loop(parent, sample_rate)
          end)

          new_state = %{state |
            teaching_active: true,
            teaching_task: task,
            teaching_data: [],
            teaching_filename: filename
          }

          Logger.info("Drag teach started - manually move the robot arm. Call drag_teach_stop() when done.")
          {:reply, :ok, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      cond do
        not state.connected -> {:reply, {:error, :not_connected}, state}
        state.teaching_active -> {:reply, {:error, :already_teaching}, state}
        true -> {:reply, {:error, :unknown_error}, state}
      end
    end
  end

  @impl true
  def handle_call(:drag_teach_stop, _from, state) do
    if state.teaching_active and state.teaching_task do
      # Stop the recording task
      Task.shutdown(state.teaching_task, :brutal_kill)

      # Re-enable torque
      case set_torque_command(true) |> send_robot_command() do
        {:ok, _} ->
          # Save recorded data to file
          case save_teaching_data(state.teaching_filename, state.teaching_data) do
            :ok ->
              Logger.info("Drag teach stopped. Data saved to #{state.teaching_filename}")
              new_state = %{state |
                teaching_active: false,
                teaching_task: nil,
                teaching_data: [],
                teaching_filename: nil
              }
              {:reply, {:ok, length(state.teaching_data)}, new_state}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_teaching}, state}
    end
  end

  @impl true
  def handle_call({:drag_teach_replay, filename, opts}, _from, state) do
    if state.connected do
      speed_multiplier = Keyword.get(opts, :speed_multiplier, 1.0)

      case load_teaching_data(filename) do
        {:ok, data} ->
          case replay_teaching_data(data, speed_multiplier) do
            :ok ->
              {:reply, :ok, state}
            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:set_torque_enabled, enabled}, _from, state) do
    if state.connected do
      command = set_torque_command(enabled)

      case send_robot_command(command) do
        {:ok, response} ->
          new_state = %{state | torque_locked: enabled}
          {:reply, {:ok, response}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:create_mission, name, description}, _from, state) do
    if state.connected do
      command = build_create_mission_command(name, description)

      case Communication.send_command(command) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:add_mission_step, name, speed}, _from, state) do
    if state.connected do
      command = build_add_step_command(name, speed)

      case Communication.send_command(command) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:add_mission_delay, name, delay_ms}, _from, state) do
    if state.connected do
      command = build_add_delay_command(name, delay_ms)

      case Communication.send_command(command) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:play_mission, name, times}, _from, state) do
    if state.connected do
      command = build_play_mission_command(name, times)

      case Communication.send_command(command) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, state.connected, state}
  end

  # Handle messages from teaching task
  @impl true
  def handle_info({:teaching_data, joint_data}, state) do
    if state.teaching_active do
      new_data = [joint_data | state.teaching_data]
      new_state = %{state | teaching_data: new_data}
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions - Command builders

  defp build_position_command(%{x: x, y: y, z: z, t: t}) do
    # RoArm uses T:104 for cartesian position control
    # Coordinates are in millimeters, t (tool angle) in radians
    %{
      "T" => 104,
      "x" => x,
      "y" => y,
      "z" => z,
      "t" => t,
      "spd" => 0.25  # Default speed
    }
    |> Jason.encode!()
  end

  defp build_joints_command(%{j1: j1, j2: j2, j3: j3, j4: j4}) do
    # RoArm uses T:122 for all joints control (angles in degrees)
    # Map j1-j4 to RoArm joint names: b(base), s(shoulder), e(elbow), h(hand)
    %{
      "T" => 122,
      "b" => j1,  # base
      "s" => j2,  # shoulder
      "e" => j3,  # elbow
      "h" => j4,  # hand/wrist
      "spd" => 10,  # Default speed
      "acc" => 10   # Default acceleration
    }
    |> Jason.encode!()
  end

  defp build_home_command do
    # RoArm uses T:100 for initialization/home position
    %{"T" => 100}
    |> Jason.encode!()
  end

  defp build_get_position_command do
    # RoArm uses T:105 to request feedback/status
    %{"T" => 105}
    |> Jason.encode!()
  end

  defp build_get_joints_command do
    # Same as get position - T:105 returns both position and joint info
    %{"T" => 105}
    |> Jason.encode!()
  end

  defp build_torque_lock_command(enabled) do
    # For torque lock, we can use individual joint control with very low speed
    # This is a workaround as RoArm doesn't have explicit torque lock command
    if enabled do
      # Send a command that essentially stops all joints
      %{
        "T" => 122,
        "b" => 0, "s" => 0, "e" => 0, "h" => 0,
        "spd" => 1,  # Very low speed
        "acc" => 1
      }
    else
      # Re-enable normal operation by sending current position
      %{"T" => 105}  # Get current position first
    end
    |> Jason.encode!()
  end

  defp build_led_command(%{r: r, g: g, b: b}) do
    # RoArm uses T:114 for gripper/LED control
    # Convert RGB to single LED value (this may need adjustment based on actual hardware)
    led_value = clamp(round((r + g + b) / 3), 0, 255)
    %{
      "T" => 114,
      "led" => led_value
    }
    |> Jason.encode!()
  end

  defp build_led_brightness_command(value) do
    # RoArm uses T:114 for LED control (mounted on gripper)
    # Value should be 0-255 where 0=off, 255=full brightness
    clamped_value = clamp(value, 0, 255)
    %{
      "T" => 114,
      "led" => clamped_value
    }
    |> Jason.encode!()
  end

  # Response parsers

  defp parse_position_response(response) do
    case Jason.decode(response) do
      {:ok, %{"coordinates" => [x, y, z]} = data} ->
        # RoArm returns coordinates as array [x, y, z]
        t = Map.get(data, "tool_angle", 0.0)  # Tool angle if available
        {:ok, %{x: x, y: y, z: z, t: t}}

      {:ok, %{"x" => x, "y" => y, "z" => z} = data} ->
        # Alternative format with individual coordinates
        t = Map.get(data, "t", 0.0)
        {:ok, %{x: x, y: y, z: z, t: t}}

      {:ok, _} ->
        # If we get any response, consider it successful but with unknown format
        Logger.warning("Unknown position response format: #{response}")
        {:ok, %{x: 0.0, y: 0.0, z: 0.0, t: 0.0}}

      {:error, reason} ->
        {:error, {:json_decode_error, reason}}
    end
  end

  defp parse_joints_response(response) do
    case Jason.decode(response) do
      {:ok, %{"joint_radians" => joint_array}} when is_list(joint_array) ->
        # RoArm returns joint angles as array in radians
        # Convert radians to degrees and map to our joint names
        [j1_rad, j2_rad, j3_rad, j4_rad | _] = joint_array ++ [0.0, 0.0, 0.0, 0.0]
        {:ok, %{
          j1: rad_to_deg(j1_rad),
          j2: rad_to_deg(j2_rad),
          j3: rad_to_deg(j3_rad),
          j4: rad_to_deg(j4_rad)
        }}

      {:ok, %{"b" => b, "s" => s, "e" => e, "h" => h}} ->
        # Alternative format with individual joint names
        {:ok, %{j1: b, j2: s, j3: e, j4: h}}

      {:ok, _} ->
        # If we get any response, consider it successful but with unknown format
        Logger.warning("Unknown joints response format: #{response}")
        {:ok, %{j1: 0.0, j2: 0.0, j3: 0.0, j4: 0.0}}

      {:error, reason} ->
        {:error, {:json_decode_error, reason}}
    end
  end

  # Helper function to convert radians to degrees
  defp rad_to_deg(radians) do
    radians * 180.0 / :math.pi()
  end

  # Teaching-related command builders

  defp set_torque_command(enabled) do
    cmd = if enabled, do: 1, else: 0
    %{"T" => 210, "cmd" => cmd}
    |> Jason.encode!()
  end

  defp build_create_mission_command(name, description) do
    %{
      "T" => 220,
      "name" => name,
      "intro" => description
    }
    |> Jason.encode!()
  end

  defp build_add_step_command(name, speed) do
    %{
      "T" => 223,
      "name" => name,
      "spd" => speed
    }
    |> Jason.encode!()
  end

  defp build_add_delay_command(name, delay_ms) do
    %{
      "T" => 224,
      "name" => name,
      "delay" => delay_ms
    }
    |> Jason.encode!()
  end

  defp build_play_mission_command(name, times) do
    %{
      "T" => 242,
      "name" => name,
      "times" => times
    }
    |> Jason.encode!()
  end

  # Teaching helper functions

  defp send_robot_command(command) do
    Communication.send_command(command)
  end

  defp teaching_loop(parent_pid, sample_rate) do
    case get_current_joints() do
      {:ok, joints} ->
        timestamp = System.system_time(:millisecond)
        joint_data = %{
          "timestamped" => timestamp,
          "joints" => joints
        }

        send(parent_pid, {:teaching_data, joint_data})
        :timer.sleep(sample_rate)
        teaching_loop(parent_pid, sample_rate)

      {:error, _reason} ->
        # Continue even if we can't get joint data for one sample
        :timer.sleep(sample_rate)
        teaching_loop(parent_pid, sample_rate)
    end
  end

  defp get_current_joints do
    command = build_get_joints_command()

    case Communication.send_command(command) do
      {:ok, response} ->
        case parse_joints_response(response) do
          {:ok, joints} ->
            # Convert to radians as expected by RoArm format
            joint_radians = [
              deg_to_rad(joints.j1),
              deg_to_rad(joints.j2),
              deg_to_rad(joints.j3),
              deg_to_rad(joints.j4)
            ]
            {:ok, joint_radians}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp save_teaching_data(filename, data) do
    # Reverse data since we collected it in reverse order
    sorted_data = Enum.reverse(data)

    case Jason.encode(sorted_data, pretty: true) do
      {:ok, json_string} ->
        case File.write(filename, json_string) do
          :ok ->
            Logger.info("Teaching data saved to #{filename} (#{length(sorted_data)} samples)")
            :ok

          {:error, reason} ->
            Logger.error("Failed to save teaching data: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to encode teaching data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp load_teaching_data(filename) do
    case File.read(filename) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            {:ok, data}

          {:error, reason} ->
            Logger.error("Failed to decode teaching data: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to read teaching file #{filename}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp replay_teaching_data(data, speed_multiplier) when is_list(data) do
    Logger.info("Replaying teaching data with #{length(data)} steps")

    # Calculate time intervals and replay movements
    case replay_steps(data, speed_multiplier, nil) do
      :ok ->
        Logger.info("Teaching replay completed successfully")
        :ok

      {:error, reason} ->
        Logger.error("Teaching replay failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp replay_steps([], _speed_multiplier, _prev_time) do
    :ok
  end

  defp replay_steps([step | remaining], speed_multiplier, prev_time) do
    current_time = step["timestamped"]
    joint_radians = step["joints"]

    # Calculate delay from previous step
    if prev_time do
      delay = trunc((current_time - prev_time) / speed_multiplier)
      if delay > 0, do: :timer.sleep(delay)
    end

    # Convert radians to degrees and send joint command
    joints = %{
      j1: rad_to_deg(Enum.at(joint_radians, 0, 0.0)),
      j2: rad_to_deg(Enum.at(joint_radians, 1, 0.0)),
      j3: rad_to_deg(Enum.at(joint_radians, 2, 0.0)),
      j4: rad_to_deg(Enum.at(joint_radians, 3, 0.0))
    }

    command = build_joints_command(joints)

    case Communication.send_command(command) do
      {:ok, _response} ->
        replay_steps(remaining, speed_multiplier, current_time)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper function to convert degrees to radians
  defp deg_to_rad(degrees) do
    degrees * :math.pi() / 180.0
  end

  # Utility functions

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end
end
