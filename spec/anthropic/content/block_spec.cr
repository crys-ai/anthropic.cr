require "../../spec_helper"

describe Anthropic::Content::Block do
  describe "generic type parameter" do
    it "wraps TextData" do
      data = Anthropic::Content::TextData.new("Hello")
      block = Anthropic::Content::Block(Anthropic::Content::TextData).new(data)
      block.data.should be_a(Anthropic::Content::TextData)
    end

    it "wraps ImageData" do
      data = Anthropic::Content::ImageData.new("image/png", "base64data")
      block = Anthropic::Content::Block(Anthropic::Content::ImageData).new(data)
      block.data.should be_a(Anthropic::Content::ImageData)
    end
  end

  describe "#data" do
    it "returns the wrapped data" do
      data = Anthropic::Content::TextData.new("Test text")
      block = Anthropic::Content::Block.new(data)
      block.data.text.should eq("Test text")
    end
  end

  describe "#type" do
    it "delegates to data.content_type for TextData" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new("test"))
      block.type.should eq(Anthropic::Content::Type::Text)
    end

    it "delegates to data.content_type for ImageData" do
      block = Anthropic::Content::Block.new(Anthropic::Content::ImageData.new("image/png", "data"))
      block.type.should eq(Anthropic::Content::Type::Image)
    end
  end

  describe "#to_json(json : JSON::Builder)" do
    it "serializes text block to correct JSON structure" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new("Hello!"))
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("text")
      json["text"].as_s.should eq("Hello!")
    end

    it "serializes image block to correct JSON structure" do
      block = Anthropic::Content::Block.new(Anthropic::Content::ImageData.new("image/jpeg", "abc123"))
      json = JSON.parse(block.to_json)

      json["type"].as_s.should eq("image")
      json["source"]["type"].as_s.should eq("base64")
      json["source"]["media_type"].as_s.should eq("image/jpeg")
      json["source"]["data"].as_s.should eq("abc123")
    end
  end

  describe "#to_json" do
    it "returns JSON string" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new("test"))
      block.to_json.should be_a(String)
    end

    it "produces valid JSON" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new("test"))
      JSON.parse(block.to_json)["type"].should eq("text")
    end
  end

  describe "edge cases" do
    it "handles empty text" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new(""))
      json = JSON.parse(block.to_json)
      json["text"].as_s.should eq("")
    end

    it "handles special characters in text" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new("Hello \"world\" with\nnewlines"))
      json = JSON.parse(block.to_json)
      json["text"].as_s.should eq("Hello \"world\" with\nnewlines")
    end

    it "handles unicode in text" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new("你好世界 🌍"))
      json = JSON.parse(block.to_json)
      json["text"].as_s.should eq("你好世界 🌍")
    end

    it "handles long text" do
      long_text = "a" * 10000
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new(long_text))
      json = JSON.parse(block.to_json)
      json["text"].as_s.size.should eq(10000)
    end
  end

  describe "struct behavior" do
    it "is a value type (struct)" do
      block = Anthropic::Content::Block.new(Anthropic::Content::TextData.new("test"))
      typeof(block).should eq(Anthropic::Content::Block(Anthropic::Content::TextData))
    end
  end
end
