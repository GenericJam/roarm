defmodule Roarm.CommandValidator do
  @moduledoc """
  Command validation module for RoArm robot commands.

  This module defines command schemas and provides validation for all robot commands.
  It supports parameter validation, range clamping, and symbolic values (:min, :mid, :max).

  ## Command Schemas

  The command schemas define the structure, types, and validation rules for all RoArm
  robot commands. Each schema includes:

  - **T-code**: Unique command identifier
  - **Description**: Human-readable command description
  - **Parameters**: Map of parameter definitions with validation rules

  ### Parameter Definition Structure

  Each parameter can have the following attributes:

  - `:type` - Parameter type (`:integer`, `:float`, `:string`)
  - `:min` - Minimum allowed value (for numeric types)
  - `:max` - Maximum allowed value (for numeric types)
  - `:default` - Default value if parameter is not provided
  - `:required` - Whether the parameter is required (default: false)

  ### Example Usage

      # Get all command schemas
      schemas = Roarm.CommandValidator.command_schemas()

      # Get specific command schema
      {:ok, schema} = Roarm.CommandValidator.get_command_schema(122)

      # Access position control parameters
      position_schema = schemas[1041]
      x_param = position_schema.parameters[:x]
      # => %{type: :float, min: -500.0, max: 500.0, required: true}

  ### Command Categories

  - **Movement Commands** (100-199): Home, joint control, position control
  - **Position Commands** (1000-1099): Coordinate-based positioning
  - **System Commands** (200-299): Torque, feedback, system control
  - **LED Commands** (100-199): Light control and effects
  - **Mission Commands** (220-249): Recorded movement sequences
  - **Advanced Commands** (100-199): PID tuning, force adaptation
  - **Gripper Commands** (222): Gripper control for M3 models
  """

  @doc """
  Validate and normalize a command map.

  Returns {:ok, validated_map} or {:error, reason}
  """
  def validate_command(%{t: t_code} = command) when is_integer(t_code) do
    case get_command_schema(t_code) do
      {:ok, schema} ->
        validate_against_schema(command, schema)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_command(%{"T" => t_code} = command) do
    # Convert string keys to atom keys for internal processing
    atom_command = convert_keys_to_atoms(command)
    validate_command(Map.put(atom_command, :t, t_code))
  end

  def validate_command(_), do: {:error, :invalid_command_format}

  @doc """
  Get the command schema for a given T-code.
  """
  def get_command_schema(t_code) do
    case command_schemas()[t_code] do
      nil -> {:error, {:unknown_command, t_code}}
      schema -> {:ok, schema}
    end
  end

  @doc """
  Convert a validated command map to JSON string.
  """
  def to_json(validated_command) do
    # Convert atom keys back to string keys for JSON
    string_command = convert_keys_to_strings(validated_command)

    # Rename :t back to "T" for the robot protocol
    json_command =
      string_command
      |> Map.delete("t")
      |> Map.put("T", validated_command.t)

    Jason.encode!(json_command)
  end

  # Private functions

  defp validate_against_schema(command, schema) do
    validated =
      schema.parameters
      |> Enum.reduce(%{t: command.t}, fn {param, param_schema}, acc ->
        value = Map.get(command, param)
        validated_value = validate_parameter(value, param_schema, param)
        Map.put(acc, param, validated_value)
      end)

    {:ok, validated}
  rescue
    e -> {:error, {:validation_error, Exception.message(e)}}
  end

  defp validate_parameter(nil, %{required: true}, param) do
    raise "Parameter #{param} is required"
  end

  defp validate_parameter(nil, %{default: default}, _param) do
    default
  end

  defp validate_parameter(nil, _schema, _param) do
    nil
  end

  defp validate_parameter(value, schema, _param) do
    value
    |> resolve_symbolic_value(schema)
    |> clamp_value(schema)
    |> validate_type(schema)
  end

  defp resolve_symbolic_value(:min, %{min: min}), do: min
  defp resolve_symbolic_value(:mid, %{min: min, max: max}), do: (min + max) / 2
  defp resolve_symbolic_value(:max, %{max: max}), do: max
  defp resolve_symbolic_value(value, _schema), do: value

  defp clamp_value(value, %{min: min, max: max}) when is_number(value) do
    value |> max(min) |> min(max)
  end
  defp clamp_value(value, _schema), do: value

  defp validate_type(value, %{type: :integer}) when is_number(value), do: round(value)
  defp validate_type(value, %{type: :float}) when is_number(value), do: value / 1
  defp validate_type(value, %{type: :string}) when is_binary(value), do: value
  defp validate_type(value, %{type: :boolean}) when is_boolean(value), do: value
  defp validate_type(value, %{type: type}), do: throw("Invalid type for #{inspect(value)}, expected #{type}")

  defp convert_keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_atom(String.downcase(key)), value}
      {key, value} -> {key, value}
    end)
  end

  defp convert_keys_to_strings(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  @doc """
  Get all command schemas for RoArm robot commands.

  Returns a map where keys are T-codes (command identifiers) and values are
  schema definitions containing parameter validation rules.

  ## Schema Structure

  Each schema contains:
  - `:description` - Human-readable description of the command
  - `:parameters` - Map of parameter definitions with validation rules

  ## Returns

  A map of T-code => schema, where each schema follows this structure:

      %{
        description: "Command description",
        parameters: %{
          param_name: %{
            type: :integer | :float | :string,
            min: number,              # For numeric types
            max: number,              # For numeric types
            default: any,             # Default value
            required: boolean         # Whether required (default: false)
          }
        }
      }

  ## Examples

      # Get all schemas
      all_schemas = Roarm.CommandValidator.command_schemas()

      # Get home command schema
      home_schema = all_schemas[100]
      # => %{description: "Home position", parameters: %{}}

      # Get position control schema
      pos_schema = all_schemas[1041]
      x_limits = pos_schema.parameters[:x]
      # => %{type: :float, min: -500.0, max: 500.0, required: true}

      # Check if a T-code exists
      Map.has_key?(all_schemas, 122)  # => true

      # Get parameter names for a command
      joint_params = Map.keys(all_schemas[122].parameters)
      # => [:b, :s, :e, :h, :w, :g, :spd]
  """
  def command_schemas do
    %{
      # Movement Commands
      100 => %{
        description: "Home position",
        parameters: %{}
      },

      101 => %{
        description: "Single joint control (radians)",
        parameters: %{
          joint: %{type: :integer, min: 1, max: 6, required: true},  # Joint number (1-6)
          radian: %{type: :float, min: -3.14159, max: 3.14159, required: true},  # Angle in radians
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}   # Movement speed
        }
      },

      102 => %{
        description: "All joints control (radians)",
        parameters: %{
          b: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},  # Base joint (j1)
          s: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},  # Shoulder joint (j2)
          e: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},  # Elbow joint (j3)
          h: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},  # Wrist joint (j4)
          w: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},  # Additional joint (j5)
          g: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},  # Additional joint (j6)
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}        # Movement speed
        }
      },

      121 => %{
        description: "Single joint control (degrees)",
        parameters: %{
          joint: %{type: :integer, min: 1, max: 6, required: true},  # Joint number (1-6)
          angle: %{type: :float, min: -180.0, max: 180.0, required: true},  # Angle in degrees
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}   # Movement speed
        }
      },

      122 => %{
        description: "All joints control (degrees)",
        parameters: %{
          b: %{type: :float, min: -180.0, max: 180.0, default: 0.0},  # Base joint (j1) in degrees
          s: %{type: :float, min: -180.0, max: 180.0, default: 0.0},  # Shoulder joint (j2) in degrees
          e: %{type: :float, min: -180.0, max: 180.0, default: 0.0},  # Elbow joint (j3) in degrees
          h: %{type: :float, min: -180.0, max: 180.0, default: 0.0},  # Wrist joint (j4) in degrees
          w: %{type: :float, min: -180.0, max: 180.0, default: 0.0},  # Additional joint (j5) in degrees
          g: %{type: :float, min: -180.0, max: 180.0, default: 0.0},  # Additional joint (j6) in degrees
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}    # Movement speed
        }
      },

      1041 => %{
        description: "Position control",
        parameters: %{
          x: %{type: :float, min: -500.0, max: 500.0, required: true},  # X coordinate in mm
          y: %{type: :float, min: -500.0, max: 500.0, required: true},  # Y coordinate in mm
          z: %{type: :float, min: 0.0, max: 500.0, required: true},     # Z coordinate in mm
          t: %{type: :float, min: -180.0, max: 180.0, default: 0.0},    # Tool rotation angle in degrees
          spd: %{type: :integer, min: 1, max: 4096, default: 1000},     # Movement speed
          acc: %{type: :integer, min: 1, max: 254, default: 100}        # Acceleration
        }
      },

      # System Commands
      105 => %{
        description: "Get feedback",
        parameters: %{}  # No parameters required
      },

      210 => %{
        description: "Torque control",
        parameters: %{
          cmd: %{type: :integer, min: 0, max: 1, required: true}  # 0 = disable, 1 = enable
        }
      },

      502 => %{
        description: "Set middle position",
        parameters: %{}  # Calibrates current position as middle/reference
      },

      # LED Commands
      114 => %{
        description: "LED control",
        parameters: %{
          led: %{type: :integer, min: 0, max: 255, default: 255},  # LED brightness (0-255)
          r: %{type: :integer, min: 0, max: 255, default: 0},      # Red component (0-255)
          g: %{type: :integer, min: 0, max: 255, default: 0},      # Green component (0-255)
          b: %{type: :integer, min: 0, max: 255, default: 0}       # Blue component (0-255)
        }
      },

      # Mission Commands
      220 => %{
        description: "Create mission",
        parameters: %{
          name: %{type: :string, required: true},    # Mission name/identifier
          intro: %{type: :string, default: ""}       # Optional mission description
        }
      },

      223 => %{
        description: "Add mission step",
        parameters: %{
          mission: %{type: :string, required: true},              # Mission name
          spd: %{type: :float, min: 0.1, max: 1.0, default: 0.25}  # Speed factor (0.1-1.0)
        }
      },

      224 => %{
        description: "Add mission delay",
        parameters: %{
          mission: %{type: :string, required: true},              # Mission name
          delay: %{type: :integer, min: 0, max: 60000, required: true}  # Delay in milliseconds
        }
      },

      242 => %{
        description: "Play mission",
        parameters: %{
          name: %{type: :string, required: true},                 # Mission name to play
          times: %{type: :integer, min: 1, max: 1000, default: 1}  # Number of repetitions
        }
      },

      # Advanced Commands
      108 => %{
        description: "Set PID parameters",
        parameters: %{
          joint: %{type: :integer, min: 1, max: 6, required: true},  # Joint number (1-6)
          p: %{type: :integer, min: 0, max: 100, required: true},    # Proportional gain
          i: %{type: :integer, min: 0, max: 100, required: true},    # Integral gain
          d: %{type: :integer, min: 0, max: 100, required: true}     # Derivative gain
        }
      },

      112 => %{
        description: "Dynamic force adaptation",
        parameters: %{
          mode: %{type: :integer, min: 0, max: 1, required: true},  # 0 = disable, 1 = enable
          b: %{type: :integer, min: 0, max: 1000, default: 500},    # Base joint force threshold
          s: %{type: :integer, min: 0, max: 1000, default: 500},    # Shoulder joint force threshold
          e: %{type: :integer, min: 0, max: 1000, default: 500},    # Elbow joint force threshold
          h: %{type: :integer, min: 0, max: 1000, default: 500},    # Wrist joint force threshold
          w: %{type: :integer, min: 0, max: 1000, default: 500},    # Additional joint force threshold
          g: %{type: :integer, min: 0, max: 1000, default: 500}     # Additional joint force threshold
        }
      },

      # Gripper Commands (M3 and M3-Pro models)
      222 => %{
        description: "Gripper control",
        parameters: %{
          mode: %{type: :integer, min: 0, max: 1, required: true},   # 0 = position mode, 1 = force mode
          angle: %{type: :integer, min: 0, max: 100, required: true} # Gripper angle/force (0-100%)
        }
      }
    }
  end
end