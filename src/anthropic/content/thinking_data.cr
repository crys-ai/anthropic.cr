require "json"

# Thinking content data for extended thinking responses.
#
# Used when Claude employs extended thinking to show its reasoning process.
# The thinking field contains the reasoning text, and signature may contain
# a cryptographic signature for verification.
struct Anthropic::Content::ThinkingData
  include Data

  getter thinking : String
  getter? signature : String?

  def initialize(@thinking : String, @signature : String? = nil)
  end

  def content_type : Type
    Type::Thinking
  end

  def to_content_json(json : JSON::Builder) : Nil
    json.field "thinking", @thinking
    json.field "signature", @signature if @signature
  end
end
