defmodule Roarm.Demo do
  @moduledoc """
  Demo and testing utilities for RoArm robot control.

  This module provides interactive demonstrations and testing functions
  to verify robot connectivity and functionality.
  """

  alias Roarm.{Communication, Robot}
  require Logger

  @doc """
  Interactive demo that guides the user through robot setup and testing.
  """
  def interactive_demo do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("RoArm Elixir Interactive Demo")
    IO.puts(String.duplicate("=", 50))

    # List available ports
    IO.puts("\nAvailable serial ports:")
    ports = Communication.list_ports()
    Enum.each(ports, fn {port, info} ->
      IO.puts("  #{port} - #{inspect(info)}")
    end)

    # Get port from user
    port = get_port_input()

    # Get robot type
    robot_type = get_robot_type_input()

    # Start demo
    case start_demo_session(robot_type, port) do
      {:ok, _pid} ->
        run_demo_sequence()
        IO.puts("\nDemo completed successfully!")

      {:error, reason} ->
        IO.puts("\nDemo failed to start: #{inspect(reason)}")
    end
  end

  @doc """
  Run a basic connection test.
  """
  def test_connection(port, opts \\ []) do
    IO.puts("Testing connection to #{port}...")

    case Roarm.test_connection(port, opts) do
      {:ok, position} ->
        IO.puts("✓ Connection successful!")
        IO.puts("  Current position: #{inspect(position)}")
        :ok

      {:error, reason} ->
        IO.puts("✗ Connection failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Run a sequence of movement tests.
  """
  def movement_demo do
    IO.puts("\n--- Movement Demo ---")

    # Test positions
    positions = [
      %{x: 100.0, y: 0.0, z: 150.0, t: 0.0},
      %{x: 0.0, y: 100.0, z: 150.0, t: 0.0},
      %{x: -100.0, y: 0.0, z: 150.0, t: 0.0},
      %{x: 0.0, y: 0.0, z: 200.0, t: 0.0}
    ]

    IO.puts("Testing position movements...")
    Enum.each(positions, fn pos ->
      IO.puts("Moving to: #{inspect(pos)}")

      case Robot.move_to_position(pos, server_name: Robot) do
        {:ok, _response} ->
          IO.puts("✓ Move command sent")
          :timer.sleep(1000)

        {:error, reason} ->
          IO.puts("✗ Move failed: #{inspect(reason)}")
      end
    end)

    # Test joint movements
    IO.puts("\nTesting joint movements...")
    joint_configs = [
      %{j1: 0.0, j2: 0.0, j3: 0.0, j4: 0.0},
      %{j1: 30.0, j2: 45.0, j3: -30.0, j4: 0.0},
      %{j1: -30.0, j2: -45.0, j3: 30.0, j4: 0.0}
    ]

    Enum.each(joint_configs, fn joints ->
      IO.puts("Moving joints to: #{inspect(joints)}")

      case Robot.move_joints(joints, server_name: Robot) do
        {:ok, _response} ->
          IO.puts("✓ Joint move command sent")
          :timer.sleep(1000)

        {:error, reason} ->
          IO.puts("✗ Joint move failed: #{inspect(reason)}")
      end
    end)

    # Return to home
    IO.puts("\nReturning to home position...")
    case Robot.home(server_name: Robot) do
      {:ok, _response} ->
        IO.puts("✓ Returned to home")

      {:error, reason} ->
        IO.puts("✗ Home failed: #{inspect(reason)}")
    end
  end

  @doc """
  Demo LED color cycling.
  """
  def led_demo do
    IO.puts("\n--- LED Demo ---")

    colors = [
      {%{r: 255, g: 0, b: 0}, "Red"},
      {%{r: 0, g: 255, b: 0}, "Green"},
      {%{r: 0, g: 0, b: 255}, "Blue"},
      {%{r: 255, g: 255, b: 0}, "Yellow"},
      {%{r: 255, g: 0, b: 255}, "Magenta"},
      {%{r: 0, g: 255, b: 255}, "Cyan"},
      {%{r: 255, g: 255, b: 255}, "White"},
      {%{r: 0, g: 0, b: 0}, "Off"}
    ]

    Enum.each(colors, fn {color, name} ->
      IO.puts("Setting LED to #{name}: #{inspect(color)}")

      case Robot.set_led(color, server_name: Robot) do
        {:ok, _response} ->
          IO.puts("✓ LED color set")
          :timer.sleep(500)

        {:error, reason} ->
          IO.puts("✗ LED failed: #{inspect(reason)}")
      end
    end)
  end

  @doc """
  Demo torque lock functionality.
  """
  def torque_demo do
    IO.puts("\n--- Torque Lock Demo ---")

    IO.puts("Enabling torque lock...")
    case Robot.set_torque_lock(true, server_name: Robot) do
      {:ok, _response} ->
        IO.puts("✓ Torque lock enabled")
        :timer.sleep(2000)

      {:error, reason} ->
        IO.puts("✗ Torque lock enable failed: #{inspect(reason)}")
    end

    IO.puts("Disabling torque lock...")
    case Robot.set_torque_lock(false, server_name: Robot) do
      {:ok, _response} ->
        IO.puts("✓ Torque lock disabled")

      {:error, reason} ->
        IO.puts("✗ Torque lock disable failed: #{inspect(reason)}")
    end
  end

  @doc """
  Run a comprehensive test suite.
  """
  def full_test_suite(port, opts \\ []) do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("RoArm Elixir Full Test Suite")
    IO.puts(String.duplicate("=", 50))

    robot_opts = Keyword.merge([port: port], opts)

    with {:ok, _pid} <- start_demo_session(:roarm_m2, port, robot_opts) do
      IO.puts("\n✓ Connection established")

      # Test position retrieval
      IO.puts("\nTesting position retrieval...")
      case Robot.get_position(server_name: Robot) do
        {:ok, position} ->
          IO.puts("✓ Current position: #{inspect(position)}")

        {:error, reason} ->
          IO.puts("✗ Get position failed: #{inspect(reason)}")
      end

      # Test joint retrieval
      IO.puts("\nTesting joint retrieval...")
      case Robot.get_joints(server_name: Robot) do
        {:ok, joints} ->
          IO.puts("✓ Current joints: #{inspect(joints)}")

        {:error, reason} ->
          IO.puts("✗ Get joints failed: #{inspect(reason)}")
      end

      # Run all demo sequences
      movement_demo()
      led_demo()
      torque_demo()

      IO.puts("\n✓ All tests completed")
      Robot.disconnect(server_name: Robot)

    else
      {:error, reason} ->
        IO.puts("\n✗ Failed to connect: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp get_port_input do
    port = IO.gets("\nEnter serial port path (e.g., /dev/ttyUSB0): ")
    |> String.trim()

    if String.length(port) > 0 do
      port
    else
      "/dev/cu.usbserial-110"
    end
  end

  defp get_robot_type_input do
    IO.puts("\nSupported robot types:")
    IO.puts("  1. roarm_m2 (default)")
    IO.puts("  2. roarm_m2_pro")
    IO.puts("  3. roarm_m3")
    IO.puts("  4. roarm_m3_pro")

    choice = IO.gets("Enter choice (1-4): ") |> String.trim()

    case choice do
      "1" -> :roarm_m2
      "2" -> :roarm_m2_pro
      "3" -> :roarm_m3
      "4" -> :roarm_m3_pro
      _ -> :roarm_m2
    end
  end

  defp start_demo_session(robot_type, port, opts \\ []) do
    robot_opts = Keyword.merge([
      robot_type: robot_type,
      port: port,
      baudrate: 115200
    ], opts)

    case Roarm.start_robot(robot_opts) do
      {:ok, pid} ->
        IO.puts("✓ Robot started successfully")
        {:ok, pid}

      {:error, reason} ->
        IO.puts("✗ Failed to start robot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp run_demo_sequence do
    IO.puts("\nRunning demo sequence...")

    if confirm("Run movement demo? (y/n): ") do
      movement_demo()
    end

    if confirm("Run LED demo? (y/n): ") do
      led_demo()
    end

    if confirm("Run torque lock demo? (y/n): ") do
      torque_demo()
    end

    if confirm("Run teach demo? (y/n): ") do
      teaching_demo()
    end

    if confirm("Run LED demo? (y/n): ") do
      led_demo_advanced()
    end
  end

  @doc """
  Demo LED functionality (mounted on gripper).
  """
  def led_demo_advanced do
    IO.puts("\n--- LED Demo (Gripper-Mounted) ---")

    # Test different LED brightness levels
    brightness_levels = [
      {0, "Off"},
      {64, "25% brightness"},
      {128, "50% brightness"},
      {192, "75% brightness"},
      {255, "Full brightness"}
    ]

    Enum.each(brightness_levels, fn {value, description} ->
      IO.puts("Setting LED: #{description} (#{value}/255)")

      case Robot.led(Robot, :on, value) do
        {:ok, _response} ->
          IO.puts("✓ LED command sent")
          :timer.sleep(1000)

        {:error, reason} ->
          IO.puts("✗ LED failed: #{inspect(reason)}")
      end
    end)

    # Test simple on/off functions
    IO.puts("\nTesting simple on/off functions:")

    IO.puts("Turning LED off...")
    case Robot.led_off(server_name: Robot) do
      {:ok, _} ->
        IO.puts("✓ LED turned off")
        :timer.sleep(2000)

      {:error, reason} ->
        IO.puts("✗ LED off failed: #{inspect(reason)}")
    end

    IO.puts("Turning LED on at full brightness...")
    case Robot.led_on(255, server_name: Robot) do
      {:ok, _} ->
        IO.puts("✓ LED turned on")
        :timer.sleep(2000)

      {:error, reason} ->
        IO.puts("✗ LED on failed: #{inspect(reason)}")
    end

    IO.puts("Setting LED to 50% brightness...")
    case Robot.led_on(128, server_name: Robot) do
      {:ok, _} ->
        IO.puts("✓ LED set to 50% brightness")

      {:error, reason} ->
        IO.puts("✗ LED brightness failed: #{inspect(reason)}")
    end
  end

  @doc """
  Demo teaching functionality - both drag teach and mission recording.
  """
  def teaching_demo do
    IO.puts("\n--- Teaching Demo ---")

    IO.puts("1. Drag Teach Demo")
    IO.puts("2. Mission Recording Demo")
    IO.puts("3. Torque Control Demo")

    choice = IO.gets("Select demo (1-3): ") |> String.trim()

    case choice do
      "1" -> drag_teach_demo()
      "2" -> mission_demo()
      "3" -> torque_demo_advanced()
      _ -> IO.puts("Invalid selection")
    end
  end

  @doc """
  Demonstrate drag teach functionality.
  """
  def drag_teach_demo do
    IO.puts("\n=== Drag Teach Demo ===")
    filename = "demo_movement.json"

    IO.puts("Starting drag teach mode...")
    IO.puts("The robot torque will be disabled so you can manually move it.")
    IO.puts("Move the robot arm to create a sequence, then press Enter to stop.")

    case Robot.drag_teach_start(filename, server_name: Robot) do
      :ok ->
        IO.puts("✓ Drag teach started - manually move the robot arm now!")
        IO.gets("Press Enter when you're done moving the arm...")

        case Robot.drag_teach_stop(server_name: Robot) do
          {:ok, sample_count} ->
            IO.puts("✓ Drag teach completed! Recorded #{sample_count} samples")

            if confirm("Replay the recorded movement? (y/n): ") do
              IO.puts("Replaying movement...")

              case Robot.drag_teach_replay(filename, server_name: Robot) do
                :ok ->
                  IO.puts("✓ Replay completed successfully")

                {:error, reason} ->
                  IO.puts("✗ Replay failed: #{inspect(reason)}")
              end
            end

          {:error, reason} ->
            IO.puts("✗ Failed to stop drag teach: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("✗ Failed to start drag teach: #{inspect(reason)}")
    end
  end

  @doc """
  Demonstrate mission recording functionality.
  """
  def mission_demo do
    IO.puts("\n=== Mission Recording Demo ===")
    mission_name = "demo_mission"

    # Create a new mission
    IO.puts("Creating mission: #{mission_name}")

    case Robot.create_mission(mission_name, "Demo mission created in Elixir", server_name: Robot) do
      {:ok, _} ->
        IO.puts("✓ Mission created")

        # Record some positions
        positions = [
          %{j1: 0, j2: 0, j3: 0, j4: 0},
          %{j1: 30, j2: 0, j3: 0, j4: 0},
          %{j1: 30, j2: 30, j3: 0, j4: 0},
          %{j1: 0, j2: 0, j3: 0, j4: 0}
        ]

        IO.puts("Recording mission steps...")

        Enum.each(positions, fn pos ->
          # Move to position first
          case Robot.move_joints(Robot, pos) do
            {:ok, _} ->
              :timer.sleep(1000)  # Wait for movement

              # Add current position to mission
              case Robot.add_mission_step(mission_name, 0.5, server_name: Robot) do
                {:ok, _} ->
                  IO.puts("✓ Added step: #{inspect(pos)}")

                {:error, reason} ->
                  IO.puts("✗ Failed to add step: #{inspect(reason)}")
              end

            {:error, reason} ->
              IO.puts("✗ Failed to move to position: #{inspect(reason)}")
          end
        end)

        # Add a delay step
        case Robot.add_mission_delay(mission_name, 2000, server_name: Robot) do
          {:ok, _} ->
            IO.puts("✓ Added 2-second delay")

          {:error, reason} ->
            IO.puts("✗ Failed to add delay: #{inspect(reason)}")
        end

        # Play the mission
        if confirm("Play the recorded mission? (y/n): ") do
          IO.puts("Playing mission...")

          case Robot.play_mission(mission_name, 1, server_name: Robot) do
            {:ok, _} ->
              IO.puts("✓ Mission playback started")

            {:error, reason} ->
              IO.puts("✗ Failed to play mission: #{inspect(reason)}")
          end
        end

      {:error, reason} ->
        IO.puts("✗ Failed to create mission: #{inspect(reason)}")
    end
  end

  @doc """
  Advanced torque control demonstration.
  """
  def torque_demo_advanced do
    IO.puts("\n=== Advanced Torque Control Demo ===")

    IO.puts("Testing torque enable/disable...")

    # Disable torque
    IO.puts("Disabling torque - you should be able to move the arm manually")

    case Robot.set_torque_enabled(false, server_name: Robot) do
      {:ok, _} ->
        IO.puts("✓ Torque disabled")
        IO.gets("Try moving the arm manually, then press Enter to continue...")

        # Re-enable torque
        IO.puts("Re-enabling torque - arm should lock in place")

        case Robot.set_torque_enabled(true, server_name: Robot) do
          {:ok, _} ->
            IO.puts("✓ Torque re-enabled")

          {:error, reason} ->
            IO.puts("✗ Failed to re-enable torque: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("✗ Failed to disable torque: #{inspect(reason)}")
    end
  end

  @doc """
  Interactive teaching session.
  """
  def interactive_teaching do
    IO.puts("\n=== Interactive Teaching Session ===")

    loop_teaching_menu()
  end

  defp loop_teaching_menu do
    IO.puts("\nTeaching Options:")
    IO.puts("1. Start drag teach")
    IO.puts("2. Replay saved movement")
    IO.puts("3. Toggle torque on/off")
    IO.puts("4. Create/record mission")
    IO.puts("5. Play mission")
    IO.puts("q. Quit")

    choice = IO.gets("Select option: ") |> String.trim() |> String.downcase()

    case choice do
      "1" ->
        filename = IO.gets("Enter filename to save: ") |> String.trim()
        start_interactive_drag_teach(filename)
        loop_teaching_menu()

      "2" ->
        filename = IO.gets("Enter filename to replay: ") |> String.trim()
        replay_interactive(filename)
        loop_teaching_menu()

      "3" ->
        toggle_torque_interactive()
        loop_teaching_menu()

      "4" ->
        mission_name = IO.gets("Enter mission name: ") |> String.trim()
        create_interactive_mission(mission_name)
        loop_teaching_menu()

      "5" ->
        mission_name = IO.gets("Enter mission name to play: ") |> String.trim()
        play_interactive_mission(mission_name)
        loop_teaching_menu()

      "q" ->
        IO.puts("Exiting teaching session")

      _ ->
        IO.puts("Invalid option")
        loop_teaching_menu()
    end
  end

  defp start_interactive_drag_teach(filename) do
    case Robot.drag_teach_start(filename, server_name: Robot) do
      :ok ->
        IO.puts("Drag teach started. Move the robot and press Enter when done.")
        IO.gets("")

        case Robot.drag_teach_stop(server_name: Robot) do
          {:ok, count} ->
            IO.puts("Recorded #{count} samples to #{filename}")

          {:error, reason} ->
            IO.puts("Error stopping: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("Error starting: #{inspect(reason)}")
    end
  end

  defp replay_interactive(filename) do
    speed = IO.gets("Speed multiplier (1.0 = normal, 0.5 = slow, 2.0 = fast): ")
    |> String.trim()
    |> case do
      "" -> 1.0
      s -> String.to_float(s)
    end

    case Robot.drag_teach_replay(filename, speed_multiplier: speed, server_name: Robot) do
      :ok ->
        IO.puts("Replay completed")

      {:error, reason} ->
        IO.puts("Replay failed: #{inspect(reason)}")
    end
  end

  defp toggle_torque_interactive do
    current = IO.gets("Enable torque? (y/n): ") |> String.trim() |> String.downcase()
    enabled = current in ["y", "yes"]

    case Robot.set_torque_enabled(enabled, server_name: Robot) do
      {:ok, _} ->
        IO.puts("Torque #{if enabled, do: "enabled", else: "disabled"}")

      {:error, reason} ->
        IO.puts("Failed: #{inspect(reason)}")
    end
  end

  defp create_interactive_mission(mission_name) do
    description = IO.gets("Mission description: ") |> String.trim()

    case Robot.create_mission(mission_name, description, server_name: Robot) do
      {:ok, _} ->
        IO.puts("Mission created. Use robot controls to move to positions, then add steps.")

      {:error, reason} ->
        IO.puts("Failed to create mission: #{inspect(reason)}")
    end
  end

  defp play_interactive_mission(mission_name) do
    times_str = IO.gets("Times to repeat (1, -1 for infinite): ") |> String.trim()

    times = case times_str do
      "" -> 1
      "-1" -> -1
      n -> String.to_integer(n)
    end

    case Robot.play_mission(mission_name, times, server_name: Robot) do
      {:ok, _} ->
        IO.puts("Mission playback started")

      {:error, reason} ->
        IO.puts("Failed to play mission: #{inspect(reason)}")
    end
  end

  defp confirm(prompt) do
    response = IO.gets(prompt) |> String.trim() |> String.downcase()
    response in ["y", "yes", ""]
  end
end
