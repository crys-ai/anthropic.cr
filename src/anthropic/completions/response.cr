require "json"

# Response model for the legacy completions API.
#
# DEPRECATED: Use `Anthropic::Messages::Response` with the Messages API instead.
# This endpoint is provided for backward compatibility only.
#
# ## Example
#
# ```
# response = client.completions.create(
#   model: "claude-2.1",
#   prompt: "\n\nHuman: Hello\n\nAssistant:",
#   max_tokens_to_sample: 100
# )
# puts response.completion
# ```
struct Anthropic::Completions::Response
  include JSON::Serializable

  getter completion : String
  getter stop_reason : String?
  getter stop : String?
  getter model : String

  @[JSON::Field(key: "truncated")]
  getter truncated : Bool?

  @[JSON::Field(key: "log_id")]
  getter log_id : String?

  # Request ID extracted from HTTP response headers (not part of JSON body).
  # Set by Completions::API after parsing the response.
  @[JSON::Field(ignore: true)]
  property request_id : String?
end
