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

# Content (generic content blocks for requests)
require "./anthropic/content/type"
require "./anthropic/content/data"
require "./anthropic/content/block"
require "./anthropic/content/text_data"
require "./anthropic/content/image_data"
require "./anthropic/content/tool_use_data"
require "./anthropic/content/tool_result_data"
require "./anthropic/content/unknown_data"
require "./anthropic/content"

# Models (order matters - dependencies first)
require "./anthropic/models/content"
require "./anthropic/models/usage"
require "./anthropic/models/message"
require "./anthropic/models/converters"
require "./anthropic/models"

# Messages API
require "./anthropic/messages/request"
require "./anthropic/messages/response"
require "./anthropic/messages/api"

# Client (depends on Messages::API)
require "./anthropic/client"

# Streaming (SSE support)
require "./anthropic/streaming/event_source"
require "./anthropic/streaming/event"
