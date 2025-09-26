defmodule RoarmTest do
  use ExUnit.Case
  doctest Roarm

  setup_all do
    # Start registry once for all tests
    case Roarm.start_registry() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :ok
    end
    :ok
  end

  describe "Roarm main module" do
    test "lists available ports" do
      ports = Roarm.list_ports()
      assert is_map(ports)
    end

    test "test_connection handles invalid ports gracefully" do
      result = Roarm.test_connection("/dev/nonexistent")
      assert {:error, _reason} = result
    end

    test "start_robot with valid options" do
      # This will fail due to no actual robot, but should handle gracefully
      opts = [robot_type: :roarm_m2, port: "/dev/nonexistent", baudrate: 115200]
      result = Roarm.start_robot(opts)
      assert {:error, _reason} = result
    end
  end
end
