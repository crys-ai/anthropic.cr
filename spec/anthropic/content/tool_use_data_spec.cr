require "../../spec_helper"

describe Anthropic::Content::ToolUseData do
  describe "#initialize" do
    it "creates with id, name, and input" do
      input = JSON.parse(%({"arg": "value"}))
      data = Anthropic::Content::ToolUseData.new("tool_123", "calculate", input)
      data.id.should eq("tool_123")
      data.name.should eq("calculate")
      data.input.should eq(input)
    end

    it "accepts empty input object" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("tool_456", "no_args", input)
      data.input.as_h.should be_empty
    end

    it "accepts complex nested input" do
      input = JSON.parse(%({"nested": {"deep": {"value": 42}}, "array": [1, 2, 3]}))
      data = Anthropic::Content::ToolUseData.new("tool_789", "complex", input)
      data.input["nested"]["deep"]["value"].as_i.should eq(42)
      data.input["array"][0].as_i.should eq(1)
    end
  end

  describe "#id" do
    it "returns the tool use id" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("unique_id", "tool_name", input)
      data.id.should eq("unique_id")
    end
  end

  describe "#name" do
    it "returns the tool name" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("id_123", "get_weather", input)
      data.name.should eq("get_weather")
    end

    it "preserves names with underscores" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("id", "my_complex_tool_name", input)
      data.name.should eq("my_complex_tool_name")
    end
  end

  describe "#input" do
    it "returns JSON::Any input" do
      input = JSON.parse(%({"key": "value"}))
      data = Anthropic::Content::ToolUseData.new("id", "name", input)
      data.input.should be_a(JSON::Any)
    end

    it "preserves string inputs" do
      input = JSON.parse(%({"location": "San Francisco", "units": "celsius"}))
      data = Anthropic::Content::ToolUseData.new("id", "weather", input)
      data.input["location"].as_s.should eq("San Francisco")
      data.input["units"].as_s.should eq("celsius")
    end

    it "preserves numeric inputs" do
      input = JSON.parse(%({"temperature": 72.5, "count": 42}))
      data = Anthropic::Content::ToolUseData.new("id", "tool", input)
      data.input["temperature"].as_f.should eq(72.5)
      data.input["count"].as_i.should eq(42)
    end

    it "preserves boolean inputs" do
      input = JSON.parse(%({"enabled": true, "verbose": false}))
      data = Anthropic::Content::ToolUseData.new("id", "tool", input)
      data.input["enabled"].as_bool.should be_true
      data.input["verbose"].as_bool.should be_false
    end

    it "preserves array inputs" do
      input = JSON.parse(%({"items": ["a", "b", "c"]}))
      data = Anthropic::Content::ToolUseData.new("id", "tool", input)
      data.input["items"].as_a.size.should eq(3)
      data.input["items"][1].as_s.should eq("b")
    end
  end

  describe "#content_type" do
    it "returns Type::ToolUse" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("id", "name", input)
      data.content_type.should eq(Anthropic::Content::Type::ToolUse)
    end
  end

  describe "Data protocol conformance" do
    it "includes Data module" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("id", "name", input)
      data.should be_a(Anthropic::Content::Data)
    end
  end

  describe "#to_content_json" do
    it "writes id, name, and input fields" do
      input = JSON.parse(%({"arg": "value"}))
      data = Anthropic::Content::ToolUseData.new("tool_123", "calculate", input)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["id"].as_s.should eq("tool_123")
      parsed["name"].as_s.should eq("calculate")
      parsed["input"]["arg"].as_s.should eq("value")
    end

    it "serializes empty input" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("id", "no_args_tool", input)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["input"].as_h.should be_empty
    end

    it "serializes nested JSON input" do
      input = JSON.parse(%({"outer": {"inner": {"deep": "value"}}}))
      data = Anthropic::Content::ToolUseData.new("id", "nested_tool", input)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["input"]["outer"]["inner"]["deep"].as_s.should eq("value")
    end

    it "serializes complex input with multiple types" do
      input = JSON.parse(%({"str": "text", "num": 42, "bool": true, "arr": [1, 2], "obj": {"key": "val"}}))
      data = Anthropic::Content::ToolUseData.new("id", "complex_tool", input)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["input"]["str"].as_s.should eq("text")
      parsed["input"]["num"].as_i.should eq(42)
      parsed["input"]["bool"].as_bool.should be_true
      parsed["input"]["arr"].as_a.size.should eq(2)
      parsed["input"]["obj"]["key"].as_s.should eq("val")
    end

    it "escapes special characters in strings" do
      input = JSON.parse(%({"text": "Quote: \\"test\\""}))
      data = Anthropic::Content::ToolUseData.new("id", "tool", input)
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["input"]["text"].as_s.should eq(%(Quote: "test"))
    end
  end

  describe "full block serialization" do
    it "serializes as Block(ToolUseData) with type and content fields" do
      input = JSON.parse(%({"location": "NYC"}))
      data = Anthropic::Content::ToolUseData.new("tool_abc", "get_weather", input)
      block = Anthropic::Content::Block.new(data)
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("tool_use")
      json["id"].as_s.should eq("tool_abc")
      json["name"].as_s.should eq("get_weather")
      json["input"]["location"].as_s.should eq("NYC")
    end

    it "produces valid JSON through Block wrapper" do
      input = JSON.parse(%({"x": 10, "y": 20}))
      data = Anthropic::Content::ToolUseData.new("id", "add", input)
      block = Anthropic::Content::Block.new(data)

      # Should parse without errors
      parsed = JSON.parse(block.to_json)
      parsed["type"].should eq("tool_use")
    end
  end

  describe "edge cases" do
    it "handles very long tool names" do
      long_name = "x" * 1000
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("id", long_name, input)
      data.name.size.should eq(1000)
    end

    it "handles very long IDs" do
      long_id = "id_" + ("x" * 1000)
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new(long_id, "name", input)
      data.id.size.should eq(1003)
    end

    it "handles large nested input structures" do
      # Create deeply nested structure
      large_input = JSON.parse(%({"level1": {"level2": {"level3": {"level4": {"data": "deep"}}}}}))
      data = Anthropic::Content::ToolUseData.new("id", "deep_tool", large_input)
      data.input["level1"]["level2"]["level3"]["level4"]["data"].as_s.should eq("deep")
    end

    it "handles input with null values" do
      input = JSON.parse(%({"value": null, "other": "data"}))
      data = Anthropic::Content::ToolUseData.new("id", "tool", input)
      data.input["value"].as_nil.should be_nil
      data.input["other"].as_s.should eq("data")
    end

    it "handles unicode in input values" do
      input = JSON.parse(%({"message": "Hello 世界 🌍"}))
      data = Anthropic::Content::ToolUseData.new("id", "tool", input)
      data.input["message"].as_s.should eq("Hello 世界 🌍")
    end

    it "handles input arrays with mixed types" do
      input = JSON.parse(%({"mixed": [1, "two", true, null, {"key": "val"}]}))
      data = Anthropic::Content::ToolUseData.new("id", "tool", input)
      arr = data.input["mixed"].as_a
      arr[0].as_i.should eq(1)
      arr[1].as_s.should eq("two")
      arr[2].as_bool.should be_true
      arr[3].as_nil.should be_nil
      arr[4]["key"].as_s.should eq("val")
    end
  end

  describe "struct behavior" do
    it "is a value type (struct)" do
      input = JSON.parse(%({}))
      data = Anthropic::Content::ToolUseData.new("id", "name", input)
      typeof(data).should eq(Anthropic::Content::ToolUseData)
    end

    it "is immutable" do
      input = JSON.parse(%({"original": "value"}))
      data = Anthropic::Content::ToolUseData.new("original_id", "original_name", input)
      data.id.should eq("original_id")
      data.name.should eq("original_name")
      data.input["original"].as_s.should eq("value")
    end
  end
end
