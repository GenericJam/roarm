# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-XX

### Added

#### Core Features
- Complete Elixir library for controlling Waveshare RoArm robot arms
- Support for RoArm M2, M2-Pro, M3, and M3-Pro models
- Registry-based multi-robot support
- UART serial communication with Circuits.UART

#### Robot Control
- High-level movement functions (`home/1`, `move_joints/2`, `move_to_position/2`)
- Position and joint angle control (degrees and radians)
- LED control with RGB support
- Torque control for manual teaching
- Emergency stop and safety features

#### Command System
- 3-layer command architecture (high-level → validation → raw communication)
- Comprehensive command validation with `Roarm.CommandValidator`
- Automatic parameter range clamping
- Symbolic value support (`:min`, `:mid`, `:max`)
- 25+ T-command types with full parameter schemas

#### Teaching and Missions
- Drag teaching mode for recording manual movements
- Mission recording and playback system
- Step-by-step movement recording
- Configurable playback speed and repetition

#### Advanced Features
- PID parameter tuning
- Dynamic force adaptation for compliant control
- Gripper control (M3 models)
- Position feedback and joint state monitoring

#### Multi-Robot Support
- Registry-based process naming
- Simultaneous control of multiple robot arms
- Independent communication channels
- Per-robot configuration and state management

#### Testing and Utilities
- Comprehensive test suite (74 tests)
- Demo and debug utilities
- Interactive control functions
- Hardware connection testing

#### Documentation
- Complete API documentation with ExDoc
- Getting Started guide
- Hardware Setup guide
- Command Reference guide
- Code examples and troubleshooting

### Architecture

#### Modules
- `Roarm.Robot` - High-level robot control GenServer
- `Roarm.Communication` - UART communication GenServer
- `Roarm.CommandValidator` - Command validation and schemas
- `Roarm.Demo` - Interactive demo functions
- `Roarm.Debug` - Debugging and diagnostics

#### Function Signatures
- Consistent `function_name(params, opts \\ [])` pattern
- `:server_name` option for multi-robot targeting
- `:timeout` options for all operations
- Backwards compatible defaults

### Technical Details

#### Dependencies
- `circuits_uart ~> 1.5` - Serial communication
- `jason ~> 1.4` - JSON encoding/decoding
- `ex_doc ~> 0.34` - Documentation generation (dev only)

#### Communication Protocol
- 115200 baud rate serial communication
- JSON command format with T-codes
- Automatic response handling and timeout management
- Connection state tracking and error recovery

#### Validation Features
- Parameter type checking and conversion
- Range validation with automatic clamping
- Required parameter enforcement
- Symbolic value resolution
- Schema-based command definitions

### Breaking Changes
- None (initial release)

### Deprecated
- None (initial release)

### Removed
- None (initial release)

### Fixed
- None (initial release)

### Security
- Safe parameter validation prevents invalid commands
- No credential storage or network communication
- Local serial communication only