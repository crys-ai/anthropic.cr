require "json"
require "base64"

# File uploaded to the Anthropic API.
struct Anthropic::File
  include JSON::Serializable

  getter id : String
  getter type : String # "file"
  getter filename : String
  @[JSON::Field(key: "size_bytes")]
  getter size_bytes : Int64
  getter created_at : String
  getter mime_type : String?
  getter downloadable : Bool?

  def initialize(
    @id : String,
    @filename : String,
    @size_bytes : Int64,
    @created_at : String,
    @type : String = "file",
    @mime_type : String? = nil,
    @downloadable : Bool? = nil,
  )
  end
end

# Response for deleting a file.
struct Anthropic::FileDeleted
  include JSON::Serializable

  getter id : String
  getter type : String # "file_deleted"
end

# Request to upload a file.
struct Anthropic::UploadFileRequest
  getter filename : String
  getter content : Bytes
  getter mime_type : String?

  def initialize(
    @filename : String,
    @content : Bytes,
    @mime_type : String? = nil,
  )
  end

  def self.from_string(
    filename : String,
    content : String,
    mime_type : String? = nil,
  ) : self
    # .dup creates an owned copy of the bytes, independent of the original string's lifetime
    new(filename, content.to_slice.dup, mime_type)
  end

  def self.from_base64(
    filename : String,
    base64_content : String,
    mime_type : String? = nil,
  ) : self
    new(filename, Base64.decode(base64_content), mime_type)
  end
end
