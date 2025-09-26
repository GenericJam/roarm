defmodule Roarm.Debug do
  @moduledoc """
  Debug and troubleshooting utilities for RoArm communication.

  This module provides tools to help diagnose communication issues
  and test the robot connection step by step.
  """

  alias Roarm.{Communication, Robot}
  require Logger

  @doc """
  Test raw serial communication without high-level protocols.
  """
  def test_raw_serial(port, opts \\ []) do
    IO.puts("Testing raw serial communication on #{port}")

    case Communication.start_link() do
      {:ok, _pid} ->
        case Communication.connect(port, opts) do
          :ok ->
            IO.puts("✓ Serial connection established")
            run_raw_tests()
            Communication.disconnect()

          {:error, reason} ->
            IO.puts("✗ Serial connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("✗ Failed to start communication process: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Test individual RoArm commands step by step.
  """
  def test_commands(port, opts \\ []) do
    IO.puts("Testing RoArm commands on #{port}")
    IO.puts("Enable debug logging with: Logger.configure(level: :debug)")

    robot_opts = Keyword.merge([port: port], opts)

    case Robot.start_link(robot_opts) do
      {:ok, _pid} ->
        case Robot.connect() do
          :ok ->
            IO.puts("✓ Robot connection established")
            run_command_tests()
            Robot.disconnect()

          {:error, reason} ->
            IO.puts("✗ Robot connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("✗ Failed to start robot process: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Monitor serial communication in real-time.
  """
  def monitor_serial(port, opts \\ []) do
    IO.puts("Starting serial monitor on #{port}")
    IO.puts("Press Ctrl+C to stop")

    case Communication.start_link() do
      {:ok, _pid} ->
        case Communication.connect(port, opts) do
          :ok ->
            IO.puts("✓ Connected. Type commands (JSON format) or 'quit' to exit:")
            monitor_loop()
            Communication.disconnect()

          {:error, reason} ->
            IO.puts("✗ Connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("✗ Failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Test hardware initialization sequence.
  """
  def test_initialization(port, opts \\ []) do
    IO.puts("Testing RoArm initialization sequence on #{port}")

    case Communication.start_link() do
      {:ok, _pid} ->
        case Communication.connect(port, opts) do
          :ok ->
            IO.puts("✓ Serial connection established")

            # Step 1: Send initialization command
            IO.puts("\nStep 1: Sending initialization command (T:100)")
            init_cmd = Jason.encode!(%{"T" => 100})

            case Communication.send_command(init_cmd, 5000) do
              {:ok, response} ->
                IO.puts("✓ Initialization response: #{response}")

                # Step 2: Wait for robot to settle
                IO.puts("\nStep 2: Waiting for robot to initialize...")
                :timer.sleep(3000)

                # Step 3: Request status
                IO.puts("\nStep 3: Requesting robot status (T:105)")
                status_cmd = Jason.encode!(%{"T" => 105})

                case Communication.send_command(status_cmd, 2000) do
                  {:ok, status_response} ->
                    IO.puts("✓ Status response: #{status_response}")

                    # Step 4: Test simple movement
                    IO.puts("\nStep 4: Testing simple joint movement")
                    test_simple_movement()

                  {:error, reason} ->
                    IO.puts("✗ Status request failed: #{inspect(reason)}")
                end

              {:error, reason} ->
                IO.puts("✗ Initialization failed: #{inspect(reason)}")
            end

            Communication.disconnect()

          {:error, reason} ->
            IO.puts("✗ Connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        IO.puts("✗ Failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp run_raw_tests do
    IO.puts("\n--- Raw Serial Tests ---")

    # Test basic communication
    test_commands = [
      "AT",           # Basic AT command
      "?\n",          # Query command
      "{\"T\":105}",  # Status request
      "{\"T\":100}"   # Initialize
    ]

    Enum.each(test_commands, fn cmd ->
      IO.puts("Sending: #{cmd}")

      case Communication.send_raw(cmd <> "\n") do
        :ok ->
          IO.puts("✓ Command sent")
          :timer.sleep(1000)  # Wait for response

        {:error, reason} ->
          IO.puts("✗ Send failed: #{inspect(reason)}")
      end
    end)
  end

  defp run_command_tests do
    IO.puts("\n--- RoArm Command Tests ---")

    tests = [
      {"Initialize (Home)", fn -> Robot.home() end},
      {"Get Position", fn -> Robot.get_position() end},
      {"Get Joints", fn -> Robot.get_joints() end},
      {"Small Joint Movement", fn ->
        Robot.move_joints(%{j1: 5.0, j2: 0.0, j3: 0.0, j4: 0.0})
      end},
      {"Return to Zero", fn ->
        Robot.move_joints(%{j1: 0.0, j2: 0.0, j3: 0.0, j4: 0.0})
      end},
      {"LED Test", fn -> Robot.set_led(%{r: 255, g: 0, b: 0}) end}
    ]

    Enum.each(tests, fn {name, test_fn} ->
      IO.puts("Testing: #{name}")

      case test_fn.() do
        {:ok, response} ->
          IO.puts("✓ Success: #{inspect(response)}")
          :timer.sleep(2000)  # Wait between commands

        {:error, reason} ->
          IO.puts("✗ Failed: #{inspect(reason)}")
      end
    end)
  end

  defp monitor_loop do
    input = IO.gets("> ") |> String.trim()

    case input do
      "quit" ->
        IO.puts("Exiting monitor")

      "" ->
        monitor_loop()

      command ->
        case Communication.send_command(command) do
          {:ok, response} ->
            IO.puts("Response: #{response}")

          {:error, reason} ->
            IO.puts("Error: #{inspect(reason)}")
        end

        monitor_loop()
    end
  end

  defp test_simple_movement do
    # Test very small movement to see if robot responds
    move_cmd = Jason.encode!(%{
      "T" => 122,
      "b" => 5,    # 5 degrees base rotation
      "s" => 0,
      "e" => 0,
      "h" => 0,
      "spd" => 5,  # Slow speed
      "acc" => 5
    })

    case Communication.send_command(move_cmd, 3000) do
      {:ok, response} ->
        IO.puts("✓ Movement response: #{response}")
        :timer.sleep(2000)

        # Return to zero
        return_cmd = Jason.encode!(%{
          "T" => 122,
          "b" => 0, "s" => 0, "e" => 0, "h" => 0,
          "spd" => 5, "acc" => 5
        })

        case Communication.send_command(return_cmd, 3000) do
          {:ok, return_response} ->
            IO.puts("✓ Return movement response: #{return_response}")

          {:error, reason} ->
            IO.puts("✗ Return movement failed: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("✗ Movement failed: #{inspect(reason)}")
    end
  end
end