#!/usr/bin/env elixir

# Basic usage example for Roarm
# Run with: elixir examples/basic_usage.exs

Mix.install([
  {:roarm, path: "."}
])

defmodule BasicUsage do
  @moduledoc """
  Basic usage examples for the Roarm library.
  """
  require Logger

  def run do
    Logger.info("Roarm Basic Usage Example")
    Logger.info("=" * 40)

    # List available ports
    Logger.info("\n1. Available serial ports:")
    ports = Roarm.list_ports()
    Enum.each(ports, fn {port, info} ->
      Logger.info("   #{port}: #{inspect(info)}")
    end)

    # Get port from user or use default
    port = get_port_input()

    if port do
      # Test connection
      Logger.info("\n2. Testing connection...")
      test_connection(port)

      # Demonstrate robot control
      Logger.info("\n3. Robot control demonstration...")
      robot_demo(port)
    else
      Logger.info("\nSkipping robot demonstrations (no port specified)")
    end

    Logger.info("\nExample completed!")
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
    case Roarm.test_connection(port) do
      {:ok, position} ->
        Logger.info("✓ Connection successful!")
        Logger.info("  Current position: #{inspect(position)}")
        true

      {:error, reason} ->
        Logger.info("✗ Connection failed: #{inspect(reason)}")
        false
    end
  end

  defp robot_demo(port) do
    robot_opts = [
      robot_type: :roarm_m2,
      port: port,
      baudrate: 115200
    ]

    case Roarm.start_robot(robot_opts) do
      {:ok, _pid} ->
        Logger.info("✓ Robot started successfully")

        # Demonstrate basic movements
        demonstrate_positions()
        demonstrate_joints()
        demonstrate_features()

        # Cleanup
        Roarm.Robot.disconnect()
        Logger.info("✓ Robot disconnected")

      {:error, reason} ->
        Logger.info("✗ Failed to start robot: #{inspect(reason)}")
    end
  end

  defp demonstrate_positions do
    Logger.info("\n--- Position Control ---")

    positions = [
      %{x: 100.0, y: 0.0, z: 150.0, t: 0.0},
      %{x: 0.0, y: 100.0, z: 150.0, t: 0.0},
      %{x: 0.0, y: 0.0, z: 200.0, t: 0.0}
    ]

    Enum.each(positions, fn pos ->
      Logger.info("Moving to: #{inspect(pos)}")

      case Roarm.Robot.move_to_position(pos) do
        {:ok, _} ->
          Logger.info("✓ Command sent successfully")
          :timer.sleep(1000)

        {:error, reason} ->
          Logger.info("✗ Move failed: #{inspect(reason)}")
      end
    end)

    # Return home
    Logger.info("Returning to home position...")
    case Roarm.Robot.home() do
      {:ok, _} -> Logger.info("✓ Homed successfully")
      {:error, reason} -> Logger.info("✗ Home failed: #{inspect(reason)}")
    end
  end

  defp demonstrate_joints do
    Logger.info("\n--- Joint Control ---")

    joint_configs = [
      %{j1: 0.0, j2: 0.0, j3: 0.0, j4: 0.0},
      %{j1: 30.0, j2: 45.0, j3: -30.0, j4: 0.0},
      %{j1: -30.0, j2: -45.0, j3: 30.0, j4: 0.0}
    ]

    Enum.each(joint_configs, fn joints ->
      Logger.info("Moving joints to: #{inspect(joints)}")

      case Roarm.Robot.move_joints(joints) do
        {:ok, _} ->
          Logger.info("✓ Joint command sent")
          :timer.sleep(1000)

        {:error, reason} ->
          Logger.info("✗ Joint move failed: #{inspect(reason)}")
      end
    end)
  end

  defp demonstrate_features do
    Logger.info("\n--- Hardware Features ---")

    # LED demonstration
    Logger.info("Testing LED colors...")
    colors = [
      {%{r: 255, g: 0, b: 0}, "Red"},
      {%{r: 0, g: 255, b: 0}, "Green"},
      {%{r: 0, g: 0, b: 255}, "Blue"},
      {%{r: 0, g: 0, b: 0}, "Off"}
    ]

    Enum.each(colors, fn {color, name} ->
      Logger.info("  Setting LED to #{name}")

      case Roarm.Robot.set_led(color) do
        {:ok, _} -> :timer.sleep(500)
        {:error, reason} -> Logger.info("    ✗ LED failed: #{inspect(reason)}")
      end
    end)

    # Torque lock demonstration
    Logger.info("Testing torque lock...")
    case Roarm.Robot.set_torque_lock(true) do
      {:ok, _} ->
        Logger.info("  ✓ Torque lock enabled")
        :timer.sleep(1000)

        case Roarm.Robot.set_torque_lock(false) do
          {:ok, _} -> Logger.info("  ✓ Torque lock disabled")
          {:error, reason} -> Logger.info("  ✗ Torque unlock failed: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.info("  ✗ Torque lock failed: #{inspect(reason)}")
    end

    # Status queries
    Logger.info("Querying robot status...")
    case Roarm.Robot.get_position() do
      {:ok, position} ->
        Logger.info("  Current position: #{inspect(position)}")

      {:error, reason} ->
        Logger.info("  ✗ Get position failed: #{inspect(reason)}")
    end

    case Roarm.Robot.get_joints() do
      {:ok, joints} ->
        Logger.info("  Current joints: #{inspect(joints)}")

      {:error, reason} ->
        Logger.info("  ✗ Get joints failed: #{inspect(reason)}")
    end
  end
end

# Run the example
BasicUsage.run()