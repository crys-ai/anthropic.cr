require "json"

# Image source for base64-encoded images.
struct Anthropic::Content::ImageSource
  include JSON::Serializable

  enum SourceType
    Base64

    def to_json(json : JSON::Builder) : Nil
      json.string(to_s.downcase)
    end
  end

  getter type : SourceType = SourceType::Base64
  getter media_type : String
  getter data : String

  def initialize(@media_type : String, @data : String)
  end
end

# Image content data.
struct Anthropic::Content::ImageData
  include Data

  SUPPORTED_MEDIA_TYPES = %w[image/jpeg image/png image/gif image/webp]

  getter source : ImageSource

  def initialize(@source : ImageSource)
    validate_media_type!(@source.media_type)
  end

  def initialize(media_type : String, data : String)
    validate_media_type!(media_type)
    @source = ImageSource.new(media_type, data)
  end

  def content_type : Type
    Type::Image
  end

  def to_content_json(json : JSON::Builder) : Nil
    json.field "source", @source
  end

  delegate media_type, to: @source
  delegate data, to: @source

  private def validate_media_type!(media_type : String) : Nil
    return if SUPPORTED_MEDIA_TYPES.includes?(media_type)
    raise ArgumentError.new(
      "Unsupported media type: #{media_type}. Supported: #{SUPPORTED_MEDIA_TYPES.join(", ")}"
    )
  end
end
