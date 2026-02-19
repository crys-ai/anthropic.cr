# Documentation smoke tests
#
# These tests verify that the API paths documented in README.md compile and work.
# The goal is NOT thorough testing (that's done in individual spec files),
# just compile-time verification that the documented API paths exist and are callable.
# This prevents API drift where README examples become stale.
#
# See: T123 - Add a docs example smoke test to prevent API drift

require "../spec_helper"

describe "Documentation Smoke Tests" do
  describe "Quick Start example" do
    it "client.messages.create with convenience params" do
      TestHelpers.stub_messages(text: "Hello! How can I help?")

      # From README Quick Start:
      # response = client.messages.create(
      #   model: Anthropic::Model.sonnet,
      #   messages: [Anthropic::Message.user("Hello!")],
      #   max_tokens: 1024
      # )
      # puts response.text

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )

      response.should be_a(Anthropic::Messages::Response)
      response.text.should eq("Hello! How can I help?")
    end
  end

  describe "Streaming example" do
    it "client.messages.stream with block" do
      TestHelpers.stub_stream(["Hello", " world"])

      # From README Streaming section:
      # client.messages.stream(
      #   model: Anthropic::Model.sonnet,
      #   messages: [Anthropic::Message.user("Tell me a story")],
      #   max_tokens: 1024,
      # ) do |event|
      #   case event
      #   when Anthropic::StreamEvent::ContentBlockDelta
      #     print event.delta.text if event.delta.text
      #   when Anthropic::StreamEvent::MessageStop
      #     puts # newline at end
      #   end
      # end

      client = TestHelpers.test_client
      text_parts = [] of String

      client.messages.stream(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Tell me a story")],
        max_tokens: 1024
      ) do |event|
        case event
        when Anthropic::StreamEvent::ContentBlockDelta
          if text = event.delta.text
            text_parts << text
          end
        end
      end

      text_parts.should eq(["Hello", " world"])
    end
  end

  describe "Models API examples" do
    it "client.models.list" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-02-24T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "claude-sonnet-4-6",
            last_id:  "claude-sonnet-4-6",
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Models API section:
      # models = client.models.list
      # models.data.each { |m| puts "#{m.id} - #{m.display_name}" }

      client = TestHelpers.test_client
      models = client.models.list

      models.data.size.should eq(1)
      models.data[0].id.should eq("claude-sonnet-4-6")
      models.data[0].display_name.should eq("Claude Sonnet 4.6")
    end

    it "client.models.retrieve(model_id)" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models/claude-sonnet-4-20250514")
        .to_return(
          status: 200,
          body: {id: "claude-sonnet-4-20250514", display_name: "Claude Sonnet 4", created_at: "2025-05-14T00:00:00Z", type: "model"}.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Models API section:
      # model = client.models.retrieve("claude-sonnet-4-20250514")
      # puts model.id
      # puts model.display_name

      client = TestHelpers.test_client
      model = client.models.retrieve("claude-sonnet-4-20250514")

      model.id.should eq("claude-sonnet-4-20250514")
      model.display_name.should eq("Claude Sonnet 4")
    end
  end

  describe "Files API examples" do
    it "client.files.list" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_123", type: "file", filename: "doc.pdf", size_bytes: 1024, created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Files API section:
      # page = client.files.list
      # page.data.each { |f| puts "#{f.filename} (#{f.size_bytes} bytes)" }

      client = TestHelpers.test_client
      page = client.files.list

      page.data.size.should eq(1)
      page.data[0].filename.should eq("doc.pdf")
    end

    it "client.files.retrieve(file_id)" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files/file_01ABC123")
        .to_return(
          status: 200,
          body: {
            id:           "file_01ABC123",
            type:         "file",
            filename:     "document.pdf",
            size_bytes:   2048,
            created_at:   "2025-01-01T00:00:00Z",
            mime_type:    "application/pdf",
            downloadable: true,
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Files API section:
      # file = client.files.retrieve("file_01ABC123")
      # puts file.filename
      # puts file.mime_type
      # puts file.downloadable

      client = TestHelpers.test_client
      file = client.files.retrieve("file_01ABC123")

      file.filename.should eq("document.pdf")
      file.mime_type.should eq("application/pdf")
      file.downloadable.should be_true
    end
  end

  describe "Batches API examples" do
    it "client.batches.create with batch requests" do
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages/batches")
        .to_return(
          status: 200,
          body: {
            id:                "batch_01ABC123",
            type:              "message_batch",
            processing_status: "in_progress",
            request_counts:    {processing: 2, succeeded: 0, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Message Batches API section (uses typed constructor from T127):
      # batch = client.batches.create([
      #   Anthropic::CreateMessageBatchRequest::BatchRequest.new(
      #     custom_id: "req-1",
      #     request: Anthropic::Messages::Request.new(
      #       model: "claude-sonnet-4-20250514",
      #       messages: [Anthropic::Message.user("Hello")],
      #       max_tokens: 1024,
      #     )
      #   ),
      # ])

      client = TestHelpers.test_client
      batch = client.batches.create([
        Anthropic::CreateMessageBatchRequest::BatchRequest.new(
          custom_id: "req-1",
          request: Anthropic::Messages::Request.new(
            model: "claude-sonnet-4-20250514",
            messages: [Anthropic::Message.user("Hello")],
            max_tokens: 1024,
          )
        ),
        Anthropic::CreateMessageBatchRequest::BatchRequest.new(
          custom_id: "req-2",
          request: Anthropic::Messages::Request.new(
            model: "claude-sonnet-4-20250514",
            messages: [Anthropic::Message.user("Hi")],
            max_tokens: 1024,
          )
        ),
      ])

      batch.id.should eq("batch_01ABC123")
      batch.processing_status.should eq("in_progress")
      batch.request_counts.processing.should eq(2)
    end

    it "client.batches.list" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "batch_1", type: "message_batch", processing_status: "succeeded",
               request_counts: {processing: 0, succeeded: 5, errored: 0, canceled: 0, expired: 0},
               created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Message Batches API section:
      # page = client.batches.list
      # page.data.each { |b| puts "#{b.id} - #{b.processing_status}" }

      client = TestHelpers.test_client
      page = client.batches.list

      page.data.size.should eq(1)
      page.data[0].id.should eq("batch_1")
      page.data[0].processing_status.should eq("succeeded")
    end

    it "client.batches.retrieve(batch_id)" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches/batch_01ABC123")
        .to_return(
          status: 200,
          body: {
            id:                "batch_01ABC123",
            type:              "message_batch",
            processing_status: "succeeded",
            request_counts:    {processing: 0, succeeded: 10, errored: 0, canceled: 0, expired: 0},
            created_at:        "2025-01-01T00:00:00Z",
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Message Batches API section:
      # batch = client.batches.retrieve("batch_01ABC123")
      # puts batch.processing_status

      client = TestHelpers.test_client
      batch = client.batches.retrieve("batch_01ABC123")

      batch.id.should eq("batch_01ABC123")
      batch.processing_status.should eq("succeeded")
    end
  end

  describe "Skills API (Beta) example" do
    it "client.beta.skills.list" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "skill_01", type: "skill", display_title: "Test Skill", source: "anthropic",
               latest_version: "123", created_at: "2025-01-15T12:00:00Z", updated_at: "2025-01-15T12:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Skills API section:
      # skills = client.beta.skills.list
      # response.data.each do |skill|
      #   puts "#{skill.display_title} (#{skill.source})"
      # end

      client = TestHelpers.test_client
      response = client.beta.skills.list

      response.data.size.should eq(1)
      response.data[0].display_title.should eq("Test Skill")
    end

    it "client.beta([...header]).skills.list merges beta headers" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:get, "https://api.anthropic.com/v1/skills")
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: %({"data": [], "has_more": false}),
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      # From README Skills API section:
      # client = Anthropic::Client.new
      # skills = client.beta(["skills-2025-10-02", "future-feature-2025-01-01"]).skills.list

      client = TestHelpers.test_client
      client.beta(["skills-2025-10-02", "future-feature-2025-01-01"]).skills.list

      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("skills-2025-10-02")
        beta_header.should contain("future-feature-2025-01-01")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end
  end

  describe "Beta namespace examples" do
    it "client.beta.messages.create with beta headers" do
      captured_headers = HTTP::Headers.new

      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          captured_headers = request.headers
          HTTP::Client::Response.new(
            status_code: 200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      # From README Beta Namespace section:
      # response = client.beta.messages.create(
      #   model: Anthropic::Model.sonnet,
      #   messages: [Anthropic::Message.user("Hello")],
      #   max_tokens: 1024,
      # )

      client = TestHelpers.test_client
      response = client.beta(["test-beta"]).messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 1024
      )

      response.should be_a(Anthropic::Messages::Response)
      if beta_header = captured_headers["anthropic-beta"]?
        beta_header.should contain("test-beta")
      else
        fail "Expected anthropic-beta header to be present"
      end
    end

    it "client.beta.models.list with beta headers" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/models")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "claude-sonnet-4-6", display_name: "Claude Sonnet 4.6", created_at: "2025-02-24T00:00:00Z", type: "model"},
            ],
            has_more: false,
            first_id: "claude-sonnet-4-6",
            last_id:  "claude-sonnet-4-6",
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Beta Namespace section:
      # models = client.beta.models.list

      client = TestHelpers.test_client
      models = client.beta.models.list

      models.data.size.should eq(1)
      models.data[0].id.should eq("claude-sonnet-4-6")
    end

    it "client.beta.files.list with beta headers" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/files")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "file_123", type: "file", filename: "doc.pdf", size_bytes: 1024, created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Beta Namespace section:
      # files = client.beta.files.list

      client = TestHelpers.test_client
      files = client.beta.files.list

      files.data.size.should eq(1)
      files.data[0].filename.should eq("doc.pdf")
    end

    it "client.beta.messages.batches.list with beta headers" do
      WebMock.stub(:get, "https://api.anthropic.com/v1/messages/batches")
        .to_return(
          status: 200,
          body: {
            data: [
              {id: "batch_1", type: "message_batch", processing_status: "succeeded",
               request_counts: {processing: 0, succeeded: 5, errored: 0, canceled: 0, expired: 0},
               created_at: "2025-01-01T00:00:00Z"},
            ],
            has_more: false,
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      # From README Beta Namespace section:
      # batches = client.beta.messages.batches.list

      client = TestHelpers.test_client
      batches = client.beta.messages.batches.list

      batches.data.size.should eq(1)
      batches.data[0].id.should eq("batch_1")
    end

    it "client.beta.merge_options merges beta headers" do
      # From README Beta Namespace section:
      # base_options = Anthropic::RequestOptions.new(timeout: 30.seconds)
      # options = client.beta.merge_options(base_options)

      client = TestHelpers.test_client
      base_options = Anthropic::RequestOptions.new(timeout: 30.seconds)
      merged = client.beta(["custom-beta"]).merge_options(base_options)

      merged.timeout.should eq(30.seconds)
      if headers = merged.beta_headers
        headers.should contain("custom-beta")
      else
        fail "Expected beta_headers to be present"
      end
    end
  end

  describe "ToolRunner example" do
    it "Anthropic::ToolRunner.run with tool handler block" do
      # Stub first response with tool_use
      tool_response = <<-JSON
        {
          "id": "msg_tool",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "tool_use", "id": "toolu_1", "name": "test_tool", "input": {"x": 1}}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      # Stub second response with final answer
      final_response = <<-JSON
        {
          "id": "msg_final",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Tool executed successfully"}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 15, "output_tokens": 5}
        }
        JSON

      request_count = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return do |_request|
          request_count += 1
          body = request_count == 1 ? tool_response : final_response
          HTTP::Client::Response.new(200, body, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end

      # From README ToolRunner usage pattern:
      # Anthropic::ToolRunner.run(client, request) do |tool|
      #   # Handle tool execution
      #   "result"
      # end

      client = TestHelpers.test_client
      tool = Anthropic::ToolDefinition.new(
        name: "test_tool",
        input_schema: JSON.parse(%({"type": "object"}))
      )
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        tools: [tool]
      )

      executed_tools = [] of String
      response = Anthropic::ToolRunner.run(client, request) do |tool_block|
        executed_tools << tool_block.name
        JSON.parse(%({"result": "ok"}))
      end

      executed_tools.should eq(["test_tool"])
      response.text.should eq("Tool executed successfully")
    end
  end

  describe "RequestOptions example" do
    it "Anthropic::RequestOptions.new(timeout: 30.seconds)" do
      # From README Beta Features section:
      # base_options = Anthropic::RequestOptions.new(timeout: 30.seconds)

      options = Anthropic::RequestOptions.new(timeout: 30.seconds)

      options.timeout.should eq(30.seconds)
      options.retry_policy.should be_nil
      options.beta_headers.should be_nil
    end

    it "RequestOptions with extra_headers" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .with(headers: {"X-Custom-Header" => "custom-value"})
        .to_return(
          status: 200,
          body: TestHelpers.response_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"}
        )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(
        timeout: 30.seconds,
        extra_headers: HTTP::Headers{"X-Custom-Header" => "custom-value"}
      )

      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        request_options: options
      )

      response.should be_a(Anthropic::Messages::Response)
    end

    it "RequestOptions with extra_query" do
      # Stub must include the query param in the URL to match.
      # If extra_query wasn't applied, WebMock would reject the request.
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages?debug=true")
        .to_return(
          status: 200,
          body: TestHelpers.response_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"}
        )

      # From README Advanced Request Options section:
      # options = Anthropic::RequestOptions.new(
      #   extra_query: {"debug" => "true"},
      # )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(extra_query: {"debug" => "true"})

      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        request_options: options
      )

      # If we get here, WebMock matched the URL with query params -- extra_query works
      response.should be_a(Anthropic::Messages::Response)
    end

    it "RequestOptions with extra_body" do
      captured_body = ""
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return do |request|
          body = request.body
          captured_body = body.is_a?(String) ? body : body.try(&.gets_to_end) || ""
          HTTP::Client::Response.new(
            status_code: 200,
            body: TestHelpers.response_json,
            headers: HTTP::Headers{"Content-Type" => "application/json"}
          )
        end

      # From README Advanced Request Options section:
      # options = Anthropic::RequestOptions.new(
      #   extra_body: {"custom_field" => JSON::Any.new("value")},
      # )

      client = TestHelpers.test_client
      options = Anthropic::RequestOptions.new(extra_body: {"custom_field" => JSON::Any.new("value")})

      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        request_options: options
      )

      response.should be_a(Anthropic::Messages::Response)
      captured_body.should contain("custom_field")
    end
  end

  describe "ToolDefinition example" do
    it "Anthropic::ToolDefinition.new with JSON.parse schema" do
      # From README and spec patterns:
      # schema = JSON.parse(%({"type": "object", "properties": {"query": {"type": "string"}}}))
      # tool = Anthropic::ToolDefinition.new(name: "search", input_schema: schema)

      schema = JSON.parse(%({"type": "object", "properties": {"query": {"type": "string"}}}))
      tool = Anthropic::ToolDefinition.new(name: "search", input_schema: schema)

      tool.name.should eq("search")
      tool.input_schema.should be_a(JSON::Any)
    end

    it "ToolDefinition works in messages.create request" do
      TestHelpers.stub_messages(text: "Result")

      schema = JSON.parse(%({"type": "object"}))
      tool = Anthropic::ToolDefinition.new(name: "test", input_schema: schema)

      client = TestHelpers.test_client
      response = client.messages.create(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        tools: [tool]
      )

      response.text.should eq("Result")
    end
  end

  describe "Model enum examples" do
    it "Model aliases" do
      # From README Models section:
      # Anthropic::Model.opus      # Claude Opus 4.6 (latest)
      # Anthropic::Model.sonnet    # Claude Sonnet 4.6 (latest)
      # Anthropic::Model.haiku     # Claude Haiku 4.5 (latest)

      Anthropic::Model.opus.to_api_string.should contain("opus")
      Anthropic::Model.sonnet.to_api_string.should contain("sonnet")
      Anthropic::Model.haiku.to_api_string.should contain("haiku")
    end

    it "Model enum values" do
      # From README Models section:
      # Anthropic::Model::ClaudeOpus4_6
      # Anthropic::Model::ClaudeSonnet4_6

      Anthropic::Model::ClaudeOpus4_6.to_api_string.should eq("claude-opus-4-6")
      Anthropic::Model::ClaudeSonnet4_6.to_api_string.should eq("claude-sonnet-4-6")
    end
  end

  describe "Error handling examples" do
    it "rescues Anthropic::APIError hierarchy" do
      WebMock.stub(:post, TestHelpers::API_URL)
        .to_return(
          status: 401,
          body: TestHelpers.error_json("authentication_error", "Invalid API key"),
          headers: {"Content-Type" => "application/json"}
        )

      # From README Error Handling section:
      # begin
      #   response = client.messages.create(...)
      # rescue ex : Anthropic::AuthenticationError
      #   puts "Invalid API key"
      # rescue ex : Anthropic::RateLimitError
      #   puts "Rate limited, retry later"
      # rescue ex : Anthropic::APIError
      #   puts "API error: #{ex.status_code} - #{ex.error_message}"
      # end

      client = TestHelpers.test_client

      expect_raises(Anthropic::AuthenticationError) do
        client.messages.create(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Test")],
          max_tokens: 100
        )
      end
    end
  end
end
