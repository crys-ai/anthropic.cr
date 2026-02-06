require "../../spec_helper"

describe Anthropic::Content::Type do
  describe "enum values" do
    it "has Text type" do
      Anthropic::Content::Type::Text.should be_a(Anthropic::Content::Type)
    end

    it "has Image type" do
      Anthropic::Content::Type::Image.should be_a(Anthropic::Content::Type)
    end

    it "has ToolUse type" do
      Anthropic::Content::Type::ToolUse.should be_a(Anthropic::Content::Type)
    end

    it "has ToolResult type" do
      Anthropic::Content::Type::ToolResult.should be_a(Anthropic::Content::Type)
    end
  end

  describe "#to_json" do
    it "serializes Text as snake_case" do
      Anthropic::Content::Type::Text.to_json.should eq(%("text"))
    end

    it "serializes Image as snake_case" do
      Anthropic::Content::Type::Image.to_json.should eq(%("image"))
    end

    it "serializes ToolUse as snake_case" do
      Anthropic::Content::Type::ToolUse.to_json.should eq(%("tool_use"))
    end

    it "serializes ToolResult as snake_case" do
      Anthropic::Content::Type::ToolResult.to_json.should eq(%("tool_result"))
    end
  end

  describe "JSON::Builder integration" do
    it "serializes correctly in JSON object" do
      json = JSON.build do |builder|
        builder.object do
          builder.field "type", Anthropic::Content::Type::Text
        end
      end
      json.should eq(%({"type":"text"}))
    end
  end
end
