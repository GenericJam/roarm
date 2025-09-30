defmodule Roarm.Debug do
  @moduledoc """
  Debug and troubleshooting utilities for RoArm communication.

  This module provides tools to help diagnose communication issues
  and test the robot connection step by step.
  """

  require Logger
  alias Roarm.Communication
  alias Roarm.Robot

  @doc """
  Test raw serial communication without high-level protocols.
  """
  def test_raw_serial(port, opts \\ []) do
    Logger.info("Testing raw serial communication on #{port}")

    case Communication.start_link() do
      {:ok, _pid} ->
        case Communication.connect(port, opts) do
          :ok ->
            Logger.info("✓ Serial connection established")
            run_raw_tests()
            Communication.disconnect()

          {:error, reason} ->
            Logger.info("✗ Serial connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.info("✗ Failed to start communication process: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Test individual RoArm commands step by step.
  """
  def test_commands(port, opts \\ []) do
    Logger.info("Testing RoArm commands on #{port}")
    Logger.info("Enable debug logging with: Logger.configure(level: :debug)")

    robot_opts = Keyword.merge([port: port], opts)

    case Robot.start_link(robot_opts) do
      {:ok, _pid} ->
        case Robot.connect() do
          :ok ->
            Logger.info("✓ Robot connection established")
            run_command_tests()
            Robot.disconnect()

          {:error, reason} ->
            Logger.info("✗ Robot connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.info("✗ Failed to start robot process: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Monitor serial communication in real-time.
  """
  def monitor_serial(port, opts \\ []) do
    Logger.info("Starting serial monitor on #{port}")
    Logger.info("Press Ctrl+C to stop")

    case Communication.start_link() do
      {:ok, _pid} ->
        case Communication.connect(port, opts) do
          :ok ->
            Logger.info("✓ Connected. Type commands (JSON format) or 'quit' to exit:")
            monitor_loop()
            Communication.disconnect()

          {:error, reason} ->
            Logger.info("✗ Connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.info("✗ Failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Test hardware initialization sequence.
  """
  def test_initialization(port, opts \\ []) do
    Logger.info("Testing RoArm initialization sequence on #{port}")

    case Communication.start_link() do
      {:ok, _pid} ->
        case Communication.connect(port, opts) do
          :ok ->
            Logger.info("✓ Serial connection established")

            # Step 1: Send initialization command
            Logger.info("\nStep 1: Sending initialization command (T:100)")
            init_cmd = Jason.encode!(%{"T" => 100})

            case Communication.send_command(init_cmd, 5000) do
              {:ok, response} ->
                Logger.info("✓ Initialization response: #{response}")

                # Step 2: Wait for robot to settle
                Logger.info("\nStep 2: Waiting for robot to initialize...")
                :timer.sleep(3000)

                # Step 3: Request status
                Logger.info("\nStep 3: Requesting robot status (T:105)")
                status_cmd = Jason.encode!(%{"T" => 105})

                case Communication.send_command(status_cmd, 2000) do
                  {:ok, status_response} ->
                    Logger.info("✓ Status response: #{status_response}")

                    # Step 4: Test simple movement
                    Logger.info("\nStep 4: Testing simple joint movement")
                    test_simple_movement()

                  {:error, reason} ->
                    Logger.info("✗ Status request failed: #{inspect(reason)}")
                end

              {:error, reason} ->
                Logger.info("✗ Initialization failed: #{inspect(reason)}")
            end

            Communication.disconnect()

          {:error, reason} ->
            Logger.info("✗ Connection failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.info("✗ Failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp run_raw_tests do
    Logger.info("\n--- Raw Serial Tests ---")

    # Test basic communication
    test_commands = [
      "AT",           # Basic AT command
      "?\n",          # Query command
      "{\"T\":105}",  # Status request
      "{\"T\":100}"   # Initialize
    ]

    Enum.each(test_commands, fn cmd ->
      Logger.info("Sending: #{cmd}")

      case Communication.send_raw(cmd <> "\n") do
        :ok ->
          Logger.info("✓ Command sent")
          :timer.sleep(1000)  # Wait for response

        {:error, reason} ->
          Logger.info("✗ Send failed: #{inspect(reason)}")
      end
    end)
  end

  defp run_command_tests do
    Logger.info("\n--- RoArm Command Tests ---")

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
      Logger.info("Testing: #{name}")

      case test_fn.() do
        {:ok, response} ->
          Logger.info("✓ Success: #{inspect(response)}")
          :timer.sleep(2000)  # Wait between commands

        {:error, reason} ->
          Logger.info("✗ Failed: #{inspect(reason)}")
      end
    end)
  end

  defp monitor_loop do
    input = IO.gets("> ") |> String.trim()

    case input do
      "quit" ->
        Logger.info("Exiting monitor")

      "" ->
        monitor_loop()

      command ->
        case Communication.send_command(command) do
          {:ok, response} ->
            Logger.info("Response: #{response}")

          {:error, reason} ->
            Logger.info("Error: #{inspect(reason)}")
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
        Logger.info("✓ Movement response: #{response}")
        :timer.sleep(2000)

        # Return to zero
        return_cmd = Jason.encode!(%{
          "T" => 122,
          "b" => 0, "s" => 0, "e" => 0, "h" => 0,
          "spd" => 5, "acc" => 5
        })

        case Communication.send_command(return_cmd, 3000) do
          {:ok, return_response} ->
            Logger.info("✓ Return movement response: #{return_response}")

          {:error, reason} ->
            Logger.info("✗ Return movement failed: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.info("✗ Movement failed: #{inspect(reason)}")
    end
  end
end