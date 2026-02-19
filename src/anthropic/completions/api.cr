require "json"

# API client for the legacy completions endpoint.
#
# DEPRECATED: Use `Anthropic::Messages::API` with the Messages API instead.
# The `/v1/complete` endpoint is deprecated. This class is provided for
# backward compatibility only.
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
class Anthropic::Completions::API
  ENDPOINT = "/v1/complete"

  def initialize(@client : Client)
  end

  # DEPRECATED: Use the Messages API instead.
  # This endpoint is provided for backward compatibility only.
  def create(request : Request, request_options : RequestOptions? = nil) : Response
    http_response = @client.post(ENDPOINT, request.to_json, options: request_options)
    result = Response.from_json(http_response.body)
    result.request_id = Client.request_id(http_response)
    result
  end

  # Convenience overload that builds a `Request` from keyword arguments.
  #
  # DEPRECATED: Use the Messages API instead.
  def create(
    model : String,
    prompt : String,
    max_tokens_to_sample : Int32,
    request_options : RequestOptions? = nil,
    **options,
  ) : Response
    request = Request.new(model, prompt, max_tokens_to_sample, **options)
    create(request, request_options)
  end
end
