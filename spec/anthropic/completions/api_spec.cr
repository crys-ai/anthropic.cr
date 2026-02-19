require "../../spec_helper"

private COMPLETIONS_URL = "https://api.anthropic.com/v1/complete"

describe Anthropic::Completions::API do
  describe "ENDPOINT" do
    it "is /v1/complete" do
      Anthropic::Completions::API::ENDPOINT.should eq("/v1/complete")
    end
  end

  describe "#create with Request" do
    it "sends POST to /v1/complete and returns Response" do
      stub_completions(completion: "The answer is 42.")

      client = TestHelpers.test_client
      request = Anthropic::Completions::Request.new(
        model: "claude-2.1",
        prompt: "\n\nHuman: What is 6*7?\n\nAssistant:",
        max_tokens_to_sample: 100,
      )

      response = client.completions.create(request)
      response.should be_a(Anthropic::Completions::Response)
      response.completion.should eq("The answer is 42.")
    end

    it "parses response model" do
      stub_completions(model: "claude-2.1")

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
      )

      response.model.should eq("claude-2.1")
    end

    it "parses stop_reason" do
      stub_completions(stop_reason: "stop_sequence")

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
      )

      response.stop_reason.should eq("stop_sequence")
    end

    it "parses stop sequence that was matched" do
      stub_completions(stop: "\n\nHuman:")

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
      )

      response.stop.should eq("\n\nHuman:")
    end
  end

  describe "#create request_id" do
    it "surfaces request-id header on successful response" do
      WebMock.stub(:post, COMPLETIONS_URL).to_return(
        status: 200,
        body: completions_response_json,
        headers: HTTP::Headers{
          "Content-Type" => "application/json",
          "request-id"   => "req_success_123",
        },
      )

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
      )

      response.request_id.should eq("req_success_123")
    end

    it "surfaces x-request-id header variant on successful response" do
      WebMock.stub(:post, COMPLETIONS_URL).to_return(
        status: 200,
        body: completions_response_json,
        headers: HTTP::Headers{
          "Content-Type" => "application/json",
          "x-request-id" => "req_x_success_456",
        },
      )

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
      )

      response.request_id.should eq("req_x_success_456")
    end

    it "returns nil request_id when no header present" do
      stub_completions

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
      )

      response.request_id.should be_nil
    end
  end

  describe "#create with params" do
    it "sends model and prompt" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["model"].as_s.should eq("claude-2.1")
          parsed["prompt"].as_s.should eq("\n\nHuman: Hello\n\nAssistant:")
          parsed["max_tokens_to_sample"].as_i.should eq(256)

          HTTP::Client::Response.new(200,
            body: completions_response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hello\n\nAssistant:",
        max_tokens_to_sample: 256,
      )
    end

    it "sends optional stop_sequences" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          stop_seq = parsed["stop_sequences"].as_a
          stop_seq.size.should eq(2)
          stop_seq[0].as_s.should eq("\n\nHuman:")
          stop_seq[1].as_s.should eq("\n\nAssistant:")

          HTTP::Client::Response.new(200,
            body: completions_response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hello\n\nAssistant:",
        max_tokens_to_sample: 100,
        stop_sequences: ["\n\nHuman:", "\n\nAssistant:"],
      )
    end

    it "sends optional temperature" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["temperature"].as_f.should eq(0.7)

          HTTP::Client::Response.new(200,
            body: completions_response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Be creative\n\nAssistant:",
        max_tokens_to_sample: 100,
        temperature: 0.7,
      )
    end

    it "sends optional top_p" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["top_p"].as_f.should eq(0.9)

          HTTP::Client::Response.new(200,
            body: completions_response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
        top_p: 0.9,
      )
    end

    it "sends optional top_k" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["top_k"].as_i.should eq(40)

          HTTP::Client::Response.new(200,
            body: completions_response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
        top_k: 40,
      )
    end

    it "sends optional metadata" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["metadata"]["user_id"].as_s.should eq("user-123")

          HTTP::Client::Response.new(200,
            body: completions_response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
        metadata: Anthropic::Metadata.with_user_id("user-123"),
      )
    end
  end

  describe "beta headers" do
    it "forwards beta headers via request_options" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .with(headers: {"anthropic-beta" => "test-beta-feature"})
        .to_return(
          status: 200,
          body: completions_response_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      request = Anthropic::Completions::Request.new(
        "claude-2.1",
        "\n\nHuman: Hi\n\nAssistant:",
        100,
      )
      options = Anthropic::RequestOptions.new(beta_headers: ["test-beta-feature"])

      client.completions.create(request, options)
    end

    it "uses client-level beta headers" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .with(headers: {"anthropic-beta" => "client-beta"})
        .to_return(
          status: 200,
          body: completions_response_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client_with_betas(beta_headers: ["client-beta"])
      client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
      )
    end
  end

  describe "request_options forwarding" do
    it "forwards extra_headers via request_options" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .with(headers: {"X-Custom-Header" => "custom-value"})
        .to_return(
          status: 200,
          body: completions_response_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      request = Anthropic::Completions::Request.new(
        "claude-2.1",
        "\n\nHuman: Hi\n\nAssistant:",
        100,
      )
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Custom-Header" => "custom-value"}
      )

      response = client.completions.create(request, options)
      response.should be_a(Anthropic::Completions::Response)
    end

    it "forwards request_options with convenience overload" do
      WebMock.stub(:post, COMPLETIONS_URL)
        .with(headers: {"X-Test" => "value"})
        .to_return(
          status: 200,
          body: completions_response_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Test" => "value"}
      )

      response = client.completions.create(
        model: "claude-2.1",
        prompt: "\n\nHuman: Hi\n\nAssistant:",
        max_tokens_to_sample: 100,
        request_options: options
      )
      response.should be_a(Anthropic::Completions::Response)
    end
  end

  describe "request validation" do
    it "raises on negative max_tokens_to_sample" do
      expect_raises(ArgumentError, /max_tokens_to_sample must be positive/) do
        Anthropic::Completions::Request.new(
          model: "claude-2.1",
          prompt: "test",
          max_tokens_to_sample: -1,
        )
      end
    end

    it "raises on zero max_tokens_to_sample" do
      expect_raises(ArgumentError, /max_tokens_to_sample must be positive/) do
        Anthropic::Completions::Request.new(
          model: "claude-2.1",
          prompt: "test",
          max_tokens_to_sample: 0,
        )
      end
    end

    it "raises on temperature out of range" do
      expect_raises(ArgumentError, /temperature must be between 0.0 and 1.0/) do
        Anthropic::Completions::Request.new(
          model: "claude-2.1",
          prompt: "test",
          max_tokens_to_sample: 100,
          temperature: 1.5,
        )
      end
    end

    it "raises on top_p out of range" do
      expect_raises(ArgumentError, /top_p must be between 0.0 and 1.0/) do
        Anthropic::Completions::Request.new(
          model: "claude-2.1",
          prompt: "test",
          max_tokens_to_sample: 100,
          top_p: -0.1,
        )
      end
    end
  end

  describe "response parsing" do
    it "parses truncated field" do
      json = <<-JSON
        {
          "completion": "Hello",
          "stop_reason": "max_tokens",
          "model": "claude-2.1",
          "truncated": true
        }
        JSON

      WebMock.stub(:post, COMPLETIONS_URL).to_return(
        status: 200,
        body: json,
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "test",
        max_tokens_to_sample: 100,
      )

      response.truncated.should be_true
    end

    it "parses log_id field" do
      json = <<-JSON
        {
          "completion": "Hello",
          "stop_reason": "end_turn",
          "model": "claude-2.1",
          "log_id": "log_abc123"
        }
        JSON

      WebMock.stub(:post, COMPLETIONS_URL).to_return(
        status: 200,
        body: json,
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "test",
        max_tokens_to_sample: 100,
      )

      response.log_id.should eq("log_abc123")
    end

    it "handles null stop_reason" do
      json = <<-JSON
        {
          "completion": "Hello",
          "stop_reason": null,
          "model": "claude-2.1"
        }
        JSON

      WebMock.stub(:post, COMPLETIONS_URL).to_return(
        status: 200,
        body: json,
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      client = TestHelpers.test_client
      response = client.completions.create(
        model: "claude-2.1",
        prompt: "test",
        max_tokens_to_sample: 100,
      )

      response.stop_reason.should be_nil
    end
  end
end

# Helper methods for completions tests
private def stub_completions(
  completion : String = "Hello!",
  model : String = "claude-2.1",
  stop_reason : String? = "end_turn",
  stop : String? = nil,
)
  json = completions_response_json(
    completion: completion,
    model: model,
    stop_reason: stop_reason,
    stop: stop,
  )

  WebMock.stub(:post, "https://api.anthropic.com/v1/complete").to_return(
    status: 200,
    body: json,
    headers: {"Content-Type" => "application/json"},
  )
end

private def completions_response_json(
  completion : String = "Hello!",
  model : String = "claude-2.1",
  stop_reason : String? = "end_turn",
  stop : String? = nil,
) : String
  stop_json = stop ? stop.to_json : "null"
  stop_reason_json = stop_reason ? stop_reason.to_json : "null"

  <<-JSON
    {
      "completion": #{completion.to_json},
      "stop_reason": #{stop_reason_json},
      "stop": #{stop_json},
      "model": #{model.to_json}
    }
    JSON
end
