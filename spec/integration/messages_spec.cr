require "../spec_helper"

# End-to-end style tests that simulate real API interactions using WebMock.
# These tests verify the full request/response cycle without hitting the actual API.

describe "Integration: Messages API" do
  it "sends a message and gets a complete response" do
    TestHelpers.stub_messages(
      text: "Hello! How can I help you today?",
      id: "msg_01XFDUDYJgAACzvnptvVoYEL",
      model: "claude-sonnet-4-5-20250929",
      stop_reason: "end_turn",
      input_tokens: 15,
      output_tokens: 25
    )

    client = TestHelpers.test_client
    response = client.messages.create(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Hello!")],
      max_tokens: 100,
    )

    response.id.should eq("msg_01XFDUDYJgAACzvnptvVoYEL")
    response.role.should eq("assistant")
    response.text.should contain("Hello")
    response.model.should eq("claude-sonnet-4-5-20250929")
    response.stop_reason.to_s.should eq("EndTurn")
    response.usage.input_tokens.should eq(15)
    response.usage.output_tokens.should eq(25)
    response.usage.total_tokens.should eq(40)
  end

  it "handles multi-turn conversation with conversation history" do
    TestHelpers.stub_messages(
      text: "The capital of France is Paris, and its population is approximately 2.1 million people.",
      id: "msg_02XFDUDYJgAACzvnptvVoYEL",
      model: "claude-haiku-4-5-20251001",
      stop_reason: "end_turn",
      input_tokens: 45,
      output_tokens: 30
    )

    client = TestHelpers.test_client
    messages = [
      Anthropic::Message.user("What is the capital of France?"),
      Anthropic::Message.assistant("The capital of France is Paris."),
      Anthropic::Message.user("What's its population?"),
    ]

    response = client.messages.create(
      model: Anthropic::Model.haiku,
      messages: messages,
      max_tokens: 100,
    )

    response.text.should_not be_empty
    response.text.downcase.should contain("paris")
    response.usage.input_tokens.should eq(45)
  end

  it "sends a message with a system prompt" do
    TestHelpers.stub_messages(
      text: "Ahoy, matey! How can I be helpin' ye today?",
      id: "msg_03XFDUDYJgAACzvnptvVoYEL",
      model: "claude-haiku-4-5-20251001",
      stop_reason: "end_turn",
      input_tokens: 20,
      output_tokens: 35
    )

    client = TestHelpers.test_client
    response = client.messages.create(
      model: Anthropic::Model.haiku,
      messages: [Anthropic::Message.user("Hello!")],
      max_tokens: 100,
      system: "You are a helpful assistant who speaks like a pirate.",
    )

    response.text.should_not be_empty
    # Pirate speak could be either ahoy or matey
    text_lower = response.text.downcase
    (text_lower.includes?("ahoy") || text_lower.includes?("matey")).should be_true
  end

  it "handles invalid model error with proper exception" do
    TestHelpers.stub_error(
      status: 400,
      type: "invalid_request_error",
      message: "invalid model: invalid-model-name"
    )

    client = TestHelpers.test_client
    expect_raises(Anthropic::InvalidRequestError, /invalid model/) do
      client.messages.create(
        model: "invalid-model-name",
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 10,
      )
    end
  end

  it "handles rate limit error" do
    TestHelpers.stub_error(
      status: 429,
      type: "rate_limit_error",
      message: "Rate limit exceeded"
    )

    client = TestHelpers.test_client
    expect_raises(Anthropic::RateLimitError, /Rate limit/) do
      client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 10,
      )
    end
  end

  it "handles authentication error" do
    TestHelpers.stub_error(
      status: 401,
      type: "authentication_error",
      message: "Invalid API key"
    )

    client = TestHelpers.test_client
    expect_raises(Anthropic::AuthenticationError, /Invalid API key/) do
      client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 10,
      )
    end
  end

  it "handles API overload error" do
    TestHelpers.stub_error(
      status: 529,
      type: "overloaded_error",
      message: "API overloaded"
    )

    client = TestHelpers.test_client
    expect_raises(Anthropic::OverloadedError, /overloaded/) do
      client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 10,
      )
    end
  end

  it "streams a message response with proper event handling" do
    TestHelpers.stub_stream(text_chunks: ["Hello", " there", "!"])

    client = TestHelpers.test_client
    events = [] of Anthropic::StreamEvent

    client.messages.stream(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Say hello")],
      max_tokens: 100,
    ) do |event|
      events << event
    end

    events.should_not be_empty
    events.any?(Anthropic::StreamEvent::MessageStart).should be_true
    events.any?(Anthropic::StreamEvent::ContentBlockStart).should be_true
    events.any?(Anthropic::StreamEvent::ContentBlockDelta).should be_true
    events.any?(Anthropic::StreamEvent::MessageStop).should be_true

    # Verify delta text content
    text_parts = events
      .select(Anthropic::StreamEvent::ContentBlockDelta)
      .compact_map(&.delta.text)
    text_parts.join.should eq("Hello there!")
  end

  it "includes streaming message with temperature and top_p parameters" do
    TestHelpers.stub_messages(
      text: "Response with params",
      input_tokens: 12,
      output_tokens: 18
    )

    client = TestHelpers.test_client
    response = client.messages.create(
      model: Anthropic::Model.opus,
      messages: [Anthropic::Message.user("Test")],
      max_tokens: 50,
      temperature: 0.7,
      top_p: 0.9,
    )

    response.text.should eq("Response with params")
  end

  it "handles stop_sequences parameter" do
    TestHelpers.stub_messages(
      text: "Stopped early",
      stop_reason: "stop_sequence",
      input_tokens: 10,
      output_tokens: 15
    )

    client = TestHelpers.test_client
    response = client.messages.create(
      model: Anthropic::Model.sonnet,
      messages: [Anthropic::Message.user("Count to 10")],
      max_tokens: 100,
      stop_sequences: ["\n\n"],
    )

    response.stop_reason.to_s.should eq("StopSequence")
  end
end
