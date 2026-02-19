require "json"

# Request model for the legacy completions API.
#
# DEPRECATED: Use `Anthropic::Messages::Request` with the Messages API instead.
# This endpoint is provided for backward compatibility only.
#
# ## Example
#
# ```
# request = Anthropic::Completions::Request.new(
#   model: "claude-2.1",
#   prompt: "\n\nHuman: Hello\n\nAssistant:",
#   max_tokens_to_sample: 100
# )
# ```
struct Anthropic::Completions::Request
  getter model : String
  getter prompt : String
  getter max_tokens_to_sample : Int32
  getter stop_sequences : Array(String)?
  getter temperature : Float64?
  getter top_p : Float64?
  getter top_k : Int32?
  getter metadata : Metadata?

  def initialize(
    @model : String,
    @prompt : String,
    @max_tokens_to_sample : Int32,
    @stop_sequences : Array(String)? = nil,
    @temperature : Float64? = nil,
    @top_p : Float64? = nil,
    @top_k : Int32? = nil,
    @metadata : Metadata? = nil,
  )
    raise ArgumentError.new("max_tokens_to_sample must be positive, got #{@max_tokens_to_sample}") if @max_tokens_to_sample <= 0
    if temp = @temperature
      raise ArgumentError.new("temperature must be between 0.0 and 1.0, got #{temp}") unless (0.0..1.0).includes?(temp)
    end
    if tp = @top_p
      raise ArgumentError.new("top_p must be between 0.0 and 1.0, got #{tp}") unless (0.0..1.0).includes?(tp)
    end
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "model", @model
      json.field "prompt", @prompt
      json.field "max_tokens_to_sample", @max_tokens_to_sample
      json.field "stop_sequences", @stop_sequences if @stop_sequences
      json.field "temperature", @temperature if @temperature
      json.field "top_p", @top_p if @top_p
      json.field "top_k", @top_k if @top_k
      json.field "metadata", @metadata if @metadata
    end
  end
end
