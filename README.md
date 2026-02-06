# anthropic.cr

A Crystal client for the Anthropic Messages API.

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  anthropic:
    github: crys-ai/anthropic.cr
```

Then run `shards install`.

## Quick Start

```crystal
require "anthropic"

client = Anthropic::Client.new
response = client.messages.create(
  model: Anthropic::Model.sonnet,
  messages: [Anthropic::Message.user("Hello!")],
  max_tokens: 1024
)
puts response.text
```

## Configuration

By default, the client reads `ANTHROPIC_API_KEY` from environment:

```crystal
client = Anthropic::Client.new
```

Or pass it explicitly:

```crystal
client = Anthropic::Client.new(api_key: "sk-ant-...")
```

Custom base URL and timeout:

```crystal
client = Anthropic::Client.new(
  api_key: "sk-ant-...",
  base_url: "https://custom.api",
  timeout: 60.seconds
)
```

## Models

Type-safe model selection with the `Model` enum:

```crystal
Anthropic::Model.opus      # Claude Opus 4.5 (latest)
Anthropic::Model.sonnet    # Claude Sonnet 4.5 (latest)
Anthropic::Model.haiku     # Claude Haiku 3.5 (latest)

# Or use specific versions
Anthropic::Model::ClaudeOpus4_5
Anthropic::Model::ClaudeSonnet4_5
Anthropic::Model::ClaudeOpus4
Anthropic::Model::ClaudeSonnet4
Anthropic::Model::ClaudeSonnet3_5
Anthropic::Model::ClaudeHaiku3_5
```

## Messages API

### Basic message

```crystal
response = client.messages.create(
  model: Anthropic::Model.sonnet,
  messages: [Anthropic::Message.user("What is Crystal?")],
  max_tokens: 1024
)
puts response.text
```

### With system prompt

```crystal
response = client.messages.create(
  model: Anthropic::Model.sonnet,
  messages: [Anthropic::Message.user("Hello!")],
  max_tokens: 1024,
  system: "You are a helpful assistant who speaks like a pirate."
)
```

### Multi-turn conversation

```crystal
messages = [
  Anthropic::Message.user("What's the capital of France?"),
  Anthropic::Message.assistant("The capital of France is Paris."),
  Anthropic::Message.user("What's its population?"),
]

response = client.messages.create(
  model: Anthropic::Model.sonnet,
  messages: messages,
  max_tokens: 1024
)
```

### With parameters

```crystal
response = client.messages.create(
  model: Anthropic::Model.opus,
  messages: [Anthropic::Message.user("Write a haiku")],
  max_tokens: 100,
  temperature: 0.9,
  top_p: 0.95,
  stop_sequences: ["\n\n"]
)
```

## Response

```crystal
response.id            # "msg_01XFDUDYJgAACzvnptvVoYEL"
response.model         # "claude-sonnet-4-5-20251101"
response.role          # Anthropic::Message::Role::Assistant
response.stop_reason   # Anthropic::Messages::Response::StopReason::EndTurn
response.text          # Combined text from all content blocks

# Token usage
response.usage.input_tokens   # 25
response.usage.output_tokens  # 42
response.usage.total_tokens   # 67
```

## Error Handling

```crystal
begin
  response = client.messages.create(...)
rescue ex : Anthropic::AuthenticationError
  puts "Invalid API key"
rescue ex : Anthropic::RateLimitError
  puts "Rate limited, retry later"
rescue ex : Anthropic::OverloadedError
  puts "API overloaded, retry later"
rescue ex : Anthropic::InvalidRequestError
  puts "Bad request: #{ex.error_message}"
rescue ex : Anthropic::APIError
  puts "API error: #{ex.status_code} - #{ex.error_message}"
end
```

## CLI

A simple CLI is included for testing:

```bash
# Basic usage
crystal run examples/cli.cr -- message "Hello!"

# With options
crystal run examples/cli.cr -- message "Hello!" -m opus -t 2048 -v

# Show help
crystal run examples/cli.cr -- -h

# Model values
# Aliases: opus, sonnet, haiku
# Enum names: see `--help` output (e.g. claude_opus4_5)

# Invalid input handling
# Invalid model/option values print "Error: ..." + usage and exit with code 1

# Options
-m MODEL    Model alias or enum name
-t TOKENS   Max tokens
-s SYSTEM   System prompt
-v          Verbose (show token usage)
-h          Help
```

## Development

```bash
# Install dependencies
shards install

# Run all checks (format, lint, test)
bin/hace all

# Individual checks
crystal tool format
bin/ameba
crystal spec
```

## License

MIT
