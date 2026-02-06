require "../../spec_helper"

describe Anthropic::Content::Data do
  describe "protocol contract" do
    it "requires content_type implementation" do
      data = TestContentData.new("test")
      data.content_type.should eq(Anthropic::Content::Type::Text)
    end

    it "requires to_content_json implementation" do
      data = TestContentData.new("hello")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      json.should eq(%({"test_value":"hello"}))
    end
  end

  describe "TextData implements Data" do
    it "includes Data module" do
      data = Anthropic::Content::TextData.new("test")
      data.should be_a(Anthropic::Content::Data)
    end

    it "implements content_type" do
      data = Anthropic::Content::TextData.new("test")
      data.content_type.should eq(Anthropic::Content::Type::Text)
    end

    it "implements to_content_json" do
      data = Anthropic::Content::TextData.new("hello")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      json.should eq(%({"text":"hello"}))
    end
  end

  describe "ImageData implements Data" do
    it "includes Data module" do
      data = Anthropic::Content::ImageData.new("image/png", "base64data")
      data.should be_a(Anthropic::Content::Data)
    end

    it "implements content_type" do
      data = Anthropic::Content::ImageData.new("image/png", "base64data")
      data.content_type.should eq(Anthropic::Content::Type::Image)
    end

    it "implements to_content_json" do
      data = Anthropic::Content::ImageData.new("image/png", "abc123")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)
      parsed["source"]["media_type"].as_s.should eq("image/png")
      parsed["source"]["data"].as_s.should eq("abc123")
    end
  end

  describe "ToolUseData implements Data" do
    it "includes Data module" do
      input = JSON.parse(%(null))
      data = Anthropic::Content::ToolUseData.new("id", "name", input)
      data.should be_a(Anthropic::Content::Data)
    end

    it "implements content_type" do
      input = JSON.parse(%(null))
      data = Anthropic::Content::ToolUseData.new("id", "name", input)
      data.content_type.should eq(Anthropic::Content::Type::ToolUse)
    end
  end

  describe "ToolResultData implements Data" do
    it "includes Data module" do
      data = Anthropic::Content::ToolResultData.new("tool_1", "result")
      data.should be_a(Anthropic::Content::Data)
    end

    it "implements content_type" do
      data = Anthropic::Content::ToolResultData.new("tool_1", "result")
      data.content_type.should eq(Anthropic::Content::Type::ToolResult)
    end
  end
end
