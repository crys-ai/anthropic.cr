require "http/client"
require "db/pool"
require "json"
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

  def models : Models::API
    @models ||= Models::API.new(self)
  end

  def batches : Messages::BatchAPI
    @batches ||= Messages::BatchAPI.new(self)
  end

  def files : Files::API
    @files ||= Files::API.new(self)
  end

  def skills : Skills::API
    @skills ||= Skills::API.new(self)
  end

  # Access the legacy completions API.
  #
  # DEPRECATED: Use `#messages` instead. The `/v1/complete` endpoint
  # is deprecated and provided for backward compatibility only.
  def completions : Completions::API
    @completions ||= Completions::API.new(self)
  end

  # Access beta-only features through an opt-in namespace.
  #
  # Creates a Beta::API wrapper that automatically injects beta headers
  # into requests. Pass specific beta headers to include them in all
  # requests made through the beta namespace.
  #
  # Example:
  # ```
  # client.beta.skills.list
  # client.beta(["some-beta-feature"]).options
  # ```
  def beta(beta_headers : Array(String) = [] of String) : Beta::API
    Beta::API.new(self, beta_headers)
  end

  # Synchronous POST with retry
  def post(path : String, body : String, options : RequestOptions? = nil) : HTTP::Client::Response
    full_path = merge_query_params(path, options)
    merged_body = merge_body_fields(body, options)
    with_retry(options) do
      http(options) do |client|
        response = client.post(full_path, headers: auth_headers(options), body: merged_body)

        if response.status_code >= 400
          raise APIError.from_response(response)
        end

        response
      end
    end
  end

  # Synchronous GET with retry
  def get(path : String, options : RequestOptions? = nil) : HTTP::Client::Response
    full_path = merge_query_params(path, options)
    with_retry(options) do
      http(options) do |client|
        response = client.get(full_path, headers: auth_headers(options))
        if response.status_code >= 400
          raise APIError.from_response(response)
        end
        response
      end
    end
  end

  # Synchronous DELETE with retry
  def delete(path : String, options : RequestOptions? = nil) : HTTP::Client::Response
    full_path = merge_query_params(path, options)
    with_retry(options) do
      http(options) do |client|
        response = client.delete(full_path, headers: auth_headers(options))
        if response.status_code >= 400
          raise APIError.from_response(response)
        end
        response
      end
    end
  end

  # Streaming GET — yields response with body_io for streaming responses.
  #
  # NOTE: Streaming requests do NOT retry because streams cannot be safely
  # replayed. Once the stream starts, there's no way to resume from a partial
  # position. If a transport error occurs mid-stream, the caller must handle
  # retry logic at the application level (e.g., re-initiate the request).
  def get_stream(path : String, options : RequestOptions? = nil, &block : HTTP::Client::Response ->) : Nil
    full_path = merge_query_params(path, options)
    http(options) do |client|
      client.get(full_path, headers: auth_headers(options)) do |response|
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

  # Streaming POST — yields response with body_io for SSE.
  #
  # NOTE: Streaming requests do NOT retry because SSE streams cannot be safely
  # replayed. Once the stream starts, there's no way to resume from a partial
  # position. If a transport error occurs mid-stream, the caller must handle
  # retry logic at the application level (e.g., re-initiate the request).
  def post_stream(path : String, body : String, options : RequestOptions? = nil, &block : HTTP::Client::Response ->) : Nil
    full_path = merge_query_params(path, options)
    merged_body = merge_body_fields(body, options)
    http(options) do |client|
      client.post(full_path, headers: auth_headers(options), body: merged_body) do |response|
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

  # Extract request ID from a response header.
  # Checks both "request-id" (preferred) and "x-request-id" headers.
  def self.request_id(response : HTTP::Client::Response) : String?
    response.headers["request-id"]? || response.headers["x-request-id"]?
  end

  # Retry wrapper with exponential backoff for transient errors.
  # Catches API errors and transport errors (IO::TimeoutError, IO::Error, Socket::Error),
  # converting transport errors to ConnectionError/TimeoutError which are retryable.
  private def with_retry(options : RequestOptions?, &)
    policy = options.try(&.retry_policy) || @config.retry_policy
    attempt = 0

    loop do
      begin
        return yield
      rescue ex : IO::TimeoutError
        # Convert to TimeoutError for consistent error hierarchy
        raise TimeoutError.new("Request timed out: #{ex.message}") if attempt >= policy.max_retries
        sleep(policy.delay_for(attempt))
        attempt += 1
      rescue ex : IO::Error | Socket::Error
        # Convert to ConnectionError for consistent error hierarchy
        raise ConnectionError.new("Network error: #{ex.message}") if attempt >= policy.max_retries
        sleep(policy.delay_for(attempt))
        attempt += 1
      rescue ex : APIError | ConnectionError
        raise ex unless RetryPolicy.retryable?(ex)
        raise ex if attempt >= policy.max_retries

        sleep(policy.delay_for(attempt))
        attempt += 1
      end
    end
  end

  # Checkout a connection from pool, yield, auto-return.
  # Applies per-request timeout if provided, restoring the default timeout
  # afterward via `ensure` so the pooled connection isn't left with a
  # non-default timeout for the next consumer.
  private def http(options : RequestOptions?, &)
    @pool.checkout do |http_client|
      if timeout = options.try(&.timeout)
        http_client.read_timeout = timeout
      end

      yield http_client
    ensure
      # Always restore the default timeout from config.
      # Crystal's HTTP::Client doesn't expose a read_timeout getter,
      # so we use the configured default stored in @timeout.
      http_client.read_timeout = @timeout
    end
  end

  # Auth headers - added per-request, uses configurable api_version
  # Merges client-level and per-request options
  private def auth_headers(options : RequestOptions?) : HTTP::Headers
    headers = HTTP::Headers{
      "x-api-key"         => @api_key,
      "Authorization"     => "Bearer #{@api_key}",
      "anthropic-version" => @config.api_version,
      "Content-Type"      => "application/json",
    }

    # Client-level beta headers
    betas = @config.beta_headers.dup

    # Merge per-request beta headers
    if request_betas = options.try(&.beta_headers)
      betas.concat(request_betas)
    end

    unless betas.empty?
      headers["anthropic-beta"] = betas.uniq.join(",")
    end

    # Merge extra headers (lowest priority, then client, then request)
    if extra = options.try(&.extra_headers)
      extra.each do |key, values|
        headers[key] = values.join(",")
      end
    end

    headers
  end

  # Merge extra_body fields into the request body JSON.
  # Extra body fields have LOWER precedence than typed fields.
  # If the original body is not a JSON object, returns it unchanged.
  # Raises ArgumentError if extra_body is set but the body is not valid JSON.
  private def merge_body_fields(body : String, options : RequestOptions?) : String
    extra = options.try(&.extra_body)
    return body if extra.nil? || extra.empty?

    begin
      original = JSON.parse(body)
    rescue JSON::ParseException
      raise ArgumentError.new(
        "extra_body cannot be merged into a non-JSON request body. " \
        "Remove extra_body from RequestOptions when sending multipart or raw payloads."
      )
    end

    # If body is not an object, we can't merge - return as-is
    original_hash = original.as_h?
    return body if original_hash.nil?

    # Build merged object with extra_body having lower precedence
    merged = original_hash.dup
    extra.each do |key, value|
      # Only add if key doesn't already exist (typed fields take precedence)
      merged[key]? || (merged[key] = value)
    end

    merged.to_json
  end

  # Merge extra_query params into the request path URL.
  # Extra query params have LOWER precedence than params already in the path.
  # Returns the path unchanged if no extra_query params are provided.
  private def merge_query_params(path : String, options : RequestOptions?) : String
    extra = options.try(&.extra_query)
    return path if extra.nil? || extra.empty?

    uri = URI.parse(path)
    params = if query = uri.query
               URI::Params.parse(query)
             else
               URI::Params.new
             end

    # Extra params have lower precedence — only add if key not already present
    extra.each do |key, value|
      params.add(key, value) unless params[key]?
    end

    query_string = params.to_s
    base = uri.path.presence || path.split('?', 2).first
    if query_string.empty?
      base
    else
      "#{base}?#{query_string}"
    end
  end
end
