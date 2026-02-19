# anthropic.cr

A Crystal client for the Anthropic API.

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

## Count Tokens

Count the number of tokens in a message without sending it:

```crystal
token_count = client.messages.count_tokens(
  model: Anthropic::Model.sonnet,
  messages: [Anthropic::Message.user("Hello, how are you?")]
)
puts token_count.input_tokens
```

With a system prompt:

```crystal
token_count = client.messages.count_tokens(
  model: Anthropic::Model.sonnet,
  messages: [Anthropic::Message.user("Hello!")],
  system: "You are a helpful assistant."
)
puts token_count.input_tokens
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

Unknown content block types from the API (e.g., future additions like `server_thought` or `future_block_type`) are preserved as `UnknownData` rather than causing parse errors. You can inspect them:

```crystal
block.data.as(Anthropic::Content::UnknownData).type_string  # => "server_thought"
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

## Models API

List available models and retrieve model details:

### List models

```crystal
models = client.models.list
models.data.each { |m| puts "#{m.id} - #{m.display_name}" }

# Pagination info
puts models.has_more?
puts models.first_id
puts models.last_id
```

### Retrieve a model

```crystal
model = client.models.retrieve("claude-sonnet-4-20250514")
puts model.id           # "claude-sonnet-4-20250514"
puts model.display_name # "Claude Sonnet 4"
puts model.created_at   # ISO 8601 timestamp
puts model.type         # "model"
```

## Files API

Upload, list, retrieve, and delete files for use with the Anthropic API.

### Upload a file

Files are uploaded as multipart form data:

```crystal
# From a string
file = client.files.upload("data.json", '{"key": "value"}', "application/json")

# From bytes
content = File.read("data.pdf").to_slice.dup
file = client.files.upload(Anthropic::UploadFileRequest.new("data.pdf", content, "application/pdf"))

# From base64
file = client.files.upload(Anthropic::UploadFileRequest.from_base64("doc.txt", base64_data))
```

### List files

```crystal
# Single page
page = client.files.list
page.data.each { |f| puts "#{f.filename} (#{f.size_bytes} bytes)" }

# Auto-paginate all files
client.files.list_all.each do |file|
  puts file.id
end
```

### Retrieve a file

```crystal
file = client.files.retrieve("file_01ABC123")
puts file.filename
puts file.mime_type
puts file.downloadable
```

### Download file content

```crystal
# As raw bytes
bytes = client.files.download("file_01ABC123")

# As string
content = client.files.download_string("file_01ABC123")

# As base64
encoded = client.files.download_base64("file_01ABC123")
```

### Delete a file

```crystal
deleted = client.files.delete("file_01ABC123")
puts deleted.type # "file_deleted"
```

## Message Batches API

Process multiple messages asynchronously with the Message Batches API.

### Create a batch

```crystal
batch = client.batches.create([
  Anthropic::CreateMessageBatchRequest::BatchRequest.new(
    custom_id: "req-1",
    request: Anthropic::Messages::Request.new(
      model: "claude-sonnet-4-20250514",
      messages: [Anthropic::Message.user("Hello")],
      max_tokens: 1024,
    )
  ),
  Anthropic::CreateMessageBatchRequest::BatchRequest.new(
    custom_id: "req-2",
    request: Anthropic::Messages::Request.new(
      model: "claude-sonnet-4-20250514",
      messages: [Anthropic::Message.user("Hi")],
      max_tokens: 1024,
    )
  ),
])

puts batch.id                # "batch_01ABC123"
puts batch.processing_status # "in_progress"
puts batch.request_counts.processing
```

### List batches

```crystal
# Single page
page = client.batches.list
page.data.each { |b| puts "#{b.id} - #{b.processing_status}" }

# Auto-paginate
client.batches.list_all.each do |batch|
  puts batch.id
end
```

### Retrieve a batch

```crystal
batch = client.batches.retrieve("batch_01ABC123")
puts batch.processing_status # "in_progress", "succeeded", "errored", "canceled", "expired"
puts batch.results_url       # Available when processing is complete
```

### Cancel a batch

```crystal
batch = client.batches.cancel("batch_01ABC123")
puts batch.processing_status # "canceled"
```

### Delete a batch

```crystal
deleted = client.batches.delete("batch_01ABC123")
puts deleted.type # "message_batch_deleted"
```

### Get batch results

Results are streamed as NDJSON for memory efficiency:

```crystal
client.batches.results("batch_01ABC123") do |result|
  puts result.custom_id

  case result.result.type
  when "succeeded"
    if message = result.result.message
      puts message.text
      puts "Tokens: #{message.usage.input_tokens}/#{message.usage.output_tokens}"
    end
  when "errored"
    if error = result.result.error
      puts "Error: #{error.message}"
    end
  end
end
```

