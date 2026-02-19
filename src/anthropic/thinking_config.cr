require "json"

# Configuration for extended thinking.
#
# Extended thinking allows Claude to show its reasoning process.
# Set a budget_tokens value to control how many tokens can be used for thinking.
#
# Example:
# ```
# config = Anthropic::ThinkingConfig.new(budget_tokens: 10000)
# request = Anthropic::Messages::Request.new(
#   model: Anthropic::Model.sonnet,
#   messages: [Anthropic::Message.user("Solve this problem...")],
#   max_tokens: 4096,
#   thinking: config
# )
# ```
struct Anthropic::ThinkingConfig
  getter type : String = "enabled"
  getter budget_tokens : Int32?

  def initialize(@budget_tokens : Int32? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "type", @type
      json.field "budget_tokens", @budget_tokens if @budget_tokens
    end
  end
end
