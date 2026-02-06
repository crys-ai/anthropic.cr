require "json"

# Response content block for parsing API responses.
# This is separate from Content::Block which is for building requests.
struct Anthropic::ResponseTextBlock
  include JSON::Serializable

  @[JSON::Field(converter: Anthropic::Converters::ContentTypeConverter)]
  getter type : Content::Type = Content::Type::Text
  getter text : String

  def initialize(@text : String)
  end
end

# Alias for backward compatibility.
alias Anthropic::TextBlock = ResponseTextBlock
