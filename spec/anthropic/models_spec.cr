require "../spec_helper"

describe Anthropic::Model do
  describe "to_api_string" do
    it "converts ClaudeOpus4_5" do
      Anthropic::Model::ClaudeOpus4_5.to_api_string.should eq("claude-opus-4-5-20251101")
    end

    it "converts ClaudeSonnet4_5" do
      Anthropic::Model::ClaudeSonnet4_5.to_api_string.should eq("claude-sonnet-4-5-20251101")
    end

    it "converts ClaudeOpus4" do
      Anthropic::Model::ClaudeOpus4.to_api_string.should eq("claude-opus-4-20251101")
    end

    it "converts ClaudeSonnet4" do
      Anthropic::Model::ClaudeSonnet4.to_api_string.should eq("claude-sonnet-4-20251101")
    end

    it "converts ClaudeSonnet3_5" do
      Anthropic::Model::ClaudeSonnet3_5.to_api_string.should eq("claude-3-5-sonnet-20260101")
    end

    it "converts ClaudeHaiku3_5" do
      Anthropic::Model::ClaudeHaiku3_5.to_api_string.should eq("claude-3-5-haiku-20260101")
    end
  end

  describe "aliases" do
    it ".opus returns ClaudeOpus4_5" do
      Anthropic::Model.opus.should eq(Anthropic::Model::ClaudeOpus4_5)
    end

    it ".sonnet returns ClaudeSonnet4_5" do
      Anthropic::Model.sonnet.should eq(Anthropic::Model::ClaudeSonnet4_5)
    end

    it ".haiku returns ClaudeHaiku3_5" do
      Anthropic::Model.haiku.should eq(Anthropic::Model::ClaudeHaiku3_5)
    end
  end

  describe "JSON serialization" do
    it "serializes to API string" do
      json = Anthropic::Model::ClaudeOpus4_5.to_json
      json.should eq(%("claude-opus-4-5-20251101"))
    end
  end

  describe ".parse" do
    it "parses enum name" do
      Anthropic::Model.parse("ClaudeOpus4_5").should eq(Anthropic::Model::ClaudeOpus4_5)
    end

    it "parses underscore format" do
      Anthropic::Model.parse("claude_opus_4_5").should eq(Anthropic::Model::ClaudeOpus4_5)
    end
  end
end
