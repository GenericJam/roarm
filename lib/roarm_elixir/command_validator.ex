defmodule Roarm.CommandValidator do
  @moduledoc """
  Command validation module for RoArm robot commands.

  This module defines command schemas and provides validation for all robot commands.
  It supports parameter validation, range clamping, and symbolic values (:min, :mid, :max).
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

  # Command schemas definition
  defp command_schemas do
    %{
      # Movement Commands
      100 => %{
        description: "Home position",
        parameters: %{}
      },

      101 => %{
        description: "Single joint control (radians)",
        parameters: %{
          joint: %{type: :integer, min: 1, max: 6, required: true},
          radian: %{type: :float, min: -3.14159, max: 3.14159, required: true},
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}
        }
      },

      102 => %{
        description: "All joints control (radians)",
        parameters: %{
          b: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},
          s: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},
          e: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},
          h: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},
          w: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},
          g: %{type: :float, min: -3.14159, max: 3.14159, default: 0.0},
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}
        }
      },

      121 => %{
        description: "Single joint control (degrees)",
        parameters: %{
          joint: %{type: :integer, min: 1, max: 6, required: true},
          angle: %{type: :float, min: -180.0, max: 180.0, required: true},
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}
        }
      },

      122 => %{
        description: "All joints control (degrees)",
        parameters: %{
          b: %{type: :float, min: -180.0, max: 180.0, default: 0.0},
          s: %{type: :float, min: -180.0, max: 180.0, default: 0.0},
          e: %{type: :float, min: -180.0, max: 180.0, default: 0.0},
          h: %{type: :float, min: -180.0, max: 180.0, default: 0.0},
          w: %{type: :float, min: -180.0, max: 180.0, default: 0.0},
          g: %{type: :float, min: -180.0, max: 180.0, default: 0.0},
          spd: %{type: :integer, min: 1, max: 4096, default: 1000}
        }
      },

      1041 => %{
        description: "Position control",
        parameters: %{
          x: %{type: :float, min: -500.0, max: 500.0, required: true},
          y: %{type: :float, min: -500.0, max: 500.0, required: true},
          z: %{type: :float, min: 0.0, max: 500.0, required: true},
          t: %{type: :float, min: -180.0, max: 180.0, default: 0.0},
          spd: %{type: :integer, min: 1, max: 4096, default: 1000},
          acc: %{type: :integer, min: 1, max: 254, default: 100}
        }
      },

      # System Commands
      105 => %{
        description: "Get feedback",
        parameters: %{}
      },

      210 => %{
        description: "Torque control",
        parameters: %{
          cmd: %{type: :integer, min: 0, max: 1, required: true}
        }
      },

      502 => %{
        description: "Set middle position",
        parameters: %{}
      },

      # LED Commands
      114 => %{
        description: "LED control",
        parameters: %{
          led: %{type: :integer, min: 0, max: 255, default: 255},
          r: %{type: :integer, min: 0, max: 255, default: 0},
          g: %{type: :integer, min: 0, max: 255, default: 0},
          b: %{type: :integer, min: 0, max: 255, default: 0}
        }
      },

      # Mission Commands
      220 => %{
        description: "Create mission",
        parameters: %{
          name: %{type: :string, required: true},
          intro: %{type: :string, default: ""}
        }
      },

      223 => %{
        description: "Add mission step",
        parameters: %{
          mission: %{type: :string, required: true},
          spd: %{type: :float, min: 0.1, max: 1.0, default: 0.25}
        }
      },

      224 => %{
        description: "Add mission delay",
        parameters: %{
          mission: %{type: :string, required: true},
          delay: %{type: :integer, min: 0, max: 60000, required: true}
        }
      },

      242 => %{
        description: "Play mission",
        parameters: %{
          name: %{type: :string, required: true},
          times: %{type: :integer, min: 1, max: 1000, default: 1}
        }
      },

      # Advanced Commands
      108 => %{
        description: "Set PID parameters",
        parameters: %{
          joint: %{type: :integer, min: 1, max: 6, required: true},
          p: %{type: :integer, min: 0, max: 100, required: true},
          i: %{type: :integer, min: 0, max: 100, required: true},
          d: %{type: :integer, min: 0, max: 100, required: true}
        }
      },

      112 => %{
        description: "Dynamic force adaptation",
        parameters: %{
          mode: %{type: :integer, min: 0, max: 1, required: true},
          b: %{type: :integer, min: 0, max: 1000, default: 500},
          s: %{type: :integer, min: 0, max: 1000, default: 500},
          e: %{type: :integer, min: 0, max: 1000, default: 500},
          h: %{type: :integer, min: 0, max: 1000, default: 500},
          w: %{type: :integer, min: 0, max: 1000, default: 500},
          g: %{type: :integer, min: 0, max: 1000, default: 500}
        }
      },

      # Gripper Commands (M3)
      222 => %{
        description: "Gripper control",
        parameters: %{
          mode: %{type: :integer, min: 0, max: 1, required: true},
          angle: %{type: :integer, min: 0, max: 100, required: true}
        }
      }
    }
  end
end