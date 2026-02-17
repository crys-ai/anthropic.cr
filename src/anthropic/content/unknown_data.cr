require "json"

# Unknown content data for forward compatibility.
# Preserves unknown content types without failing parsing.
struct Anthropic::Content::UnknownData
  include Data

  getter type_string : String
  getter raw : JSON::Any

  def initialize(@type_string : String, @raw : JSON::Any)
  end

  def content_type : Type
    Type::Text # Fallback to text for serialization (will have custom JSON)
  end

  def to_content_json(json : JSON::Builder) : Nil
    # Serialize the raw JSON data
    @raw.to_json(json)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "type", @type_string
      # Merge raw fields (excluding type which we already wrote)
      if hash = @raw.as_h?
        hash.each do |key, value|
          json.field key, value unless key == "type"
        end
      end
    end
  end
end
