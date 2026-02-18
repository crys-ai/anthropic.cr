require "../../spec_helper"

describe Anthropic::Content::UnknownData do
  describe "protocol contract" do
    it "includes Data module" do
      raw = JSON.parse(%({"type":"thinking","thinking":"test"}))
      unknown = Anthropic::Content::UnknownData.new("thinking", raw)
      unknown.should be_a(Anthropic::Content::Data)
    end

    it "implements content_type with Type::Text fallback" do
      raw = JSON.parse(%({"type":"thinking","thinking":"test"}))
      unknown = Anthropic::Content::UnknownData.new("thinking", raw)
      # Returns Text as safe default, but this is NOT used for serialization
      unknown.content_type.should eq(Anthropic::Content::Type::Text)
    end

    it "implements to_content_json" do
      raw = JSON.parse(%({"type":"thinking","thinking":"internal","signature":"abc"}))
      unknown = Anthropic::Content::UnknownData.new("thinking", raw)
      json = JSON.build do |builder|
        builder.object do
          unknown.to_content_json(builder)
        end
      end
      # to_content_json writes raw fields excluding "type" (which Block adds)
      parsed = JSON.parse(json)
      parsed["thinking"].as_s.should eq("internal")
      parsed["signature"].as_s.should eq("abc")
      parsed["type"]?.should be_nil
    end
  end

  describe "#type_string" do
    it "preserves the original type string" do
      raw = JSON.parse(%({"type":"thinking","value":"test"}))
      unknown = Anthropic::Content::UnknownData.new("thinking", raw)
      unknown.type_string.should eq("thinking")
    end

    it "handles empty type string" do
      raw = JSON.parse(%({"custom":"value"}))
      unknown = Anthropic::Content::UnknownData.new("", raw)
      unknown.type_string.should eq("")
    end
  end

  describe "#raw" do
    it "preserves the full raw JSON data" do
      raw = JSON.parse(%({"type":"citation","text":"Hello","source":{"id":"123"}}))
      unknown = Anthropic::Content::UnknownData.new("citation", raw)
      unknown.raw["text"].as_s.should eq("Hello")
      unknown.raw["source"]["id"].as_s.should eq("123")
    end
  end

  describe "#to_json" do
    it "serializes with the original type string, not the content_type fallback" do
      raw = JSON.parse(%({"type":"thinking","thinking":"reasoning"}))
      unknown = Anthropic::Content::UnknownData.new("thinking", raw)
      json = unknown.to_json
      parsed = JSON.parse(json)

      # The type field uses type_string ("thinking"), NOT content_type (which would be "text")
      parsed["type"].as_s.should eq("thinking")
      parsed["thinking"].as_s.should eq("reasoning")
    end

    it "preserves all fields from the original JSON" do
      raw = JSON.parse(%({"type":"citation","text":"Hello","source":{"type":"file","id":"file_123"}}))
      unknown = Anthropic::Content::UnknownData.new("citation", raw)
      json = unknown.to_json
      parsed = JSON.parse(json)

      parsed["type"].as_s.should eq("citation")
      parsed["text"].as_s.should eq("Hello")
      parsed["source"]["type"].as_s.should eq("file")
      parsed["source"]["id"].as_s.should eq("file_123")
    end

    it "handles complex nested structures" do
      raw = JSON.parse(%({"type":"complex","nested":{"deep":{"value":42}}}))
      unknown = Anthropic::Content::UnknownData.new("complex", raw)
      json = unknown.to_json
      parsed = JSON.parse(json)

      parsed["nested"]["deep"]["value"].as_i.should eq(42)
    end
  end

  describe "Block(UnknownData) serialization" do
    it "uses UnknownData's custom to_json, not the default Block serialization" do
      raw = JSON.parse(%({"type":"thinking","thinking":"reasoning payload"}))
      unknown_data = Anthropic::Content::UnknownData.new("thinking", raw)
      block = Anthropic::Content::Block.new(unknown_data)

      json = block.to_json
      parsed = JSON.parse(json)

      # The type should be "thinking" from type_string, not "text" from content_type
      parsed["type"].as_s.should eq("thinking")
      parsed["thinking"].as_s.should eq("reasoning payload")
    end

    it "delegates type method to content_type (returns Text for UnknownData)" do
      raw = JSON.parse(%({"type":"thinking","thinking":"test"}))
      unknown_data = Anthropic::Content::UnknownData.new("thinking", raw)
      block = Anthropic::Content::Block.new(unknown_data)

      # block.type calls data.content_type which returns Type::Text as fallback
      block.type.should eq(Anthropic::Content::Type::Text)

      # But serialization uses the correct type_string
      json = JSON.parse(block.to_json)
      json["type"].as_s.should eq("thinking")
    end
  end

  describe "forward compatibility" do
    it "can represent any unknown future content type" do
      # Simulate a future content type not yet known to this library
      raw = JSON.parse(%({"type":"future_type_3000","field1":"value1","field2":123}))
      unknown = Anthropic::Content::UnknownData.new("future_type_3000", raw)

      unknown.type_string.should eq("future_type_3000")
      unknown.raw["field1"].as_s.should eq("value1")
      unknown.raw["field2"].as_i.should eq(123)

      # Roundtrip preserves everything
      json = unknown.to_json
      parsed = JSON.parse(json)
      parsed["type"].as_s.should eq("future_type_3000")
      parsed["field1"].as_s.should eq("value1")
      parsed["field2"].as_i.should eq(123)
    end
  end
end
