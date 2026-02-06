require "json"

# JSON converters for enum types with snake_case serialization.
module Anthropic::Converters
  # Converts Message::Role enum to/from JSON lowercase strings.
  module RoleConverter
    def self.from_json(pull : JSON::PullParser) : Message::Role
      Message::Role.parse(pull.read_string)
    end

    def self.to_json(value : Message::Role, json : JSON::Builder) : Nil
      json.string(value.to_s.downcase)
    end
  end

  # Converts StopReason enum to/from JSON snake_case strings, handling null.
  module StopReasonConverter
    def self.from_json(pull : JSON::PullParser) : Messages::Response::StopReason?
      pull.read_null_or do
        Messages::Response::StopReason.parse(pull.read_string)
      end
    end

    def self.to_json(value : Messages::Response::StopReason?, json : JSON::Builder) : Nil
      if value
        json.string(value.to_s.underscore)
      else
        json.null
      end
    end
  end
end
