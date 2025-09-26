defmodule Roarm.CommandValidatorTest do
  use ExUnit.Case
  alias Roarm.CommandValidator

  describe "Command validation" do
    test "validates simple home command" do
      assert {:ok, validated} = CommandValidator.validate_command(%{t: 100})
      assert validated.t == 100
    end

    test "validates joint control command with all parameters" do
      command = %{t: 121, joint: 4, angle: 90, spd: 2000}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.t == 121
      assert validated.joint == 4
      assert validated.angle == 90
      assert validated.spd == 2000
    end

    test "applies default values for missing optional parameters" do
      command = %{t: 121, joint: 2, angle: 45}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.spd == 1000  # Default speed
    end

    test "clamps values that exceed maximum" do
      command = %{t: 121, joint: 1, angle: 45, spd: 9999}  # Speed too high
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.spd == 4096  # Clamped to maximum
    end

    test "clamps values that are below minimum" do
      command = %{t: 121, joint: 1, angle: 45, spd: -100}  # Speed too low
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.spd == 1  # Clamped to minimum
    end

    test "handles symbolic values" do
      command = %{t: 121, joint: 1, angle: 45, spd: :max}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.spd == 4096  # Maximum speed
    end

    test "handles :min symbolic value" do
      command = %{t: 121, joint: 1, angle: 45, spd: :min}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.spd == 1  # Minimum speed
    end

    test "handles :mid symbolic value" do
      command = %{t: 121, joint: 1, angle: 45, spd: :mid}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.spd == 2049  # Middle of 1-4096 range (rounded)
    end

    test "validates LED command" do
      command = %{t: 114, led: 128, r: 255, g: 0, b: 0}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.t == 114
      assert validated.led == 128
      assert validated.r == 255
      assert validated.g == 0
      assert validated.b == 0
    end

    test "validates LED command with symbolic brightness" do
      command = %{t: 114, led: :max}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.led == 255
    end

    test "validates joint control with all 6 joints (M3)" do
      command = %{t: 122, b: 30, s: 45, e: -30, h: 15, w: 90, g: -45, spd: 1500}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.b == 30.0
      assert validated.s == 45.0
      assert validated.e == -30.0
      assert validated.h == 15.0
      assert validated.w == 90.0
      assert validated.g == -45.0
      assert validated.spd == 1500
    end

    test "validates mission creation" do
      command = %{t: 220, name: "test_mission", intro: "Test description"}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.name == "test_mission"
      assert validated.intro == "Test description"
    end

    test "applies default description for mission" do
      command = %{t: 220, name: "test_mission"}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.name == "test_mission"
      assert validated.intro == ""  # Default empty string
    end

    test "returns error for unknown command" do
      command = %{t: 9999, unknown: "parameter"}
      assert {:error, {:unknown_command, 9999}} = CommandValidator.validate_command(command)
    end

    test "returns error for missing required parameters" do
      command = %{t: 121}  # Missing required joint and angle
      assert {:error, {:validation_error, _message}} = CommandValidator.validate_command(command)
    end

    test "handles string keys" do
      command = %{"T" => 100}
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.t == 100
    end

    test "converts to JSON correctly" do
      validated = %{t: 121, joint: 4, angle: 90, spd: 2000}
      json = CommandValidator.to_json(validated)

      assert is_binary(json)
      decoded = Jason.decode!(json)
      assert decoded["T"] == 121
      assert decoded["joint"] == 4
      assert decoded["angle"] == 90
      assert decoded["spd"] == 2000
    end
  end

  describe "Edge cases and boundary conditions" do
    test "handles floating point angles" do
      command = %{t: 121, joint: 1, angle: 45.5, spd: 1000}
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.angle == 45.5
    end

    test "converts integer angles to float internally" do
      command = %{t: 121, joint: 1, angle: 45, spd: 1000}
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.angle == 45  # Should still be a number
    end

    test "clamps angle to valid range" do
      command = %{t: 121, joint: 1, angle: 200, spd: 1000}  # Angle too high
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.angle == 180.0  # Clamped to max
    end

    test "handles zero values" do
      command = %{t: 121, joint: 1, angle: 0, spd: 1}
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.angle == 0
      assert validated.spd == 1
    end

    test "validates PID parameters" do
      command = %{t: 108, joint: 1, p: 16, i: 0, d: 1}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.joint == 1
      assert validated.p == 16
      assert validated.i == 0
      assert validated.d == 1
    end

    test "validates dynamic force adaptation" do
      command = %{t: 112, mode: 1, b: 60, s: 110, e: 50, h: 50}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.mode == 1
      assert validated.b == 60
      assert validated.s == 110
      assert validated.e == 50
      assert validated.h == 50
      assert validated.w == 500  # Default value
      assert validated.g == 500  # Default value
    end

    test "validates gripper commands" do
      command = %{t: 222, mode: 1, angle: 75}
      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.mode == 1
      assert validated.angle == 75
    end
  end

  describe "Complex validation scenarios" do
    test "validates full joint command with symbolic values" do
      command = %{
        t: 122,
        b: :min,
        s: :mid,
        e: :max,
        h: 0,
        w: 90,
        g: -90,
        spd: :max
      }

      assert {:ok, validated} = CommandValidator.validate_command(command)

      assert validated.b == -180.0  # min angle
      assert validated.s == 0.0     # mid angle
      assert validated.e == 180.0   # max angle
      assert validated.spd == 4096  # max speed
    end

    test "validates mission delay with edge values" do
      command = %{t: 224, mission: "test", delay: 0}
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.delay == 0

      command = %{t: 224, mission: "test", delay: 60000}
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.delay == 60000
    end

    test "clamps mission delay that exceeds maximum" do
      command = %{t: 224, mission: "test", delay: 70000}
      assert {:ok, validated} = CommandValidator.validate_command(command)
      assert validated.delay == 60000  # Clamped to max
    end
  end

  describe "Command schemas access" do
    test "command_schemas returns all schemas" do
      schemas = CommandValidator.command_schemas()

      assert is_map(schemas)
      assert map_size(schemas) > 0

      # Check that major commands are present
      assert Map.has_key?(schemas, 100)   # Home position
      assert Map.has_key?(schemas, 122)   # All joints control
      assert Map.has_key?(schemas, 1041)  # Position control
      assert Map.has_key?(schemas, 114)   # LED control
      assert Map.has_key?(schemas, 220)   # Create mission
    end

    test "schemas have correct structure" do
      schemas = CommandValidator.command_schemas()

      # Test a few key schemas
      home_schema = schemas[100]
      assert home_schema.description == "Home position"
      assert is_map(home_schema.parameters)

      joint_schema = schemas[122]
      assert joint_schema.description == "All joints control (degrees)"
      assert is_map(joint_schema.parameters)
      assert Map.has_key?(joint_schema.parameters, :b)
      assert Map.has_key?(joint_schema.parameters, :spd)

      position_schema = schemas[1041]
      assert position_schema.description == "Position control"
      x_param = position_schema.parameters[:x]
      assert x_param.type == :float
      assert x_param.min == -500.0
      assert x_param.max == 500.0
      assert x_param.required == true
    end

    test "can access parameter details for validation" do
      schemas = CommandValidator.command_schemas()

      # Test position control parameters
      pos_params = schemas[1041].parameters
      assert pos_params[:x].min == -500.0
      assert pos_params[:x].max == 500.0
      assert pos_params[:y].min == -500.0
      assert pos_params[:y].max == 500.0
      assert pos_params[:z].min == 0.0
      assert pos_params[:z].max == 500.0
      assert pos_params[:t].min == -180.0
      assert pos_params[:t].max == 180.0

      # Test joint control parameters
      joint_params = schemas[122].parameters
      assert joint_params[:b].min == -180.0
      assert joint_params[:b].max == 180.0
      assert joint_params[:spd].min == 1
      assert joint_params[:spd].max == 4096
      assert joint_params[:spd].default == 1000
    end

    test "schemas can be used for custom validation" do
      schemas = CommandValidator.command_schemas()

      # Example: Check if a T-code exists
      assert Map.has_key?(schemas, 100)
      refute Map.has_key?(schemas, 999)

      # Example: Get parameter names for a command
      joint_param_names = Map.keys(schemas[122].parameters)
      assert :b in joint_param_names
      assert :s in joint_param_names
      assert :spd in joint_param_names

      # Example: Check parameter requirements
      pos_params = schemas[1041].parameters
      required_params = pos_params
                       |> Enum.filter(fn {_, spec} -> Map.get(spec, :required, false) end)
                       |> Enum.map(fn {name, _} -> name end)

      assert :x in required_params
      assert :y in required_params
      assert :z in required_params
      refute :t in required_params  # has default, not required
    end
  end
end