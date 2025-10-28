# frozen_string_literal: true

require_relative "../services/profile_manager"

module PngConform
  module Commands
    # Command to list available validation profiles.
    #
    # Displays information about all available profiles including
    # their requirements and restrictions.
    class ListCommand
      attr_reader :options

      # @param options [Hash] Command-line options
      def initialize(options = {})
        @options = options
      end

      # Execute the list command.
      #
      # @return [Integer] Exit code (always 0)
      def run
        profiles = Services::ProfileManager.available_profiles

        puts "Available Validation Profiles:"
        puts

        profiles.each do |profile_name|
          display_profile(profile_name)
          puts
        end

        0
      end

      private

      # Display information about a single profile.
      #
      # @param profile_name [String] Name of the profile to display
      def display_profile(profile_name)
        profile = Services::ProfileManager.get_profile(profile_name)

        puts "  #{profile_name.upcase}"
        puts "  #{'-' * (profile_name.length + 2)}"

        puts "  Description: #{profile[:description]}" if profile[:description]

        if profile[:required_chunks] && !profile[:required_chunks].empty?
          puts "  Required chunks: #{profile[:required_chunks].join(', ')}"
        end

        if profile[:optional_chunks] && !profile[:optional_chunks].empty?
          puts "  Optional chunks: #{profile[:optional_chunks].join(', ')}"
        end

        if profile[:prohibited_chunks] && !profile[:prohibited_chunks].empty?
          puts "  Prohibited chunks: #{profile[:prohibited_chunks].join(', ')}"
        end

        return unless profile[:strict_mode]

        puts "  Strict mode: enabled"
      end
    end
  end
end
