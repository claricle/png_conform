# frozen_string_literal: true

require "yeptris/psych"

module PngConform
  # YAML operations through Yeptris without installing its global drop-in.
  module YamlIO
    def self.load_file(...)
      Yeptris::Psych.load_file(...)
    end

    def self.safe_load_file(...)
      Yeptris::Psych.safe_load_file(...)
    end

    def self.parse_file(...)
      Yeptris::Psych.parse_file(...)
    end

    def self.dump(...)
      Yeptris::Psych.dump(...)
    end
  end
end
