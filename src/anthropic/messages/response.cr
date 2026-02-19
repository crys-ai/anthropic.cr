require "json"

struct Anthropic::Messages::Response
  enum StopReason
    EndTurn
    MaxTokens
    StopSequence
    ToolUse
  end

  getter id : String
  getter type : String
  getter role : String
  getter content : Array(ResponseContentBlock)
  getter model : String
  getter stop_reason : StopReason?
  getter stop_sequence : String?
  getter usage : Usage

  # Request ID extracted from HTTP response headers (not part of JSON body).
  # Set by Messages::API after parsing the response.
  property request_id : String?

  def initialize(
    @id : String,
    @type : String,
    @role : String,
    @content : Array(ResponseContentBlock),
    @model : String,
    @stop_reason : StopReason?,
    @stop_sequence : String?,
    @usage : Usage,
  )
  end

  def self.new(pull : JSON::PullParser) : Response
    id = ""
    type = ""
    role = "assistant"
    content = [] of ResponseContentBlock
    model = ""
    stop_reason : StopReason? = nil
    stop_sequence : String? = nil
    usage = Usage.new

    found_id = false
    found_type = false
    found_role = false
    found_model = false
    found_usage = false

    pull.read_object do |key|
      case key
      when "id"            then id = pull.read_string; found_id = true
      when "type"          then type = pull.read_string; found_type = true
      when "role"          then role = pull.read_string; found_role = true
      when "content"       then content = parse_content(pull)
      when "model"         then model = pull.read_string; found_model = true
      when "stop_reason"   then stop_reason = parse_stop_reason(pull)
      when "stop_sequence" then stop_sequence = pull.read_null_or { pull.read_string }
      when "usage"         then usage = Usage.new(pull); found_usage = true
      else                      pull.skip
      end
    end

    validate_required_fields(found_id, found_type, found_role, found_model, found_usage)
    new(id, type, role, content, model, stop_reason, stop_sequence, usage)
  end

  def text : String
    content.compact_map do |block|
      block.is_a?(ResponseTextBlock) ? block.text : nil
    end.join
  end

  def tool_use_blocks : Array(ResponseToolUseBlock)
    content.select(ResponseToolUseBlock)
  end

  # Returns a typed enum for the role if it's a known value.
  # Returns nil for unknown/future role values (forward compatibility).
  # Case-insensitive: handles "assistant", "Assistant", etc.
  def role_enum : Anthropic::Message::Role?
    Anthropic::Message::Role.parse?(@role)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "id", @id
      json.field "type", @type
      json.field "role", @role
      json.field "content", @content
      json.field "model", @model
      json.field "stop_reason" { Converters::StopReasonConverter.to_json(@stop_reason, json) }
      json.field "stop_sequence", @stop_sequence
      json.field "usage", @usage
    end
  end

  private def self.validate_required_fields(
    found_id : Bool,
    found_type : Bool,
    found_role : Bool,
    found_model : Bool,
    found_usage : Bool,
  ) : Nil
    raise JSON::ParseException.new("Missing required field 'id' in Messages::Response", 0, 0) unless found_id
    raise JSON::ParseException.new("Missing required field 'type' in Messages::Response", 0, 0) unless found_type
    raise JSON::ParseException.new("Missing required field 'role' in Messages::Response", 0, 0) unless found_role
    raise JSON::ParseException.new("Missing required field 'model' in Messages::Response", 0, 0) unless found_model
    raise JSON::ParseException.new("Missing required field 'usage' in Messages::Response", 0, 0) unless found_usage
  end

  private def self.parse_content(pull : JSON::PullParser) : Array(ResponseContentBlock)
    blocks = [] of ResponseContentBlock
    pull.read_array do
      block_json = JSON::Any.new(pull)
      type = block_json["type"]?.try(&.as_s)
      raw = block_json.to_json
      case type
      when "text"     then blocks << ResponseTextBlock.from_json(raw)
      when "tool_use" then blocks << ResponseToolUseBlock.from_json(raw)
      when "thinking" then blocks << ResponseThinkingBlock.from_json(raw)
      else                 blocks << ResponseUnknownBlock.new(type || "unknown", block_json)
      end
    end
    blocks
  end

  private def self.parse_stop_reason(pull : JSON::PullParser) : StopReason?
    pull.read_null_or do
      str = pull.read_string
      StopReason.parse?(str)
    end
  end
end
