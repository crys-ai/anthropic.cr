require "../../spec_helper"

describe Anthropic::TextBlock do
  describe "#initialize" do
    it "sets type to text" do
      block = Anthropic::TextBlock.new("Hello!")
      block.type.should eq("text")
      block.text.should eq("Hello!")
    end

    it "handles empty text" do
      block = Anthropic::TextBlock.new("")
      block.text.should eq("")
    end

    it "handles multiline text" do
      block = Anthropic::TextBlock.new("Line 1\nLine 2\nLine 3")
      block.text.should eq("Line 1\nLine 2\nLine 3")
    end

    it "handles unicode" do
      block = Anthropic::TextBlock.new("Hello 世界! 🌍")
      block.text.should eq("Hello 世界! 🌍")
    end
  end

  describe "JSON" do
    it "serializes" do
      block = Anthropic::TextBlock.new("Hello!")
      block.to_json.should eq(%({"type":"text","text":"Hello!"}))
    end

    it "deserializes" do
      block = Anthropic::TextBlock.from_json(%({"type":"text","text":"Hello!"}))
      block.text.should eq("Hello!")
    end

    it "handles escaped characters" do
      block = Anthropic::TextBlock.from_json(%({"type":"text","text":"Line 1\\nLine 2"}))
      block.text.should eq("Line 1\nLine 2")
    end

    it "roundtrips correctly" do
      original = Anthropic::TextBlock.new("Complex \"text\" with\nnewlines")
      json = original.to_json
      restored = Anthropic::TextBlock.from_json(json)
      restored.text.should eq(original.text)
    end
  end
end
