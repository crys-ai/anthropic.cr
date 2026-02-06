# Protocol for content data types.
# Each content type implements this to define its type and serialization.
module Anthropic::Content::Data
  abstract def content_type : Type
  abstract def to_content_json(json : JSON::Builder) : Nil
end
