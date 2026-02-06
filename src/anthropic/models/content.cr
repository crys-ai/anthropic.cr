require "json"

# Response content block for parsing API responses.
# This is separate from Content::Block which is for building requests.
struct Anthropic::ResponseTextBlock
  include JSON::Serializable

  getter type : String = "text"
  getter text : String

  def initialize(@text : String)
  end
end

# Response content block for tool use in API responses.
struct Anthropic::ResponseToolUseBlock
  include JSON::Serializable

  getter type : String
  getter id : String
  getter name : String
  getter input : JSON::Any

  def initialize(@id : String, @name : String, @input : JSON::Any)
    @type = "tool_use"
  end
end

# Response content block for forward compatibility.
# Preserves unknown block types without failing parsing.
struct Anthropic::ResponseUnknownBlock
  getter type : String
  getter raw : JSON::Any

  def initialize(@type : String, @raw : JSON::Any)
  end

  def to_json(json : JSON::Builder) : Nil
    @raw.to_json(json)
  end
end

# Union type for all possible response content blocks.
alias Anthropic::ResponseContentBlock = Anthropic::ResponseTextBlock |
                                        Anthropic::ResponseToolUseBlock |
                                        Anthropic::ResponseUnknownBlock
