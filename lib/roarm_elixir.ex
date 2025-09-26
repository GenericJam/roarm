defmodule Roarm do
  @moduledoc """
  Elixir library for controlling Waveshare RoArm robot arms.

  This library provides a high-level interface for controlling Waveshare RoArm
  robot arms using Circuits.UART for serial communication. It replicates the
  functionality of the official Waveshare RoArm SDK in Elixir.

  ## Features

  - Serial communication with RoArm devices
  - Position and joint control
  - LED control and torque lock
  - Concurrent robot control using GenServer
  - Support for multiple RoArm models

  ## Configuration

  Configure Roarm in your `config.exs`:

      config :roarm,
        port: "/dev/cu.usbserial-110",
        baudrate: 115200,
        robot_type: :roarm_m2

  ## Quick Start

      # With configuration - just start the robot
      {:ok, _pid} = Roarm.start_robot()

      # Or override specific options
      {:ok, _pid} = Roarm.start_robot(port: "/dev/ttyUSB0", robot_type: :roarm_m3)

      # Move to a position
      Roarm.Robot.move_to_position(%{x: 100.0, y: 0.0, z: 150.0, t: 0.0})

      # Control joints
      Roarm.Robot.move_joints(%{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0})

      # Set LED color
      Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})

  ## Modules

  - `Roarm.Communication` - Low-level UART communication
  - `Roarm.Robot` - High-level robot control
  - `Roarm.Config` - Configuration management
  - `Roarm.Demo` - Demo and testing utilities
  - `Roarm.Debug` - Debug and troubleshooting tools
  """

  alias Roarm.Communication
  alias Roarm.Config
  alias Roarm.Robot

  @registry_name Roarm.Registry

  @doc """
  Start the Roarm registry.
  """
  def start_registry do
    Registry.start_link(keys: :unique, name: @registry_name)
  end

  @doc """
  Get the registry name used by Roarm.
  """
  def registry_name, do: @registry_name

  @doc """
  Convenience function to start a robot with given configuration.

  Uses application configuration as defaults, with provided options taking precedence.

  ## Parameters
    - `opts` - Configuration options (overrides config.exs values)
      - `:robot_type` - Type of robot (:roarm_m2, :roarm_m2_pro, :roarm_m3, :roarm_m3_pro)
      - `:port` - Serial port path
      - `:baudrate` - Communication speed (default: 115200)
      - `:name` - Process name for registry

  ## Examples
      # Using configuration from config.exs
      Roarm.start_robot()

      # Override specific options
      Roarm.start_robot(port: "/dev/ttyUSB1", robot_type: :roarm_m3)
  """
  def start_robot(opts \\ []) do
    # Ensure registry is started
    case start_registry() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      error -> error
    end

    # Merge configuration with provided options
    config_opts = [
      robot_type: Config.get_robot_type(),
      port: Config.get(:port),
      baudrate: Config.get_baudrate(),
      name: Config.get_robot_server_name()
    ]
    merged_opts = Keyword.merge(config_opts, opts)

    # Extract values
    name = Keyword.get(merged_opts, :name, Robot)
    comm_name = Config.get_communication_server_name()

    # Prepare options for robot
    robot_opts = Keyword.put(merged_opts, :name, name)
    comm_opts = [name: comm_name]

    with {:ok, _comm_pid} <- Communication.start_link(comm_opts),
         {:ok, robot_pid} <- Robot.start_link(robot_opts),
         :ok <- Robot.connect(server_name: name) do
      {:ok, robot_pid}
    else
      error -> error
    end
  end

  @doc """
  List available serial ports on the system.
  """
  def list_ports do
    Communication.list_ports()
  end

  @doc """
  Quick connection test to verify robot communication.
  """
  def test_connection(port, opts \\ []) do
    robot_opts = Keyword.merge([port: port], opts)

    case start_robot(robot_opts) do
      {:ok, _pid} ->
        case Robot.get_position() do
          {:ok, position} ->
            Robot.disconnect()
            {:ok, position}

          error ->
            Robot.disconnect()
            error
        end

      error ->
        error
    end
  end
end
