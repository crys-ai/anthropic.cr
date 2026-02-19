require "../spec_helper"

describe Anthropic::ToolRunner do
  describe ".run" do
    it "returns response immediately when stop_reason is not tool_use" do
      # First response ends with end_turn
      TestHelpers.stub_messages(text: "Hello!", stop_reason: "end_turn")

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello")],
        max_tokens: 100
      )

      executed_tools = [] of String
      response = Anthropic::ToolRunner.run(client, request) do |tool_block|
        executed_tools << tool_block.name
        JSON.parse(%({"result": "ok"}))
      end

      response.text.should eq("Hello!")
      executed_tools.should be_empty
    end

    it "executes tools and continues conversation" do
      # First response: tool_use
      tool_response = <<-JSON
        {
          "id": "msg_tool_1",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "tool_use", "id": "toolu_1", "name": "get_weather", "input": {"city": "SF"}}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      # Second response: final answer
      final_response = <<-JSON
        {
          "id": "msg_final",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "The weather in SF is sunny."}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 30, "output_tokens": 15}
        }
        JSON

      request_count = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return do |_request|
          request_count += 1
          if request_count == 1
            HTTP::Client::Response.new(200, tool_response, headers: HTTP::Headers{"Content-Type" => "application/json"})
          else
            HTTP::Client::Response.new(200, final_response, headers: HTTP::Headers{"Content-Type" => "application/json"})
          end
        end

      client = TestHelpers.test_client
      schema = JSON.parse(%({"type": "object", "properties": {"city": {"type": "string"}}}))
      tool = Anthropic::ToolDefinition.new(name: "get_weather", input_schema: schema)

      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("What's the weather in SF?")],
        max_tokens: 100,
        tools: [tool]
      )

      executed_tools = [] of {String, JSON::Any}
      response = Anthropic::ToolRunner.run(client, request) do |tool_block|
        executed_tools << {tool_block.name, tool_block.input}
        JSON.parse(%({"temperature": 72, "condition": "sunny"}))
      end

      # Should have executed one tool
      executed_tools.size.should eq(1)

      if tool_info = executed_tools.first?
        tool_info[0].should eq("get_weather")
        tool_info[1]["city"].as_s.should eq("SF")
      end

      # Should return final response
      response.text.should eq("The weather in SF is sunny.")
      response.stop_reason.should eq(Anthropic::Messages::Response::StopReason::EndTurn)
    end

    it "handles multiple tools in single response" do
      # First response: two tool_uses
      tool_response = <<-JSON
        {
          "id": "msg_tool_1",
          "type": "message",
          "role": "assistant",
          "content": [
            {"type": "tool_use", "id": "toolu_1", "name": "get_weather", "input": {"city": "SF"}},
            {"type": "tool_use", "id": "toolu_2", "name": "get_weather", "input": {"city": "NYC"}}
          ],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      # Second response: final answer
      final_response = <<-JSON
        {
          "id": "msg_final",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "SF is sunny, NYC is rainy."}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 50, "output_tokens": 20}
        }
        JSON

      request_count = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return do |_request|
          request_count += 1
          if request_count == 1
            HTTP::Client::Response.new(200, tool_response, headers: HTTP::Headers{"Content-Type" => "application/json"})
          else
            HTTP::Client::Response.new(200, final_response, headers: HTTP::Headers{"Content-Type" => "application/json"})
          end
        end

      client = TestHelpers.test_client
      tool = Anthropic::ToolDefinition.new(
        name: "get_weather",
        input_schema: JSON.parse(%({"type": "object"}))
      )

      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Compare weather")],
        max_tokens: 100,
        tools: [tool]
      )

      executed_ids = [] of String
      response = Anthropic::ToolRunner.run(client, request) do |tool_block|
        executed_ids << tool_block.id
        JSON.parse(%({"temp": 70}))
      end

      executed_ids.size.should eq(2)
      executed_ids.should contain("toolu_1")
      executed_ids.should contain("toolu_2")
      response.text.should eq("SF is sunny, NYC is rainy.")
    end

    it "respects max_iterations limit" do
      # Response that always wants tool_use
      tool_response = <<-JSON
        {
          "id": "msg_tool",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "tool_use", "id": "toolu_loop", "name": "loop_tool", "input": {}}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 20}
        }
        JSON

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: tool_response, headers: HTTP::Headers{"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      tool = Anthropic::ToolDefinition.new(
        name: "loop_tool",
        input_schema: JSON.parse(%({"type": "object"}))
      )

      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Loop test")],
        max_tokens: 100,
        tools: [tool]
      )

      execution_count = 0
      Anthropic::ToolRunner.run(client, request, max_iterations: 3) do |_tool|
        execution_count += 1
        JSON.parse(%({"continue": true}))
      end

      # Should stop after 3 iterations (max_iterations reached)
      execution_count.should eq(3)
    end

    it "supports string result from executor" do
      tool_response = <<-JSON
        {
          "id": "msg_tool_1",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      final_response = <<-JSON
        {
          "id": "msg_final",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Echoed!"}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 15, "output_tokens": 5}
        }
        JSON

      request_count = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return do
          request_count += 1
          body = request_count == 1 ? tool_response : final_response
          HTTP::Client::Response.new(200, body, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Echo")],
        max_tokens: 100,
        tools: [Anthropic::ToolDefinition.new(name: "echo", input_schema: JSON.parse(%({"type": "object"})))]
      )

      response = Anthropic::ToolRunner.run(client, request) do |_tool|
        "plain string result"
      end

      response.text.should eq("Echoed!")
    end

    it "preserves request parameters in subsequent calls" do
      tool_response = <<-JSON
        {
          "id": "msg_tool_1",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "tool_use", "id": "toolu_1", "name": "test", "input": {}}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      final_response = <<-JSON
        {
          "id": "msg_final",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Done"}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 15, "output_tokens": 5}
        }
        JSON

      received_bodies = [] of String
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return do |request|
          body_str = request.body.to_s
          received_bodies << body_str
          response_body = received_bodies.size == 1 ? tool_response : final_response
          HTTP::Client::Response.new(200, response_body, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end

      client = TestHelpers.test_client
      tool = Anthropic::ToolDefinition.new(
        name: "test",
        input_schema: JSON.parse(%({"type": "object"}))
      )

      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 500,
        temperature: 0.5,
        tools: [tool],
        system: "You are helpful."
      )

      Anthropic::ToolRunner.run(client, request) do |_tool|
        JSON.parse(%({"ok": true}))
      end

      # Check second request preserves parameters
      second_body = received_bodies[1]
      second_body.should contain("\"max_tokens\":500")
      second_body.should contain("\"temperature\":0.5")
      second_body.should contain("\"system\":\"You are helpful.\"")
    end

    it "forwards request_options to messages API" do
      # Stub that requires the custom header to be present
      tool_response = <<-JSON
        {
          "id": "msg_tool_1",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "tool_use", "id": "toolu_1", "name": "test", "input": {}}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      final_response = <<-JSON
        {
          "id": "msg_final",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Done"}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 15, "output_tokens": 5}
        }
        JSON

      request_count = 0
      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: {"X-Test-Header" => "test-value"})
        .to_return do
          request_count += 1
          body = request_count == 1 ? tool_response : final_response
          HTTP::Client::Response.new(200, body, headers: HTTP::Headers{"Content-Type" => "application/json"})
        end

      client = TestHelpers.test_client
      tool = Anthropic::ToolDefinition.new(
        name: "test",
        input_schema: JSON.parse(%({"type": "object"}))
      )

      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        tools: [tool]
      )

      options = Anthropic::RequestOptions.new(
        extra_headers: HTTP::Headers{"X-Test-Header" => "test-value"}
      )

      response = Anthropic::ToolRunner.run(client, request, request_options: options) do |_tool|
        JSON.parse(%({"ok": true}))
      end

      # Should have made 2 requests (tool_use + final)
      request_count.should eq(2)
      response.text.should eq("Done")
    end

    it "raises ToolUseError when stop_reason is tool_use but content has only text" do
      # Response with stop_reason=tool_use but no actual tool_use blocks
      malformed_response = <<-JSON
        {
          "id": "msg_empty",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "I need to use a tool."}],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: malformed_response, headers: HTTP::Headers{"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      tool = Anthropic::ToolDefinition.new(
        name: "test",
        input_schema: JSON.parse(%({"type": "object"}))
      )

      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        tools: [tool]
      )

      error = expect_raises(Anthropic::ToolUseError) do
        Anthropic::ToolRunner.run(client, request) do |_tool|
          JSON.parse(%({"ok": true}))
        end
      end

      if msg = error.message
        msg.should contain("stop_reason=tool_use")
        msg.should contain("no tool_use content blocks")
      end
    end

    it "raises ToolUseError when stop_reason is tool_use but content is empty" do
      # Response with stop_reason=tool_use but empty content array
      empty_response = <<-JSON
        {
          "id": "msg_empty",
          "type": "message",
          "role": "assistant",
          "content": [],
          "model": "claude-sonnet-4-5-20250929",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 0}
        }
        JSON

      WebMock.stub(:post, "https://api.anthropic.com/v1/messages")
        .to_return(body: empty_response, headers: HTTP::Headers{"Content-Type" => "application/json"})

      client = TestHelpers.test_client
      tool = Anthropic::ToolDefinition.new(
        name: "test",
        input_schema: JSON.parse(%({"type": "object"}))
      )

      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100,
        tools: [tool]
      )

      error = expect_raises(Anthropic::ToolUseError) do
        Anthropic::ToolRunner.run(client, request) do |_tool|
          JSON.parse(%({"ok": true}))
        end
      end

      if msg = error.message
        msg.should contain("stop_reason=tool_use")
        msg.should contain("no tool_use content blocks")
      end
    end

    it "raises ArgumentError for negative max_iterations" do
      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100
      )

      expect_raises(ArgumentError, /max_iterations must be non-negative/) do
        Anthropic::ToolRunner.run(client, request, max_iterations: -1) do |_tool|
          JSON.parse(%({"ok": true}))
        end
      end
    end

    it "allows zero max_iterations (returns first response without tool execution)" do
      TestHelpers.stub_messages(text: "Immediate return", stop_reason: "end_turn")

      client = TestHelpers.test_client
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Test")],
        max_tokens: 100
      )

      executed = false
      response = Anthropic::ToolRunner.run(client, request, max_iterations: 0) do |_tool|
        executed = true
        JSON.parse(%({"ok": true}))
      end

      executed.should be_false
      response.text.should eq("Immediate return")
    end
  end
end
