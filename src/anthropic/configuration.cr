require "uri"

struct Anthropic::Configuration
  getter api_key : String
  getter base_url : String
  getter api_version : String
  getter timeout : Time::Span
  getter max_pool_size : Int32
  getter retry_policy : RetryPolicy
  @beta_headers : Array(String)

  DEFAULT_BASE_URL    = "https://api.anthropic.com"
  DEFAULT_API_VERSION = "2023-06-01"
  DEFAULT_TIMEOUT     = 120.seconds
  DEFAULT_POOL_SIZE   = 10

  def initialize(
    api_key : String? = nil,
    @base_url : String = ENV["ANTHROPIC_BASE_URL"]? || DEFAULT_BASE_URL,
    @api_version : String = DEFAULT_API_VERSION,
    @timeout : Time::Span = DEFAULT_TIMEOUT,
    @max_pool_size : Int32 = DEFAULT_POOL_SIZE,
    @retry_policy : RetryPolicy = RetryPolicy.default,
    beta_headers : Array(String) = [] of String,
  )
    @api_key = api_key || ENV["ANTHROPIC_API_KEY"]? || raise ArgumentError.new(
      "API key required. Pass api_key: or set ANTHROPIC_API_KEY env var."
    )
    validate_base_url(@base_url)
    @base_url = @base_url.strip

    raise ArgumentError.new(
      "timeout must be positive, got #{@timeout}"
    ) unless @timeout > Time::Span.zero

    raise ArgumentError.new(
      "max_pool_size must be positive, got #{@max_pool_size}"
    ) unless @max_pool_size > 0

    # Defensive copy to prevent external mutation
    @beta_headers = beta_headers.dup
  end

  # Returns a copy of the beta headers to prevent external mutation.
  def beta_headers : Array(String)
    @beta_headers.dup
  end

  private def validate_base_url(url : String) : Nil
    raise ArgumentError.new("base_url must not be empty") if url.strip.empty?

    url = url.strip
    begin
      uri = URI.parse(url)
    rescue ex
      raise ArgumentError.new("base_url is not a valid URL: #{ex.message}")
    end
    validate_url_scheme(uri)
    validate_url_host(uri, url)
    validate_url_port(uri)
    validate_url_origin(uri, url)
  end

  private def validate_url_scheme(uri : URI) : Nil
    scheme = uri.scheme
    unless scheme == "http" || scheme == "https"
      raise ArgumentError.new(
        "base_url must use http or https scheme, got #{scheme.inspect}"
      )
    end
  end

  private def validate_url_host(uri : URI, url : String) : Nil
    host = uri.host
    if host.nil? || host.empty?
      raise ArgumentError.new(
        "base_url must have a host, got #{url.inspect}"
      )
    end

    host.each_char do |char|
      if char.ascii_whitespace? || char.ord < 0x20 || char.ord == 0x7F
        raise ArgumentError.new(
          "base_url host must not contain whitespace or control characters, got #{host.inspect}"
        )
      end
    end
  end

  private def validate_url_port(uri : URI) : Nil
    if port = uri.port
      unless 1 <= port <= 65535
        raise ArgumentError.new(
          "base_url port must be in range 1..65535, got #{port}"
        )
      end
    end
  end

  private def validate_url_origin(uri : URI, url : String) : Nil
    if uri.user || uri.password
      raise ArgumentError.new(
        "base_url must not contain userinfo, got #{url.inspect}"
      )
    end

    path = uri.path
    unless path.nil? || path.empty? || path == "/"
      raise ArgumentError.new(
        "base_url must be an origin (no path), got #{url.inspect}"
      )
    end

    if uri.query
      raise ArgumentError.new(
        "base_url must not contain a query string, got #{url.inspect}"
      )
    end

    if uri.fragment
      raise ArgumentError.new(
        "base_url must not contain a fragment, got #{url.inspect}"
      )
    end
  end
end
