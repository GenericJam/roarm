defmodule Roarm.Config do
  @moduledoc """
  Configuration management for Roarm.

  This module provides functions to read configuration values from the application
  environment, with sensible defaults for all options.

  ## Configuration Options

  You can configure Roarm in your `config.exs` file:

      config :roarm,
        port: "/dev/cu.usbserial-110",
        baudrate: 115200,
        robot_type: :roarm_m2,
        communication_server_name: Roarm.Communication,
        robot_server_name: Roarm.Robot,
        timeout: 5000

  ## Available Keys

    - `:port` - Serial port path (e.g., "/dev/ttyUSB0", "/dev/cu.usbserial-110")
    - `:baudrate` - Communication speed (default: 115200)
    - `:robot_type` - Type of robot (:roarm_m2, :roarm_m2_pro, :roarm_m3, :roarm_m3_pro)
    - `:communication_server_name` - Name for communication server (default: Roarm.Communication)
    - `:robot_server_name` - Name for robot server (default: Roarm.Robot)
    - `:timeout` - Default timeout for operations in milliseconds (default: 5000)

  ## Examples

      # Get the configured port
      port = Roarm.Config.get(:port)

      # Get robot type with fallback
      robot_type = Roarm.Config.get(:robot_type, :roarm_m2)

      # Get all configuration as a keyword list
      config = Roarm.Config.all()
  """

  @default_config [
    port: nil,
    baudrate: 115200,
    robot_type: :roarm_m2,
    communication_server_name: Roarm.Communication,
    robot_server_name: Roarm.Robot,
    timeout: 5000
  ]

  @doc """
  Get a configuration value by key.

  ## Parameters
    - `key` - Configuration key to retrieve
    - `default` - Default value if key is not configured (optional)

  ## Examples
      iex> Roarm.Config.get(:baud_rate)
      115200

      iex> Roarm.Config.get(:port, "/dev/ttyUSB0")
      "/dev/ttyUSB0"
  """
  def get(key, default \\ nil) do
    configured_default = Keyword.get(@default_config, key, default)
    Application.get_env(:roarm, key, configured_default)
  end

  @doc """
  Get all configuration as a keyword list.

  ## Examples
      iex> Roarm.Config.all()
      [port: "/dev/cu.usbserial-110", baud_rate: 115200, robot_type: :roarm_m2, ...]
  """
  def all do
    configured = Application.get_all_env(:roarm)
    Keyword.merge(@default_config, configured)
  end

  @doc """
  Get the configured port with validation.

  Returns `{:ok, port}` if a port is configured, or `{:error, :no_port_configured}`
  if no port is set in configuration.

  ## Examples
      # When port is configured
      {:ok, "/dev/cu.usbserial-110"} = Roarm.Config.get_port()

      # When no port is configured
      {:error, :no_port_configured} = Roarm.Config.get_port()
  """
  def get_port do
    case get(:port) do
      nil -> {:error, :no_port_configured}
      port when is_binary(port) -> {:ok, port}
      port -> {:error, {:invalid_port, port}}
    end
  end

  @doc """
  Get the configured baudrate.

  Always returns a valid baud rate, defaulting to 115200.

  ## Examples
      iex> Roarm.Config.get_baudrate()
      115200
  """
  def get_baudrate do
    get(:baudrate, 115200)
  end

  @doc """
  Get the configured robot type.

  ## Examples
      iex> Roarm.Config.get_robot_type()
      :roarm_m2
  """
  def get_robot_type do
    get(:robot_type, :roarm_m2)
  end

  @doc """
  Get the configured communication server name.

  ## Examples
      iex> Roarm.Config.get_communication_server_name()
      Roarm.Communication
  """
  def get_communication_server_name do
    get(:communication_server_name, Roarm.Communication)
  end

  @doc """
  Get the configured robot server name.

  ## Examples
      iex> Roarm.Config.get_robot_server_name()
      Roarm.Robot
  """
  def get_robot_server_name do
    get(:robot_server_name, Roarm.Robot)
  end

  @doc """
  Get the configured default timeout.

  ## Examples
      iex> Roarm.Config.get_timeout()
      5000
  """
  def get_timeout do
    get(:timeout, 5000)
  end
end