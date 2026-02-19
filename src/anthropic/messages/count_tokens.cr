require "json"

# Request for token counting. Reuses the same message format.
struct Anthropic::Messages::CountTokensRequest
  getter model : Model | String
  getter messages : Array(Message)
  getter system : String?

  def initialize(
    @model : Model | String,
    @messages : Array(Message),
    @system : String? = nil,
  )
    raise ArgumentError.new("messages must not be empty") if @messages.empty?
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
      json.field "system", @system if @system
    end
  end
end

# Response from the count_tokens endpoint.
struct Anthropic::Messages::CountTokensResponse
  include JSON::Serializable

  getter input_tokens : Int32

  def initialize(@input_tokens : Int32 = 0)
  end
end
