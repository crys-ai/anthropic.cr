require "json"

# Text content data.
struct Anthropic::Content::TextData
  include Data

  getter text : String

  def initialize(@text : String)
  end

  def content_type : Type
    Type::Text
  end

  def to_content_json(json : JSON::Builder) : Nil
    json.field "text", @text
  end
end
