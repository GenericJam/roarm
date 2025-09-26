defmodule Roarm.Communication do
  @moduledoc """
  UART communication module for Waveshare RoArm robot arms.

  Handles serial communication using Circuits.UART, providing a clean interface
  for sending commands and receiving responses from RoArm devices.
  """

  use GenServer
  require Logger
  alias Circuits.UART
  alias Roarm.Config

  @response_timeout 1000

  defstruct [:uart_pid, :port, :baudrate, :timeout]

  # Client API

  @doc """
  Start the communication GenServer.

  ## Options
    - `:name` - Process name for registry (default: __MODULE__)
    - `:port` - Serial port path (e.g., "/dev/ttyUSB0", "COM3")
    - `:baudrate` - Communication speed (default: from config or 115200)
    - `:timeout` - Response timeout in milliseconds (default: from config or 5000)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    registry_name = {:via, Registry, {Roarm.registry_name(), name}}
    GenServer.start_link(__MODULE__, opts, name: registry_name)
  end

  @doc """
  Open connection to the robot arm.
  """
  def connect(port, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:connect, port, opts})
  end

  @doc """
  Disconnect from the robot arm.
  """
  def disconnect(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :disconnect)
  end

  @doc """
  Send a command to the robot and wait for response.
  """
  def send_command(command, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, @response_timeout)
    GenServer.call(resolve_server(server), {:send_command, command, timeout}, timeout + 1000)
  end

  @doc """
  Send raw data to the robot without waiting for response.
  """
  def send_raw(data, opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), {:send_raw, data})
  end

  @doc """
  Check if connection is active.
  """
  def connected?(opts \\ []) do
    server = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(resolve_server(server), :connected?)
  end

  # Helper function to resolve server name to PID via registry
  defp resolve_server(name) when is_atom(name) do
    case Registry.lookup(Roarm.registry_name(), name) do
      [{pid, _}] -> pid
      [] -> name  # Fallback to atom for backwards compatibility
    end
  end
  defp resolve_server(pid) when is_pid(pid), do: pid

  @doc """
  List available serial ports.
  """
  def list_ports do
    UART.enumerate()
  end

  # Server callbacks

  @impl true
  def init(opts) do
    baudrate = Keyword.get(opts, :baudrate, Config.get_baudrate())
    timeout = Keyword.get(opts, :timeout, Config.get_timeout())

    {:ok, uart_pid} = UART.start_link()

    state = %__MODULE__{
      uart_pid: uart_pid,
      baudrate: baudrate,
      timeout: timeout
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:connect, port, opts}, _from, state) do
    baudrate = Keyword.get(opts, :baudrate, state.baudrate)

    case UART.open(state.uart_pid, port,
                   speed: baudrate,
                   active: false,
                   framing: {UART.Framing.Line, separator: "\r\n"}) do
      :ok ->
        Logger.info("Connected to RoArm on #{port} at #{baudrate} baud")
        new_state = %{state | port: port, baudrate: baudrate}
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to connect to RoArm on #{port}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:disconnect, _from, state) do
    if state.port do
      UART.close(state.uart_pid)
      Logger.info("Disconnected from RoArm on #{state.port}")
      new_state = %{state | port: nil}
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:send_command, command, timeout}, _from, state) do
    if state.port do
      case send_and_receive(state.uart_pid, command, timeout) do
        {:ok, response} ->
          {:reply, {:ok, response}, state}

        {:error, reason} ->
          Logger.warning("Command failed: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:send_raw, data}, _from, state) do
    if state.port do
      case UART.write(state.uart_pid, data) do
        :ok ->
          {:reply, :ok, state}

        {:error, reason} ->
          Logger.warning("Raw send failed: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, not is_nil(state.port), state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port do
      UART.close(state.uart_pid)
    end
    :ok
  end

  # Private functions

  defp send_and_receive(uart_pid, command, timeout) do
    # Clear any pending data
    UART.drain(uart_pid)

    Logger.debug("Sending command: #{command}")

    # Send command
    case UART.write(uart_pid, command <> "\n") do
      :ok ->
        Logger.debug("Command sent successfully")

        # Wait for response
        case UART.read(uart_pid, timeout) do
          {:ok, response} ->
            trimmed_response = String.trim(response)
            Logger.debug("Received response: #{trimmed_response}")
            {:ok, trimmed_response}

          {:error, :timeout} ->
            Logger.warning("Command timed out waiting for response")
            {:error, :timeout}

          {:error, reason} ->
            Logger.error("Failed to read response: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to send command: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
