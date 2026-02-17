require "http/client"
require "db/pool"
require "uri"

class Anthropic::Client
  BASE_URL          = "https://api.anthropic.com"
  API_VERSION       = "2023-06-01"
  DEFAULT_TIMEOUT   = 120.seconds
  DEFAULT_POOL_SIZE = 10

  getter api_key : String
  getter base_url : String
  getter timeout : Time::Span

  def initialize(
    api_key : String? = nil,
    @base_url : String = BASE_URL,
    @timeout : Time::Span = DEFAULT_TIMEOUT,
    max_idle_pool_size : Int32 = DEFAULT_POOL_SIZE,
  )
    @api_key = api_key || ENV["ANTHROPIC_API_KEY"]? || raise ArgumentError.new(
      "API key required. Pass api_key: or set ANTHROPIC_API_KEY env var."
    )

    uri = URI.parse(@base_url)

    # DB::Pool.new with DB::Pool::Options
    options = DB::Pool::Options.new(
      initial_pool_size: 1,
      max_idle_pool_size: max_idle_pool_size,
      max_pool_size: max_idle_pool_size * 2
    )
    @pool = DB::Pool(HTTP::Client).new(options) do
      # Create base client - auth headers added per-request (no before_request hook in stdlib)
      client = HTTP::Client.new(uri)
      client.read_timeout = @timeout
      client
    end
  end

  def messages : Messages::API
    @messages ||= Messages::API.new(self)
  end

  # Synchronous POST
  def post(path : String, body : String) : HTTP::Client::Response
    http do |client|
      response = client.post(path, headers: auth_headers, body: body)

      if response.status_code >= 400
        raise APIError.from_response(response)
      end

      response
    end
  end

  # Streaming POST — yields response with body_io for SSE
  def post_stream(path : String, body : String, &block : HTTP::Client::Response ->) : Nil
    http do |client|
      client.post(path, headers: auth_headers, body: body) do |response|
        if response.status_code >= 400
          # For error responses, read full body before raising
          error_body = response.body_io.gets_to_end
          raise APIError.from_response(HTTP::Client::Response.new(
            response.status_code,
            response.status_message,
            response.headers,
            error_body,
            response.version
          ))
        end
        block.call(response)
      end
    end
  end

  # Checkout a connection from pool, yield, auto-return
  private def http(&)
    @pool.checkout { |http_client| yield http_client }
  end

  # Auth headers - added per-request (HTTP::Client has no before_request hook)
  private def auth_headers : HTTP::Headers
    HTTP::Headers{
      "x-api-key"         => @api_key,
      "anthropic-version" => API_VERSION,
      "Content-Type"      => "application/json",
    }
  end
end
