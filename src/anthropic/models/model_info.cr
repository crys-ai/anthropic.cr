require "json"

struct Anthropic::ModelInfo
  include JSON::Serializable

  getter id : String
  getter display_name : String
  getter created_at : String # ISO 8601 timestamp
  getter type : String       # "model"

  def initialize(@id, @display_name, @created_at, @type = "model")
  end
end