## Skills API (Beta)

The Skills API requires beta opt-in via the `skills-2025-10-02` header.

### Access through the beta namespace

```crystal
# Skills automatically get the required beta header
skills = client.beta.skills.list

# Or explicitly set additional beta headers
client = Anthropic::Client.new
skills = client.beta(["skills-2025-10-02", "future-feature-2025-01-01"]).skills.list
```

### List skills

```crystal
response = client.beta.skills.list
response.data.each do |skill|
  puts "#{skill.display_title} (#{skill.source})" # source: "custom" or "anthropic"
end
```

### Retrieve a skill

```crystal
skill = client.beta.skills.retrieve("skill_01ABC123")
puts skill.display_title
puts skill.latest_version
puts skill.custom?  # true if source == "custom"
```

### Create a skill

```crystal
# From a file (ZIP archive)
req = Anthropic::UploadSkillRequest.from_file("my_skill.zip")
skill = client.beta.skills.create(req)

# Or create empty (no upload)
skill = client.beta.skills.create
```

### Create a skill version

```crystal
req = Anthropic::UploadSkillRequest.from_file("my_skill_v2.zip")
version = client.beta.skills.create_version("skill_01ABC123", req)
puts version.version     # Unix timestamp
puts version.name        # From SKILL.md
puts version.description # From SKILL.md
```

### Delete a skill

```crystal
deleted = client.beta.skills.delete("skill_01ABC123")
puts deleted.type # "skill_deleted"
```

### Working with skill versions

```crystal
# List versions
versions = client.beta.skills.list_versions("skill_01ABC123")
versions.data.each { |v| puts "#{v.version} - #{v.name}" }

# Retrieve specific version
version = client.beta.skills.retrieve_version("skill_01ABC123", "1234567890")

# Delete a version
deleted = client.beta.skills.delete_version("skill_01ABC123", "1234567890")
```

## Beta Features

The `beta` namespace provides access to beta-only features with automatic header management:

### Beta Namespace

Access beta features through `client.beta`:

```crystal
# Messages with beta headers
response = client.beta.messages.create(
  model: Anthropic::Model.sonnet,
  messages: [Anthropic::Message.user("Hello")],
  max_tokens: 1024,
)

# Streaming with beta headers
client.beta.messages.stream(request) { |event| puts event }

# Models with beta headers
models = client.beta.models.list
model = client.beta.models.retrieve("claude-3-5-sonnet-20241022")

# Files with beta headers
files = client.beta.files.list
file = client.beta.files.retrieve("file_123")

# Batches through beta messages
batches = client.beta.messages.batches.list
batch = client.beta.messages.batches.create(request)

# Custom beta headers
response = client.beta(["future-feature-2025"]).messages.create(request)

# Merge beta headers into existing options
base_options = Anthropic::RequestOptions.new(timeout: 30.seconds)
options = client.beta.merge_options(base_options)
```

## Advanced Request Options

Every API method accepts `request_options` for per-request customization:

```crystal
options = Anthropic::RequestOptions.new(
  timeout: 60.seconds,
  retry_policy: Anthropic::RetryPolicy.new(max_retries: 5),
  beta_headers: ["feature-2025"],
  extra_headers: HTTP::Headers{"X-Custom" => "value"},
  extra_query: {"debug" => "true"},
  extra_body: {"custom_field" => JSON::Any.new("value")},
)

response = client.messages.create(request, request_options: options)
```

**`extra_query`** -- Appends query parameters to the request URL. Existing query parameters take precedence.

**`extra_body`** -- Merges additional JSON fields into the request body. Existing body fields take precedence. Only works with JSON request bodies.

**`extra_headers`** -- Adds custom HTTP headers to the request.

> **Note:** `extra_body` cannot be used with multipart uploads (file and skill uploads).
> These endpoints will raise `ArgumentError` if `extra_body` is provided.
> Use `extra_query` for additional parameters on upload requests.

## Legacy Completions API

> **Deprecated**: The `/v1/complete` endpoint is deprecated. Use the Messages API (`/v1/messages`) for all new development.

The legacy completions API is provided for backward compatibility with older Anthropic models:

```crystal
response = client.completions.create(
  model: "claude-2.1",
  prompt: "\n\nHuman: Hello\n\nAssistant:",
  max_tokens_to_sample: 100
)
puts response.completion
```

With additional parameters:

```crystal
response = client.completions.create(
  model: "claude-2.1",
  prompt: "\n\nHuman: Hello\n\nAssistant:",
  max_tokens_to_sample: 256,
  stop_sequences: ["\n\nHuman:"],
  temperature: 0.7
)
puts response.completion
puts response.stop_reason  # "stop_sequence" or "max_tokens"
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
