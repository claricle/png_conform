# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG pCAL (Pixel Calibration) chunk
      #
      # pCAL maps pixel values to physical values:
      # - Calibration name (1-79 bytes, Latin-1)
      # - Null separator (1 byte)
      # - Original zero (4 bytes, signed)
      # - Original max (4 bytes, signed)
      # - Equation type (1 byte, 0-3)
      # - Number of parameters (1 byte)
      # - Unit name (null-terminated Latin-1)
      # - Parameters (null-terminated ASCII floating point strings)
      #
      # Validation rules from PNG spec:
      # - Calibration name must be 1-79 characters, Latin-1 printable
      # - Calibration name must not have leading/trailing/consecutive spaces
      # - Equation type must be 0-3
      # - Number of parameters must match equation type requirements
      # - Parameters must be valid ASCII floating point numbers
      # - Must appear before IDAT chunk
      # - Only one pCAL chunk allowed
      class PcalValidator < BaseValidator
        # Maximum calibration name length
        MAX_CALIBRATION_NAME_LENGTH = 79

        # Latin-1 printable characters (space to tilde + high ASCII)
        PRINTABLE_LATIN1 = (32..126).to_a + (161..255).to_a

        # Valid equation types and required parameter counts
        EQUATION_LINEAR = 0            # p0 + p1*x (2 params)
        EQUATION_BASE_E = 1            # p0 + p1*e^(p2*x) (3 params)
        EQUATION_BASE_10 = 2           # p0 + p1*10^(p2*x) (3 params)
        EQUATION_ARBITRARY = 3         # p0 + p1*n^(p2*x) (4 params)

        EQUATION_PARAM_COUNTS = {
          EQUATION_LINEAR => 2,
          EQUATION_BASE_E => 3,
          EQUATION_BASE_10 => 3,
          EQUATION_ARBITRARY => 4,
        }.freeze

        # ASCII floating point regex
        FLOAT_REGEX = /\A[+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\z/

        # Validate pCAL chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_uniqueness
          return false unless check_position
          return false unless check_structure
          return false unless check_calibration_name
          return false unless check_equation_type
          return false unless check_parameters

          store_calibration_info
          true
        end

        private

        # Check that only one pCAL chunk exists
        def check_uniqueness
          if context.retrieve(:has_calibration)
            add_error("duplicate pCAL chunk (only one allowed)")
            return false
          end

          true
        end

        # Check that pCAL appears before IDAT
        def check_position
          if context.seen?("IDAT")
            add_error("pCAL chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check pCAL chunk structure
        def check_structure
          data = chunk.chunk_data

          # Must contain at least name + nulls + int fields + equation type + param count
          if data.length < 12
            add_error("pCAL chunk too short (minimum 12 bytes)")
            return false
          end

          # Must contain null separator after name
          null_pos = data.index("\0")
          unless null_pos
            add_error("pCAL chunk missing null separator")
            return false
          end

          true
        end

        # Check calibration name validity
        def check_calibration_name
          data = chunk.chunk_data
          null_pos = data.index("\0")
          cal_name = data[0, null_pos]

          # Check calibration name length
          if cal_name.empty?
            add_error("pCAL chunk has empty calibration name")
            return false
          end

          if cal_name.length > MAX_CALIBRATION_NAME_LENGTH
            add_error("pCAL calibration name too long " \
                      "(#{cal_name.length}, max #{MAX_CALIBRATION_NAME_LENGTH})")
            return false
          end

          # Check for Latin-1 printable characters
          cal_name.bytes.each do |byte|
            next if PRINTABLE_LATIN1.include?(byte)

            add_error("pCAL calibration name contains non-printable " \
                      "character (0x#{byte.to_s(16)})")
            return false
          end

          # Check for leading/trailing spaces
          if cal_name.start_with?(" ")
            add_error("pCAL calibration name has leading space")
            return false
          end

          if cal_name.end_with?(" ")
            add_error("pCAL calibration name has trailing space")
            return false
          end

          # Check for consecutive spaces
          if cal_name.include?("  ")
            add_error("pCAL calibration name has consecutive spaces")
            return false
          end

          true
        end

        # Check equation type
        def check_equation_type
          data = chunk.chunk_data
          null_pos = data.index("\0")
          equation_type = data[null_pos + 9].ord

          unless EQUATION_PARAM_COUNTS.key?(equation_type)
            add_error("pCAL invalid equation type (#{equation_type}, " \
                      "must be 0-3)")
            return false
          end

          true
        end

        # Check parameters
        def check_parameters
          data = chunk.chunk_data
          null_pos = data.index("\0")
          equation_type = data[null_pos + 9].ord
          num_params = data[null_pos + 10].ord

          expected_params = EQUATION_PARAM_COUNTS[equation_type]
          unless num_params == expected_params
            add_error("pCAL parameter count mismatch (#{num_params}, " \
                      "expected #{expected_params} for equation type #{equation_type})")
            return false
          end

          # Find unit name and parameters
          unit_start = null_pos + 11
          unit_null = data.index("\0", unit_start)
          unless unit_null
            add_error("pCAL missing unit name null terminator")
            return false
          end

          # Parse parameters
          param_start = unit_null + 1
          params_found = 0
          pos = param_start

          while params_found < num_params && pos < data.length
            param_end = data.index("\0", pos)
            unless param_end
              add_error("pCAL missing parameter #{params_found + 1} " \
                        "null terminator")
              return false
            end

            param_str = data[pos, param_end - pos]
            unless valid_float_string?(param_str)
              add_error("pCAL invalid parameter #{params_found + 1} " \
                        "format: '#{param_str}'")
              return false
            end

            params_found += 1
            pos = param_end + 1
          end

          unless params_found == num_params
            add_error("pCAL found #{params_found} parameters, " \
                      "expected #{num_params}")
            return false
          end

          true
        end

        # Validate floating point string format
        def valid_float_string?(str)
          return false if str.empty?

          str.match?(FLOAT_REGEX)
        end

        # Store calibration information in context
        def store_calibration_info
          data = chunk.chunk_data
          null_pos = data.index("\0")
          cal_name = data[0, null_pos]

          # Parse original zero and max (signed 32-bit big-endian)
          orig_zero_bytes = data[null_pos + 1, 4].bytes
          orig_zero = (orig_zero_bytes[0] << 24) |
            (orig_zero_bytes[1] << 16) |
            (orig_zero_bytes[2] << 8) |
            orig_zero_bytes[3]
          orig_zero -= (1 << 32) if orig_zero >= (1 << 31)

          orig_max_bytes = data[null_pos + 5, 4].bytes
          orig_max = (orig_max_bytes[0] << 24) |
            (orig_max_bytes[1] << 16) |
            (orig_max_bytes[2] << 8) |
            orig_max_bytes[3]
          orig_max -= (1 << 32) if orig_max >= (1 << 31)

          equation_type = data[null_pos + 9].ord
          num_params = data[null_pos + 10].ord

          # Parse unit name
          unit_start = null_pos + 11
          unit_null = data.index("\0", unit_start)
          unit_name = data[unit_start, unit_null - unit_start]

          # Parse parameters
          params = []
          pos = unit_null + 1
          num_params.times do
            param_end = data.index("\0", pos)
            param_str = data[pos, param_end - pos]
            params << param_str.to_f
            pos = param_end + 1
          end

          # Store in context
          context.store(:has_calibration, true)
          context.store(:calibration_name, cal_name)
          context.store(:calibration_equation_type, equation_type)
          context.store(:calibration_parameters, params)

          # Add info about the calibration
          eq_type_name = %w[linear base-e base-10
                            arbitrary][equation_type]
          add_info("pCAL: \"#{cal_name}\" #{eq_type_name} equation, " \
                   "range #{orig_zero}..#{orig_max}, " \
                   "unit \"#{unit_name}\", " \
                   "params: #{params.join(', ')}")
        end
      end
    end
  end
end
