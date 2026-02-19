require "json"

# Per-request options that override client-level configuration.
struct Anthropic::RequestOptions
  getter timeout : Time::Span?
  getter retry_policy : RetryPolicy?
  @beta_headers : Array(String)?
  @extra_headers : HTTP::Headers?
  @extra_body : Hash(String, JSON::Any)?
  @extra_query : Hash(String, String)?

  def initialize(
    @timeout : Time::Span? = nil,
    @retry_policy : RetryPolicy? = nil,
    beta_headers : Array(String)? = nil,
    extra_headers : HTTP::Headers? = nil,
    extra_body : Hash(String, JSON::Any)? = nil,
    extra_query : Hash(String, String)? = nil,
  )
    # Defensive copies to prevent external mutation
    @beta_headers = beta_headers.try(&.dup)
    @extra_headers = extra_headers.try(&.dup)
    @extra_body = extra_body.try(&.dup)
    @extra_query = extra_query.try(&.dup)
  end

  # Returns a copy of the beta headers to prevent external mutation.
  def beta_headers : Array(String)?
    @beta_headers.try(&.dup)
  end

  # Returns a copy of the extra headers to prevent external mutation.
  def extra_headers : HTTP::Headers?
    @extra_headers.try(&.dup)
  end

  # Returns a copy of the extra body fields to prevent external mutation.
  # These fields are merged into the request body JSON with lower precedence
  # than typed request fields (existing keys are not overwritten).
  def extra_body : Hash(String, JSON::Any)?
    @extra_body.try(&.dup)
  end

  # Returns a copy of the extra query params to prevent external mutation.
  # These params are merged into GET request URLs with lower precedence
  # than params already embedded in the path.
  def extra_query : Hash(String, String)?
    @extra_query.try(&.dup)
  end
end
