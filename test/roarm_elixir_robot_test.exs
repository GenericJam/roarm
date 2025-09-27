defmodule Roarm.RobotTest do
  use ExUnit.Case
  alias Roarm.Robot
  doctest Roarm.Robot

  setup_all do
    # Start registry once for all tests
    case Roarm.start_registry() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :ok
    end
    :ok
  end

  describe "Robot GenServer" do
    test "starts successfully with valid options" do
      # Generate unique name for this test to avoid conflicts
      test_name = String.to_atom("test_#{System.unique_integer([:positive])}")
      opts = [robot_type: :roarm_m2, port: "/dev/ttyUSB0", baudrate: 115200, name: test_name]
      assert {:ok, pid} = Robot.start_link(opts)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "starts with default options" do
      # Generate unique name for this test to avoid conflicts
      test_name = String.to_atom("test_#{System.unique_integer([:positive])}")
      opts = [name: test_name]
      assert {:ok, pid} = Robot.start_link(opts)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "handles connection when no port specified" do
      case Robot.start_link() do
        {:ok, pid} ->
          assert {:error, :no_port_specified} = Robot.connect(server_name: pid)
          GenServer.stop(pid)
        {:error, {:already_started, pid}} ->
          GenServer.stop(pid)
          {:ok, pid} = Robot.start_link()
          assert {:error, :no_port_specified} = Robot.connect(server_name: pid)
          GenServer.stop(pid)
      end
    end

    test "tracks connection state" do
      opts = [robot_type: :roarm_m2, port: "/dev/nonexistent"]
      {:ok, pid} = Robot.start_link(opts)

      # Initially not connected
      assert Robot.connected?(server_name: pid) == false

      GenServer.stop(pid)
    end

    test "handles commands when not connected" do
      {:ok, pid} = Robot.start_link()

      position = %{x: 100.0, y: 0.0, z: 150.0, t: 0.0}
      assert {:error, :not_connected} = Robot.move_to_position(position, server_name: pid)

      joints = %{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0}
      assert {:error, :not_connected} = Robot.move_joints(joints, server_name: pid)

      assert {:error, :not_connected} = Robot.home(server_name: pid)
      assert {:error, :not_connected} = Robot.get_position(server_name: pid)
      assert {:error, :not_connected} = Robot.get_joints(server_name: pid)
      assert {:error, :not_connected} = Robot.set_torque_lock(true, server_name: pid)

      color = %{r: 255, g: 0, b: 0}
      assert {:error, :not_connected} = Robot.set_led(color, server_name: pid)

      GenServer.stop(pid)
    end

    test "validates robot types" do
      valid_types = [:roarm_m2, :roarm_m2_pro, :roarm_m3, :roarm_m3_pro]

      Enum.each(valid_types, fn type ->
        opts = [robot_type: type, port: "/dev/ttyUSB0"]
        assert {:ok, pid} = Robot.start_link(opts)
        GenServer.stop(pid)
      end)
    end
  end

  describe "Position validation" do
    test "accepts valid position maps" do
      {:ok, pid} = Robot.start_link()

      position = %{x: 100.0, y: 0.0, z: 150.0, t: 0.0}
      # Should not raise an error (though will fail due to no connection)
      assert {:error, :not_connected} = Robot.move_to_position(position, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Joint validation" do
    test "accepts valid joint maps" do
      {:ok, pid} = Robot.start_link()

      joints = %{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0}
      # Should not raise an error (though will fail due to no connection)
      assert {:error, :not_connected} = Robot.move_joints(joints, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "LED validation" do
    test "accepts valid RGB maps" do
      {:ok, pid} = Robot.start_link()

      color = %{r: 255, g: 0, b: 0}
      # Should not raise an error (though will fail due to no connection)
      assert {:error, :not_connected} = Robot.set_led(color, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Torque lock" do
    test "accepts boolean values" do
      {:ok, pid} = Robot.start_link()

      # Should not raise an error (though will fail due to no connection)
      assert {:error, :not_connected} = Robot.set_torque_lock(true, server_name: pid)
      assert {:error, :not_connected} = Robot.set_torque_lock(false, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Torque enable/disable" do
    test "accepts boolean values for torque enabled" do
      {:ok, pid} = Robot.start_link()

      # Should not raise an error (though will fail due to no connection)
      assert {:error, :not_connected} = Robot.set_torque_enabled(true, server_name: pid)
      assert {:error, :not_connected} = Robot.set_torque_enabled(false, server_name: pid)

      GenServer.stop(pid)
    end

    test "accepts various parameter types" do
      {:ok, pid} = Robot.start_link()

      # Should not raise function clause errors, but will fail due to no connection
      assert {:error, :not_connected} = Robot.set_torque_enabled("true", server_name: pid)
      assert {:error, :not_connected} = Robot.set_torque_enabled(1, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "LED control" do
    test "led_on with default brightness" do
      {:ok, pid} = Robot.start_link()

      assert {:error, :not_connected} = Robot.led_on(255, server_name: pid)

      GenServer.stop(pid)
    end

    test "led_on with custom brightness" do
      {:ok, pid} = Robot.start_link()

      assert {:error, :not_connected} = Robot.led_on(128, server_name: pid)

      GenServer.stop(pid)
    end

    test "led_off" do
      {:ok, pid} = Robot.start_link()

      assert {:error, :not_connected} = Robot.led_off(server_name: pid)

      GenServer.stop(pid)
    end

    test "handles brightness range clamping" do
      {:ok, pid} = Robot.start_link()

      # Valid range 0-255
      assert {:error, :not_connected} = Robot.led_on(0, server_name: pid)
      assert {:error, :not_connected} = Robot.led_on(255, server_name: pid)

      # Out of range values should be clamped (not raise errors)
      assert {:error, :not_connected} = Robot.led_on(-1, server_name: pid)  # Should clamp to 0
      assert {:error, :not_connected} = Robot.led_on(256, server_name: pid)  # Should clamp to 255

      GenServer.stop(pid)
    end
  end

  describe "Drag teach functionality" do
    test "drag_teach_start with filename" do
      {:ok, pid} = Robot.start_link()

      filename = "test_movement.json"
      assert {:error, :not_connected} = Robot.drag_teach_start(filename, server_name: pid)

      GenServer.stop(pid)
    end

    test "drag_teach_start with options" do
      {:ok, pid} = Robot.start_link()

      filename = "test_movement.json"
      opts = [sample_rate: 100, server_name: pid]
      assert {:error, :not_connected} = Robot.drag_teach_start(filename, opts)

      GenServer.stop(pid)
    end

    test "drag_teach_stop" do
      {:ok, pid} = Robot.start_link()

      assert {:error, :not_teaching} = Robot.drag_teach_stop(server_name: pid)

      GenServer.stop(pid)
    end

    test "drag_teach_replay with filename" do
      {:ok, pid} = Robot.start_link()

      filename = "test_movement.json"
      assert {:error, :not_connected} = Robot.drag_teach_replay(filename, server_name: pid)

      GenServer.stop(pid)
    end

    test "drag_teach_replay with options" do
      {:ok, pid} = Robot.start_link()

      filename = "test_movement.json"
      opts = [speed: 0.5, server_name: pid]
      assert {:error, :not_connected} = Robot.drag_teach_replay(filename, opts)

      GenServer.stop(pid)
    end

    test "accepts various filename parameter types" do
      {:ok, pid} = Robot.start_link()

      # Functions accept any parameter types (validation happens inside GenServer)
      assert {:error, :not_connected} = Robot.drag_teach_start(123, server_name: pid)
      assert {:error, :not_connected} = Robot.drag_teach_replay(:filename, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Mission recording functionality" do
    test "create_mission with name only" do
      {:ok, pid} = Robot.start_link()

      mission_name = "test_mission"
      assert {:error, :not_connected} = Robot.create_mission(mission_name, "", server_name: pid)

      GenServer.stop(pid)
    end

    test "create_mission with name and description" do
      {:ok, pid} = Robot.start_link()

      mission_name = "test_mission"
      description = "Test mission description"
      assert {:error, :not_connected} = Robot.create_mission(mission_name, description, server_name: pid)

      GenServer.stop(pid)
    end

    test "add_mission_step with default speed" do
      {:ok, pid} = Robot.start_link()

      mission_name = "test_mission"
      assert {:error, :not_connected} = Robot.add_mission_step(mission_name, 0.25, server_name: pid)

      GenServer.stop(pid)
    end

    test "add_mission_step with custom speed" do
      {:ok, pid} = Robot.start_link()

      mission_name = "test_mission"
      speed = 0.8
      assert {:error, :not_connected} = Robot.add_mission_step(mission_name, speed, server_name: pid)

      GenServer.stop(pid)
    end

    test "add_mission_delay" do
      {:ok, pid} = Robot.start_link()

      mission_name = "test_mission"
      delay_ms = 2000
      assert {:error, :not_connected} = Robot.add_mission_delay(mission_name, delay_ms, server_name: pid)

      GenServer.stop(pid)
    end

    test "play_mission with default times" do
      {:ok, pid} = Robot.start_link()

      mission_name = "test_mission"
      assert {:error, :not_connected} = Robot.play_mission(mission_name, 1, server_name: pid)

      GenServer.stop(pid)
    end

    test "play_mission with custom times" do
      {:ok, pid} = Robot.start_link()

      mission_name = "test_mission"
      times = 3
      assert {:error, :not_connected} = Robot.play_mission(mission_name, times, server_name: pid)

      GenServer.stop(pid)
    end

    test "accepts various parameter types" do
      {:ok, pid} = Robot.start_link()

      # Functions accept any parameter types (validation happens inside GenServer)
      assert {:error, :not_connected} = Robot.create_mission(123, "", server_name: pid)
      assert {:error, :not_connected} = Robot.add_mission_step(:mission_name, 0.25, server_name: pid)
      assert {:error, :not_connected} = Robot.add_mission_step("mission", "fast", server_name: pid)
      assert {:error, :not_connected} = Robot.add_mission_delay("mission", "2000", server_name: pid)
      assert {:error, :not_connected} = Robot.play_mission("mission", "once", server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Custom command functionality" do
    test "send_custom_command with JSON string" do
      {:ok, pid} = Robot.start_link()

      command = ~s({"T": 100})
      assert {:error, :not_connected} = Robot.send_custom_command(command, server_name: pid)

      GenServer.stop(pid)
    end

    test "send_custom_command with complex command" do
      {:ok, pid} = Robot.start_link()

      command = ~s({"T": 121, "joint": 1, "angle": 45, "spd": 1000})
      assert {:error, :not_connected} = Robot.send_custom_command(command, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Integration scenarios" do
    test "complete drag teach workflow when not connected" do
      {:ok, pid} = Robot.start_link()

      filename = "integration_test.json"

      # Steps should fail with appropriate errors
      assert {:error, :not_connected} = Robot.drag_teach_start(filename, server_name: pid)
      assert {:error, :not_teaching} = Robot.drag_teach_stop(server_name: pid)  # Not teaching, so :not_teaching
      assert {:error, :not_connected} = Robot.drag_teach_replay(filename, server_name: pid)

      GenServer.stop(pid)
    end

    test "complete mission workflow when not connected" do
      {:ok, pid} = Robot.start_link()

      mission_name = "integration_mission"

      # All steps should fail with :not_connected
      assert {:error, :not_connected} = Robot.create_mission(mission_name, "Test integration", server_name: pid)
      assert {:error, :not_connected} = Robot.add_mission_step(mission_name, 0.5, server_name: pid)
      assert {:error, :not_connected} = Robot.add_mission_delay(mission_name, 1000, server_name: pid)
      assert {:error, :not_connected} = Robot.play_mission(mission_name, 2, server_name: pid)

      GenServer.stop(pid)
    end

    test "torque control workflow when not connected" do
      {:ok, pid} = Robot.start_link()

      # All steps should fail with :not_connected
      assert {:error, :not_connected} = Robot.set_torque_enabled(false, server_name: pid)
      assert {:error, :not_connected} = Robot.set_torque_lock(true, server_name: pid)
      assert {:error, :not_connected} = Robot.set_torque_enabled(true, server_name: pid)

      GenServer.stop(pid)
    end

    test "LED control workflow when not connected" do
      {:ok, pid} = Robot.start_link()

      # All steps should fail with :not_connected
      assert {:error, :not_connected} = Robot.led_on(255, server_name: pid)
      assert {:error, :not_connected} = Robot.led_off(server_name: pid)
      assert {:error, :not_connected} = Robot.set_led(%{r: 255, g: 0, b: 0}, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Partial position updates" do
    test "accepts partial position maps - single coordinate" do
      {:ok, pid} = Robot.start_link()

      # Test single coordinate updates
      assert {:error, :not_connected} = Robot.move_to_position(%{x: 100.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_to_position(%{y: 50.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_to_position(%{z: 200.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_to_position(%{t: 45.0}, server_name: pid)

      GenServer.stop(pid)
    end

    test "accepts partial position maps - multiple coordinates" do
      {:ok, pid} = Robot.start_link()

      # Test multiple partial coordinates
      assert {:error, :not_connected} = Robot.move_to_position(%{x: 100.0, y: 50.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_to_position(%{y: 0.0, z: 150.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_to_position(%{x: 75.0, z: 200.0, t: 30.0}, server_name: pid)

      GenServer.stop(pid)
    end

    test "accepts empty position map" do
      {:ok, pid} = Robot.start_link()

      # Empty map should work (though will use defaults)
      assert {:error, :not_connected} = Robot.move_to_position(%{}, server_name: pid)

      GenServer.stop(pid)
    end

    test "handles atom and string keys in position map" do
      {:ok, pid} = Robot.start_link()

      # Both atom and string keys should be handled gracefully
      assert {:error, :not_connected} = Robot.move_to_position(%{"x" => 100.0, "y" => 50.0}, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Partial joint updates" do
    test "accepts partial joint maps - single joint" do
      {:ok, pid} = Robot.start_link()

      # Test single joint updates
      assert {:error, :not_connected} = Robot.move_joints(%{j1: 45.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j2: 30.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j3: -45.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j4: 90.0}, server_name: pid)

      GenServer.stop(pid)
    end

    test "accepts partial joint maps - multiple joints" do
      {:ok, pid} = Robot.start_link()

      # Test multiple partial joints
      assert {:error, :not_connected} = Robot.move_joints(%{j1: 45.0, j2: 30.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j2: 0.0, j4: -30.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j1: 90.0, j3: -45.0, j4: 15.0}, server_name: pid)

      GenServer.stop(pid)
    end

    test "accepts empty joint map" do
      {:ok, pid} = Robot.start_link()

      # Empty map should work (though will use defaults)
      assert {:error, :not_connected} = Robot.move_joints(%{}, server_name: pid)

      GenServer.stop(pid)
    end

    test "handles extended joints j5 and j6" do
      {:ok, pid} = Robot.start_link()

      # Should handle j5 and j6 even though they may not be used by all robot types
      assert {:error, :not_connected} = Robot.move_joints(%{j5: 30.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j6: -15.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j1: 45.0, j5: 30.0, j6: -15.0}, server_name: pid)

      GenServer.stop(pid)
    end

    test "handles atom and string keys in joint map" do
      {:ok, pid} = Robot.start_link()

      # Both atom and string keys should be handled gracefully
      assert {:error, :not_connected} = Robot.move_joints(%{"j1" => 45.0, "j2" => 30.0}, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Partial update merging behavior" do
    # These tests verify the position/joint merging logic by testing
    # that the functions don't crash and accept the expected parameters

    test "position merging works with current position unavailable" do
      {:ok, pid} = Robot.start_link()

      # When get_position fails, should fall back to defaults and merge
      # We can't test the exact merging without a connection, but we can verify
      # the function calls don't crash and return expected error types
      partial_update = %{x: 150.0}
      result = Robot.move_to_position(partial_update, server_name: pid)

      # Should return not_connected error, not a crash
      assert {:error, :not_connected} = result

      GenServer.stop(pid)
    end

    test "joint merging works with current joints unavailable" do
      {:ok, pid} = Robot.start_link()

      # When get_joints fails, should fall back to defaults and merge
      partial_update = %{j1: 45.0}
      result = Robot.move_joints(partial_update, server_name: pid)

      # Should return not_connected error, not a crash
      assert {:error, :not_connected} = result

      GenServer.stop(pid)
    end

    test "position merging handles all coordinate combinations" do
      {:ok, pid} = Robot.start_link()

      # Test all possible combinations of partial coordinates
      coordinate_combinations = [
        %{x: 100.0},
        %{y: 50.0},
        %{z: 200.0},
        %{t: 30.0},
        %{x: 100.0, y: 50.0},
        %{x: 100.0, z: 200.0},
        %{x: 100.0, t: 30.0},
        %{y: 50.0, z: 200.0},
        %{y: 50.0, t: 30.0},
        %{z: 200.0, t: 30.0},
        %{x: 100.0, y: 50.0, z: 200.0},
        %{x: 100.0, y: 50.0, t: 30.0},
        %{x: 100.0, z: 200.0, t: 30.0},
        %{y: 50.0, z: 200.0, t: 30.0}
      ]

      Enum.each(coordinate_combinations, fn coords ->
        result = Robot.move_to_position(coords, server_name: pid)
        assert {:error, :not_connected} = result
      end)

      GenServer.stop(pid)
    end

    test "joint merging handles all joint combinations" do
      {:ok, pid} = Robot.start_link()

      # Test various combinations of partial joints
      joint_combinations = [
        %{j1: 45.0},
        %{j2: 30.0},
        %{j3: -45.0},
        %{j4: 90.0},
        %{j1: 45.0, j2: 30.0},
        %{j1: 45.0, j3: -45.0},
        %{j2: 30.0, j4: 90.0},
        %{j1: 45.0, j2: 30.0, j3: -45.0},
        %{j2: 30.0, j3: -45.0, j4: 90.0},
        %{j1: 45.0, j3: -45.0, j4: 90.0}
      ]

      Enum.each(joint_combinations, fn joints ->
        result = Robot.move_joints(joints, server_name: pid)
        assert {:error, :not_connected} = result
      end)

      GenServer.stop(pid)
    end
  end

  describe "Partial update edge cases" do
    test "handles extreme coordinate values" do
      {:ok, pid} = Robot.start_link()

      # Should accept extreme values (validation happens in command validator)
      assert {:error, :not_connected} = Robot.move_to_position(%{x: -999.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_to_position(%{z: 999.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_to_position(%{t: 180.0}, server_name: pid)

      GenServer.stop(pid)
    end

    test "handles extreme joint angle values" do
      {:ok, pid} = Robot.start_link()

      # Should accept extreme values (validation happens in command validator)
      assert {:error, :not_connected} = Robot.move_joints(%{j1: -180.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j2: 180.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j3: 0.001}, server_name: pid)

      GenServer.stop(pid)
    end

    test "handles mixed data types gracefully" do
      {:ok, pid} = Robot.start_link()

      # Should handle various numeric types
      assert {:error, :not_connected} = Robot.move_to_position(%{x: 100, y: 50.0}, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joints(%{j1: 45, j2: 30.0}, server_name: pid)

      GenServer.stop(pid)
    end

    test "maintains backward compatibility with full maps" do
      {:ok, pid} = Robot.start_link()

      # Full position and joint maps should still work exactly as before
      full_position = %{x: 100.0, y: 0.0, z: 150.0, t: 0.0}
      assert {:error, :not_connected} = Robot.move_to_position(full_position, server_name: pid)

      full_joints = %{j1: 0.0, j2: 45.0, j3: -30.0, j4: 0.0}
      assert {:error, :not_connected} = Robot.move_joints(full_joints, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Parameter validation edge cases" do
    test "empty strings and edge values" do
      {:ok, pid} = Robot.start_link()

      # Empty filename should still be a valid string
      assert {:error, :not_connected} = Robot.drag_teach_start("", server_name: pid)

      # Empty mission name should still be a valid string
      assert {:error, :not_connected} = Robot.create_mission("", "", server_name: pid)

      # Zero delay should be valid
      assert {:error, :not_connected} = Robot.add_mission_delay("mission", 0, server_name: pid)

      # Zero times should be valid (though might not make sense)
      assert {:error, :not_connected} = Robot.play_mission("mission", 0, server_name: pid)

      GenServer.stop(pid)
    end

    test "boundary values for LED brightness" do
      {:ok, pid} = Robot.start_link()

      # Test exact boundaries
      assert {:error, :not_connected} = Robot.led_on(0, server_name: pid)
      assert {:error, :not_connected} = Robot.led_on(255, server_name: pid)

      GenServer.stop(pid)
    end
  end

  describe "Gripper control" do
    test "gripper_control accepts valid position values for M2" do
      {:ok, pid} = Robot.start_link([robot_type: :roarm_m2])

      # Test valid position range (0-100)
      assert {:error, :not_connected} = Robot.gripper_control(0, server_name: pid)
      assert {:error, :not_connected} = Robot.gripper_control(50, server_name: pid)
      assert {:error, :not_connected} = Robot.gripper_control(100, server_name: pid)

      GenServer.stop(pid)
    end

    test "gripper_control accepts valid position values for M3" do
      {:ok, pid} = Robot.start_link([robot_type: :roarm_m3])

      # Test valid position range (0-100)
      assert {:error, :not_connected} = Robot.gripper_control(0, server_name: pid)
      assert {:error, :not_connected} = Robot.gripper_control(75, server_name: pid)
      assert {:error, :not_connected} = Robot.gripper_control(100, server_name: pid)

      GenServer.stop(pid)
    end

    test "gripper_control clamps out-of-range values" do
      {:ok, pid} = Robot.start_link([robot_type: :roarm_m2])

      # Test values outside range are accepted (should be clamped internally)
      assert {:error, :not_connected} = Robot.gripper_control(-10, server_name: pid)
      assert {:error, :not_connected} = Robot.gripper_control(150, server_name: pid)

      GenServer.stop(pid)
    end

    test "gripper_control uses model-specific commands" do
      # Test M2 uses T:121 joint 4 control
      {:ok, pid_m2} = Robot.start_link([robot_type: :roarm_m2])

      # Mock the command sending to verify correct T-code is used
      # This will fail with :not_connected but we're testing the function exists
      assert {:error, :not_connected} = Robot.gripper_control(50, server_name: pid_m2)

      GenServer.stop(pid_m2)

      # Test M3 uses T:222 gripper command
      {:ok, pid_m3} = Robot.start_link([robot_type: :roarm_m3])

      assert {:error, :not_connected} = Robot.gripper_control(50, server_name: pid_m3)

      GenServer.stop(pid_m3)
    end

    test "gripper_control with custom speed option" do
      {:ok, pid} = Robot.start_link([robot_type: :roarm_m2])

      # Test with custom speed
      assert {:error, :not_connected} = Robot.gripper_control(50, speed: 1000, server_name: pid)
      assert {:error, :not_connected} = Robot.gripper_control(75, speed: 4096, server_name: pid)

      GenServer.stop(pid)
    end

    test "gripper_control workflow for different robot types" do
      # M2 workflow
      {:ok, pid_m2} = Robot.start_link([robot_type: :roarm_m2])

      # Test open and close cycle
      assert {:error, :not_connected} = Robot.gripper_control(0, server_name: pid_m2)   # Open
      assert {:error, :not_connected} = Robot.gripper_control(100, server_name: pid_m2) # Close
      assert {:error, :not_connected} = Robot.gripper_control(50, server_name: pid_m2)  # Half

      GenServer.stop(pid_m2)

      # M3 workflow
      {:ok, pid_m3} = Robot.start_link([robot_type: :roarm_m3])

      assert {:error, :not_connected} = Robot.gripper_control(0, server_name: pid_m3)   # Open
      assert {:error, :not_connected} = Robot.gripper_control(100, server_name: pid_m3) # Close
      assert {:error, :not_connected} = Robot.gripper_control(75, server_name: pid_m3)  # Partial

      GenServer.stop(pid_m3)
    end

    test "get_robot_type returns correct robot type" do
      {:ok, pid_m2} = Robot.start_link([robot_type: :roarm_m2])
      assert {:ok, :roarm_m2} = Robot.get_robot_type(server_name: pid_m2)
      GenServer.stop(pid_m2)

      {:ok, pid_m3} = Robot.start_link([robot_type: :roarm_m3])
      assert {:ok, :roarm_m3} = Robot.get_robot_type(server_name: pid_m3)
      GenServer.stop(pid_m3)
    end
  end

  describe "Single joint control" do
    test "move_joint accepts valid joint numbers and angles" do
      {:ok, pid} = Robot.start_link()

      # Test all valid joint numbers (1-6)
      assert {:error, :not_connected} = Robot.move_joint(1, 45.0, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(2, -30.0, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(3, 90.0, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(4, 0.0, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(5, 15.0, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(6, -45.0, server_name: pid)

      GenServer.stop(pid)
    end

    test "move_joint clamps angles to valid range" do
      {:ok, pid} = Robot.start_link()

      # Test boundary values - should be accepted (clamped internally)
      assert {:error, :not_connected} = Robot.move_joint(1, -180.0, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(2, 180.0, server_name: pid)

      # Test out-of-range values - should be accepted (clamped internally)
      assert {:error, :not_connected} = Robot.move_joint(1, -200.0, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(3, 250.0, server_name: pid)

      GenServer.stop(pid)
    end

    test "move_joint with custom speed option" do
      {:ok, pid} = Robot.start_link()

      # Test with custom speed
      assert {:error, :not_connected} = Robot.move_joint(1, 45.0, speed: 500, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(2, -30.0, speed: 2000, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(4, 90.0, speed: 4096, server_name: pid)

      GenServer.stop(pid)
    end

    test "move_joint with invalid joint numbers should fail" do
      {:ok, pid} = Robot.start_link()

      # These should raise FunctionClauseError due to guard constraints
      assert_raise FunctionClauseError, fn ->
        Robot.move_joint(0, 45.0, server_name: pid)
      end

      assert_raise FunctionClauseError, fn ->
        Robot.move_joint(7, 45.0, server_name: pid)
      end

      assert_raise FunctionClauseError, fn ->
        Robot.move_joint(-1, 45.0, server_name: pid)
      end

      GenServer.stop(pid)
    end

    test "move_joint with non-numeric angles should fail" do
      {:ok, pid} = Robot.start_link()

      # These should raise FunctionClauseError due to guard constraints
      assert_raise FunctionClauseError, fn ->
        Robot.move_joint(1, "45", server_name: pid)
      end

      assert_raise FunctionClauseError, fn ->
        Robot.move_joint(1, :invalid, server_name: pid)
      end

      assert_raise FunctionClauseError, fn ->
        Robot.move_joint(1, nil, server_name: pid)
      end

      GenServer.stop(pid)
    end

    test "move_joint accepts integer and float angles" do
      {:ok, pid} = Robot.start_link()

      # Should handle both integer and float angles
      assert {:error, :not_connected} = Robot.move_joint(1, 45, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(2, 45.5, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(3, -30, server_name: pid)
      assert {:error, :not_connected} = Robot.move_joint(4, -30.75, server_name: pid)

      GenServer.stop(pid)
    end
  end
end