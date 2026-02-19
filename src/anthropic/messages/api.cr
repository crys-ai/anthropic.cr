require "json"

class Anthropic::Messages::API
  ENDPOINT              = "/v1/messages"
  COUNT_TOKENS_ENDPOINT = "/v1/messages/count_tokens"

  def initialize(@client : Client)
  end

  # Count tokens for a request without sending it.
  def count_tokens(request : CountTokensRequest, request_options : RequestOptions? = nil) : CountTokensResponse
    response = @client.post(COUNT_TOKENS_ENDPOINT, request.to_json, options: request_options)
    CountTokensResponse.from_json(response.body)
  end

  def count_tokens(
    model : Model | String,
    messages : Array(Message),
    system : String? = nil,
    request_options : RequestOptions? = nil,
  ) : CountTokensResponse
    request = CountTokensRequest.new(model, messages, system: system)
    count_tokens(request, request_options)
  end

  def create(request : Request, request_options : RequestOptions? = nil) : Response
    http_response = @client.post(ENDPOINT, request.to_json, options: request_options)
    result = Response.from_json(http_response.body)
    result.request_id = Client.request_id(http_response)
    result
  end

  def create(
    model : Model | String,
    messages : Array(Message),
    max_tokens : Int32,
    request_options : RequestOptions? = nil,
    **options,
  ) : Response
    request = Request.new(model, messages, max_tokens, **options)
    create(request, request_options)
  end

  # Streaming: yields StreamEvent for each SSE event
  def stream(request : Request, request_options : RequestOptions? = nil, &block : StreamEvent ->) : Nil
    # Create a copy with stream=true to avoid mutating caller's request
    stream_request = request.with_stream(true)

    @client.post_stream(ENDPOINT, stream_request.to_json, options: request_options) do |response|
      EventSource.new(response.body_io)
        .on_message do |msg, _|
          data = msg.data.join("\n")
          next if data.empty?
          block.call(StreamEvent.parse(msg.event, data))
        end
        .run
    end
  end

  def stream(
    model : Model | String,
    messages : Array(Message),
    max_tokens : Int32,
    request_options : RequestOptions? = nil,
    **options,
    &block : StreamEvent ->
  ) : Nil
    request = Request.new(model, messages, max_tokens, **options)
    stream(request, request_options, &block)
  end
end
