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

  describe "#create request_id" do
    it "surfaces request-id header on successful response" do
      WebMock.stub(:post, TestHelpers::API_URL).to_return(
        status: 200,
        body: TestHelpers.response_json,
        headers: HTTP::Headers{
          "Content-Type" => "application/json",
          "request-id"   => "req_success_123",
        },
      )

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      response.request_id.should eq("req_success_123")
    end

    it "surfaces x-request-id header variant on successful response" do
      WebMock.stub(:post, TestHelpers::API_URL).to_return(
        status: 200,
        body: TestHelpers.response_json,
        headers: HTTP::Headers{
          "Content-Type" => "application/json",
          "x-request-id" => "req_x_success_456",
        },
      )

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      response.request_id.should eq("req_x_success_456")
    end

    it "returns nil request_id when no header present" do
      TestHelpers.stub_messages

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      response.request_id.should be_nil
    end

    it "preserves request_id on error responses via exception" do
      WebMock.stub(:post, TestHelpers::API_URL).to_return(
        status: 429,
        body: TestHelpers.error_json("rate_limit_error", "Rate limited"),
        headers: HTTP::Headers{
          "Content-Type" => "application/json",
          "request-id"   => "req_err_429",
        },
      )

      client = TestHelpers.test_client
      begin
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
        fail "Expected RateLimitError to be raised"
      rescue ex : Anthropic::RateLimitError
        ex.request_id.should eq("req_err_429")
      end
    end

    it "preserves request_id on 5xx error responses" do
      WebMock.stub(:post, TestHelpers::API_URL).to_return(
        status: 529,
        body: TestHelpers.error_json("overloaded_error", "Overloaded"),
        headers: HTTP::Headers{
          "Content-Type" => "application/json",
          "request-id"   => "req_err_529",
        },
      )

      client = TestHelpers.test_client
      begin
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
        fail "Expected OverloadedError to be raised"
      rescue ex : Anthropic::OverloadedError
        ex.request_id.should eq("req_err_529")
      end
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

  describe "#stream with Request" do
    it "yields StreamEvent objects for each SSE event" do
      TestHelpers.stub_stream(["Hello", " world"])

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Say hello")],
        max_tokens: 100,
      )

      events = [] of Anthropic::StreamEvent
      client.messages.stream(request) do |event|
        events << event
      end

      events.should_not be_empty
      events.first.should be_a(Anthropic::StreamEvent::MessageStart)
      events.last.should be_a(Anthropic::StreamEvent::MessageStop)

      # Find all text deltas
      text_deltas = events.compact_map do |e|
        if delta = e.as?(Anthropic::StreamEvent::ContentBlockDelta)
          delta.delta.text
        end
      end

      text_deltas.should eq(["Hello", " world"])
    end

    it "sets stream flag on request" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["stream"].as_bool.should be_true

          sse = TestHelpers.stream_sse(["OK"])
          HTTP::Client::Response.new(200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
            body_io: IO::Memory.new(sse),
          )
        end

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      client.messages.stream(request) { |_| }
    end

    it "does not mutate the caller's request object" do
      WebMock.stub(:post, TestHelpers::API_URL).to_return(
        body_io: IO::Memory.new(TestHelpers.stream_sse),
        status: 200,
        headers: {"Content-Type" => "text/event-stream"},
      )

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      # Verify stream is nil before
      request.stream.should be_nil

      client.messages.stream(request) { |_| }

      # Verify stream is still nil after (not mutated)
      request.stream.should be_nil
    end

    it "handles empty stream" do
      TestHelpers.stub_stream([] of String)

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      events = [] of Anthropic::StreamEvent
      client.messages.stream(request) { |e| events << e }

      # Should still have start/stop events
      events.any?(Anthropic::StreamEvent::MessageStart).should be_true
      events.any?(Anthropic::StreamEvent::MessageStop).should be_true
    end
  end

  describe "#stream with params" do
    it "accepts Model enum and streams response" do
      TestHelpers.stub_stream(["Test", " output"])

      client = TestHelpers.test_client
      events = [] of Anthropic::StreamEvent

      client.messages.stream(
        model: Anthropic::Model.opus,
        messages: [Anthropic::Message.user("Stream test")],
        max_tokens: 100,
      ) do |event|
        events << event
      end

      events.should_not be_empty
    end

    it "accepts String model and streams response" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["model"].as_s.should eq("claude-custom-2026")

          sse = TestHelpers.stream_sse(["Custom"])
          HTTP::Client::Response.new(200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
            body_io: IO::Memory.new(sse),
          )
        end

      client = TestHelpers.test_client
      events = [] of Anthropic::StreamEvent

      client.messages.stream(
        model: "claude-custom-2026",
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      ) do |event|
        events << event
      end

      events.should_not be_empty
    end

    it "passes optional parameters in stream request" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body.try(&.gets_to_end) || ""
          parsed = JSON.parse(body)
          parsed["system"].as_s.should eq("Be concise")
          parsed["temperature"].as_f.should eq(0.5)

          sse = TestHelpers.stream_sse(["Short"])
          HTTP::Client::Response.new(200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
            body_io: IO::Memory.new(sse),
          )
        end

      client = TestHelpers.test_client
      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
        system: "Be concise",
        temperature: 0.5,
      ) { |_| }
    end
  end

  describe "streaming errors" do
    it "raises APIError on error response during stream" do
      TestHelpers.stub_stream_error(529, "overloaded_error", "Server overloaded")

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      expect_raises(Anthropic::OverloadedError, "Server overloaded") do
        client.messages.stream(request) { |_| }
      end
    end

    it "raises APIError on 401 during stream" do
      TestHelpers.stub_stream_error(401, "authentication_error", "Invalid API key")

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      )

      expect_raises(Anthropic::AuthenticationError, "Invalid API key") do
        client.messages.stream(request) { |_| }
      end
    end
  end

  describe "streaming keepalive/comment frames" do
    it "skips comment-only SSE frames without crashing" do
      TestHelpers.stub_stream_with_keepalives(["Hello", " world"])

      client = TestHelpers.test_client
      events = [] of Anthropic::StreamEvent

      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      ) do |event|
        events << event
      end

      events.should_not be_empty
      events.first.should be_a(Anthropic::StreamEvent::MessageStart)
      events.last.should be_a(Anthropic::StreamEvent::MessageStop)

      # Verify text deltas are still collected correctly
      text_deltas = events.compact_map do |e|
        if delta = e.as?(Anthropic::StreamEvent::ContentBlockDelta)
          delta.delta.text
        end
      end

      text_deltas.should eq(["Hello", " world"])
    end

    it "handles a stream that is only comment frames" do
      sse = String.build do |io|
        io << ":keepalive\n"
        io << "\n"
        io << ":keepalive\n"
        io << "\n"
      end

      WebMock.stub(:post, TestHelpers::API_URL).to_return(
        body_io: IO::Memory.new(sse),
        status: 200,
        headers: {"Content-Type" => "text/event-stream"},
      )

      client = TestHelpers.test_client
      events = [] of Anthropic::StreamEvent

      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      ) do |event|
        events << event
      end

      events.should be_empty
    end
  end

  describe "streaming event types" do
    it "parses all standard event types" do
      TestHelpers.stub_stream(["A", "B"])

      client = TestHelpers.test_client
      event_types = [] of String

      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      ) do |event|
        event_types << event.type
      end

      event_types.should contain("message_start")
      event_types.should contain("content_block_start")
      event_types.should contain("content_block_delta")
      event_types.should contain("content_block_stop")
      event_types.should contain("message_delta")
      event_types.should contain("message_stop")
    end

    it "handles unknown event types with UnknownStreamEvent" do
      sse = <<-SSE
        event: message_start
        data: {"type":"message_start","message":{"id":"msg-123","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5-20250929","stop_reason":null,"usage":{"input_tokens":10,"output_tokens":0}}}

        event: future_event
        data: {"type":"future_event","some_field":"value"}

        event: message_stop
        data: {"type":"message_stop"}

        SSE

      WebMock.stub(:post, TestHelpers::API_URL).to_return(
        body_io: IO::Memory.new(sse),
        status: 200,
        headers: {"Content-Type" => "text/event-stream"},
      )

      client = TestHelpers.test_client
      unknown_events = [] of Anthropic::UnknownStreamEvent

      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      ) do |event|
        unknown_events << event if event.is_a?(Anthropic::UnknownStreamEvent)
      end

      unknown_events.size.should eq(1)
      unknown_events.first.type.should eq("future_event")
    end
  end

  describe "streaming content accumulation" do
    it "accumulates text deltas across events" do
      TestHelpers.stub_stream(["Four", " score", " and", " seven", " years"])

      client = TestHelpers.test_client
      text_parts = [] of String

      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Say the phrase")],
        max_tokens: 100,
      ) do |event|
        if event.is_a?(Anthropic::StreamEvent::ContentBlockDelta)
          if text = event.delta.text
            text_parts << text
          end
        end
      end

      text_parts.should eq(["Four", " score", " and", " seven", " years"])
      text_parts.join.should eq("Four score and seven years")
    end
  end

  describe "streaming usage" do
    it "reports usage in message_delta event" do
      TestHelpers.stub_stream(["Usage"])

      client = TestHelpers.test_client
      usage = [] of Anthropic::Usage

      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hi")],
        max_tokens: 100,
      ) do |event|
        if event.is_a?(Anthropic::StreamEvent::MessageDelta)
          if u = event.usage
            usage << u
          end
        end
      end

      usage.should_not be_empty
      usage.first.input_tokens.should eq(10)
      usage.first.output_tokens.should be > 0
    end
  end

  describe "request_options forwarding" do
    describe "#create" do
      it "forwards request_options to client" do
        WebMock.stub(:post, TestHelpers::API_URL)
          .with(headers: {"X-Custom-Header" => "custom-value"})
          .to_return(
            status: 200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
        options = Anthropic::RequestOptions.new(
          extra_headers: HTTP::Headers{"X-Custom-Header" => "custom-value"}
        )

        response = client.messages.create(request, options)
        response.should be_a(Anthropic::Messages::Response)
      end

      it "forwards beta headers via request_options" do
        WebMock.stub(:post, TestHelpers::API_URL)
          .with(headers: {"anthropic-beta" => "test-beta-feature"})
          .to_return(
            status: 200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
        options = Anthropic::RequestOptions.new(beta_headers: ["test-beta-feature"])

        client.messages.create(request, options)
      end

      it "forwards request_options with convenience overload" do
        WebMock.stub(:post, TestHelpers::API_URL)
          .with(headers: {"X-Test" => "value"})
          .to_return(
            status: 200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        options = Anthropic::RequestOptions.new(
          extra_headers: HTTP::Headers{"X-Test" => "value"}
        )

        response = client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
          request_options: options
        )
        response.should be_a(Anthropic::Messages::Response)
      end
    end

    describe "#count_tokens" do
      it "forwards request_options to client" do
        WebMock.stub(:post, "#{TestHelpers::API_URL}/count_tokens")
          .with(headers: {"X-Custom-Header" => "token-header"})
          .to_return(
            status: 200,
            body: {input_tokens: 42}.to_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        request = Anthropic::Messages::CountTokensRequest.new(
          Anthropic::Model.sonnet,
          [Anthropic::Message.user("Hello")]
        )
        options = Anthropic::RequestOptions.new(
          extra_headers: HTTP::Headers{"X-Custom-Header" => "token-header"}
        )

        response = client.messages.count_tokens(request, options)
        response.input_tokens.should eq(42)
      end

      it "forwards request_options with convenience method" do
        WebMock.stub(:post, "#{TestHelpers::API_URL}/count_tokens")
          .to_return(
            status: 200,
            body: {input_tokens: 10}.to_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"},
          )

        client = TestHelpers.test_client
        options = Anthropic::RequestOptions.new(timeout: 30.seconds)

        response = client.messages.count_tokens(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Test")],
          request_options: options
        )
        response.input_tokens.should eq(10)
      end
    end

    describe "#stream" do
      it "forwards request_options to client" do
        WebMock.stub(:post, TestHelpers::API_URL)
          .with(headers: {"X-Stream-Header" => "stream-value"})
          .to_return(
            body_io: IO::Memory.new(TestHelpers.stream_sse(["OK"])),
            status: 200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
          )

        client = TestHelpers.test_client
        request = Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
        )
        options = Anthropic::RequestOptions.new(
          extra_headers: HTTP::Headers{"X-Stream-Header" => "stream-value"}
        )

        events = [] of Anthropic::StreamEvent
        client.messages.stream(request, options) { |e| events << e }
        events.should_not be_empty
      end

      it "forwards request_options with convenience overload" do
        WebMock.stub(:post, TestHelpers::API_URL)
          .with(headers: {"X-Test" => "value"})
          .to_return(
            body_io: IO::Memory.new(TestHelpers.stream_sse(["OK"])),
            status: 200,
            headers: HTTP::Headers{"Content-Type" => "text/event-stream"},
          )

        client = TestHelpers.test_client
        options = Anthropic::RequestOptions.new(
          extra_headers: HTTP::Headers{"X-Test" => "value"}
        )

        events = [] of Anthropic::StreamEvent
        client.messages.stream(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hi")],
          max_tokens: 100,
          request_options: options,
        ) { |e| events << e }
        events.should_not be_empty
      end
    end
  end
end
