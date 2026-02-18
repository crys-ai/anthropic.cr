require "json"

# Tool result content data for returning tool call results.
struct Anthropic::Content::ToolResultData
  include Data

  getter tool_use_id : String
  getter content : String | Array(JSON::Any)
  getter? is_error : Bool

  def initialize(@tool_use_id : String, @content : String | Array(JSON::Any), @is_error : Bool = false)
  end

  def content_type : Type
    Type::ToolResult
  end

  def to_content_json(json : JSON::Builder) : Nil
    json.field "tool_use_id", @tool_use_id
    json.field "content", @content
    json.field "is_error", @is_error if @is_error
  end
end
