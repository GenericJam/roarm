#!/usr/bin/env elixir

# Teaching functionality example for RoarmElixir
# Run with: elixir examples/teach_example.exs

Mix.install([
  {:roarm_elixir, path: "."}
])

defmodule TeachExample do
  @moduledoc """
  Examples demonstrating the teaching functionality of RoarmElixir.
  """

  alias RoarmElixir.{Robot, Demo}

  def run do
    IO.puts("RoarmElixir Teaching Examples")
    IO.puts("=" * 40)

    # Get port from user
    port = get_port_input()

    if port do
      case connect_robot(port) do
        :ok ->
          show_teaching_menu()
          Robot.disconnect()

        {:error, reason} ->
          IO.puts("Failed to connect: #{inspect(reason)}")
      end
    else
      IO.puts("No port specified - showing teaching concepts only")
      show_teaching_concepts()
    end
  end

  defp get_port_input do
    port = IO.gets("Enter serial port (or press Enter to skip): ")
    |> String.trim()

    case port do
      "" -> nil
      port -> port
    end
  end

  defp connect_robot(port) do
    case RoarmElixir.start_robot(port: port, robot_type: :roarm_m2) do
      {:ok, _pid} ->
        IO.puts("✓ Robot connected successfully")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp show_teaching_menu do
    IO.puts("\nTeaching Examples:")
    IO.puts("1. Basic drag teach example")
    IO.puts("2. Mission recording example")
    IO.puts("3. Torque control example")
    IO.puts("4. Interactive teaching session")
    IO.puts("5. Run demo suite")

    choice = IO.gets("Select example (1-5): ") |> String.trim()

    case choice do
      "1" -> basic_drag_teach()
      "2" -> mission_example()
      "3" -> torque_control_example()
      "4" -> Demo.interactive_teaching()
      "5" -> Demo.teaching_demo()
      _ -> IO.puts("Invalid selection")
    end
  end

  defp basic_drag_teach do
    IO.puts("\n=== Basic Drag Teach Example ===")

    filename = "example_movement.json"

    IO.puts("This example will:")
    IO.puts("1. Disable robot torque so you can move it manually")
    IO.puts("2. Record your movements for 10 seconds")
    IO.puts("3. Re-enable torque and replay the movement")

    if confirm("Continue? (y/n): ") do
      # Start teaching
      case Robot.drag_teach_start(filename, sample_rate: 50) do
        :ok ->
          IO.puts("✓ Drag teach started!")
          IO.puts("  Torque is now disabled - manually move the robot arm")
          IO.puts("  Recording will stop automatically in 10 seconds...")

          # Record for 10 seconds
          :timer.sleep(10_000)

          case Robot.drag_teach_stop() do
            {:ok, sample_count} ->
              IO.puts("✓ Recording complete! Captured #{sample_count} samples")

              if confirm("Replay the movement? (y/n): ") do
                IO.puts("Replaying movement...")

                case Robot.drag_teach_replay(filename) do
                  :ok ->
                    IO.puts("✓ Replay completed")
                  {:error, reason} ->
                    IO.puts("✗ Replay failed: #{inspect(reason)}")
                end
              end

            {:error, reason} ->
              IO.puts("✗ Failed to stop recording: #{inspect(reason)}")
          end

        {:error, reason} ->
          IO.puts("✗ Failed to start drag teach: #{inspect(reason)}")
      end
    end
  end

  defp mission_example do
    IO.puts("\n=== Mission Recording Example ===")

    mission_name = "elixir_example"

    IO.puts("This example will:")
    IO.puts("1. Create a mission named '#{mission_name}'")
    IO.puts("2. Move through several positions and record them")
    IO.puts("3. Add delays between movements")
    IO.puts("4. Play back the entire sequence")

    if confirm("Continue? (y/n): ") do
      # Create mission
      case Robot.create_mission(mission_name, "Example mission from Elixir") do
        {:ok, _} ->
          IO.puts("✓ Mission created")

          # Define a sequence of movements
          movements = [
            {%{j1: 0, j2: 0, j3: 0, j4: 0}, "Home position"},
            {%{j1: 45, j2: 0, j3: 0, j4: 0}, "Turn base 45 degrees"},
            {%{j1: 45, j2: 30, j3: -15, j4: 0}, "Lift arm"},
            {%{j1: 45, j2: 30, j3: -15, j4: 90}, "Rotate wrist"},
            {%{j1: 0, j2: 0, j3: 0, j4: 0}, "Return home"}
          ]

          # Execute and record each movement
          Enum.each(movements, fn {position, description} ->
            IO.puts("Moving to: #{description}")

            case Robot.move_joints(position) do
              {:ok, _} ->
                :timer.sleep(2000)  # Wait for movement

                case Robot.add_mission_step(mission_name, 0.3) do
                  {:ok, _} ->
                    IO.puts("✓ Recorded step")

                  {:error, reason} ->
                    IO.puts("✗ Failed to record: #{inspect(reason)}")
                end

              {:error, reason} ->
                IO.puts("✗ Movement failed: #{inspect(reason)}")
            end
          end)

          # Add a pause in the sequence
          case Robot.add_mission_delay(mission_name, 3000) do
            {:ok, _} ->
              IO.puts("✓ Added 3-second pause")

            {:error, reason} ->
              IO.puts("✗ Failed to add delay: #{inspect(reason)}")
          end

          if confirm("Play the mission? (y/n): ") do
            case Robot.play_mission(mission_name, 2) do
              {:ok, _} ->
                IO.puts("✓ Mission playback started (will repeat 2 times)")

              {:error, reason} ->
                IO.puts("✗ Playback failed: #{inspect(reason)}")
            end
          end

        {:error, reason} ->
          IO.puts("✗ Failed to create mission: #{inspect(reason)}")
      end
    end
  end

  defp torque_control_example do
    IO.puts("\n=== Torque Control Example ===")

    IO.puts("This example demonstrates torque control:")
    IO.puts("- Torque enabled = joints locked, robot holds position")
    IO.puts("- Torque disabled = joints free, you can move robot manually")

    if confirm("Continue? (y/n): ") do
      IO.puts("\nStep 1: Disabling torque...")

      case Robot.set_torque_enabled(false) do
        {:ok, _} ->
          IO.puts("✓ Torque disabled")
          IO.puts("  Try gently moving the robot arm - it should move freely")
          IO.gets("Press Enter when you've tried moving it...")

          IO.puts("\nStep 2: Re-enabling torque...")

          case Robot.set_torque_enabled(true) do
            {:ok, _} ->
              IO.puts("✓ Torque re-enabled")
              IO.puts("  The robot should now hold its current position firmly")

            {:error, reason} ->
              IO.puts("✗ Failed to re-enable torque: #{inspect(reason)}")
          end

        {:error, reason} ->
          IO.puts("✗ Failed to disable torque: #{inspect(reason)}")
      end
    end
  end

  defp show_teaching_concepts do
    IO.puts("\n=== Teaching Functionality Overview ===")

    IO.puts("""

    The RoarmElixir library includes two main teaching approaches:

    ## 1. Drag Teach (Continuous Recording)
    - `Robot.drag_teach_start(filename)` - Start recording
    - Disables torque so you can manually move the robot
    - Records joint positions continuously (default: every 100ms)
    - `Robot.drag_teach_stop()` - Stop and save recording
    - `Robot.drag_teach_replay(filename)` - Replay the movement

    ## 2. Mission Recording (Step-by-Step)
    - `Robot.create_mission(name, description)` - Create new mission
    - `Robot.add_mission_step(name, speed)` - Add current position
    - `Robot.add_mission_delay(name, milliseconds)` - Add pause
    - `Robot.play_mission(name, times)` - Execute sequence

    ## 3. Torque Control
    - `Robot.set_torque_enabled(false)` - Allow manual movement
    - `Robot.set_torque_enabled(true)` - Lock joints in position

    ## Example Usage:
    ```elixir
    # Connect to robot
    {:ok, _} = RoarmElixir.start_robot(port: "/dev/cu.usbserial-110")

    # Drag teach example
    Robot.drag_teach_start("my_movement.json")
    # ... manually move robot ...
    Robot.drag_teach_stop()
    Robot.drag_teach_replay("my_movement.json")

    # Mission example
    Robot.create_mission("pick_and_place", "Pick up object and move it")
    Robot.move_joints(%{j1: 0, j2: 30, j3: -15, j4: 0})
    Robot.add_mission_step("pick_and_place", 0.5)
    Robot.add_mission_delay("pick_and_place", 2000)
    Robot.play_mission("pick_and_place", 1)
    ```

    """)
  end

  defp confirm(prompt) do
    response = IO.gets(prompt) |> String.trim() |> String.downcase()
    response in ["y", "yes"]
  end
end

# Run the example
TeachExample.run()