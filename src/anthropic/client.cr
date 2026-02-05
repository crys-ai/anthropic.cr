require "crest"

class Anthropic::Client
  BASE_URL        = "https://api.anthropic.com"
  API_VERSION     = "2023-06-01"
  DEFAULT_TIMEOUT = 120.seconds

  getter api_key : String
  getter base_url : String
  getter timeout : Time::Span

  def initialize(
    api_key : String? = nil,
    @base_url : String = BASE_URL,
    @timeout : Time::Span = DEFAULT_TIMEOUT,
  )
    @api_key = api_key || ENV["ANTHROPIC_API_KEY"]? || raise ArgumentError.new(
      "API key required. Pass api_key: or set ANTHROPIC_API_KEY env var."
    )
  end

  def messages : Messages::API
    @messages ||= Messages::API.new(self)
  end

  def post(path : String, body : String) : Crest::Response
    Crest.post(
      "#{@base_url}#{path}",
      headers: headers,
      form: body,
      json: true,
      read_timeout: @timeout
    )
  rescue ex : Crest::RequestFailed
    handle_error(ex.response)
  end

  private def headers : Hash(String, String)
    {
      "x-api-key"         => @api_key,
      "anthropic-version" => API_VERSION,
    }
  end

  private def handle_error(response : Crest::Response) : NoReturn
    raise APIError.from_response(response)
  end
end
