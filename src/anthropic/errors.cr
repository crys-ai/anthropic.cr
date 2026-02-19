require "json"

class Anthropic::Error < Exception
end

class Anthropic::APIError < Anthropic::Error
  getter status_code : Int32
  getter error_type : String
  getter error_message : String
  # Request ID extracted from HTTP response headers (request-id or x-request-id).
  getter request_id : String?

  def initialize(@status_code, @error_type, @error_message, @request_id : String? = nil)
    super("#{@error_type}: #{@error_message} (HTTP #{@status_code})")
  end

  def self.from_response(response : HTTP::Client::Response) : APIError
    body = parse_error_body(response.body)
    request_id = extract_request_id(response)
    error_class_for(response.status_code).new(
      response.status_code,
      body["type"],
      body["message"],
      request_id
    )
  end

  # Extract request ID from response headers, preferring "request-id" over "x-request-id".
  private def self.extract_request_id(response : HTTP::Client::Response) : String?
    response.headers["request-id"]? || response.headers["x-request-id"]?
  end

  private def self.parse_error_body(body : String) : Hash(String, String)
    parsed = JSON.parse(body)
    if hash = parsed.as_h?
      error = hash["error"]?
      if error_hash = error.try(&.as_h?)
        type = error_hash["type"]?.try(&.as_s?) || "unknown_error"
        message = error_hash["message"]?.try(&.as_s?) || body
        {"type" => type, "message" => message}
      elsif error_str = error.try(&.as_s?)
        # Handle {"error": "string message"} shape
        {"type" => "unknown_error", "message" => error_str}
      else
        # Handle {"error": [1,2,3]}, {"error": null}, {"error": 42}, etc.
        {"type" => "unknown_error", "message" => body}
      end
    else
      {"type" => "unknown_error", "message" => body}
    end
  rescue JSON::ParseException
    {"type" => "unknown_error", "message" => body}
  end

  private def self.error_class_for(status : Int32) : APIError.class
    case status
    when 400 then InvalidRequestError
    when 401 then AuthenticationError
    when 403 then PermissionError
    when 404 then NotFoundError
    when 408 then RequestTimeoutError
    when 409 then ConflictError
    when 422 then UnprocessableEntityError
    when 429 then RateLimitError
    when 529 then OverloadedError
    else          APIError
    end
  end
end

class Anthropic::AuthenticationError < Anthropic::APIError
end

class Anthropic::PermissionError < Anthropic::APIError
end

class Anthropic::NotFoundError < Anthropic::APIError
end

class Anthropic::RateLimitError < Anthropic::APIError
end

class Anthropic::InvalidRequestError < Anthropic::APIError
end

class Anthropic::OverloadedError < Anthropic::APIError
end

class Anthropic::RequestTimeoutError < Anthropic::APIError
end

class Anthropic::ConflictError < Anthropic::APIError
end

class Anthropic::UnprocessableEntityError < Anthropic::APIError
end

# Raised when batch results are requested before the batch has completed.
# The batch must have processing_status "ended" and a non-nil results_url.
class Anthropic::BatchResultsNotReadyError < Anthropic::Error
  getter batch_id : String
  getter processing_status : String

  def initialize(@batch_id : String, @processing_status : String)
    super("Batch '#{@batch_id}' results are not available (status: #{@processing_status}). " \
          "The batch must complete processing before results can be retrieved.")
  end
end

# Raised when a results_url authority (scheme + host + port) does not match
# the configured client base_url authority. This is a security concern to
# prevent unauthorized data access.
class Anthropic::URLAuthorityMismatchError < Anthropic::Error
  getter expected_authority : String
  getter actual_authority : String

  def initialize(@expected_authority : String, @actual_authority : String)
    super("Results URL authority '#{@actual_authority}' does not match configured base URL authority '#{@expected_authority}'. " \
          "Refusing to fetch results from unauthorized origin.")
  end
end

# Raised when a results_url is malformed or uses a disallowed format.
# This includes protocol-relative URLs (//host/path), non-absolute paths,
# and empty values.
class Anthropic::MalformedResultsURLError < Anthropic::Error
  getter url : String

  def initialize(@url : String, reason : String)
    super("Malformed results URL '#{@url}': #{reason}")
  end
end

# Backward-compatible alias for URLAuthorityMismatchError.
# Deprecated: Use URLAuthorityMismatchError instead.
alias Anthropic::URLHostMismatchError = Anthropic::URLAuthorityMismatchError

# Network error wrapper for connection issues
class Anthropic::ConnectionError < Anthropic::Error
end

# Network error wrapper for timeouts (distinct from 408 timeout from API)
class Anthropic::TimeoutError < Anthropic::ConnectionError
end

# Raised when pagination detects a non-advancing cursor.
# This guards against infinite loops when a server returns the same
# cursor repeatedly while claiming more pages exist.
class Anthropic::PaginationError < Anthropic::Error
end

# Raised when a response has stop_reason=tool_use but contains no tool_use blocks.
# This indicates an unexpected API response that would cause empty follow-up calls.
class Anthropic::ToolUseError < Anthropic::Error
end
