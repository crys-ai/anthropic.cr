require "../spec_helper"

describe Anthropic::RequestOptions do
  describe ".new" do
    it "creates with defaults" do
      opts = Anthropic::RequestOptions.new

      opts.timeout.should be_nil
      opts.retry_policy.should be_nil
      opts.beta_headers.should be_nil
      opts.extra_headers.should be_nil
    end

    it "accepts custom values" do
      policy = Anthropic::RetryPolicy.new(max_retries: 5)
      extra = HTTP::Headers{"X-Custom" => "value"}

      opts = Anthropic::RequestOptions.new(
        timeout: 30.seconds,
        retry_policy: policy,
        beta_headers: ["tools-1.0"],
        extra_headers: extra,
      )

      opts.timeout.should eq(30.seconds)
      if policy = opts.retry_policy
        policy.max_retries.should eq(5)
      else
        fail "retry_policy should not be nil"
      end
      opts.beta_headers.should eq(["tools-1.0"])
      opts.extra_headers.should eq(extra)
    end
  end

  describe "defensive copies" do
    it "does not mutate stored beta_headers when original array is modified" do
      original = ["beta-1", "beta-2"]
      opts = Anthropic::RequestOptions.new(beta_headers: original)

      original << "injected-beta"

      if betas = opts.beta_headers
        betas.should eq(["beta-1", "beta-2"])
        betas.size.should eq(2)
      else
        fail "beta_headers should not be nil"
      end
    end

    it "does not mutate stored extra_headers when original headers are modified" do
      original = HTTP::Headers{"X-Custom" => "value1"}
      opts = Anthropic::RequestOptions.new(extra_headers: original)

      original["X-Injected"] = "injected"

      if headers = opts.extra_headers
        headers.should eq(HTTP::Headers{"X-Custom" => "value1"})
        headers.has_key?("X-Injected").should be_false
      else
        fail "extra_headers should not be nil"
      end
    end

    it "handles nil beta_headers without error" do
      opts = Anthropic::RequestOptions.new(beta_headers: nil)
      opts.beta_headers.should be_nil
    end

    it "handles nil extra_headers without error" do
      opts = Anthropic::RequestOptions.new(extra_headers: nil)
      opts.extra_headers.should be_nil
    end

    it "does not leak internal beta_headers via getter" do
      opts = Anthropic::RequestOptions.new(beta_headers: ["original"])
      if betas = opts.beta_headers
        betas << "injected"
      end
      opts.beta_headers.should eq(["original"])
    end

    it "does not leak internal extra_headers via getter" do
      opts = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Test" => "original"}
      )
      if headers = opts.extra_headers
        headers["X-Injected"] = "bad"
      end
      opts.extra_headers.try(&.["X-Injected"]?).should be_nil
    end
  end
end

describe "Per-request options" do
  describe "timeout override" do
    it "applies per-request timeout" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      opts = Anthropic::RequestOptions.new(timeout: 5.seconds)
      response = client.post("/v1/messages", "{}", options: opts)
      response.status_code.should eq(200)
    end
  end

  describe "beta headers override" do
    it "merges per-request beta headers with client-level" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client_with_betas(beta_headers: ["client-beta"])
      opts = Anthropic::RequestOptions.new(beta_headers: ["request-beta"])
      response = client.post("/v1/messages", "{}", options: opts)
      response.status_code.should eq(200)
    end

    it "uses only per-request beta headers when client has none" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      opts = Anthropic::RequestOptions.new(beta_headers: ["request-beta"])
      response = client.post("/v1/messages", "{}", options: opts)
      response.status_code.should eq(200)
    end
  end

  describe "retry policy override" do
    it "uses per-request retry policy" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 3
            HTTP::Client::Response.new(
              429,
              body: TestHelpers.error_json("rate_limit_error", "Rate limited"),
              headers: HTTP::Headers{"Content-Type" => "application/json"}
            )
          else
            HTTP::Client::Response.new(
              200,
              body: TestHelpers.response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"}
            )
          end
        end

      # Client has disabled retries, but request-level enables 3 retries
      client = TestHelpers.test_client # disabled retries
      opts = Anthropic::RequestOptions.new(
        retry_policy: Anthropic::RetryPolicy.new(max_retries: 3)
      )

      response = client.post("/v1/messages", "{}", options: opts)
      response.status_code.should eq(200)
      call_count.should eq(3)
    end
  end

  describe "extra headers" do
    it "includes extra headers in request" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      opts = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Custom-Header" => "custom-value"}
      )
      response = client.post("/v1/messages", "{}", options: opts)
      response.status_code.should eq(200)
    end
  end
end
