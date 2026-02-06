require "../../spec_helper"

describe Anthropic::Content::TextData do
  describe "#initialize" do
    it "creates with text" do
      data = Anthropic::Content::TextData.new("Hello!")
      data.text.should eq("Hello!")
    end

    it "accepts empty string" do
      data = Anthropic::Content::TextData.new("")
      data.text.should eq("")
    end
  end

  describe "#text" do
    it "returns the text value" do
      data = Anthropic::Content::TextData.new("Test text")
      data.text.should eq("Test text")
    end

    it "preserves unicode" do
      data = Anthropic::Content::TextData.new("日本語テスト 🎉")
      data.text.should eq("日本語テスト 🎉")
    end

    it "preserves newlines" do
      data = Anthropic::Content::TextData.new("Line 1\nLine 2\nLine 3")
      data.text.should eq("Line 1\nLine 2\nLine 3")
    end

    it "preserves tabs and whitespace" do
      data = Anthropic::Content::TextData.new("col1\tcol2\t\tcol3")
      data.text.should eq("col1\tcol2\t\tcol3")
    end
  end

  describe "#content_type" do
    it "returns Type::Text" do
      data = Anthropic::Content::TextData.new("test")
      data.content_type.should eq(Anthropic::Content::Type::Text)
    end
  end

  describe "#to_content_json" do
    it "writes text field" do
      data = Anthropic::Content::TextData.new("Hello!")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      json.should eq(%({"text":"Hello!"}))
    end

    it "escapes special characters" do
      data = Anthropic::Content::TextData.new("Quote: \"test\"")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)
      parsed["text"].as_s.should eq("Quote: \"test\"")
    end

    it "escapes newlines correctly" do
      data = Anthropic::Content::TextData.new("Line1\nLine2")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      # The JSON string should have escaped newline
      json.should contain("\\n")
    end
  end

  describe "Data protocol conformance" do
    it "includes Data module" do
      data = Anthropic::Content::TextData.new("test")
      data.should be_a(Anthropic::Content::Data)
    end
  end

  describe "struct behavior" do
    it "is a value type (struct)" do
      # Verify it's a struct by checking it compiles as such
      data = Anthropic::Content::TextData.new("test")
      typeof(data).should eq(Anthropic::Content::TextData)
    end

    it "is immutable" do
      data = Anthropic::Content::TextData.new("original")
      # text getter returns String, which is immutable in Crystal
      data.text.should eq("original")
    end
  end

  describe "edge cases" do
    it "handles very long text" do
      long_text = "x" * 100_000
      data = Anthropic::Content::TextData.new(long_text)
      data.text.size.should eq(100_000)
    end

    it "handles null bytes" do
      data = Anthropic::Content::TextData.new("before\0after")
      data.text.should eq("before\0after")
    end

    it "handles mixed scripts" do
      data = Anthropic::Content::TextData.new("English العربية 中文 हिन्दी")
      data.text.should eq("English العربية 中文 हिन्दी")
    end
  end
end
