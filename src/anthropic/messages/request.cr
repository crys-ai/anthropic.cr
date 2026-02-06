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
  getter stream : Bool?

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
end
