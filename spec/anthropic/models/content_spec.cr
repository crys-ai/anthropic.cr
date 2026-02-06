require "../../spec_helper"

describe Anthropic::ResponseTextBlock do
  describe "#initialize" do
    it "sets type to text" do
      block = Anthropic::ResponseTextBlock.new("Hello!")
      block.type.should eq("text")
      block.text.should eq("Hello!")
    end

    it "handles empty text" do
      block = Anthropic::ResponseTextBlock.new("")
      block.text.should eq("")
    end

    it "handles multiline text" do
      block = Anthropic::ResponseTextBlock.new("Line 1\nLine 2\nLine 3")
      block.text.should eq("Line 1\nLine 2\nLine 3")
    end

    it "handles unicode" do
      block = Anthropic::ResponseTextBlock.new("Hello 世界! 🌍")
      block.text.should eq("Hello 世界! 🌍")
    end
  end

  describe "JSON deserialization (for API responses)" do
    it "deserializes from API response format" do
      block = Anthropic::ResponseTextBlock.from_json(%({"type":"text","text":"Hello!"}))
      block.text.should eq("Hello!")
    end

    it "handles escaped characters" do
      block = Anthropic::ResponseTextBlock.from_json(%({"type":"text","text":"Line 1\\nLine 2"}))
      block.text.should eq("Line 1\nLine 2")
    end

    it "roundtrips correctly" do
      original = Anthropic::ResponseTextBlock.new("Complex \"text\" with\nnewlines")
      json = original.to_json
      restored = Anthropic::ResponseTextBlock.from_json(json)
      restored.text.should eq(original.text)
    end
  end

end
