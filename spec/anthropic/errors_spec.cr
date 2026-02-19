require "../spec_helper"

describe Anthropic::Error do
  it "is an Exception" do
    Anthropic::Error.new("test").should be_a(Exception)
  end

  it "stores the message" do
    error = Anthropic::Error.new("something went wrong")
    error.message.should eq("something went wrong")
  end
end

describe Anthropic::APIError do
  it "includes status code and message" do
    error = Anthropic::APIError.new(400, "invalid_request_error", "Bad request")
    error.status_code.should eq(400)
    error.error_type.should eq("invalid_request_error")
    error.error_message.should eq("Bad request")
    error.to_s.should contain("400")
  end

  it "formats error message with all details" do
    error = Anthropic::APIError.new(500, "api_error", "Internal error")
    error.to_s.should eq("api_error: Internal error (HTTP 500)")
  end

  it "inherits from Error" do
    error = Anthropic::APIError.new(400, "invalid_request_error", "Bad request")
    error.should be_a(Anthropic::Error)
  end
end

describe Anthropic::AuthenticationError do
  it "inherits from APIError" do
    error = Anthropic::AuthenticationError.new(401, "authentication_error", "Invalid API key")
    error.should be_a(Anthropic::APIError)
  end

  it "stores authentication error details" do
    error = Anthropic::AuthenticationError.new(401, "authentication_error", "Invalid API key")
    error.status_code.should eq(401)
    error.error_type.should eq("authentication_error")
  end
end

describe Anthropic::RateLimitError do
  it "inherits from APIError" do
    error = Anthropic::RateLimitError.new(429, "rate_limit_error", "Too many requests")
    error.should be_a(Anthropic::APIError)
  end

  it "stores rate limit details" do
    error = Anthropic::RateLimitError.new(429, "rate_limit_error", "Rate limit exceeded")
    error.status_code.should eq(429)
  end
end

describe Anthropic::OverloadedError do
  it "inherits from APIError" do
    error = Anthropic::OverloadedError.new(529, "overloaded_error", "API overloaded")
    error.should be_a(Anthropic::APIError)
  end

  it "stores overloaded details" do
    error = Anthropic::OverloadedError.new(529, "overloaded_error", "API overloaded")
    error.status_code.should eq(529)
  end
end

describe Anthropic::PermissionError do
  it "inherits from APIError" do
    error = Anthropic::PermissionError.new(403, "permission_error", "Forbidden")
    error.should be_a(Anthropic::APIError)
  end
end

describe Anthropic::NotFoundError do
  it "inherits from APIError" do
    error = Anthropic::NotFoundError.new(404, "not_found_error", "Resource not found")
    error.should be_a(Anthropic::APIError)
  end
end

describe Anthropic::InvalidRequestError do
  it "inherits from APIError" do
    error = Anthropic::InvalidRequestError.new(400, "invalid_request_error", "Invalid request")
    error.should be_a(Anthropic::APIError)
  end

  it "stores invalid request details" do
    error = Anthropic::InvalidRequestError.new(400, "invalid_request_error", "Missing required field")
    error.status_code.should eq(400)
    error.error_message.should eq("Missing required field")
  end
end

describe Anthropic::RequestTimeoutError do
  it "inherits from APIError" do
    error = Anthropic::RequestTimeoutError.new(408, "request_timeout_error", "Request timed out")
    error.should be_a(Anthropic::APIError)
  end

  it "stores timeout details" do
    error = Anthropic::RequestTimeoutError.new(408, "request_timeout_error", "Request timed out")
    error.status_code.should eq(408)
  end
end

describe Anthropic::ConflictError do
  it "inherits from APIError" do
    error = Anthropic::ConflictError.new(409, "conflict_error", "Resource conflict")
    error.should be_a(Anthropic::APIError)
  end

  it "stores conflict details" do
    error = Anthropic::ConflictError.new(409, "conflict_error", "Resource conflict")
    error.status_code.should eq(409)
  end
end

describe Anthropic::UnprocessableEntityError do
  it "inherits from APIError" do
    error = Anthropic::UnprocessableEntityError.new(422, "unprocessable_entity_error", "Invalid entity")
    error.should be_a(Anthropic::APIError)
  end

  it "stores unprocessable entity details" do
    error = Anthropic::UnprocessableEntityError.new(422, "unprocessable_entity_error", "Invalid entity")
    error.status_code.should eq(422)
  end
end

describe Anthropic::ConnectionError do
  it "inherits from Error" do
    error = Anthropic::ConnectionError.new("Network error")
    error.should be_a(Anthropic::Error)
  end

  it "preserves error message" do
    error = Anthropic::ConnectionError.new("Connection refused")
    error.message.should eq("Connection refused")
  end
end

describe Anthropic::TimeoutError do
  it "inherits from ConnectionError" do
    error = Anthropic::TimeoutError.new("Request timed out")
    error.should be_a(Anthropic::ConnectionError)
  end

  it "preserves error message" do
    error = Anthropic::TimeoutError.new("Connection timeout")
    error.message.should eq("Connection timeout")
  end
end

