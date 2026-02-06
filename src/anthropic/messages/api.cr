class Anthropic::Messages::API
  ENDPOINT = "/v1/messages"

  def initialize(@client : Client)
  end

  def create(request : Request) : Response
    response = @client.post(ENDPOINT, request.to_json)
    Response.from_json(response.body)
  end

  def create(
    model : Model,
    messages : Array(Message),
    max_tokens : Int32,
    **options,
  ) : Response
    request = Request.new(model, messages, max_tokens, **options)
    create(request)
  end

  def create(
    model : String,
    messages : Array(Message),
    max_tokens : Int32,
    **options,
  ) : Response
    request = Request.new(model, messages, max_tokens, **options)
    create(request)
  end
end
