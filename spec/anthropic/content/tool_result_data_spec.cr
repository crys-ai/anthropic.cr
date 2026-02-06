require "../../spec_helper"

describe Anthropic::Content::ToolResultData do
  describe "#initialize" do
    it "creates with tool_use_id and content" do
      data = Anthropic::Content::ToolResultData.new("tool_123", "result content")
      data.tool_use_id.should eq("tool_123")
      data.content.should eq("result content")
      data.is_error?.should be_false
    end

    it "creates with tool_use_id, content, and is_error" do
      data = Anthropic::Content::ToolResultData.new("tool_456", "error message", true)
      data.tool_use_id.should eq("tool_456")
      data.content.should eq("error message")
      data.is_error?.should be_true
    end

    it "defaults is_error to false" do
      data = Anthropic::Content::ToolResultData.new("tool_789", "success")
      data.is_error?.should be_false
    end

    it "accepts empty content" do
      data = Anthropic::Content::ToolResultData.new("tool_empty", "")
      data.content.should eq("")
    end
  end

  describe "#tool_use_id" do
    it "returns the tool use id" do
      data = Anthropic::Content::ToolResultData.new("unique_tool_id", "result")
      data.tool_use_id.should eq("unique_tool_id")
    end

    it "preserves long IDs" do
      long_id = "tool_" + ("x" * 1000)
      data = Anthropic::Content::ToolResultData.new(long_id, "result")
      data.tool_use_id.size.should eq(1005)
    end
  end

  describe "#content" do
    it "returns the content string" do
      data = Anthropic::Content::ToolResultData.new("id", "The weather is sunny")
      data.content.should eq("The weather is sunny")
    end

    it "preserves unicode characters" do
      data = Anthropic::Content::ToolResultData.new("id", "Temperature: 25°C in 北京 🌤️")
      data.content.should eq("Temperature: 25°C in 北京 🌤️")
    end

    it "preserves newlines" do
      data = Anthropic::Content::ToolResultData.new("id", "Line 1\nLine 2\nLine 3")
      data.content.should eq("Line 1\nLine 2\nLine 3")
    end

    it "preserves JSON strings" do
      json_result = %({"status": "success", "value": 42})
      data = Anthropic::Content::ToolResultData.new("id", json_result)
      data.content.should eq(json_result)
    end

    it "preserves whitespace" do
      data = Anthropic::Content::ToolResultData.new("id", "  indented  \t  text  ")
      data.content.should eq("  indented  \t  text  ")
    end
  end

  describe "#is_error?" do
    it "returns false when is_error is false" do
      data = Anthropic::Content::ToolResultData.new("id", "success", false)
      data.is_error?.should be_false
    end

    it "returns true when is_error is true" do
      data = Anthropic::Content::ToolResultData.new("id", "error", true)
      data.is_error?.should be_true
    end

    it "returns false when is_error is not provided (default)" do
      data = Anthropic::Content::ToolResultData.new("id", "result")
      data.is_error?.should be_false
    end
  end

  describe "#content_type" do
    it "returns Type::ToolResult" do
      data = Anthropic::Content::ToolResultData.new("id", "content")
      data.content_type.should eq(Anthropic::Content::Type::ToolResult)
    end

    it "returns Type::ToolResult even for error results" do
      data = Anthropic::Content::ToolResultData.new("id", "error", true)
      data.content_type.should eq(Anthropic::Content::Type::ToolResult)
    end
  end

  describe "Data protocol conformance" do
    it "includes Data module" do
      data = Anthropic::Content::ToolResultData.new("id", "content")
      data.should be_a(Anthropic::Content::Data)
    end
  end

  describe "#to_content_json" do
    it "writes tool_use_id and content fields" do
      data = Anthropic::Content::ToolResultData.new("tool_123", "result text")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["tool_use_id"].as_s.should eq("tool_123")
      parsed["content"].as_s.should eq("result text")
      parsed["is_error"]?.should be_nil # Not included when false
    end

    it "includes is_error field only when true" do
      data = Anthropic::Content::ToolResultData.new("tool_456", "error message", true)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["tool_use_id"].as_s.should eq("tool_456")
      parsed["content"].as_s.should eq("error message")
      parsed["is_error"].as_bool.should be_true
    end

    it "omits is_error field when false" do
      data = Anthropic::Content::ToolResultData.new("tool_789", "success", false)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["is_error"]?.should be_nil
      parsed.as_h.has_key?("is_error").should be_false
    end

    it "escapes special characters in content" do
      data = Anthropic::Content::ToolResultData.new("id", %(Quote: "test" and newline\n))
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["content"].as_s.should eq(%(Quote: "test" and newline\n))
    end

    it "serializes empty content" do
      data = Anthropic::Content::ToolResultData.new("id", "")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["content"].as_s.should eq("")
    end

    it "serializes JSON content as string" do
      json_content = %({"temperature": 72, "conditions": "sunny"})
      data = Anthropic::Content::ToolResultData.new("id", json_content)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      # Content should be a string containing JSON
      parsed["content"].as_s.should eq(json_content)
    end
  end

  describe "full block serialization" do
    it "serializes as Block(ToolResultData) for success result" do
      data = Anthropic::Content::ToolResultData.new("tool_abc", "Operation completed")
      block = Anthropic::Content::Block.new(data)
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("tool_result")
      json["tool_use_id"].as_s.should eq("tool_abc")
      json["content"].as_s.should eq("Operation completed")
      json["is_error"]?.should be_nil
    end

    it "serializes as Block(ToolResultData) for error result" do
      data = Anthropic::Content::ToolResultData.new("tool_xyz", "File not found", true)
      block = Anthropic::Content::Block.new(data)
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("tool_result")
      json["tool_use_id"].as_s.should eq("tool_xyz")
      json["content"].as_s.should eq("File not found")
      json["is_error"].as_bool.should be_true
    end

    it "produces valid JSON through Block wrapper" do
      data = Anthropic::Content::ToolResultData.new("id", "result")
      block = Anthropic::Content::Block.new(data)

      # Should parse without errors
      parsed = JSON.parse(block.to_json)
      parsed["type"].should eq("tool_result")
    end
  end

  describe "edge cases" do
    it "handles very long content" do
      long_content = "x" * 100_000
      data = Anthropic::Content::ToolResultData.new("id", long_content)
      data.content.size.should eq(100_000)
    end

    it "handles empty content with error flag" do
      data = Anthropic::Content::ToolResultData.new("id", "", true)
      data.content.should eq("")
      data.is_error?.should be_true
    end

    it "handles null bytes in content" do
      data = Anthropic::Content::ToolResultData.new("id", "before\0after")
      data.content.should eq("before\0after")
    end

    it "handles multiline error messages" do
      error_msg = "Error on line 1\nError on line 2\nStack trace follows..."
      data = Anthropic::Content::ToolResultData.new("id", error_msg, true)
      data.content.should eq(error_msg)
      data.is_error?.should be_true
    end

    it "handles mixed scripts in content" do
      data = Anthropic::Content::ToolResultData.new("id", "English العربية 中文 हिन्दी")
      data.content.should eq("English العربية 中文 हिन्दी")
    end

    it "handles content with special JSON characters" do
      content = %({"key": "value", "nested": {"array": [1, 2, 3]}})
      data = Anthropic::Content::ToolResultData.new("id", content)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      # Content should be properly escaped as a string
      parsed["content"].as_s.should eq(content)
    end

    it "handles backslashes in content" do
      data = Anthropic::Content::ToolResultData.new("id", "Path: C:\\Users\\test\\file.txt")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["content"].as_s.should eq("Path: C:\\Users\\test\\file.txt")
    end

    it "serializes error result with complex error message" do
      error_json = %({"error": "FileNotFoundError", "message": "File does not exist", "code": 404})
      data = Anthropic::Content::ToolResultData.new("tool_err", error_json, true)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["content"].as_s.should eq(error_json)
      parsed["is_error"].as_bool.should be_true
    end
  end

  describe "struct behavior" do
    it "is a value type (struct)" do
      data = Anthropic::Content::ToolResultData.new("id", "content")
      typeof(data).should eq(Anthropic::Content::ToolResultData)
    end

    it "is immutable" do
      data = Anthropic::Content::ToolResultData.new("original_id", "original_content", false)
      data.tool_use_id.should eq("original_id")
      data.content.should eq("original_content")
      data.is_error?.should be_false
    end
  end

  describe "success vs error scenarios" do
    it "represents successful tool execution" do
      data = Anthropic::Content::ToolResultData.new("tool_1", "Success: operation completed")
      data.is_error?.should be_false

      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed.as_h.has_key?("is_error").should be_false
    end

    it "represents failed tool execution" do
      data = Anthropic::Content::ToolResultData.new("tool_2", "Error: permission denied", true)
      data.is_error?.should be_true

      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["is_error"].as_bool.should be_true
    end

    it "distinguishes between empty success and empty error" do
      success = Anthropic::Content::ToolResultData.new("id1", "", false)
      error = Anthropic::Content::ToolResultData.new("id2", "", true)

      success.is_error?.should be_false
      error.is_error?.should be_true
    end
  end
end
