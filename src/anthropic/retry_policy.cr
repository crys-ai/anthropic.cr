# Retry policy for transient API errors.
struct Anthropic::RetryPolicy
  getter max_retries : Int32
  getter base_delay : Time::Span
  getter max_delay : Time::Span
  getter backoff_factor : Float64

  # Default: 2 retries with exponential backoff (1s, 2s, max 10s)
  DEFAULT_MAX_RETRIES    = 2
  DEFAULT_BASE_DELAY     = 1.second
  DEFAULT_MAX_DELAY      = 10.seconds
  DEFAULT_BACKOFF_FACTOR = 2.0

  def initialize(
    @max_retries : Int32 = DEFAULT_MAX_RETRIES,
    @base_delay : Time::Span = DEFAULT_BASE_DELAY,
    @max_delay : Time::Span = DEFAULT_MAX_DELAY,
    @backoff_factor : Float64 = DEFAULT_BACKOFF_FACTOR,
  )
    raise ArgumentError.new("max_retries must be >= 0") if @max_retries < 0
    raise ArgumentError.new("backoff_factor must be > 1") if @backoff_factor <= 1
    raise ArgumentError.new("base_delay must be positive") if @base_delay <= Time::Span.zero
    raise ArgumentError.new("max_delay must be positive") if @max_delay <= Time::Span.zero
  end

  # No retries - disabled policy
  def self.disabled : RetryPolicy
    new(max_retries: 0)
  end

  # Default retry policy
  def self.default : RetryPolicy
    new
  end

  # Aggressive retry policy (5 retries, longer delays)
  def self.aggressive : RetryPolicy
    new(max_retries: 5, max_delay: 30.seconds)
  end

  # Calculate delay for a given attempt number (0-indexed).
  # Uses exponential backoff: base_delay * (backoff_factor ^ attempt)
  def delay_for(attempt : Int32) : Time::Span
    delay_ms = @base_delay.total_milliseconds * (@backoff_factor ** attempt)
    # Guard against Infinity/NaN from large exponents, and cap before
    # converting to Time::Span to avoid OverflowError in .milliseconds
    if delay_ms.infinite? || delay_ms.nan? || delay_ms < 0 || delay_ms > @max_delay.total_milliseconds
      return @max_delay
    end
    delay_ms.milliseconds
  end

  # Whether retries are enabled
  def enabled? : Bool
    @max_retries > 0
  end

  # Whether an error is retryable (429 rate limit, 529 overloaded, 408 timeout,
  # generic 5xx server errors, or network errors)
  def self.retryable?(error : Exception) : Bool
    case error
    when Anthropic::RateLimitError, Anthropic::OverloadedError
      true
    when Anthropic::RequestTimeoutError
      true
    when Anthropic::ConnectionError
      true
    when Anthropic::APIError
      error.status_code >= 500
    else
      false
    end
  end
end
