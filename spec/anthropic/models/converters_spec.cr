require "../../spec_helper"

describe Anthropic::Converters do
  describe Anthropic::Converters::RoleConverter do
    describe ".from_json" do
      it "parses 'user' to User role" do
        json = %("user")
        role = Anthropic::Converters::RoleConverter.from_json(JSON::PullParser.new(json))
        role.should eq(Anthropic::Message::Role::User)
      end

      it "parses 'assistant' to Assistant role" do
        json = %("assistant")
        role = Anthropic::Converters::RoleConverter.from_json(JSON::PullParser.new(json))
        role.should eq(Anthropic::Message::Role::Assistant)
      end

      it "parses case-insensitively" do
        json = %("User")
        role = Anthropic::Converters::RoleConverter.from_json(JSON::PullParser.new(json))
        role.should eq(Anthropic::Message::Role::User)
      end

      it "raises on invalid role string" do
        json = %("invalid_role")
        expect_raises(ArgumentError) do
          Anthropic::Converters::RoleConverter.from_json(JSON::PullParser.new(json))
        end
      end
    end

    describe ".to_json" do
      it "serializes User to 'user'" do
        json = JSON.build do |builder|
          Anthropic::Converters::RoleConverter.to_json(Anthropic::Message::Role::User, builder)
        end
        json.should eq(%("user"))
      end

      it "serializes Assistant to 'assistant'" do
        json = JSON.build do |builder|
          Anthropic::Converters::RoleConverter.to_json(Anthropic::Message::Role::Assistant, builder)
        end
        json.should eq(%("assistant"))
      end
    end

    describe "roundtrip" do
      it "roundtrips User role" do
        original = Anthropic::Message::Role::User
        json = JSON.build do |builder|
          Anthropic::Converters::RoleConverter.to_json(original, builder)
        end
        restored = Anthropic::Converters::RoleConverter.from_json(JSON::PullParser.new(json))
        restored.should eq(original)
      end

      it "roundtrips Assistant role" do
        original = Anthropic::Message::Role::Assistant
        json = JSON.build do |builder|
          Anthropic::Converters::RoleConverter.to_json(original, builder)
        end
        restored = Anthropic::Converters::RoleConverter.from_json(JSON::PullParser.new(json))
        restored.should eq(original)
      end
    end
  end

  describe Anthropic::Converters::StopReasonConverter do
    describe ".from_json" do
      it "parses 'end_turn' to EndTurn" do
        json = %("end_turn")
        reason = Anthropic::Converters::StopReasonConverter.from_json(JSON::PullParser.new(json))
        reason.should eq(Anthropic::Messages::Response::StopReason::EndTurn)
      end

      it "parses 'max_tokens' to MaxTokens" do
        json = %("max_tokens")
        reason = Anthropic::Converters::StopReasonConverter.from_json(JSON::PullParser.new(json))
        reason.should eq(Anthropic::Messages::Response::StopReason::MaxTokens)
      end

      it "parses 'stop_sequence' to StopSequence" do
        json = %("stop_sequence")
        reason = Anthropic::Converters::StopReasonConverter.from_json(JSON::PullParser.new(json))
        reason.should eq(Anthropic::Messages::Response::StopReason::StopSequence)
      end

      it "parses null to nil" do
        json = %(null)
        reason = Anthropic::Converters::StopReasonConverter.from_json(JSON::PullParser.new(json))
        reason.should be_nil
      end

      it "raises on invalid stop reason" do
        json = %("invalid_reason")
        expect_raises(ArgumentError) do
          Anthropic::Converters::StopReasonConverter.from_json(JSON::PullParser.new(json))
        end
      end
    end

    describe ".to_json" do
      it "serializes EndTurn to 'end_turn'" do
        json = JSON.build do |builder|
          Anthropic::Converters::StopReasonConverter.to_json(
            Anthropic::Messages::Response::StopReason::EndTurn, builder
          )
        end
        json.should eq(%("end_turn"))
      end

      it "serializes MaxTokens to 'max_tokens'" do
        json = JSON.build do |builder|
          Anthropic::Converters::StopReasonConverter.to_json(
            Anthropic::Messages::Response::StopReason::MaxTokens, builder
          )
        end
        json.should eq(%("max_tokens"))
      end

      it "serializes nil to null" do
        json = JSON.build do |builder|
          Anthropic::Converters::StopReasonConverter.to_json(nil, builder)
        end
        json.should eq(%(null))
      end
    end

    describe "roundtrip" do
      it "roundtrips EndTurn" do
        original = Anthropic::Messages::Response::StopReason::EndTurn
        json = JSON.build do |builder|
          Anthropic::Converters::StopReasonConverter.to_json(original, builder)
        end
        restored = Anthropic::Converters::StopReasonConverter.from_json(JSON::PullParser.new(json))
        restored.should eq(original)
      end

      it "roundtrips nil" do
        original : Anthropic::Messages::Response::StopReason? = nil
        json = JSON.build do |builder|
          Anthropic::Converters::StopReasonConverter.to_json(original, builder)
        end
        restored = Anthropic::Converters::StopReasonConverter.from_json(JSON::PullParser.new(json))
        restored.should be_nil
      end
    end
  end
end