describe Anthropic::APIError, "#request_id" do
  it "extracts request-id header from response" do
    response = HTTP::Client::Response.new(
      400,
      body: %({"error":{"type":"invalid_request_error","message":"Bad"}}),
      headers: HTTP::Headers{"request-id" => "req_err_123"}
    )
    error = Anthropic::APIError.from_response(response)
    error.request_id.should eq("req_err_123")
  end

  it "extracts x-request-id header from response" do
    response = HTTP::Client::Response.new(
      400,
      body: %({"error":{"type":"invalid_request_error","message":"Bad"}}),
      headers: HTTP::Headers{"x-request-id" => "req_x_456"}
    )
    error = Anthropic::APIError.from_response(response)
    error.request_id.should eq("req_x_456")
  end

  it "prefers request-id over x-request-id" do
    response = HTTP::Client::Response.new(
      400,
      body: %({"error":{"type":"invalid_request_error","message":"Bad"}}),
      headers: HTTP::Headers{
        "request-id"   => "req_preferred",
        "x-request-id" => "req_fallback",
      }
    )
    error = Anthropic::APIError.from_response(response)
    error.request_id.should eq("req_preferred")
  end

  it "returns nil when no request ID header is present" do
    response = HTTP::Client::Response.new(
      400,
      body: %({"error":{"type":"invalid_request_error","message":"Bad"}})
    )
    error = Anthropic::APIError.from_response(response)
    error.request_id.should be_nil
  end

  it "preserves request_id on 4xx errors" do
    response = HTTP::Client::Response.new(
      401,
      body: %({"error":{"type":"authentication_error","message":"Invalid key"}}),
      headers: HTTP::Headers{"request-id" => "req_401_abc"}
    )
    error = Anthropic::APIError.from_response(response)
    error.should be_a(Anthropic::AuthenticationError)
    error.request_id.should eq("req_401_abc")
  end

  it "preserves request_id on 5xx errors" do
    response = HTTP::Client::Response.new(
      529,
      body: %({"error":{"type":"overloaded_error","message":"Overloaded"}}),
      headers: HTTP::Headers{"request-id" => "req_529_xyz"}
    )
    error = Anthropic::APIError.from_response(response)
    error.should be_a(Anthropic::OverloadedError)
    error.request_id.should eq("req_529_xyz")
  end

  it "defaults to nil when constructed without request_id" do
    error = Anthropic::APIError.new(400, "invalid_request_error", "Bad request")
    error.request_id.should be_nil
  end

  it "stores request_id when constructed with one" do
    error = Anthropic::APIError.new(400, "invalid_request_error", "Bad request", "req_manual")
    error.request_id.should eq("req_manual")
  end
end

describe Anthropic::APIError, "#parse_error_body" do
  it "parses valid error body correctly" do
    response = HTTP::Client::Response.new(400, body: %({"error":{"type":"invalid_request_error","message":"Bad input"}}))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("invalid_request_error")
    error.error_message.should eq("Bad input")
  end

  it "handles malformed JSON body" do
    response = HTTP::Client::Response.new(500, body: "Internal Server Error")
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("Internal Server Error")
  end

  it "handles JSON without error key" do
    response = HTTP::Client::Response.new(400, body: %({"status":"error","detail":"Something went wrong"}))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should contain("Something went wrong")
  end

  it "handles error with non-string type field" do
    response = HTTP::Client::Response.new(400, body: %({"error":{"type":123,"message":"Bad input"}}))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("Bad input")
  end

  it "handles error with non-string message field" do
    response = HTTP::Client::Response.new(400, body: %({"error":{"type":"invalid_request_error","message":456}}))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("invalid_request_error")
    error.error_message.should contain("invalid_request_error")
  end

  it "handles error with null type field" do
    response = HTTP::Client::Response.new(400, body: %({"error":{"type":null,"message":"Bad input"}}))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("Bad input")
  end

  it "handles error with null message field" do
    response = HTTP::Client::Response.new(400, body: %({"error":{"type":"invalid_request_error","message":null}}))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("invalid_request_error")
    error.error_message.should contain("invalid_request_error")
  end

  it "handles completely empty body" do
    response = HTTP::Client::Response.new(500, body: "")
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("")
  end

  it "handles missing error object entirely" do
    response = HTTP::Client::Response.new(400, body: %({"data":{"some":"value"}}))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should contain("data")
  end

  it "handles JSON number scalar body" do
    response = HTTP::Client::Response.new(500, body: "123")
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("123")
  end

  it "handles JSON string scalar body" do
    response = HTTP::Client::Response.new(500, body: %("just a string"))
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq(%("just a string"))
  end

  it "handles JSON array body" do
    response = HTTP::Client::Response.new(500, body: "[1,2,3]")
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("[1,2,3]")
  end

  it "handles JSON boolean true body" do
    response = HTTP::Client::Response.new(500, body: "true")
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("true")
  end

  it "handles JSON boolean false body" do
    response = HTTP::Client::Response.new(500, body: "false")
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("false")
  end

  it "handles JSON null body" do
    response = HTTP::Client::Response.new(500, body: "null")
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("null")
  end

  it "handles error value as a plain string" do
    body = %({"error":"oops"})
    response = HTTP::Client::Response.new(500, body: body)
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq("oops")
  end

  it "handles error value as an array" do
    body = %({"error":[1,2,3]})
    response = HTTP::Client::Response.new(500, body: body)
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq(body)
  end

  it "handles error value as null" do
    body = %({"error":null})
    response = HTTP::Client::Response.new(500, body: body)
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq(body)
  end

  it "handles error value as a number" do
    body = %({"error":42})
    response = HTTP::Client::Response.new(500, body: body)
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq(body)
  end

  it "handles error hash with non-string type and message fields" do
    body = %({"error":{"type":123,"message":true}})
    response = HTTP::Client::Response.new(500, body: body)
    error = Anthropic::APIError.from_response(response)

    error.error_type.should eq("unknown_error")
    error.error_message.should eq(body)
  end
end
