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
  )
    raise ArgumentError.new("max_tokens must be positive, got #{@max_tokens}") if @max_tokens <= 0
    raise ArgumentError.new("messages must not be empty") if @messages.empty?
    if temp = @temperature
      raise ArgumentError.new("temperature must be between 0.0 and 1.0, got #{temp}") unless (0.0..1.0).includes?(temp)
    end
    if tp = @top_p
      raise ArgumentError.new("top_p must be between 0.0 and 1.0, got #{tp}") unless (0.0..1.0).includes?(tp)
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
      json.field "system", @system if @system
      json.field "temperature", @temperature if @temperature
      json.field "top_p", @top_p if @top_p
      json.field "top_k", @top_k if @top_k
      json.field "stop_sequences", @stop_sequences if @stop_sequences
      json.field "stream", @stream unless @stream.nil?
    end
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
    )
  end
end
