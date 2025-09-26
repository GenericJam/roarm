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

  ## Quick Start

      # Start the communication process
      {:ok, _} = Roarm.Communication.start_link()

      # Start a robot controller
      {:ok, _} = Roarm.Robot.start_link(
        robot_type: :roarm_m2,
        port: "/dev/ttyUSB0",
        baudrate: 115200
      )

      # Connect to the robot
      :ok = Roarm.Robot.connect()

      # Move to a position
      Roarm.Robot.move_to_position(%{x: 100.0, y: 0.0, z: 150.0, t: 0.0})

      # Control joints
      Roarm.Robot.move_joints(%{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0})

      # Set LED color
      Roarm.Robot.set_led(%{r: 255, g: 0, b: 0})

  ## Modules

  - `Roarm.Communication` - Low-level UART communication
  - `Roarm.Robot` - High-level robot control
  - `Roarm.Demo` - Demo and testing utilities
  - `Roarm.Debug` - Debug and troubleshooting tools
  """

  alias Roarm.{Communication, Robot}

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

  ## Parameters
    - `opts` - Configuration options including :robot_type, :port, :baudrate

  ## Example
      Roarm.start_robot(robot_type: :roarm_m2, port: "/dev/ttyUSB0")
  """
  def start_robot(opts \\ []) do
    # Ensure registry is started
    case start_registry() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      error -> error
    end

    # Set default name if none provided
    name = Keyword.get(opts, :name, Robot)
    opts_with_name = Keyword.put(opts, :name, name)

    with {:ok, _comm_pid} <- Communication.start_link(),
         {:ok, robot_pid} <- Robot.start_link(opts_with_name),
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
