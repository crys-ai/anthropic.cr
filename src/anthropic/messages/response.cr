require "json"

struct Anthropic::Messages::Response
  include JSON::Serializable

  enum StopReason
    EndTurn
    MaxTokens
    StopSequence
    ToolUse
  end

  getter id : String
  getter type : String

  @[JSON::Field(converter: Anthropic::Converters::RoleConverter)]
  getter role : Message::Role

  getter content : Array(TextBlock)
  getter model : String

  @[JSON::Field(converter: Anthropic::Converters::StopReasonConverter)]
  getter stop_reason : StopReason?

  getter stop_sequence : String?
  getter usage : Usage

  def text : String
    content.map(&.text).join
  end
end
