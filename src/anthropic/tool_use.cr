require "json"

# Tool definition for the Anthropic Messages API.
struct Anthropic::ToolDefinition
  getter name : String
  getter description : String?
  getter input_schema : JSON::Any

  def initialize(
    @name : String,
    @input_schema : JSON::Any,
    @description : String? = nil,
  )
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "name", @name
      json.field "description", @description if @description
      json.field "input_schema", @input_schema
    end
  end
end

# Tool choice configuration.
struct Anthropic::ToolChoice
  getter type : String # "auto", "any", "tool"
  getter name : String?

  def initialize(@type : String, @name : String? = nil)
  end

  # Let the model decide whether to use tools.
  def self.auto : ToolChoice
    new("auto")
  end

  # Force the model to use a tool (any tool).
  def self.any : ToolChoice
    new("any")
  end

  # Force the model to use a specific tool.
  def self.tool(name : String) : ToolChoice
    new("tool", name)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "type", @type
      json.field "name", @name if @name
    end
  end
end

# Helper for extracting tool use blocks from API responses.
module Anthropic::ToolUse
  # Extract all tool use blocks from a response.
  def self.extract_tool_calls(response : Messages::Response) : Array(ResponseToolUseBlock)
    response.tool_use_blocks
  end

  # Build a tool result message from tool call results.
  # Takes an array of {tool_use_id, content} tuples.
  def self.build_tool_result(
    results : Array({String, String}),
    is_error : Bool = false,
  ) : Message
    blocks = [] of ContentBlock
    results.each do |(id, content)|
      blocks << Content.tool_result(id, content, is_error: is_error)
    end
    Message.new(role: Message::Role::User, content: blocks)
  end

  # Build a single tool result message.
  def self.build_tool_result(
    tool_use_id : String,
    content : String,
    is_error : Bool = false,
  ) : Message
    blocks = [] of ContentBlock
    blocks << Content.tool_result(tool_use_id, content, is_error: is_error)
    Message.new(role: Message::Role::User, content: blocks)
  end

  # Check if a response contains any tool use blocks.
  def self.has_tool_calls?(response : Messages::Response) : Bool
    !response.tool_use_blocks.empty?
  end

  # Check if the model stopped because it wants to use a tool.
  def self.wants_tool_use?(response : Messages::Response) : Bool
    response.stop_reason == Messages::Response::StopReason::ToolUse
  end
end
