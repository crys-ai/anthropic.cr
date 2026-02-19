require "../spec_helper"

# Test struct for structured output parsing
private struct PersonData
  include JSON::Serializable
  getter name : String
  getter age : Int32
end

describe Anthropic::StructuredOutput do
  describe ".tool" do
    it "creates a tool definition with schema" do
      schema = JSON.parse(%({"type": "object", "properties": {"name": {"type": "string"}}}))
      tool = Anthropic::StructuredOutput.tool("person", schema, description: "Extract person")

      tool.name.should eq("person")
      tool.description.should eq("Extract person")
      tool.input_schema.should eq(schema)
    end

    it "uses default tool name" do
      tool = Anthropic::StructuredOutput.tool
      tool.name.should eq("structured_output")
    end
  end

  describe ".tool_choice" do
    it "creates a tool choice for the named tool" do
      choice = Anthropic::StructuredOutput.tool_choice("my_tool")
      choice.type.should eq("tool")
      choice.name.should eq("my_tool")
    end

    it "uses default tool name" do
      choice = Anthropic::StructuredOutput.tool_choice
      choice.name.should eq("structured_output")
    end
  end

  describe ".extract" do
    it "extracts JSON from tool_use block" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_test",
              "name": "structured_output",
              "input": {"name": "John", "age": 25}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)

      result = Anthropic::StructuredOutput.extract(response)
      result.should_not be_nil

      if r = result
        r["name"].as_s.should eq("John")
        r["age"].as_i.should eq(25)
      end
    end

    it "returns nil if no tool_use block" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Hello"}],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::StructuredOutput.extract(response).should be_nil
    end

    it "supports custom tool name" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_test",
              "name": "custom_tool",
              "input": {"data": true}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)

      # Default tool name doesn't match
      Anthropic::StructuredOutput.extract(response).should be_nil

      # Custom tool name matches
      result = Anthropic::StructuredOutput.extract(response, "custom_tool")
      result.should_not be_nil

      if r = result
        r["data"].as_bool.should be_true
      end
    end
  end

  describe ".extract!" do
    it "raises ExtractionError if no tool_use block" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Hello"}],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)

      expect_raises(Anthropic::StructuredOutput::ExtractionError) do
        Anthropic::StructuredOutput.extract!(response)
      end
    end

    it "returns JSON when tool_use block exists" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_test",
              "name": "structured_output",
              "input": {"key": "value"}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)

      result = Anthropic::StructuredOutput.extract!(response)
      result["key"].as_s.should eq("value")
    end
  end

  describe ".extract_as" do
    it "extracts and deserializes to typed struct" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_test",
              "name": "structured_output",
              "input": {"name": "Alice", "age": 30}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)

      person = Anthropic::StructuredOutput.extract_as(PersonData, response)
      person.should_not be_nil

      if p = person
        p.name.should eq("Alice")
        p.age.should eq(30)
      end
    end

    it "returns nil if no tool_use block" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Hello"}],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::StructuredOutput.extract_as(PersonData, response).should be_nil
    end
  end

  describe ".has_output?" do
    it "returns true if tool_use block exists" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_test",
              "name": "structured_output",
              "input": {}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::StructuredOutput.has_output?(response).should be_true
    end

    it "returns false if no tool_use block" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Hello"}],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::StructuredOutput.has_output?(response).should be_false
    end

    it "supports custom tool name" do
      response_json = <<-JSON
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_test",
              "name": "my_tool",
              "input": {}
            }
          ],
          "model": "claude-sonnet-4-20250514",
          "stop_reason": "tool_use",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        JSON

      response = Anthropic::Messages::Response.from_json(response_json)
      Anthropic::StructuredOutput.has_output?(response).should be_false
      Anthropic::StructuredOutput.has_output?(response, "my_tool").should be_true
    end
  end
end

describe Anthropic::StructuredOutput::ExtractionError do
  it "is an Exception" do
    Anthropic::StructuredOutput::ExtractionError.new("test").should be_a(Exception)
  end

  it "stores message" do
    error = Anthropic::StructuredOutput::ExtractionError.new("Something went wrong")
    error.message.should eq("Something went wrong")
  end
end
