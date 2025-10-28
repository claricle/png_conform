# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG tIME (Image Last-Modification Time) chunk
      #
      # tIME specifies the time of the last image modification:
      # - Year (2 bytes, complete; e.g., 1995, not 95)
      # - Month (1 byte, 1-12)
      # - Day (1 byte, 1-31)
      # - Hour (1 byte, 0-23)
      # - Minute (1 byte, 0-59)
      # - Second (1 byte, 0-60, to allow for leap seconds)
      #
      # Validation rules from PNG spec:
      # - Must be exactly 7 bytes
      # - Only one tIME chunk allowed
      # - Month must be 1-12
      # - Day must be 1-31
      # - Hour must be 0-23
      # - Minute must be 0-59
      # - Second must be 0-60 (60 for leap seconds)
      class TimeValidator < BaseValidator
        # Validate tIME chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(7)
          return false unless check_uniqueness
          return false unless check_datetime

          store_time_info
          true
        end

        private

        # Check that only one tIME chunk is present
        def check_uniqueness
          if context.seen?("tIME")
            add_error("duplicate tIME chunk")
            return false
          end
          true
        end

        # Check date and time values
        def check_datetime
          data = chunk.chunk_data
          year = data[0, 2].unpack1("n")
          month = data[2].unpack1("C")
          day = data[3].unpack1("C")
          hour = data[4].unpack1("C")
          minute = data[5].unpack1("C")
          second = data[6].unpack1("C")

          valid = true

          # PNG was created in 1996, so years before that are invalid
          if year < 1996
            add_error("invalid tIME year (before PNG existed!) (#{year})")
            valid = false
          end

          valid &= check_range(month, 1, 12, "month")
          valid &= check_range(day, 1, 31, "day")
          valid &= check_range(hour, 0, 23, "hour")
          valid &= check_range(minute, 0, 59, "minute")
          valid &= check_range(second, 0, 60, "second")

          # Additional day validation based on month
          if valid && !valid_day_for_month?(year, month, day)
            add_error("invalid day (#{day}) for month #{month}")
            valid = false
          end

          valid
        end

        # Check if day is valid for given month and year
        def valid_day_for_month?(year, month, day)
          days_in_month = case month
                          when 2
                            leap_year?(year) ? 29 : 28
                          when 4, 6, 9, 11
                            30
                          else
                            31
                          end

          day <= days_in_month
        end

        # Check if year is a leap year
        def leap_year?(year)
          (year % 4).zero? && ((year % 100 != 0) || (year % 400).zero?)
        end

        # Store time information in context
        def store_time_info
          data = chunk.chunk_data
          year = data[0, 2].unpack1("n")
          month = data[2].unpack1("C")
          day = data[3].unpack1("C")
          hour = data[4].unpack1("C")
          minute = data[5].unpack1("C")
          second = data[6].unpack1("C")

          timestamp = {
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second,
          }

          context.store(:modification_time, timestamp)

          # Format as ISO 8601
          iso_time = format("%04d-%02d-%02d %02d:%02d:%02d UTC",
                            year, month, day, hour, minute, second)
          add_info("tIME: #{iso_time}")
        end
      end
    end
  end
end
