require "../spec_helper"

describe Anthropic::RetryPolicy do
  describe ".new" do
    it "creates with defaults" do
      policy = Anthropic::RetryPolicy.new

      policy.max_retries.should eq(2)
      policy.base_delay.should eq(1.second)
      policy.max_delay.should eq(10.seconds)
      policy.backoff_factor.should eq(2.0)
    end

    it "accepts custom values" do
      policy = Anthropic::RetryPolicy.new(
        max_retries: 5,
        base_delay: 2.seconds,
        max_delay: 30.seconds,
        backoff_factor: 1.5,
      )

      policy.max_retries.should eq(5)
      policy.base_delay.should eq(2.seconds)
      policy.max_delay.should eq(30.seconds)
      policy.backoff_factor.should eq(1.5)
    end

    it "raises on negative max_retries" do
      expect_raises(ArgumentError, "max_retries must be >= 0") do
        Anthropic::RetryPolicy.new(max_retries: -1)
      end
    end

    it "raises on backoff_factor <= 1" do
      expect_raises(ArgumentError, "backoff_factor must be > 1") do
        Anthropic::RetryPolicy.new(backoff_factor: 1.0)
      end
    end

    it "allows max_retries = 0" do
      policy = Anthropic::RetryPolicy.new(max_retries: 0)
      policy.max_retries.should eq(0)
      policy.enabled?.should be_false
    end

    it "raises ArgumentError for zero base_delay" do
      expect_raises(ArgumentError, "base_delay must be positive") do
        Anthropic::RetryPolicy.new(base_delay: 0.seconds)
      end
    end

    it "raises ArgumentError for negative base_delay" do
      expect_raises(ArgumentError, "base_delay must be positive") do
        Anthropic::RetryPolicy.new(base_delay: -1.second)
      end
    end

    it "raises ArgumentError for zero max_delay" do
      expect_raises(ArgumentError, "max_delay must be positive") do
        Anthropic::RetryPolicy.new(max_delay: 0.seconds)
      end
    end

    it "raises ArgumentError for negative max_delay" do
      expect_raises(ArgumentError, "max_delay must be positive") do
        Anthropic::RetryPolicy.new(max_delay: -1.second)
      end
    end

    it "accepts valid positive delays" do
      policy = Anthropic::RetryPolicy.new(
        base_delay: 0.5.seconds,
        max_delay: 5.seconds,
      )
      policy.base_delay.should eq(0.5.seconds)
      policy.max_delay.should eq(5.seconds)
    end
  end

  describe ".disabled" do
    it "creates a disabled policy" do
      policy = Anthropic::RetryPolicy.disabled
      policy.max_retries.should eq(0)
      policy.enabled?.should be_false
    end
  end

  describe ".default" do
    it "creates the default policy" do
      policy = Anthropic::RetryPolicy.default
      policy.max_retries.should eq(2)
    end
  end

  describe ".aggressive" do
    it "creates an aggressive policy" do
      policy = Anthropic::RetryPolicy.aggressive
      policy.max_retries.should eq(5)
      policy.max_delay.should eq(30.seconds)
    end
  end

  describe "#delay_for" do
    it "calculates exponential backoff" do
      policy = Anthropic::RetryPolicy.new(
        base_delay: 1.second,
        max_delay: 10.seconds,
        backoff_factor: 2.0,
      )

      policy.delay_for(0).should eq(1.second)
      policy.delay_for(1).should eq(2.seconds)
      policy.delay_for(2).should eq(4.seconds)
      policy.delay_for(3).should eq(8.seconds)
      policy.delay_for(4).should eq(10.seconds) # capped at max_delay
      policy.delay_for(10).should eq(10.seconds)
    end

    it "returns max_delay for extremely large attempt values" do
      policy = Anthropic::RetryPolicy.new(
        base_delay: 1.second,
        max_delay: 10.seconds,
        backoff_factor: 2.0,
      )

      policy.delay_for(1000).should eq(10.seconds)
    end

    it "returns max_delay for attempt producing Infinity" do
      policy = Anthropic::RetryPolicy.new(
        base_delay: 1.second,
        max_delay: 10.seconds,
        backoff_factor: 2.0,
      )

      # attempt=10000 guarantees overflow to Infinity
      policy.delay_for(10000).should eq(10.seconds)
    end

    it "normal attempts still work correctly" do
      policy = Anthropic::RetryPolicy.new(
        base_delay: 1.second,
        max_delay: 10.seconds,
        backoff_factor: 2.0,
      )

      policy.delay_for(0).should eq(1.second)
      policy.delay_for(1).should eq(2.seconds)
    end
  end

  describe "#enabled?" do
    it "returns true when max_retries > 0" do
      policy = Anthropic::RetryPolicy.new(max_retries: 1)
      policy.enabled?.should be_true
    end

    it "returns false when max_retries = 0" do
      policy = Anthropic::RetryPolicy.new(max_retries: 0)
      policy.enabled?.should be_false
    end
  end

  describe ".retryable?" do
    it "returns true for RateLimitError" do
      error = Anthropic::RateLimitError.new(429, "rate_limit_error", "Too many requests")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for OverloadedError" do
      error = Anthropic::OverloadedError.new(529, "overloaded_error", "Service overloaded")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for ConnectionError" do
      error = Anthropic::ConnectionError.new("Network error")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for TimeoutError (subclass of ConnectionError)" do
      error = Anthropic::TimeoutError.new("Request timed out")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for RequestTimeoutError (408)" do
      error = Anthropic::RequestTimeoutError.new(408, "request_timeout_error", "Request timed out")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for generic 500 server error" do
      error = Anthropic::APIError.new(500, "api_error", "Internal server error")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for 502 Bad Gateway" do
      error = Anthropic::APIError.new(502, "api_error", "Bad gateway")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for 503 Service Unavailable" do
      error = Anthropic::APIError.new(503, "api_error", "Service unavailable")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns true for 504 Gateway Timeout" do
      error = Anthropic::APIError.new(504, "api_error", "Gateway timeout")
      Anthropic::RetryPolicy.retryable?(error).should be_true
    end

    it "returns false for InvalidRequestError (400)" do
      error = Anthropic::InvalidRequestError.new(400, "invalid_request_error", "Bad request")
      Anthropic::RetryPolicy.retryable?(error).should be_false
    end

    it "returns false for AuthenticationError (401)" do
      error = Anthropic::AuthenticationError.new(401, "authentication_error", "Invalid key")
      Anthropic::RetryPolicy.retryable?(error).should be_false
    end

    it "returns false for NotFoundError (404)" do
      error = Anthropic::NotFoundError.new(404, "not_found_error", "Not found")
      Anthropic::RetryPolicy.retryable?(error).should be_false
    end

    it "returns false for ConflictError (409)" do
      error = Anthropic::ConflictError.new(409, "conflict_error", "Resource conflict")
      Anthropic::RetryPolicy.retryable?(error).should be_false
    end

    it "returns false for UnprocessableEntityError (422)" do
      error = Anthropic::UnprocessableEntityError.new(422, "unprocessable_entity_error", "Invalid input")
      Anthropic::RetryPolicy.retryable?(error).should be_false
    end

    it "returns false for generic Exception" do
      Anthropic::RetryPolicy.retryable?(Exception.new("oops")).should be_false
    end
  end
end
