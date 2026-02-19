require "../../spec_helper"

describe Anthropic::Messages::CountTokensRequest do
  describe "#initialize" do
    it "creates a valid request" do
      messages = [Anthropic::Message.user("Hello")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: Anthropic::Model.sonnet,
        messages: messages,
      )

      request.model.should eq(Anthropic::Model.sonnet)
      request.messages.size.should eq(1)
      request.system.should be_nil
    end

    it "accepts string model IDs" do
      messages = [Anthropic::Message.user("Hello")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: "claude-custom-model",
        messages: messages,
      )

      request.model.should eq("claude-custom-model")
    end

    it "accepts system prompt" do
      messages = [Anthropic::Message.user("Hello")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: Anthropic::Model.sonnet,
        messages: messages,
        system: "You are a helpful assistant.",
      )

      request.system.should eq("You are a helpful assistant.")
    end

    it "raises on empty messages" do
      expect_raises(ArgumentError, "messages must not be empty") do
        Anthropic::Messages::CountTokensRequest.new(
          model: Anthropic::Model.sonnet,
          messages: [] of Anthropic::Message,
        )
      end
    end
  end

  describe "#to_json" do
    it "serializes to JSON with Model enum" do
      messages = [Anthropic::Message.user("Hello")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: Anthropic::Model.sonnet,
        messages: messages,
      )

      json = request.to_json
      json.should contain("\"model\":\"claude-sonnet-4-6\"")
      json.should contain("\"messages\":[")
    end

    it "serializes to JSON with string model" do
      messages = [Anthropic::Message.user("Hello")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: "claude-custom",
        messages: messages,
      )

      json = request.to_json
      json.should contain("\"model\":\"claude-custom\"")
    end

    it "includes system when provided" do
      messages = [Anthropic::Message.user("Hello")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: Anthropic::Model.sonnet,
        messages: messages,
        system: "System prompt",
      )

      json = request.to_json
      json.should contain("\"system\":\"System prompt\"")
    end

    it "omits system when nil" do
      messages = [Anthropic::Message.user("Hello")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: Anthropic::Model.sonnet,
        messages: messages,
      )

      json = request.to_json
      json.should_not contain("\"system\"")
    end
  end
end

describe Anthropic::Messages::CountTokensResponse do
  describe "JSON deserialization" do
    it "parses response JSON" do
      json = %({"input_tokens": 42})
      response = Anthropic::Messages::CountTokensResponse.from_json(json)
      response.input_tokens.should eq(42)
    end
  end

  describe "JSON round-trip" do
    it "survives to_json -> from_json" do
      response = Anthropic::Messages::CountTokensResponse.new(input_tokens: 100)
      parsed = Anthropic::Messages::CountTokensResponse.from_json(response.to_json)
      parsed.input_tokens.should eq(100)
    end
  end

  describe "#initialize" do
    it "defaults input_tokens to 0" do
      response = Anthropic::Messages::CountTokensResponse.new
      response.input_tokens.should eq(0)
    end
  end
end

describe Anthropic::Messages::API do
  describe "#count_tokens" do
    it "calls count_tokens endpoint and returns response" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
        .to_return(
          status: 200,
          body: {input_tokens: 15}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      messages = [Anthropic::Message.user("Hello, world!")]
      response = client.messages.count_tokens(
        model: Anthropic::Model.sonnet,
        messages: messages,
      )

      response.input_tokens.should eq(15)
    end

    it "accepts a CountTokensRequest" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
        .to_return(
          status: 200,
          body: {input_tokens: 20}.to_json,
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      messages = [Anthropic::Message.user("Test")]
      request = Anthropic::Messages::CountTokensRequest.new(
        model: Anthropic::Model.sonnet,
        messages: messages,
        system: "You are helpful.",
      )

      response = client.messages.count_tokens(request)
      response.input_tokens.should eq(20)
    end

    it "raises AuthenticationError on 401" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
        .to_return(
          status: 401,
          body: TestHelpers.error_json("authentication_error", "Invalid API key"),
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      messages = [Anthropic::Message.user("Hello")]

      expect_raises(Anthropic::AuthenticationError) do
        client.messages.count_tokens(
          model: Anthropic::Model.sonnet,
          messages: messages,
        )
      end
    end

    it "raises InvalidRequestError on 400" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/count_tokens")
        .to_return(
          status: 400,
          body: TestHelpers.error_json("invalid_request_error", "Invalid request"),
          headers: {"Content-Type" => "application/json"},
        )

      client = TestHelpers.test_client
      messages = [Anthropic::Message.user("Hello")]

      expect_raises(Anthropic::InvalidRequestError) do
        client.messages.count_tokens(
          model: Anthropic::Model.sonnet,
          messages: messages,
        )
      end
    end
  end
end
