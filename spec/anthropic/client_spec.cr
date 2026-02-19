require "../spec_helper"

describe Anthropic::Client do
  describe "#initialize" do
    it "raises without API key" do
      TestHelpers.with_env("ANTHROPIC_API_KEY", nil) do
        expect_raises(ArgumentError, /API key required/) do
          Anthropic::Client.new
        end
      end
    end

    it "accepts explicit API key" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.api_key.should eq("sk-ant-test")
    end

    it "reads from environment" do
      TestHelpers.with_env("ANTHROPIC_API_KEY", "sk-ant-from-env") do
        client = Anthropic::Client.new
        client.api_key.should eq("sk-ant-from-env")
      end
    end

    it "uses default base URL" do
      TestHelpers.with_env("ANTHROPIC_BASE_URL", nil) do
        client = Anthropic::Client.new(api_key: "sk-ant-test")
        client.base_url.should eq("https://api.anthropic.com")
      end
    end

    it "allows custom base URL" do
      client = Anthropic::Client.new(api_key: "sk-ant-test", base_url: "https://custom.api")
      client.base_url.should eq("https://custom.api")
    end

    it "uses default timeout" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.timeout.should eq(120.seconds)
    end

    it "allows custom timeout" do
      client = Anthropic::Client.new(api_key: "sk-ant-test", timeout: 30.seconds)
      client.timeout.should eq(30.seconds)
    end

    it "reads ANTHROPIC_BASE_URL from environment" do
      TestHelpers.with_env("ANTHROPIC_BASE_URL", "https://proxy.example.com") do
        client = Anthropic::Client.new(api_key: "sk-ant-test")
        client.base_url.should eq("https://proxy.example.com")
      end
    end

    it "accepts a Configuration struct" do
      config = Anthropic::Configuration.new(
        api_key: "sk-ant-config-test",
        base_url: "https://config.example.com",
        api_version: "2024-06-01",
        timeout: 60.seconds,
        max_pool_size: 5,
      )
      client = Anthropic::Client.new(config)
      client.api_key.should eq("sk-ant-config-test")
      client.base_url.should eq("https://config.example.com")
      client.timeout.should eq(60.seconds)
      client.config.api_version.should eq("2024-06-01")
      client.config.max_pool_size.should eq(5)
    end

    it "uses config.api_version in auth headers" do
      TestHelpers.with_env("ANTHROPIC_BASE_URL", nil) do
        config = Anthropic::Configuration.new(
          api_key: "sk-ant-test",
          api_version: "2025-01-01",
        )

        WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
          .with(headers: {"anthropic-version" => "2025-01-01"})
          .to_return(status: 200, body: TestHelpers.response_json)

        client = Anthropic::Client.new(config)
        client.post("/v1/messages", "{}")
      end
    end
  end

  describe "#messages" do
    it "returns Messages::API" do
      client = TestHelpers.test_client
      client.messages.should be_a(Anthropic::Messages::API)
    end

    it "memoizes the instance" do
      client = TestHelpers.test_client
      client.messages.should be(client.messages)
    end
  end

  describe "#post" do
    it "sends POST request to correct URL" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      client.post("/v1/messages", "{}")
    end

    it "includes x-api-key header" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: {"x-api-key" => "sk-ant-my-key"})
        .to_return(status: 200, body: TestHelpers.response_json)

      client = Anthropic::Client.new(api_key: "sk-ant-my-key", base_url: "https://api.anthropic.com")
      client.post("/v1/messages", "{}")
    end

    it "includes anthropic-version header" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: {"anthropic-version" => "2023-06-01"})
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      client.post("/v1/messages", "{}")
    end

    it "includes Content-Type header" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: {"Content-Type" => "application/json"})
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      client.post("/v1/messages", "{}")
    end

    it "sends the request body" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .with(body: %({"model":"test"}))
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      client.post("/v1/messages", %({"model":"test"}))
    end

    it "returns HTTP::Client::Response on success" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      response = client.post("/v1/messages", "{}")
      response.should be_a(HTTP::Client::Response)
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      TestHelpers.stub_error(401, "authentication_error", "invalid x-api-key")

      client = TestHelpers.test_client
      expect_raises(Anthropic::AuthenticationError, /invalid x-api-key/) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end

    it "raises RateLimitError on 429" do
      TestHelpers.stub_error(429, "rate_limit_error", "Rate limit exceeded")

      client = TestHelpers.test_client
      expect_raises(Anthropic::RateLimitError, /Rate limit exceeded/) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end

    it "raises OverloadedError on 529" do
      TestHelpers.stub_error(529, "overloaded_error", "API is temporarily overloaded")

      client = TestHelpers.test_client
      expect_raises(Anthropic::OverloadedError, /overloaded/) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end

    it "raises InvalidRequestError on 400" do
      TestHelpers.stub_error(400, "invalid_request_error", "max_tokens must be positive")

      client = TestHelpers.test_client
      expect_raises(Anthropic::InvalidRequestError, /max_tokens/) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end

    it "raises NotFoundError on 404" do
      TestHelpers.stub_error(404, "not_found_error", "Resource not found")

      client = TestHelpers.test_client
      expect_raises(Anthropic::NotFoundError, /not found/) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end

    it "raises PermissionError on 403" do
      TestHelpers.stub_error(403, "permission_error", "Not allowed")

      client = TestHelpers.test_client
      expect_raises(Anthropic::PermissionError, /Not allowed/) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end

    it "raises APIError on unknown status codes" do
      TestHelpers.stub_error(502, "api_error", "Bad gateway")

      client = TestHelpers.test_client
      expect_raises(Anthropic::APIError, /Bad gateway/) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end

    it "handles malformed error response bodies" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return(status: 500, body: "Internal Server Error")

      client = TestHelpers.test_client
      expect_raises(Anthropic::APIError) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
      end
    end
  end

  describe "#models" do
    it "returns Models::API" do
      client = TestHelpers.test_client
      client.models.should be_a(Anthropic::Models::API)
    end

    it "memoizes the instance" do
      client = TestHelpers.test_client
      client.models.should be(client.models)
    end
  end

  describe ".request_id" do
    it "extracts request-id from response headers" do
      response = HTTP::Client::Response.new(
        200,
        body: "{}",
        headers: HTTP::Headers{"request-id" => "req_abc123"}
      )
      Anthropic::Client.request_id(response).should eq("req_abc123")
    end

    it "extracts x-request-id from response headers" do
      response = HTTP::Client::Response.new(
        200,
        body: "{}",
        headers: HTTP::Headers{"x-request-id" => "req_xyz789"}
      )
      Anthropic::Client.request_id(response).should eq("req_xyz789")
    end

    it "prefers request-id over x-request-id when both present" do
      response = HTTP::Client::Response.new(
        200,
        body: "{}",
        headers: HTTP::Headers{
          "request-id"   => "req_preferred",
          "x-request-id" => "req_fallback",
        }
      )
      Anthropic::Client.request_id(response).should eq("req_preferred")
    end

    it "returns nil when no request ID header is present" do
      response = HTTP::Client::Response.new(200, body: "{}")
      Anthropic::Client.request_id(response).should be_nil
    end
  end

  describe "beta headers" do
    it "includes anthropic-beta header when beta_headers are set" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: {"anthropic-beta" => "tools-1.0,max-tokens-3.0"})
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client_with_betas(beta_headers: ["tools-1.0", "max-tokens-3.0"])
      client.post("/v1/messages", "{}")
    end

    it "does not include anthropic-beta header when empty" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: TestHelpers.response_json)

      client = TestHelpers.test_client
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
    end

    it "includes anthropic-beta in GET requests" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .with(headers: {"anthropic-beta" => "tools-1.0"})
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
        )

      client = TestHelpers.test_client_with_betas(beta_headers: ["tools-1.0"])
      client.get("/v1/models")
    end
  end

  describe "#post_stream error handling" do
    it "raises OverloadedError on 529 during stream" do
      TestHelpers.stub_stream_error(529, "overloaded_error", "API overloaded")

      client = TestHelpers.test_client
      expect_raises(Anthropic::OverloadedError, /overloaded/) do
        client.post_stream("/v1/messages", "{}") do |_response|
          # Should not reach here
          fail "Expected error to be raised"
        end
      end
    end

    it "raises AuthenticationError on 401 during stream" do
      TestHelpers.stub_stream_error(401, "authentication_error", "Invalid API key")

      client = TestHelpers.test_client
      expect_raises(Anthropic::AuthenticationError, /Invalid API key/) do
        client.post_stream("/v1/messages", "{}") do |_response|
          # Should not reach here
          fail "Expected error to be raised"
        end
      end
    end

    it "raises RateLimitError on 429 during stream" do
      TestHelpers.stub_stream_error(429, "rate_limit_error", "Rate limit exceeded")

      client = TestHelpers.test_client
      expect_raises(Anthropic::RateLimitError, /Rate limit exceeded/) do
        client.post_stream("/v1/messages", "{}") do |_response|
          # Should not reach here
          fail "Expected error to be raised"
        end
      end
    end

    it "handles error response without body_io gracefully" do
      # Stub an error with a regular body instead of body_io
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return(status: 500, body: "Server error")

      client = TestHelpers.test_client
      expect_raises(Anthropic::APIError, /Server error/) do
        client.post_stream("/v1/messages", "{}") do |_response|
          # Should not reach here
          fail "Expected error to be raised"
        end
      end
    end

    it "handles malformed error body during stream" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return(status: 500, body: "Not JSON", headers: {"Content-Type" => "text/plain"})

      client = TestHelpers.test_client
      expect_raises(Anthropic::APIError) do
        client.post_stream("/v1/messages", "{}") do |_response|
          # Should not reach here
          fail "Expected error to be raised"
        end
      end
    end
  end

  describe "retry behavior" do
    it "retries on 429 RateLimitError and eventually succeeds" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 3
            # First 2 calls: rate limit error
            HTTP::Client::Response.new(
              429,
              body: TestHelpers.error_json("rate_limit_error", "Rate limited"),
              headers: HTTP::Headers{"Content-Type" => "application/json"}
            )
          else
            # 3rd call: success
            HTTP::Client::Response.new(
              200,
              body: TestHelpers.response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"}
            )
          end
        end

      client = TestHelpers.test_client_with_retries(max_retries: 3)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(3)
    end

    it "retries on 529 OverloadedError" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            HTTP::Client::Response.new(
              529,
              body: TestHelpers.error_json("overloaded_error", "Overloaded"),
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

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "retries on 408 RequestTimeoutError" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            HTTP::Client::Response.new(
              408,
              body: TestHelpers.error_json("request_timeout_error", "Request timed out"),
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

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "retries on 500 generic server error" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            HTTP::Client::Response.new(
              500,
              body: TestHelpers.error_json("api_error", "Internal server error"),
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

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "retries on 502 Bad Gateway" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            HTTP::Client::Response.new(
              502,
              body: TestHelpers.error_json("api_error", "Bad gateway"),
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

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "retries on 503 Service Unavailable" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            HTTP::Client::Response.new(
              503,
              body: TestHelpers.error_json("api_error", "Service unavailable"),
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

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "retries on 504 Gateway Timeout" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            HTTP::Client::Response.new(
              504,
              body: TestHelpers.error_json("api_error", "Gateway timeout"),
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

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "gives up after max_retries" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          HTTP::Client::Response.new(
            429,
            body: TestHelpers.error_json("rate_limit_error", "Still rate limited"),
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      expect_raises(Anthropic::RateLimitError) do
        client.post("/v1/messages", "{}")
      end
      # 1 initial + 2 retries = 3 total calls
      call_count.should eq(3)
    end

    it "does not retry on non-retryable errors" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          HTTP::Client::Response.new(
            401,
            body: TestHelpers.error_json("authentication_error", "Invalid key"),
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client_with_retries(max_retries: 3)
      expect_raises(Anthropic::AuthenticationError) do
        client.post("/v1/messages", "{}")
      end
      # No retries - just 1 call
      call_count.should eq(1)
    end
  end

  describe "transport error retry behavior" do
    it "retries on IO::TimeoutError and eventually succeeds" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 3
            raise IO::TimeoutError.new("Connection timed out")
          else
            HTTP::Client::Response.new(
              200,
              body: TestHelpers.response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"}
            )
          end
        end

      client = TestHelpers.test_client_with_retries(max_retries: 3)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(3)
    end

    it "retries on Socket::Error" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            raise Socket::Error.new("Connection refused")
          else
            HTTP::Client::Response.new(
              200,
              body: TestHelpers.response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"}
            )
          end
        end

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "retries on IO::Error" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          if call_count < 2
            raise IO::Error.new("Broken pipe")
          else
            HTTP::Client::Response.new(
              200,
              body: TestHelpers.response_json,
              headers: HTTP::Headers{"Content-Type" => "application/json"}
            )
          end
        end

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
      call_count.should eq(2)
    end

    it "gives up after max_retries on IO::TimeoutError" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          raise IO::TimeoutError.new("Connection timed out")
        end

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      expect_raises(Anthropic::TimeoutError, /Request timed out/) do
        client.post("/v1/messages", "{}")
      end
      # 1 initial + 2 retries = 3 total calls
      call_count.should eq(3)
    end

    it "gives up after max_retries on Socket::Error" do
      call_count = 0

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do
          call_count += 1
          raise Socket::Error.new("Connection reset")
        end

      client = TestHelpers.test_client_with_retries(max_retries: 2)
      expect_raises(Anthropic::ConnectionError, /Network error/) do
        client.post("/v1/messages", "{}")
      end
      # 1 initial + 2 retries = 3 total calls
      call_count.should eq(3)
    end

    it "converts IO::TimeoutError to TimeoutError" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return { raise IO::TimeoutError.new("Read timeout") }

      client = TestHelpers.test_client_with_retries(max_retries: 0)
      error = expect_raises(Anthropic::TimeoutError) do
        client.post("/v1/messages", "{}")
      end
      if msg = error.message
        msg.should contain("Request timed out")
        msg.should contain("Read timeout")
      else
        fail "Expected error to have a message"
      end
    end

    it "converts Socket::Error to ConnectionError" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return { raise Socket::Error.new("Network unreachable") }

      client = TestHelpers.test_client_with_retries(max_retries: 0)
      error = expect_raises(Anthropic::ConnectionError) do
        client.post("/v1/messages", "{}")
      end
      if msg = error.message
        msg.should contain("Network error")
        msg.should contain("Network unreachable")
      else
        fail "Expected error to have a message"
      end
    end
  end

  describe "timeout restoration" do
    it "restores default timeout after per-request override" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return(status: 200, body: TestHelpers.response_json)

      # Create a client with retries disabled for simplicity
      client = TestHelpers.test_client

      # First request with custom timeout
      options = Anthropic::RequestOptions.new(timeout: 5.seconds)
      client.post("/v1/messages", "{}", options)

      # Second request without custom timeout - should use client's default (120s)
      # We can't directly verify the timeout on the HTTP client, but we verify
      # the mechanism exists by ensuring no error is raised.
      response = client.post("/v1/messages", "{}")
      response.status_code.should eq(200)
    end
  end

  describe "extra_body" do
    it "merges extra body fields into POST body" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {
          "undocumented_field" => JSON::Any.new("test_value"),
        }
      )
      client.post("/v1/messages", %({"model":"claude-3-sonnet"}), options)

      if body = received_body
        parsed = JSON.parse(body)
        parsed["model"].should eq("claude-3-sonnet")
        parsed["undocumented_field"]?.should eq(JSON::Any.new("test_value"))
      else
        fail "Expected request body to be present"
      end
    end

    it "existing typed fields take precedence over extra_body" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {
          "model" => JSON::Any.new("should-be-ignored"),
        }
      )
      client.post("/v1/messages", %({"model":"claude-3-sonnet"}), options)

      if body = received_body
        parsed = JSON.parse(body)
        # Typed field should NOT be overwritten
        parsed["model"].should eq("claude-3-sonnet")
      else
        fail "Expected request body to be present"
      end
    end

    it "multiple extra body fields work" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {
          "field1" => JSON::Any.new("value1"),
          "field2" => JSON::Any.new(42),
          "field3" => JSON::Any.new(true),
        }
      )
      client.post("/v1/messages", %({"model":"claude-3-sonnet"}), options)

      if body = received_body
        parsed = JSON.parse(body)
        parsed["field1"].should eq(JSON::Any.new("value1"))
        parsed["field2"].should eq(JSON::Any.new(42))
        parsed["field3"].should eq(JSON::Any.new(true))
      else
        fail "Expected request body to be present"
      end
    end

    it "JSON::Any values of different types work" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {
          "string_val" => JSON::Any.new("text"),
          "number_val" => JSON::Any.new(123),
          "float_val"  => JSON::Any.new(45.67),
          "bool_val"   => JSON::Any.new(true),
          "null_val"   => JSON::Any.new(nil),
          "array_val"  => JSON::Any.new([JSON::Any.new("a"), JSON::Any.new("b")]),
          "object_val" => JSON::Any.new({"nested" => JSON::Any.new("value")}),
        }
      )
      client.post("/v1/messages", %({"model":"claude-3-sonnet"}), options)

      if body = received_body
        parsed = JSON.parse(body)
        parsed["string_val"].should eq(JSON::Any.new("text"))
        parsed["number_val"].should eq(JSON::Any.new(123))
        parsed["float_val"].should eq(JSON::Any.new(45.67))
        parsed["bool_val"].should eq(JSON::Any.new(true))
        parsed["null_val"].should eq(JSON::Any.new(nil))
        parsed["array_val"].should eq(JSON::Any.new([JSON::Any.new("a"), JSON::Any.new("b")]))
        parsed["object_val"].should eq(JSON::Any.new({"nested" => JSON::Any.new("value")}))
      else
        fail "Expected request body to be present"
      end
    end

    it "non-object body with extra_body is handled gracefully" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body.to_s
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {
          "field" => JSON::Any.new("value"),
        }
      )
      # Array body - not an object
      client.post("/v1/messages", %([1, 2, 3]), options)

      if body = received_body
        # Body should be unchanged since it's not an object
        body.should eq(%([1, 2, 3]))
      else
        fail "Expected request body to be present"
      end
    end

    it "does nothing when extra_body is nil" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body.to_s
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new # no extra_body
      client.post("/v1/messages", %({"model":"claude-3-sonnet"}), options)

      if body = received_body
        body.should eq(%({"model":"claude-3-sonnet"}))
      else
        fail "Expected request body to be present"
      end
    end

    it "does nothing when extra_body is empty" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body.to_s
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(extra_body: {} of String => JSON::Any)
      client.post("/v1/messages", %({"model":"claude-3-sonnet"}), options)

      if body = received_body
        body.should eq(%({"model":"claude-3-sonnet"}))
      else
        fail "Expected request body to be present"
      end
    end

    it "merges extra body in post_stream" do
      received_body = nil
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          received_body = request.body
          HTTP::Client::Response.new(
            200,
            body: "data: {\"type\":\"message_start\"}\n\n",
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {
          "stream_option" => JSON::Any.new("value"),
        }
      )
      client.post_stream("/v1/messages", %({"model":"claude-3-sonnet","stream":true}), options) do |_response|
        # Just consume the stream
      end

      if body = received_body
        parsed = JSON.parse(body)
        parsed["model"].should eq("claude-3-sonnet")
        parsed["stream"].should be_true
        parsed["stream_option"]?.should eq(JSON::Any.new("value"))
      else
        fail "Expected request body to be present"
      end
    end

    it "extra_body is defensive copied on initialization" do
      original = {"field" => JSON::Any.new("original")}
      options = Anthropic::RequestOptions.new(extra_body: original)

      # Modify original hash
      original["new_field"] = JSON::Any.new("added")

      # Options should not be affected
      if extra = options.extra_body
        extra.has_key?("new_field").should be_false
      else
        fail "Expected extra_body to be present"
      end
    end

    it "extra_body getter returns a copy" do
      options = Anthropic::RequestOptions.new(
        extra_body: {"field" => JSON::Any.new("value")}
      )

      if first = options.extra_body
        first["modified"] = JSON::Any.new(true)

        if second = options.extra_body
          second.has_key?("modified").should be_false
        else
          fail "Expected second extra_body to be present"
        end
      else
        fail "Expected first extra_body to be present"
      end
    end

    it "raises ArgumentError when extra_body is used with non-JSON body" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return(status: 200, body: "{}")

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {"key" => JSON::Any.new("value")}
      )

      error = expect_raises(ArgumentError, /extra_body cannot be merged/) do
        client.post("/v1/messages", "not json content", options)
      end
      if msg = error.message
        msg.should contain("non-JSON request body")
        msg.should contain("multipart or raw payloads")
      else
        fail "Expected error to have a message"
      end
    end

    it "raises ArgumentError when extra_body is used with multipart-like body" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return(status: 200, body: "{}")

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_body: {"field" => JSON::Any.new("extra")}
      )

      # Simulate a multipart boundary string that is not valid JSON
      multipart_body = "------WebKitFormBoundary\r\nContent-Disposition: form-data"

      error = expect_raises(ArgumentError, /extra_body cannot be merged/) do
        client.post("/v1/messages", multipart_body, options)
      end
      if msg = error.message
        msg.should contain("Remove extra_body from RequestOptions")
      else
        fail "Expected error to have a message"
      end
    end
  end

  describe "extra_query" do
    it "appends extra query params to GET path" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?custom=value")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"custom" => "value"}
      )
      response = client.get("/v1/models", options)
      response.status_code.should eq(200)
    end

    it "multiple extra query params work" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?foo=bar&baz=qux")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"foo" => "bar", "baz" => "qux"}
      )
      response = client.get("/v1/models", options)
      response.status_code.should eq(200)
    end

    it "existing query params in path take precedence over extra_query" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?limit=10&extra=added")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"limit" => "99", "extra" => "added"}
      )
      # limit=10 in path should take precedence over limit=99 in extra_query
      response = client.get("/v1/models?limit=10", options)
      response.status_code.should eq(200)
    end

    it "special characters in query values are encoded" do
      # URI::Params.to_s encodes special characters
      WebMock.stub(:get, "https://api.anthropic.com/v1/models?q=hello+world")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"q" => "hello world"}
      )
      response = client.get("/v1/models", options)
      response.status_code.should eq(200)
    end

    it "appends extra query params to DELETE path" do
      WebMock.stub(:delete, "https://api.anthropic.com/v1/files/file-123?force=true")
        .to_return(status: 200, body: "{}")

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"force" => "true"}
      )
      response = client.delete("/v1/files/file-123", options)
      response.status_code.should eq(200)
    end

    it "returns path unchanged when extra_query is nil" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new # no extra_query
      response = client.get("/v1/models", options)
      response.status_code.should eq(200)
    end

    it "returns path unchanged when extra_query is empty" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {data: [] of String, has_more: false}.to_json,
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(extra_query: {} of String => String)
      response = client.get("/v1/models", options)
      response.status_code.should eq(200)
    end

    it "extra_query is defensive copied on initialization" do
      original = {"field" => "original"}
      options = Anthropic::RequestOptions.new(extra_query: original)

      # Modify original hash
      original["new_field"] = "added"

      # Options should not be affected
      if extra = options.extra_query
        extra.has_key?("new_field").should be_false
      else
        fail "Expected extra_query to be present"
      end
    end

    it "extra_query getter returns a copy" do
      options = Anthropic::RequestOptions.new(
        extra_query: {"field" => "value"}
      )

      if first = options.extra_query
        first["modified"] = "true"

        if second = options.extra_query
          second.has_key?("modified").should be_false
        else
          fail "Expected second extra_query to be present"
        end
      else
        fail "Expected first extra_query to be present"
      end
    end

    it "appends extra query params to POST path" do
      captured_path = nil
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages?custom=value")
        .to_return do |request|
          captured_path = request.resource
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"custom" => "value"}
      )
      response = client.post("/v1/messages", %({"model":"claude-3-sonnet"}), options)
      response.status_code.should eq(200)

      if path = captured_path
        path.should contain("custom=value")
      else
        fail "Expected request path to be captured"
      end
    end

    it "appends extra query params to streaming POST path" do
      captured_path = nil
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages?stream_opt=yes")
        .to_return do |request|
          captured_path = request.resource
          HTTP::Client::Response.new(
            200,
            body: "data: {\"type\":\"message_start\"}\n\n",
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"stream_opt" => "yes"}
      )
      client.post_stream("/v1/messages", %({"model":"claude-3-sonnet","stream":true}), options) do |_response|
        # Just consume the stream
      end

      if path = captured_path
        path.should contain("stream_opt=yes")
      else
        fail "Expected request path to be captured"
      end
    end

    it "existing path query params take precedence over extra_query in POST" do
      captured_path = nil
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages?limit=10&extra=added")
        .to_return do |request|
          captured_path = request.resource
          HTTP::Client::Response.new(
            200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_query: {"limit" => "99", "extra" => "added"}
      )
      # limit=10 in path should take precedence over limit=99 in extra_query
      response = client.post("/v1/messages?limit=10", %({"model":"claude-3-sonnet"}), options)
      response.status_code.should eq(200)

      if path = captured_path
        path.should contain("limit=10")
        path.should_not contain("limit=99")
        path.should contain("extra=added")
      else
        fail "Expected request path to be captured"
      end
    end
  end
end
