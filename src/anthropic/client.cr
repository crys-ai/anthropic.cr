require "http/client"
require "db/pool"
require "uri"

class Anthropic::Client
  getter api_key : String
  getter base_url : String
  getter timeout : Time::Span
  getter config : Configuration

  # Initialize from a Configuration struct.
  def initialize(@config : Configuration)
    @api_key = @config.api_key
    @base_url = @config.base_url
    @timeout = @config.timeout

    uri = URI.parse(@base_url)

    max_idle = @config.max_pool_size
    options = DB::Pool::Options.new(
      initial_pool_size: 1,
      max_idle_pool_size: max_idle,
      max_pool_size: max_idle * 2
    )
    @pool = DB::Pool(HTTP::Client).new(options) do
      client = HTTP::Client.new(uri)
      client.read_timeout = @timeout
      client
    end
  end

  # Backward-compatible initialize with individual parameters.
  def initialize(
    api_key : String? = nil,
    base_url : String = ENV["ANTHROPIC_BASE_URL"]? || Configuration::DEFAULT_BASE_URL,
    timeout : Time::Span = Configuration::DEFAULT_TIMEOUT,
    max_idle_pool_size : Int32 = Configuration::DEFAULT_POOL_SIZE,
  )
    initialize(Configuration.new(
      api_key: api_key,
      base_url: base_url,
      timeout: timeout,
      max_pool_size: max_idle_pool_size,
    ))
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
  rescue ex : IO::TimeoutError
    raise TimeoutError.new("Request timed out: #{ex.message}")
  rescue ex : IO::Error | Socket::Error
    raise ConnectionError.new("Network error: #{ex.message}")
  end

  # Streaming POST — yields response with body_io for SSE
  def post_stream(path : String, body : String, &block : HTTP::Client::Response ->) : Nil
    http do |client|
      client.post(path, headers: auth_headers, body: body) do |response|
        if response.status_code >= 400
          # For error responses, read full body before raising.
          # body_io may raise if unavailable; fall back to body string.
          error_body = begin
            response.body_io.gets_to_end
          rescue NilAssertionError | IO::Error
            response.body
          end
          raise APIError.from_response(HTTP::Client::Response.new(
            response.status_code,
            body: error_body,
            headers: response.headers,
            version: response.version
          ))
        end
        block.call(response)
      end
    end
  rescue ex : IO::TimeoutError
    raise TimeoutError.new("Stream timed out: #{ex.message}")
  rescue ex : IO::Error | Socket::Error
    raise ConnectionError.new("Network error during stream: #{ex.message}")
  end

  # Checkout a connection from pool, yield, auto-return
  private def http(&)
    @pool.checkout { |http_client| yield http_client }
  end

  # Auth headers - added per-request, uses configurable api_version
  private def auth_headers : HTTP::Headers
    HTTP::Headers{
      "x-api-key"         => @api_key,
      "Authorization"     => "Bearer #{@api_key}",
      "anthropic-version" => @config.api_version,
      "Content-Type"      => "application/json",
    }
  end
end
