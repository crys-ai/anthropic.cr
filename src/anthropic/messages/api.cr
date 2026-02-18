require "json"

class Anthropic::Messages::API
  ENDPOINT = "/v1/messages"

  def initialize(@client : Client)
  end

  def create(request : Request) : Response
    response = @client.post(ENDPOINT, request.to_json)
    Response.from_json(response.body)
  end

  def create(
    model : Model | String,
    messages : Array(Message),
    max_tokens : Int32,
    **options,
  ) : Response
    request = Request.new(model, messages, max_tokens, **options)
    create(request)
  end

  # Streaming: yields StreamEvent for each SSE event
  def stream(request : Request, &block : StreamEvent ->) : Nil
    # Create a copy with stream=true to avoid mutating caller's request
    stream_request = request.with_stream(true)

    @client.post_stream(ENDPOINT, stream_request.to_json) do |response|
      EventSource.new(response.body_io)
        .on_message do |msg, _|
          data = msg.data.join("\n")
          block.call(StreamEvent.parse(msg.event, data))
        end
        .run
    end
  end

  def stream(
    model : Model | String,
    messages : Array(Message),
    max_tokens : Int32,
    **options,
    &block : StreamEvent ->
  ) : Nil
    request = Request.new(model, messages, max_tokens, **options)
    stream(request, &block)
  end
end
