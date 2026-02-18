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
end
