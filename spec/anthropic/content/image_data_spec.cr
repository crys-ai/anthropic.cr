require "../../spec_helper"

describe Anthropic::Content::ImageSource do
  describe "#initialize" do
    it "creates with media_type and data" do
      source = Anthropic::Content::ImageSource.new("image/png", "base64data")
      source.media_type.should eq("image/png")
      source.data.should eq("base64data")
    end
  end

  describe "#type" do
    it "defaults to base64" do
      source = Anthropic::Content::ImageSource.new("image/png", "data")
      source.type.should eq(Anthropic::Content::ImageSource::SourceType::Base64)
    end
  end

  describe "JSON serialization" do
    it "serializes to correct structure" do
      source = Anthropic::Content::ImageSource.new("image/jpeg", "abc123")
      json = JSON.parse(source.to_json)

      json["type"].as_s.should eq("base64")
      json["media_type"].as_s.should eq("image/jpeg")
      json["data"].as_s.should eq("abc123")
    end
  end
end

describe Anthropic::Content::ImageData do
  describe "#initialize with media_type and data" do
    it "creates ImageSource internally" do
      data = Anthropic::Content::ImageData.new("image/png", "base64data")
      data.source.should be_a(Anthropic::Content::ImageSource)
    end

    it "passes media_type to source" do
      data = Anthropic::Content::ImageData.new("image/gif", "gifdata")
      data.source.media_type.should eq("image/gif")
    end

    it "passes data to source" do
      data = Anthropic::Content::ImageData.new("image/png", "mydata123")
      data.source.data.should eq("mydata123")
    end
  end

  describe "#initialize with ImageSource" do
    it "accepts ImageSource directly" do
      source = Anthropic::Content::ImageSource.new("image/webp", "webpdata")
      data = Anthropic::Content::ImageData.new(source)
      data.source.should eq(source)
    end
  end

  describe "#content_type" do
    it "returns Type::Image" do
      data = Anthropic::Content::ImageData.new("image/png", "data")
      data.content_type.should eq(Anthropic::Content::Type::Image)
    end
  end

  describe "delegated methods" do
    it "delegates media_type to source" do
      data = Anthropic::Content::ImageData.new("image/jpeg", "jpegdata")
      data.media_type.should eq("image/jpeg")
    end

    it "delegates data to source" do
      data = Anthropic::Content::ImageData.new("image/png", "pngdata")
      data.data.should eq("pngdata")
    end
  end

  describe "#to_content_json" do
    it "writes source field with nested structure" do
      data = Anthropic::Content::ImageData.new("image/png", "abc123")
      json = JSON.build do |builder|
        builder.object do
          data.to_content_json(builder)
        end
      end
      parsed = JSON.parse(json)

      parsed["source"]["type"].as_s.should eq("base64")
      parsed["source"]["media_type"].as_s.should eq("image/png")
      parsed["source"]["data"].as_s.should eq("abc123")
    end
  end

  describe "Data protocol conformance" do
    it "includes Data module" do
      data = Anthropic::Content::ImageData.new("image/png", "data")
      data.should be_a(Anthropic::Content::Data)
    end
  end

  describe "supported media types" do
    it "accepts image/jpeg" do
      data = Anthropic::Content::ImageData.new("image/jpeg", "data")
      data.media_type.should eq("image/jpeg")
    end

    it "accepts image/png" do
      data = Anthropic::Content::ImageData.new("image/png", "data")
      data.media_type.should eq("image/png")
    end

    it "accepts image/gif" do
      data = Anthropic::Content::ImageData.new("image/gif", "data")
      data.media_type.should eq("image/gif")
    end

    it "accepts image/webp" do
      data = Anthropic::Content::ImageData.new("image/webp", "data")
      data.media_type.should eq("image/webp")
    end
  end

  describe "edge cases" do
    it "handles large base64 data" do
      large_data = "x" * 1_000_000 # ~750KB image
      data = Anthropic::Content::ImageData.new("image/png", large_data)
      data.data.size.should eq(1_000_000)
    end

    it "handles empty data" do
      data = Anthropic::Content::ImageData.new("image/png", "")
      data.data.should eq("")
    end
  end

  describe "struct behavior" do
    it "is a value type (struct)" do
      data = Anthropic::Content::ImageData.new("image/png", "data")
      typeof(data).should eq(Anthropic::Content::ImageData)
    end
  end

  describe "media type validation" do
    describe "with separate parameters constructor" do
      it "raises ArgumentError for unsupported media type image/bmp" do
        expect_raises(ArgumentError, /Unsupported media type: image\/bmp/) do
          Anthropic::Content::ImageData.new("image/bmp", "data")
        end
      end

      it "raises ArgumentError for text/plain" do
        expect_raises(ArgumentError, /Unsupported media type: text\/plain/) do
          Anthropic::Content::ImageData.new("text/plain", "data")
        end
      end

      it "raises ArgumentError for application/pdf" do
        expect_raises(ArgumentError, /Unsupported media type: application\/pdf/) do
          Anthropic::Content::ImageData.new("application/pdf", "data")
        end
      end

      it "error message includes supported types" do
        expect_raises(ArgumentError, /Supported: image\/jpeg, image\/png, image\/gif, image\/webp/) do
          Anthropic::Content::ImageData.new("image/tiff", "data")
        end
      end
    end

    describe "with ImageSource constructor" do
      it "raises ArgumentError for unsupported media type" do
        source = Anthropic::Content::ImageSource.new("image/svg+xml", "data")
        expect_raises(ArgumentError, /Unsupported media type: image\/svg\+xml/) do
          Anthropic::Content::ImageData.new(source)
        end
      end

      it "accepts ImageSource with supported media type" do
        source = Anthropic::Content::ImageSource.new("image/jpeg", "data")
        data = Anthropic::Content::ImageData.new(source)
        data.media_type.should eq("image/jpeg")
      end
    end

    describe "SUPPORTED_MEDIA_TYPES constant" do
      it "is accessible" do
        Anthropic::Content::ImageData::SUPPORTED_MEDIA_TYPES.should be_a(Array(String))
      end

      it "contains exactly 4 supported types" do
        types = Anthropic::Content::ImageData::SUPPORTED_MEDIA_TYPES
        types.size.should eq(4)
        types.should contain("image/jpeg")
        types.should contain("image/png")
        types.should contain("image/gif")
        types.should contain("image/webp")
      end
    end
  end
end
