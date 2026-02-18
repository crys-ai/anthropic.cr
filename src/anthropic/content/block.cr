require "json"

# Generic content block that wraps typed content data.
# The type parameter T must include Content::Data protocol.
struct Anthropic::Content::Block(T)
  getter data : T

  def initialize(@data : T)
  end

  def type : Type
    data.content_type
  end

  def to_json(json : JSON::Builder) : Nil
    {% if T == Anthropic::Content::UnknownData %}
      # UnknownData has its own complete serialization that preserves the
      # original type string. We delegate directly to avoid using the
      # `content_type` fallback (which returns Type::Text for protocol
      # compatibility, not the actual unknown type).
      data.to_json(json)
    {% else %}
      json.object do
        json.field "type", type
        data.to_content_json(json)
      end
    {% end %}
  end

  def to_json : String
    JSON.build do |json|
      to_json(json)
    end
  end
end
