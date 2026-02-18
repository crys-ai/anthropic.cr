# Contributing to anthropic.cr

Thank you for your interest in contributing to anthropic.cr!
This document provides guidelines and information to help you get started.

## Table of Contents

- [Development Setup](#development-setup)
- [Project Architecture](#project-architecture)
- [Running Tests](#running-tests)
- [Code Coverage](#code-coverage)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)

## Development Setup

### Prerequisites

- [Crystal](https://crystal-lang.org/install/) >= 1.18.2 (I recommend using [mise](https://github.com/jdx/mise))
- [Hace](https://github.com/ralsina/hace) task runner (could be installed via shards)
- [Lefthook](https://github.com/evilmartians/lefthook#install) - Git hooks manager

### Setup

1. Clone the repository:

```bash
git clone https://github.com/crys-ai/anthropic.cr.git
cd anthropic.cr
```

1. Install dependencies and build tools:

```bash
shards install
shards build ameba
shards build hace # currently broken due to upstream bug, better install via yay or copy an older binary to /bin
```

1. Install git hooks:

```bash
lefthook install
```

1. Run tests:

```bash
bin/hace spec
```

## Project Architecture

```
src/
├── anthropic.cr                  # Entry point (Namespace + requires)
└── anthropic/
    ├── client.cr                 # HTTP::Client + DB::Pool
    ├── configuration.cr          # Configuration struct
    ├── version.cr                # Compile-time version
    ├── errors.cr                 # Error hierarchy
    ├── models.cr                 # Model enum
    ├── content/                  # Generic content block system
    │   ├── data.cr               # Data protocol
    │   ├── block.cr              # Block(T) generic
    │   ├── type.cr               # Type enum
    │   ├── text_data.cr          # Text content
    │   ├── image_data.cr         # Image content
    │   ├── tool_use_data.cr      # Tool use content
    │   ├── tool_result_data.cr   # Tool result content
    │   └── unknown_data.cr       # Forward-compat unknown types
    ├── content.cr                # Factory methods + union type
    ├── models/                   # API data models
    │   ├── message.cr            # Message struct + JSON parser
    │   ├── content.cr            # Response content blocks
    │   ├── converters.cr         # JSON converters
    │   └── usage.cr              # Usage stats
    ├── messages/                 # Messages API
    │   ├── api.cr                # API client (create + stream)
    │   ├── request.cr            # Request struct
    │   └── response.cr           # Response struct
    └── streaming/                # SSE streaming
        ├── event.cr              # StreamEvent types
        └── event_source.cr       # SSE parser
```

### Module Overview

- **`Anthropic::Client`** -- Entry point. Wraps HTTP::Client, handles authentication headers and error responses.
- **`Anthropic::Content::Block(T)`** -- Generic content block parameterized on a `Data` protocol type. Provides compile-time type safety for text, image, tool use, and tool result blocks.
- **`Anthropic::Content::UnknownData`** -- Forward-compatibility catch-all for unrecognized content block types from the API.
- **`Anthropic::Messages::API`** -- Messages endpoint handler (`create` for synchronous, `stream` for SSE).
- **`Anthropic::Messages::Request` / `Response`** -- Structs for serializing requests and deserializing responses.
- **`Anthropic::Model`** -- Enum of supported models with convenience aliases (`.opus`, `.sonnet`, `.haiku`) and API string conversion.
- **`Anthropic::EventSource`** -- SSE parser for streaming responses.

## Running Tests

```bash
# Run all tests
bin/hace spec

# Run specific test file
crystal spec spec/anthropic/somefile.cr

# Run with verbose output
crystal spec --verbose
```

## Integration Tests

Integration tests are end-to-end style tests that simulate real API interactions using WebMock. They verify the full request/response cycle without hitting the actual Anthropic API.

Run them with the standard test command:

```bash
crystal spec
```

These tests use mocked HTTP responses to ensure consistent, fast test execution without requiring API credentials.

## Code Coverage

Code coverage is automatically generated and uploaded to [Codecov](https://codecov.io) on every push to `main`. The CI workflow uses [kcov](https://github.com/SimonKagstrom/kcov) to measure coverage.

View coverage reports at: `https://codecov.io/gh/crys-ai/anthropic.cr`

### Available Tasks

Run `bin/hace --list` to see all available tasks. Key tasks:

| Task              | Description            |
| ----------------- | ---------------------- |
| `bin/hace spec`   | Run crystal spec       |
| `bin/hace format` | Format code            |
| `bin/hace ameba`  | Run Ameba linter       |
| `bin/hace all`    | Format, lint, and test |
| `bin/hace clean`  | Clean build artifacts  |

### Pre-commit Hooks

The project uses Lefthook for pre-commit hooks. They run automatically on commit:

- `bin/hace format` - Code formatting
- `bin/hace ameba` - Static analysis
- `yamlfmt` - YAML formatting

To run hooks manually:

```bash
lefthook run pre-commit
```

## Code Style

- Follow Crystal's standard formatting (`bin/hace format`)
- Use `bin/hace ameba` for static analysis
- Keep methods focused and small
- Document public methods with Crystal doc comments
- Use meaningful variable and method names

## Submitting Changes

1. **Fork** the repository
2. **Create a branch** for your feature or fix
3. **Write tests** for new functionality
4. **Run `bin/hace all`** to format, lint, and test
5. **Commit** with a clear message
6. **Push** and create a Pull Request

### Commit Message Format

```
Add feature description

- Bullet points for specific changes
- Keep it concise but informative
```

### Pull Request Guidelines

- Reference any related issues
- Describe what changed and why
- Include test coverage for new features
- Update documentation if needed

## Questions?

Open an issue if you have questions or need guidance on a contribution.
