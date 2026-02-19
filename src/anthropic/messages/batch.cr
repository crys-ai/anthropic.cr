require "json"

# Message batch for asynchronous processing.
struct Anthropic::MessageBatch
  include JSON::Serializable

  getter id : String
  getter type : String              # "message_batch"
  getter processing_status : String # "in_progress", "succeeded", "errored", "canceled", "expired"
  getter request_counts : RequestCounts
  getter created_at : String
  getter ended_at : String?
  getter expires_at : String?
  getter archived_at : String?
  getter cancel_initiated_at : String?
  getter results_url : String?

  struct RequestCounts
    include JSON::Serializable

    getter processing : Int32
    getter succeeded : Int32
    getter errored : Int32
    getter canceled : Int32
    getter expired : Int32
  end
end

# Request to create a message batch.
struct Anthropic::CreateMessageBatchRequest
  @requests : Array(BatchRequest)

  def initialize(@requests : Array(BatchRequest))
    raise ArgumentError.new("requests must not be empty") if @requests.empty?
  end

  # Convenience method to create a batch from typed Messages::Request objects.
  #
  # Example:
  # ```
  # items = [
  #   {"req-1", Anthropic::Messages::Request.new(model: Anthropic::Model.sonnet, messages: [...], max_tokens: 1024)},
  #   {"req-2", Anthropic::Messages::Request.new(model: Anthropic::Model.sonnet, messages: [...], max_tokens: 512)},
  # ]
  # batch = Anthropic::CreateMessageBatchRequest.from_requests(items)
  # ```
  def self.from_requests(batch_items : Array({String, Anthropic::Messages::Request})) : CreateMessageBatchRequest
    requests = batch_items.map { |(custom_id, request)| BatchRequest.new(custom_id, request) }
    new(requests)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "requests", @requests
    end
  end

  struct BatchRequest
    include JSON::Serializable

    getter custom_id : String
    getter params : Hash(String, JSON::Any)

    # Original constructor for raw params (backward compatible).
    def initialize(@custom_id : String, @params : Hash(String, JSON::Any))
    end

    # Typed constructor from a Messages::Request.
    #
    # This allows callers to build batch items from typed Request objects
    # without hand-assembling Hash(String, JSON::Any).
    #
    # Example:
    # ```
    # request = Anthropic::Messages::Request.new(
    #   model: Anthropic::Model.sonnet,
    #   messages: [Anthropic::Message.user("Hello")],
    #   max_tokens: 1024
    # )
    # batch_req = Anthropic::CreateMessageBatchRequest::BatchRequest.new(
    #   custom_id: "req-1",
    #   request: request
    # )
    # ```
    def initialize(@custom_id : String, request : Anthropic::Messages::Request)
      @params = JSON.parse(request.to_json).as_h
    end
  end
end

# Result of a single message in a batch.
struct Anthropic::MessageBatchResult
  include JSON::Serializable

  getter custom_id : String
  getter result : ResultData

  struct ResultData
    include JSON::Serializable

    getter type : String # "succeeded", "errored", "cancelled", "expired"
    getter message : BatchResultMessage?
    getter error : ErrorInfo?

    struct ErrorInfo
      include JSON::Serializable

      getter type : String
      getter message : String
    end
  end
end

# Message payload in a batch result. Similar to Messages::Response but without
# the full request_id property (batch results don't include per-message request IDs).
# Contains response-shaped fields: id, model, usage, content blocks, stop_reason, etc.
struct Anthropic::BatchResultMessage
  getter id : String
  getter type : String
  getter role : String
  getter content : Array(Anthropic::ResponseContentBlock)
  getter model : String
  getter stop_reason : String?
  getter stop_sequence : String?
  getter usage : Anthropic::Usage

  def initialize(
    @id : String,
    @type : String,
    @role : String,
    @content : Array(Anthropic::ResponseContentBlock),
    @model : String,
    @stop_reason : String?,
    @stop_sequence : String?,
    @usage : Anthropic::Usage,
  )
  end

  def self.new(pull : JSON::PullParser) : BatchResultMessage
    id = ""
    type = ""
    role = "assistant"
    content = [] of Anthropic::ResponseContentBlock
    model = ""
    stop_reason : String? = nil
    stop_sequence : String? = nil
    usage = Anthropic::Usage.new

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
      when "stop_reason"   then stop_reason = pull.read_null_or { pull.read_string }
      when "stop_sequence" then stop_sequence = pull.read_null_or { pull.read_string }
      when "usage"         then usage = Anthropic::Usage.new(pull); found_usage = true
      else                      pull.skip
      end
    end

    validate_required_fields(found_id, found_type, found_role, found_model, found_usage)
    new(id, type, role, content, model, stop_reason, stop_sequence, usage)
  end

  private def self.validate_required_fields(found_id, found_type, found_role, found_model, found_usage) : Nil
    raise JSON::ParseException.new("Missing required field 'id' in BatchResultMessage", 0, 0) unless found_id
    raise JSON::ParseException.new("Missing required field 'type' in BatchResultMessage", 0, 0) unless found_type
    raise JSON::ParseException.new("Missing required field 'role' in BatchResultMessage", 0, 0) unless found_role
    raise JSON::ParseException.new("Missing required field 'model' in BatchResultMessage", 0, 0) unless found_model
    raise JSON::ParseException.new("Missing required field 'usage' in BatchResultMessage", 0, 0) unless found_usage
  end

  # Extracts all text from content blocks, joined together.
  def text : String
    content.compact_map do |block|
      block.is_a?(Anthropic::ResponseTextBlock) ? block.text : nil
    end.join
  end

  # Returns only the tool use blocks from content.
  def tool_use_blocks : Array(Anthropic::ResponseToolUseBlock)
    content.select(Anthropic::ResponseToolUseBlock)
  end

  private def self.parse_content(pull : JSON::PullParser) : Array(Anthropic::ResponseContentBlock)
    blocks = [] of Anthropic::ResponseContentBlock
    pull.read_array do
      block_json = JSON::Any.new(pull)
      type = block_json["type"]?.try(&.as_s)
      raw = block_json.to_json
      case type
      when "text"     then blocks << Anthropic::ResponseTextBlock.from_json(raw)
      when "tool_use" then blocks << Anthropic::ResponseToolUseBlock.from_json(raw)
      when "thinking" then blocks << Anthropic::ResponseThinkingBlock.from_json(raw)
      else                 blocks << Anthropic::ResponseUnknownBlock.new(type || "unknown", block_json)
      end
    end
    blocks
  end
end

# Response for deleting a message batch.
struct Anthropic::MessageBatchDeleted
  include JSON::Serializable

  getter id : String
  getter type : String # "message_batch_deleted"
end
