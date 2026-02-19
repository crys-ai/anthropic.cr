require "json"

struct Anthropic::Messages::Request
  getter model : Model | String
  getter messages : Array(Message)
  getter max_tokens : Int32
  getter system : String?
  getter temperature : Float64?
  getter top_p : Float64?
  getter top_k : Int32?
  getter stop_sequences : Array(String)?
  getter metadata : Metadata?
  getter tools : Array(ToolDefinition)?
  getter tool_choice : ToolChoice?
  getter thinking : ThinkingConfig?
  property stream : Bool?

  def initialize(
    @model : Model | String,
    @messages : Array(Message),
    @max_tokens : Int32,
    @system : String? = nil,
    @temperature : Float64? = nil,
    @top_p : Float64? = nil,
    @top_k : Int32? = nil,
    @stop_sequences : Array(String)? = nil,
    @stream : Bool? = nil,
    @metadata : Metadata? = nil,
    @tools : Array(ToolDefinition)? = nil,
    @tool_choice : ToolChoice? = nil,
    @thinking : ThinkingConfig? = nil,
  )
    raise ArgumentError.new("max_tokens must be positive, got #{@max_tokens}") if @max_tokens <= 0
    raise ArgumentError.new("messages must not be empty") if @messages.empty?
    if temp = @temperature
      raise ArgumentError.new("temperature must be between 0.0 and 1.0, got #{temp}") unless (0.0..1.0).includes?(temp)
    end
    if tp = @top_p
      raise ArgumentError.new("top_p must be between 0.0 and 1.0, got #{tp}") unless (0.0..1.0).includes?(tp)
    end
    validate_tool_configuration!
  end

  private def validate_tool_configuration! : Nil
    if choice = @tool_choice
      tools_array = @tools
      if tools_array.nil? || tools_array.empty?
        raise ArgumentError.new(
          "tool_choice is set to type '#{choice.type}' but no tools are provided; " \
          "either provide a tools array or remove tool_choice"
        )
      end

      unless {"auto", "any", "tool"}.includes?(choice.type)
        raise ArgumentError.new(
          "unknown tool_choice type '#{choice.type}'; " \
          "valid types are: auto, any, tool"
        )
      end

      if choice.type == "tool"
        tool_name = choice.name
        if tool_name.nil? || tool_name.empty?
          raise ArgumentError.new(
            "tool_choice type 'tool' requires a non-empty name"
          )
        end

        tool_names = tools_array.map(&.name)
        unless tool_names.includes?(tool_name)
          raise ArgumentError.new(
            "tool_choice specifies tool '#{tool_name}' but it was not found in the tools array; " \
            "available tools: #{tool_names.join(", ")}"
          )
        end
      end
    end
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "model" do
        case model = @model
        when Model  then json.string(model.to_api_string)
        when String then json.string(model)
        end
      end
      json.field "messages", @messages
      json.field "max_tokens", @max_tokens
      serialize_optional_fields(json)
      json.field "stream", @stream unless @stream.nil?
    end
  end

  private def serialize_optional_fields(json : JSON::Builder) : Nil
    json.field "system", @system if @system
    json.field "temperature", @temperature if @temperature
    json.field "top_p", @top_p if @top_p
    json.field "top_k", @top_k if @top_k
    json.field "stop_sequences", @stop_sequences if @stop_sequences
    json.field "metadata", @metadata if @metadata
    json.field "tools", @tools if @tools
    json.field "tool_choice", @tool_choice if @tool_choice
    json.field "thinking", @thinking if @thinking
  end

  # Returns a copy of this request with the stream flag set.
  # Does not mutate the original request.
  def with_stream(stream : Bool) : Request
    Request.new(
      model: @model,
      messages: @messages,
      max_tokens: @max_tokens,
      system: @system,
      temperature: @temperature,
      top_p: @top_p,
      top_k: @top_k,
      stop_sequences: @stop_sequences,
      stream: stream,
      metadata: @metadata,
      tools: @tools,
      tool_choice: @tool_choice,
      thinking: @thinking,
    )
  end
end
