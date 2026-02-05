# Anthropic API client for Crystal
#
# A pure Crystal client for the Anthropic Messages API.
#
# ## Quick Start
#
# ```crystal
# require "anthropic"
#
# client = Anthropic::Client.new
# response = client.messages.create(
#   model: Anthropic::Models::CLAUDE_SONNET_4,
#   messages: [Anthropic::Message.user("Hello!")],
#   max_tokens: 1024
# )
# puts response.content.first.as(Anthropic::TextBlock).text
# ```
#
# ## Configuration
#
# By default, the client reads `ANTHROPIC_API_KEY` from environment.
# You can also pass it explicitly:
#
# ```crystal
# client = Anthropic::Client.new(api_key: "sk-ant-...")
# ```
class Anthropic
  # Convenience method to create a single message
  def self.message(
    model : String,
    messages : Array(Message),
    max_tokens : Int32,
    **options
  ) : Messages::Response
    Client.new.messages.create(
      Messages::Request.new(model, messages, max_tokens, **options)
    )
  end
end

require "./anthropic/version"
require "./anthropic/models/*"
require "./anthropic/messages/*"
require "./anthropic/client"
