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
Anthropic::Model.opus      # Claude Opus 4.6 (latest)
Anthropic::Model.sonnet    # Claude Sonnet 4.6 (latest)
Anthropic::Model.haiku     # Claude Haiku 4.5 (latest)

# Or use specific versions
Anthropic::Model::ClaudeOpus4_6
Anthropic::Model::ClaudeSonnet4_6
Anthropic::Model::ClaudeOpus4_5
Anthropic::Model::ClaudeSonnet4_5
Anthropic::Model::ClaudeHaiku4_5
Anthropic::Model::ClaudeOpus4
Anthropic::Model::ClaudeSonnet4
```

> **Note:** The `Request` accepts `String | Model` for the model parameter, so custom model strings are also supported.

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

## Streaming

Stream responses token-by-token using server-sent events (SSE):

```crystal
client.messages.stream(
  model: Anthropic::Model.sonnet,
  messages: [Anthropic::Message.user("Tell me a story")],
  max_tokens: 1024,
) do |event|
  case event
  when Anthropic::StreamEvent::ContentBlockDelta
    print event.delta.text if event.delta.text
  when Anthropic::StreamEvent::MessageStop
    puts # newline at end
  end
end
```

## Response

```crystal
response.id            # "msg_01XFDUDYJgAACzvnptvVoYEL"
response.model         # "claude-sonnet-4-5-20251101"
response.role          # "assistant" (String - raw value)
response.role_enum     # Anthropic::Message::Role::Assistant (typed enum, nil for unknown roles)
response.stop_reason   # Anthropic::Messages::Response::StopReason::EndTurn
response.text          # Combined text from all content blocks

# Token usage
response.usage.input_tokens   # 25
response.usage.output_tokens  # 42
response.usage.total_tokens   # 67
```

The `role` field is a raw string for forward compatibility with future role values. Use `role_enum` for type-safe role checks:

```crystal
case response.role_enum
when Anthropic::Message::Role::Assistant
  # handle assistant response
when Anthropic::Message::Role::User
  # handle user message (rare in responses)
else
  # future/unknown role - forward compatible
end
```

## Forward Compatibility

Unknown content block types from the API (e.g., future additions like `thinking`) are preserved as `UnknownData` rather than causing parse errors. You can inspect them:

```crystal
block.data.as(Anthropic::Content::UnknownData).type_string  # => "thinking"
block.data.as(Anthropic::Content::UnknownData).raw           # => JSON::Any
```

This means your code will not break when Anthropic introduces new content block types.

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
# Enum names: see `--help` output (e.g. claude_opus4_6, claude_sonnet4_5)

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

# Run all tests including integration (WebMock-mocked end-to-end tests)
crystal spec
```

## License

MIT
