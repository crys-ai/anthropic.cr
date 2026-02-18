require "json"

# Unknown content data for forward compatibility.
# Preserves unknown content types without failing parsing.
#
# NOTE: The `content_type` method returns `Type::Text` as a safe default
# to satisfy the `Data` protocol contract. This value is NOT used for
# JSON serialization—the actual type from `type_string` is written instead
# via the custom `to_json` method.
struct Anthropic::Content::UnknownData
  include Data

  getter type_string : String
  getter raw : JSON::Any

  def initialize(@type_string : String, @raw : JSON::Any)
  end

  # Returns `Type::Text` as a safe default value.
  #
  # This satisfies the `Data` protocol contract but is NOT used for JSON
  # serialization. The actual type string is preserved in `type_string`
  # and written directly via `to_json`.
  def content_type : Type
    Type::Text
  end

  def to_content_json(json : JSON::Builder) : Nil
    # Write each field from the raw JSON (except "type" which is written by Block)
    # Note: This is only called if UnknownData is used outside of Block(T).
    # Within Block(T), the compile-time branch calls data.to_json directly.
    if hash = @raw.as_h?
      hash.each do |key, value|
        json.field key, value unless key == "type"
      end
    end
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
