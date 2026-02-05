require "json"

struct Anthropic::Usage
  include JSON::Serializable

  getter input_tokens : Int32
  getter output_tokens : Int32
  getter cache_creation_input_tokens : Int32?
  getter cache_read_input_tokens : Int32?

  def total_tokens : Int32
    input_tokens + output_tokens
  end
end
