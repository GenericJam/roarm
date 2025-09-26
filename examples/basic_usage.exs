#!/usr/bin/env elixir

# Basic usage example for RoarmElixir
# Run with: elixir examples/basic_usage.exs

Mix.install([
  {:roarm_elixir, path: "."}
])

defmodule BasicUsage do
  @moduledoc """
  Basic usage examples for the RoarmElixir library.
  """

  def run do
    IO.puts("RoarmElixir Basic Usage Example")
    IO.puts("=" * 40)

    # List available ports
    IO.puts("\n1. Available serial ports:")
    ports = RoarmElixir.list_ports()
    Enum.each(ports, fn {port, info} ->
      IO.puts("   #{port}: #{inspect(info)}")
    end)

    # Get port from user or use default
    port = get_port_input()

    if port do
      # Test connection
      IO.puts("\n2. Testing connection...")
      test_connection(port)

      # Demonstrate robot control
      IO.puts("\n3. Robot control demonstration...")
      robot_demo(port)
    else
      IO.puts("\nSkipping robot demonstrations (no port specified)")
    end

    IO.puts("\nExample completed!")
  end

  defp get_port_input do
    port = IO.gets("Enter serial port (or press Enter to skip): ")
    |> String.trim()

    case port do
      "" -> nil
      port -> port
    end
  end

  defp test_connection(port) do
    case RoarmElixir.test_connection(port) do
      {:ok, position} ->
        IO.puts("✓ Connection successful!")
        IO.puts("  Current position: #{inspect(position)}")
        true

      {:error, reason} ->
        IO.puts("✗ Connection failed: #{inspect(reason)}")
        false
    end
  end

  defp robot_demo(port) do
    robot_opts = [
      robot_type: :roarm_m2,
      port: port,
      baudrate: 115200
    ]

    case RoarmElixir.start_robot(robot_opts) do
      {:ok, _pid} ->
        IO.puts("✓ Robot started successfully")

        # Demonstrate basic movements
        demonstrate_positions()
        demonstrate_joints()
        demonstrate_features()

        # Cleanup
        RoarmElixir.Robot.disconnect()
        IO.puts("✓ Robot disconnected")

      {:error, reason} ->
        IO.puts("✗ Failed to start robot: #{inspect(reason)}")
    end
  end

  defp demonstrate_positions do
    IO.puts("\n--- Position Control ---")

    positions = [
      %{x: 100.0, y: 0.0, z: 150.0, t: 0.0},
      %{x: 0.0, y: 100.0, z: 150.0, t: 0.0},
      %{x: 0.0, y: 0.0, z: 200.0, t: 0.0}
    ]

    Enum.each(positions, fn pos ->
      IO.puts("Moving to: #{inspect(pos)}")

      case RoarmElixir.Robot.move_to_position(pos) do
        {:ok, _} ->
          IO.puts("✓ Command sent successfully")
          :timer.sleep(1000)

        {:error, reason} ->
          IO.puts("✗ Move failed: #{inspect(reason)}")
      end
    end)

    # Return home
    IO.puts("Returning to home position...")
    case RoarmElixir.Robot.home() do
      {:ok, _} -> IO.puts("✓ Homed successfully")
      {:error, reason} -> IO.puts("✗ Home failed: #{inspect(reason)}")
    end
  end

  defp demonstrate_joints do
    IO.puts("\n--- Joint Control ---")

    joint_configs = [
      %{j1: 0.0, j2: 0.0, j3: 0.0, j4: 0.0},
      %{j1: 30.0, j2: 45.0, j3: -30.0, j4: 0.0},
      %{j1: -30.0, j2: -45.0, j3: 30.0, j4: 0.0}
    ]

    Enum.each(joint_configs, fn joints ->
      IO.puts("Moving joints to: #{inspect(joints)}")

      case RoarmElixir.Robot.move_joints(joints) do
        {:ok, _} ->
          IO.puts("✓ Joint command sent")
          :timer.sleep(1000)

        {:error, reason} ->
          IO.puts("✗ Joint move failed: #{inspect(reason)}")
      end
    end)
  end

  defp demonstrate_features do
    IO.puts("\n--- Hardware Features ---")

    # LED demonstration
    IO.puts("Testing LED colors...")
    colors = [
      {%{r: 255, g: 0, b: 0}, "Red"},
      {%{r: 0, g: 255, b: 0}, "Green"},
      {%{r: 0, g: 0, b: 255}, "Blue"},
      {%{r: 0, g: 0, b: 0}, "Off"}
    ]

    Enum.each(colors, fn {color, name} ->
      IO.puts("  Setting LED to #{name}")

      case RoarmElixir.Robot.set_led(color) do
        {:ok, _} -> :timer.sleep(500)
        {:error, reason} -> IO.puts("    ✗ LED failed: #{inspect(reason)}")
      end
    end)

    # Torque lock demonstration
    IO.puts("Testing torque lock...")
    case RoarmElixir.Robot.set_torque_lock(true) do
      {:ok, _} ->
        IO.puts("  ✓ Torque lock enabled")
        :timer.sleep(1000)

        case RoarmElixir.Robot.set_torque_lock(false) do
          {:ok, _} -> IO.puts("  ✓ Torque lock disabled")
          {:error, reason} -> IO.puts("  ✗ Torque unlock failed: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("  ✗ Torque lock failed: #{inspect(reason)}")
    end

    # Status queries
    IO.puts("Querying robot status...")
    case RoarmElixir.Robot.get_position() do
      {:ok, position} ->
        IO.puts("  Current position: #{inspect(position)}")

      {:error, reason} ->
        IO.puts("  ✗ Get position failed: #{inspect(reason)}")
    end

    case RoarmElixir.Robot.get_joints() do
      {:ok, joints} ->
        IO.puts("  Current joints: #{inspect(joints)}")

      {:error, reason} ->
        IO.puts("  ✗ Get joints failed: #{inspect(reason)}")
    end
  end
end

# Run the example
BasicUsage.run()