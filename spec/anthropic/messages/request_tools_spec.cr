require "../../spec_helper"

private def sample_tool(name : String = "search", description : String? = "Search the web") : Anthropic::ToolDefinition
  schema = JSON.parse(%({"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}))
  Anthropic::ToolDefinition.new(name: name, input_schema: schema, description: description)
end

describe Anthropic::Messages::Request do
  describe "tools param" do
    it "defaults to nil when not provided" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.tools.should be_nil
    end

    it "accepts an array of ToolDefinition" do
      tools = [sample_tool]
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: tools
      )
      request_tools = request.tools
      request_tools.should_not be_nil
      request_tools.should be_a(Array(Anthropic::ToolDefinition))
      tools_array = request_tools.as(Array(Anthropic::ToolDefinition))
      tools_array.size.should eq(1)
      tools_array[0].name.should eq("search")
    end

    it "accepts multiple tools" do
      tools = [sample_tool("search"), sample_tool("calculator", "Do math")]
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: tools
      )
      request_tools = request.tools
      request_tools.should_not be_nil
      request_tools.as(Array(Anthropic::ToolDefinition)).size.should eq(2)
    end
  end

  describe "tool_choice param" do
    it "defaults to nil when not provided" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.tool_choice.should be_nil
    end

    it "accepts ToolChoice.auto" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.auto
      )
      choice = request.tool_choice
      choice.should_not be_nil
      choice.as(Anthropic::ToolChoice).type.should eq("auto")
    end

    it "accepts ToolChoice.any" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.any
      )
      choice = request.tool_choice
      choice.should_not be_nil
      choice.as(Anthropic::ToolChoice).type.should eq("any")
    end

    it "accepts ToolChoice.tool with specific name" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.tool("search")
      )
      choice = request.tool_choice
      choice.should_not be_nil
      tc = choice.as(Anthropic::ToolChoice)
      tc.type.should eq("tool")
      tc.name.should eq("search")
    end
  end

  describe "JSON serialization with tools" do
    it "omits tools when nil" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      json = request.to_json
      json.should_not contain("\"tools\"")
      json.should_not contain("\"tool_choice\"")
    end

    it "serializes tools array" do
      tools = [sample_tool("search", "Search the web")]
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: tools
      )
      parsed = JSON.parse(request.to_json)
      parsed["tools"].as_a.size.should eq(1)
      parsed["tools"][0]["name"].as_s.should eq("search")
      parsed["tools"][0]["description"].as_s.should eq("Search the web")
      parsed["tools"][0]["input_schema"]["type"].as_s.should eq("object")
    end

    it "serializes multiple tools" do
      tools = [sample_tool("search"), sample_tool("calculator", "Do math")]
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: tools
      )
      parsed = JSON.parse(request.to_json)
      parsed["tools"].as_a.size.should eq(2)
      parsed["tools"][0]["name"].as_s.should eq("search")
      parsed["tools"][1]["name"].as_s.should eq("calculator")
    end

    it "serializes tool_choice auto" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.auto
      )
      parsed = JSON.parse(request.to_json)
      parsed["tool_choice"]["type"].as_s.should eq("auto")
    end

    it "serializes tool_choice any" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.any
      )
      parsed = JSON.parse(request.to_json)
      parsed["tool_choice"]["type"].as_s.should eq("any")
    end

    it "serializes tool_choice with specific tool name" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.tool("search")
      )
      parsed = JSON.parse(request.to_json)
      parsed["tool_choice"]["type"].as_s.should eq("tool")
      parsed["tool_choice"]["name"].as_s.should eq("search")
    end

    it "omits tool_choice when nil even if tools present" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool]
      )
      json = request.to_json
      json.should contain("\"tools\"")
      json.should_not contain("\"tool_choice\"")
    end
  end

  describe "tool configuration validation" do
    it "raises ArgumentError when tool_choice is set but tools is nil" do
      expect_raises(ArgumentError, /tool_choice is set to type 'auto' but no tools are provided/) do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          tool_choice: Anthropic::ToolChoice.auto
        )
      end
    end

    it "raises ArgumentError when tool_choice is set but tools is empty" do
      expect_raises(ArgumentError, /tool_choice is set to type 'any' but no tools are provided/) do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          tools: [] of Anthropic::ToolDefinition,
          tool_choice: Anthropic::ToolChoice.any
        )
      end
    end

    it "raises ArgumentError when tool_choice specifies a tool name not in tools array" do
      tools = [sample_tool("search")]
      expect_raises(ArgumentError, /tool_choice specifies tool 'calculator' but it was not found in the tools array/) do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          tools: tools,
          tool_choice: Anthropic::ToolChoice.tool("calculator")
        )
      end
    end

    it "raises ArgumentError when tool_choice type is tool but name is nil" do
      tools = [sample_tool("search")]
      expect_raises(ArgumentError, /tool_choice type 'tool' requires a non-empty name/) do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          tools: tools,
          tool_choice: Anthropic::ToolChoice.new("tool", nil)
        )
      end
    end

    it "raises ArgumentError when tool_choice type is tool but name is empty" do
      tools = [sample_tool("search")]
      expect_raises(ArgumentError, /tool_choice type 'tool' requires a non-empty name/) do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          tools: tools,
          tool_choice: Anthropic::ToolChoice.new("tool", "")
        )
      end
    end

    it "raises ArgumentError with unknown tool_choice type" do
      tools = [sample_tool("search")]
      expect_raises(ArgumentError, /unknown tool_choice type 'invalid'; valid types are: auto, any, tool/) do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          tools: tools,
          tool_choice: Anthropic::ToolChoice.new("invalid")
        )
      end
    end

    it "does not raise when tools and tool_choice are valid together" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool("search")],
        tool_choice: Anthropic::ToolChoice.tool("search")
      )
      request.tool_choice.should_not be_nil
    end

    it "does not raise when tools is provided but tool_choice is nil" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool("search")]
      )
      request.tools.should_not be_nil
      request.tool_choice.should be_nil
    end

    it "does not raise when neither tools nor tool_choice are set" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.tools.should be_nil
      request.tool_choice.should be_nil
    end

    it "includes available tools in error message when specified tool not found" do
      tools = [sample_tool("search"), sample_tool("weather")]
      error = expect_raises(ArgumentError, /available tools: search, weather/) do
        Anthropic::Messages::Request.new(
          model: Anthropic::Model.sonnet,
          messages: [Anthropic::Message.user("Hello!")],
          max_tokens: 1024,
          tools: tools,
          tool_choice: Anthropic::ToolChoice.tool("calculator")
        )
      end
      if msg = error.message
        msg.should contain("available tools: search, weather")
      end
    end
  end

  describe "#with_stream copies tool params" do
    it "copies tools to the stream request" do
      tools = [sample_tool("search")]
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: tools
      )

      stream_request = request.with_stream(true)

      stream_tools = stream_request.tools
      stream_tools.should_not be_nil
      stream_tools.as(Array(Anthropic::ToolDefinition)).size.should eq(1)
      stream_tools.as(Array(Anthropic::ToolDefinition))[0].name.should eq("search")
      stream_request.stream.should be_true
    end

    it "copies tool_choice to the stream request" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.auto
      )

      stream_request = request.with_stream(true)

      stream_choice = stream_request.tool_choice
      stream_choice.should_not be_nil
      stream_choice.as(Anthropic::ToolChoice).type.should eq("auto")
    end

    it "does not mutate original request" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        tools: [sample_tool],
        tool_choice: Anthropic::ToolChoice.any
      )

      stream_request = request.with_stream(true)

      # Original should not be mutated
      request.stream.should be_nil

      # Copy should have stream set
      stream_request.stream.should be_true

      # Both should have the same tools/tool_choice
      orig_tools = request.tools
      stream_tools = stream_request.tools
      orig_tools.should_not be_nil
      stream_tools.should_not be_nil
      orig_tools.as(Array(Anthropic::ToolDefinition)).size.should eq(
        stream_tools.as(Array(Anthropic::ToolDefinition)).size
      )

      orig_choice = request.tool_choice
      stream_choice = stream_request.tool_choice
      orig_choice.should_not be_nil
      stream_choice.should_not be_nil
      orig_choice.as(Anthropic::ToolChoice).type.should eq(
        stream_choice.as(Anthropic::ToolChoice).type
      )
    end
  end
end
