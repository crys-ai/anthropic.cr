require "json"

class Anthropic::Error < Exception
end

class Anthropic::APIError < Anthropic::Error
  getter status_code : Int32
  getter error_type : String
  getter error_message : String

  def initialize(@status_code, @error_type, @error_message)
    super("#{@error_type}: #{@error_message} (HTTP #{@status_code})")
  end

  def self.from_response(response : Crest::Response) : APIError
    body = parse_error_body(response.body)
    error_class_for(response.status_code).new(
      response.status_code,
      body["type"],
      body["message"]
    )
  end

  private def self.parse_error_body(body : String) : Hash(String, String)
    parsed = JSON.parse(body)
    {
      "type"    => parsed.dig("error", "type").as_s,
      "message" => parsed.dig("error", "message").as_s,
    }
  rescue JSON::ParseException | KeyError
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
