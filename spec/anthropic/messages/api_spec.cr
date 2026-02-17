require "../../spec_helper"

describe Anthropic::Messages::API do
  describe "ENDPOINT" do
    it "is /v1/messages" do
      Anthropic::Messages::API::ENDPOINT.should eq("/v1/messages")
    end
  end

  describe "#create with Request" do
    it "sends POST to /v1/messages and returns Response" do
      TestHelpers.stub_messages(text: "The answer is 42.")

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("What is 6*7?")],
        max_tokens: 100,
      )

      response = client.messages.create(request)
      response.should be_a(Anthropic::Messages::Response)
      response.text.should eq("The answer is 42.")
    end

    it "parses response id and model" do
      TestHelpers.stub_messages(id: "msg_abc", model: "claude-opus-4-5-20251101")

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.opus,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      response.id.should eq("msg_abc")
      response.model.should eq("claude-opus-4-5-20251101")
    end

    it "parses usage statistics" do
      TestHelpers.stub_messages(input_tokens: 50, output_tokens: 100)

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Write a poem")],
        max_tokens: 200,
      )

      response.usage.input_tokens.should eq(50)
      response.usage.output_tokens.should eq(100)
    end

    it "parses stop_reason" do
      TestHelpers.stub_messages(stop_reason: "max_tokens")

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Write a long story")],
        max_tokens: 10,
      )

      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::MaxTokens)
    end
  end

  describe "#create with params" do
    it "sends model and messages" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["model"].as_s.should eq("claude-sonnet-4-6")
          parsed["messages"].as_a.size.should eq(1)
          parsed["max_tokens"].as_i.should eq(256)

          HTTP::Client::Response.new(200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 256,
      )
    end

    it "sends optional system prompt" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["system"].as_s.should eq("You are a poet.")

          HTTP::Client::Response.new(200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Write a haiku")],
        max_tokens: 100,
        system: "You are a poet.",
      )
    end

    it "sends optional temperature" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["temperature"].as_f.should eq(0.7)

          HTTP::Client::Response.new(200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Be creative")],
        max_tokens: 100,
        temperature: 0.7,
      )
    end
  end

  describe "#create with custom model string" do
    it "accepts a custom model string" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["model"].as_s.should eq("claude-custom-2026")

          HTTP::Client::Response.new(200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      client.messages.create(
        model: "claude-custom-2026",
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )
    end
  end

  describe "multi-turn conversation" do
    it "sends multiple messages in conversation" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          messages = parsed["messages"].as_a
          messages.size.should eq(3)
          messages[0]["role"].as_s.should eq("user")
          messages[1]["role"].as_s.should eq("assistant")
          messages[2]["role"].as_s.should eq("user")

          HTTP::Client::Response.new(200,
            body: TestHelpers.response_json(text: "6"),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [
          Anthropic::Message.user("What is 2+2?"),
          Anthropic::Message.assistant("4"),
          Anthropic::Message.user("And 3+3?"),
        ],
        max_tokens: 100,
      )

      response.text.should eq("6")
    end
  end

  describe "multimodal content" do
    it "sends image content blocks" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          content = parsed["messages"][0]["content"].as_a
          content.size.should eq(2)
          content[0]["type"].as_s.should eq("text")
          content[1]["type"].as_s.should eq("image")

          HTTP::Client::Response.new(200,
            body: TestHelpers.response_json(text: "I see a cat."),
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )
        end

      client = TestHelpers.test_client
      blocks = [
        Anthropic::Content.text("What is in this image?"),
        Anthropic::Content.image("image/png", "base64data"),
      ] of Anthropic::ContentBlock

      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user(blocks)],
        max_tokens: 100,
      )

      response.text.should eq("I see a cat.")
    end
  end
end
