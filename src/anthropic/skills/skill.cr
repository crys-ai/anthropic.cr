require "json"
require "base64"
require "uri"

# Skill source enum
enum Anthropic::SkillSource
  Custom
  Anthropic

  def to_s : String
    case self
    in .custom?    then "custom"
    in .anthropic? then "anthropic"
    end
  end

  def self.parse?(value : String) : self?
    case value.downcase
    when "custom"    then Custom
    when "anthropic" then Anthropic
    end
  end
end

# A skill object from the Anthropic API.
struct Anthropic::Skill
  include JSON::Serializable

  getter id : String
  getter type : String # "skill"
  getter display_title : String
  getter source : String # "custom" or "anthropic"
  getter latest_version : String
  getter created_at : String
  getter updated_at : String

  # Parse source as enum
  def source_enum : SkillSource?
    SkillSource.parse?(source)
  end

  def custom? : Bool
    source == "custom"
  end

  def anthropic? : Bool
    source == "anthropic"
  end
end

# A skill version object.
struct Anthropic::SkillVersion
  include JSON::Serializable

  getter id : String
  getter type : String # "skill_version"
  getter skill_id : String
  getter version : String     # Unix epoch timestamp
  getter name : String        # From SKILL.md
  getter description : String # From SKILL.md
  getter directory : String   # Top-level directory name
  getter created_at : String
end

# Response for deleting a skill.
struct Anthropic::SkillDeleted
  include JSON::Serializable

  getter id : String
  getter type : String # "skill_deleted"
end

# Response for deleting a skill version.
struct Anthropic::SkillVersionDeleted
  include JSON::Serializable

  getter id : String
  getter type : String # "skill_version_deleted"
end

# Paginated list response for skills.
struct Anthropic::SkillsListResponse
  include JSON::Serializable

  getter data : Array(Skill)
  getter? has_more : Bool
  getter next_page : String?

  def initialize(@data : Array(Skill) = [] of Skill, @has_more : Bool = false, @next_page : String? = nil)
  end
end

# Paginated list response for skill versions.
struct Anthropic::SkillVersionsListResponse
  include JSON::Serializable

  getter data : Array(SkillVersion)
  getter? has_more : Bool
  getter next_page : String?

  def initialize(@data : Array(SkillVersion) = [] of SkillVersion, @has_more : Bool = false, @next_page : String? = nil)
  end
end

# Parameters for listing skills.
struct Anthropic::SkillsListParams
  getter limit : Int32?
  getter page : String?
  getter source : String? # "custom" or "anthropic"

  def initialize(
    @limit : Int32? = nil,
    @page : String? = nil,
    @source : String? = nil,
  )
    if l = @limit
      raise ArgumentError.new("limit must be positive, got #{l}") unless l > 0
    end
    if src = @source
      if SkillSource.parse?(src).nil?
        raise ArgumentError.new(
          "source must be \"custom\" or \"anthropic\" (case-insensitive), got #{src.inspect}"
        )
      end
    end
  end

  # Build query string using query-component encoding.
  def to_query_string : String
    result = URI::Params.build do |builder|
      if l = @limit
        builder.add("limit", l.to_s)
      end
      if p = @page
        builder.add("page", p)
      end
      if s = @source
        builder.add("source", s)
      end
    end
    result.empty? ? "" : "?#{result}"
  end
end

# Parameters for listing skill versions.
struct Anthropic::SkillVersionsListParams
  getter limit : Int32?
  getter page : String?

  def initialize(
    @limit : Int32? = nil,
    @page : String? = nil,
  )
    if l = @limit
      raise ArgumentError.new("limit must be positive, got #{l}") unless l > 0
    end
  end

  def to_query_string : String
    result = URI::Params.build do |builder|
      if l = @limit
        builder.add("limit", l.to_s)
      end
      if p = @page
        builder.add("page", p)
      end
    end
    result.empty? ? "" : "?#{result}"
  end
end

# Request to create a skill (upload as multipart).
struct Anthropic::UploadSkillRequest
  getter content : Bytes
  getter filename : String

  def initialize(@content : Bytes, @filename : String = "skill.zip")
  end

  # Create from a file path. Reads file content and makes an owned copy
  # of the byte buffer so there are no dangling slice references.
  def self.from_file(path : String) : self
    content = ::File.read(path).to_slice.dup
    new(content, ::File.basename(path))
  end

  # Create from a string. Makes an owned copy of the byte buffer
  # so there are no dangling slice references.
  def self.from_string(content : String, filename : String = "skill.zip") : self
    new(content.to_slice.dup, filename)
  end

  def self.from_base64(base64_content : String, filename : String = "skill.zip") : self
    new(Base64.decode(base64_content), filename)
  end
end
