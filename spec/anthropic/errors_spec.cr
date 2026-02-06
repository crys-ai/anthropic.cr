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
