require "json"

# Request metadata for the Anthropic API.
#
# Contains `user_id` for end-user identification (used for abuse monitoring)
# and an optional `custom` hash for arbitrary key-value metadata.
#
# ## Usage
#
# ```
# # With user_id only
# metadata = Anthropic::Metadata.with_user_id("user-123")
#
# # With user_id and custom fields
# metadata = Anthropic::Metadata.new(
#   user_id: "user-123",
#   custom: {"session_id" => JSON::Any.new("abc")}
# )
# ```
struct Anthropic::Metadata
  getter user_id : String?
  getter custom : Hash(String, JSON::Any)?

  def initialize(@user_id : String? = nil, @custom : Hash(String, JSON::Any)? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "user_id", @user_id if @user_id
      if custom = @custom
        custom.each do |key, value|
          json.field key, value
        end
      end
    end
  end

  # Convenience constructor for just user_id.
  def self.with_user_id(user_id : String) : Metadata
    new(user_id: user_id)
  end
end
