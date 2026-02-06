require "json"

# Tool use content data for function calling.
struct Anthropic::Content::ToolUseData
  include Data

  getter id : String
  getter name : String
  getter input : JSON::Any

  def initialize(@id : String, @name : String, @input : JSON::Any)
  end

  def content_type : Type
    Type::ToolUse
  end

  def to_content_json(json : JSON::Builder) : Nil
    json.field "id", @id
    json.field "name", @name
    json.field "input", @input
  end
end
