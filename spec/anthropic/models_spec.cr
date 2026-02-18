require "../spec_helper"

describe Anthropic::Model do
  describe "to_api_string" do
    it "converts ClaudeOpus4_6" do
      Anthropic::Model::ClaudeOpus4_6.to_api_string.should eq("claude-opus-4-6")
    end

    it "converts ClaudeSonnet4_6" do
      Anthropic::Model::ClaudeSonnet4_6.to_api_string.should eq("claude-sonnet-4-6")
    end

    it "converts ClaudeOpus4_5" do
      Anthropic::Model::ClaudeOpus4_5.to_api_string.should eq("claude-opus-4-5-20251101")
    end

    it "converts ClaudeSonnet4_5" do
      Anthropic::Model::ClaudeSonnet4_5.to_api_string.should eq("claude-sonnet-4-5-20250929")
    end

    it "converts ClaudeHaiku4_5" do
      Anthropic::Model::ClaudeHaiku4_5.to_api_string.should eq("claude-haiku-4-5-20251001")
    end

    it "converts ClaudeOpus4" do
      Anthropic::Model::ClaudeOpus4.to_api_string.should eq("claude-opus-4-20250514")
    end

    it "converts ClaudeSonnet4" do
      Anthropic::Model::ClaudeSonnet4.to_api_string.should eq("claude-sonnet-4-20250514")
    end
  end

  describe "api_strings mapping" do
    it "has a unique API string for each model" do
      api_strings = Anthropic::Model.api_strings.values
      api_strings.uniq.size.should eq(api_strings.size)
    end

    it "has a mapping for every enum value" do
      Anthropic::Model.each do |model|
        Anthropic::Model.api_strings.has_key?(model).should be_true
      end
    end
  end

  describe "aliases" do
    it ".opus returns ClaudeOpus4_6" do
      Anthropic::Model.opus.should eq(Anthropic::Model::ClaudeOpus4_6)
    end

    it ".sonnet returns ClaudeSonnet4_6" do
      Anthropic::Model.sonnet.should eq(Anthropic::Model::ClaudeSonnet4_6)
    end

    it ".haiku returns ClaudeHaiku4_5" do
      Anthropic::Model.haiku.should eq(Anthropic::Model::ClaudeHaiku4_5)
    end
  end

  describe "alias resolution" do
    it "opus resolves to ClaudeOpus4_6" do
      Anthropic::Model.opus.should eq(Anthropic::Model::ClaudeOpus4_6)
    end

    it "sonnet resolves to ClaudeSonnet4_6" do
      Anthropic::Model.sonnet.should eq(Anthropic::Model::ClaudeSonnet4_6)
    end

    it "haiku resolves to ClaudeHaiku4_5" do
      Anthropic::Model.haiku.should eq(Anthropic::Model::ClaudeHaiku4_5)
    end

    it "opus alias maps to correct API string" do
      Anthropic::Model.opus.to_api_string.should eq("claude-opus-4-6")
    end

    it "sonnet alias maps to correct API string" do
      Anthropic::Model.sonnet.to_api_string.should eq("claude-sonnet-4-6")
    end

    it "haiku alias maps to correct API string" do
      Anthropic::Model.haiku.to_api_string.should eq("claude-haiku-4-5-20251001")
    end
  end

  describe "JSON serialization" do
    it "serializes to API string" do
      json = Anthropic::Model::ClaudeOpus4_6.to_json
      json.should eq(%("claude-opus-4-6"))
    end
  end

  describe ".parse" do
    it "parses enum name" do
      Anthropic::Model.parse("ClaudeOpus4_6").should eq(Anthropic::Model::ClaudeOpus4_6)
    end

    it "parses underscore format" do
      Anthropic::Model.parse("claude_opus_4_6").should eq(Anthropic::Model::ClaudeOpus4_6)
    end
  end

  describe ".from_friendly" do
    it "parses 'opus' alias" do
      Anthropic::Model.from_friendly("opus").should eq(Anthropic::Model::ClaudeOpus4_6)
    end

    it "parses 'sonnet' alias" do
      Anthropic::Model.from_friendly("sonnet").should eq(Anthropic::Model::ClaudeSonnet4_6)
    end

    it "parses 'haiku' alias" do
      Anthropic::Model.from_friendly("haiku").should eq(Anthropic::Model::ClaudeHaiku4_5)
    end

    it "is case-insensitive for aliases" do
      Anthropic::Model.from_friendly("OPUS").should eq(Anthropic::Model::ClaudeOpus4_6)
      Anthropic::Model.from_friendly("Sonnet").should eq(Anthropic::Model::ClaudeSonnet4_6)
      Anthropic::Model.from_friendly("HAIKU").should eq(Anthropic::Model::ClaudeHaiku4_5)
    end

    it "falls back to Model.parse for enum-style names" do
      Anthropic::Model.from_friendly("claude_opus_4_6").should eq(Anthropic::Model::ClaudeOpus4_6)
      Anthropic::Model.from_friendly("ClaudeSonnet4_5").should eq(Anthropic::Model::ClaudeSonnet4_5)
    end

    it "raises on unknown model" do
      expect_raises(ArgumentError) do
        Anthropic::Model.from_friendly("unknown_model")
      end
    end
  end
end
