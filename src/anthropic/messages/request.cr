require "json"

struct Anthropic::Messages::Request
  include JSON::Serializable

  getter model : Model
  getter messages : Array(Message)
  getter max_tokens : Int32

  @[JSON::Field(emit_null: false)]
  getter system : String?

  @[JSON::Field(emit_null: false)]
  getter temperature : Float64?

  @[JSON::Field(emit_null: false)]
  getter top_p : Float64?

  @[JSON::Field(emit_null: false)]
  getter top_k : Int32?

  @[JSON::Field(emit_null: false)]
  getter stop_sequences : Array(String)?

  @[JSON::Field(emit_null: false)]
  getter stream : Bool?

  def initialize(
    @model : Model,
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
end
