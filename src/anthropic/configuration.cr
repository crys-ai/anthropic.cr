struct Anthropic::Configuration
  getter api_key : String
  getter base_url : String
  getter api_version : String
  getter timeout : Time::Span
  getter max_pool_size : Int32

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
  )
    @api_key = api_key || ENV["ANTHROPIC_API_KEY"]? || raise ArgumentError.new(
      "API key required. Pass api_key: or set ANTHROPIC_API_KEY env var."
    )
  end
end
