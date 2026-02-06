require "spec"
require "webmock"
require "../src/anthropic"
require "./support/*"

Spec.before_each &->WebMock.reset
