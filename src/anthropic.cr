# Anthropic API client for Crystal
#
# A Crystal client for the Anthropic Messages API.
#
# ## Quick Start
#
# ```
# require "anthropic"
#
# client = Anthropic::Client.new
# response = client.messages.create(
#   model: Anthropic::Model.sonnet,
#   messages: [Anthropic::Message.user("Hello!")],
#   max_tokens: 1024
# )
# puts response.text
# ```
#
# ## Configuration
#
# By default, the client reads `ANTHROPIC_API_KEY` from environment.
# You can also pass it explicitly:
#
# ```
# client = Anthropic::Client.new(api_key: "sk-ant-...")
# ```
class Anthropic
end

# Core
require "./anthropic/version"
require "./anthropic/errors"
require "./anthropic/retry_policy"
require "./anthropic/configuration"
require "./anthropic/request_options"
require "./anthropic/metadata"

# Content (generic content blocks for requests)
require "./anthropic/content/type"
require "./anthropic/content/data"
require "./anthropic/content/block"
require "./anthropic/content/text_data"
require "./anthropic/content/image_data"
require "./anthropic/content/tool_use_data"
require "./anthropic/content/tool_result_data"
require "./anthropic/content/thinking_data"
require "./anthropic/content/unknown_data"
require "./anthropic/content"

# Models (order matters - dependencies first)
require "./anthropic/models/content"
require "./anthropic/models/usage"
require "./anthropic/models/message"
require "./anthropic/models/converters"
require "./anthropic/models"
require "./anthropic/models/model_info"
require "./anthropic/models/api"

# Thinking (extended thinking config)
require "./anthropic/thinking_config"

# Messages API
require "./anthropic/messages/request"
require "./anthropic/messages/response"
require "./anthropic/messages/count_tokens"
require "./anthropic/messages/api"
require "./anthropic/messages/batch"
require "./anthropic/messages/batch_api"

# Files API
require "./anthropic/files/file"
require "./anthropic/files/api"

# Skills API
require "./anthropic/skills/skill"
require "./anthropic/skills/api"

# Completions API (legacy/deprecated)
require "./anthropic/completions/request"
require "./anthropic/completions/response"
require "./anthropic/completions/api"

# Pagination
require "./anthropic/pagination"

# Tool use helpers
require "./anthropic/tool_use"

# Structured output helpers
require "./anthropic/structured_output"

# Client (depends on Messages::API)
require "./anthropic/client"

# Beta namespace
require "./anthropic/beta/batches_api"
require "./anthropic/beta/files_api"
require "./anthropic/beta/messages_api"
require "./anthropic/beta/models_api"
require "./anthropic/beta/api"

# Tool runner
require "./anthropic/tool_runner"

# Streaming (SSE support)
require "./anthropic/streaming/event_source"
require "./anthropic/streaming/event"
