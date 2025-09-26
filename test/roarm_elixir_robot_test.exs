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
end