defmodule Roarm.CommunicationTest do
  use ExUnit.Case
  alias Roarm.Communication
  doctest Roarm.Communication

  setup_all do
    # Start registry once for all tests
    case Roarm.start_registry() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :ok
    end
    :ok
  end

  describe "Communication GenServer" do
    test "starts successfully" do
      # Generate unique name for this test to avoid conflicts
      test_name = String.to_atom("test_#{System.unique_integer([:positive])}")
      opts = [name: test_name]
      assert {:ok, pid} = Communication.start_link(opts)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "lists available ports" do
      ports = Communication.list_ports()
      assert is_map(ports)
    end

    test "handles connection errors gracefully" do
      test_name = String.to_atom("test_#{System.unique_integer([:positive])}")
      {:ok, pid} = Communication.start_link(name: test_name)

      # Try to connect to non-existent port
      assert {:error, _reason} = Communication.connect("/dev/nonexistent", server_name: test_name)

      GenServer.stop(pid)
    end

    test "tracks connection state" do
      test_name = String.to_atom("test_#{System.unique_integer([:positive])}")
      {:ok, pid} = Communication.start_link(name: test_name)

      # Initially not connected
      assert Communication.connected?(server_name: test_name) == false

      # Still not connected after failed connection attempt
      Communication.connect("/dev/nonexistent", server_name: test_name)
      assert Communication.connected?(server_name: test_name) == false

      GenServer.stop(pid)
    end

    test "handles commands when not connected" do
      test_name = String.to_atom("test_#{System.unique_integer([:positive])}")
      {:ok, pid} = Communication.start_link(name: test_name)

      assert {:error, :not_connected} = Communication.send_command("test", server_name: test_name)
      assert {:error, :not_connected} = Communication.send_raw("test", server_name: test_name)

      GenServer.stop(pid)
    end

    test "handles disconnect when not connected" do
      test_name = String.to_atom("test_#{System.unique_integer([:positive])}")
      {:ok, pid} = Communication.start_link(name: test_name)

      assert {:error, :not_connected} = Communication.disconnect(server_name: test_name)

      GenServer.stop(pid)
    end
  end
end