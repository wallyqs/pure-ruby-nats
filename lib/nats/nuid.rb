# Copyright 2016-2018 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'securerandom'

module NATS
  class NUID
    DIGITS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.split('')
    BASE          = 62
    PREFIX_LENGTH = 12
    SEQ_LENGTH    = 10
    TOTAL_LENGTH  = PREFIX_LENGTH + SEQ_LENGTH
    MAX_SEQ       = BASE**10
    MIN_INC       = 33
    MAX_INC       = 333
    INC = MAX_INC - MIN_INC
    SUFFIX = ('%s' * 10)

    def initialize
      @prand    = Random.new
      @seq      = @prand.rand(MAX_SEQ)
      @inc      = MIN_INC + @prand.rand(INC)
      @prefix   = ''

      @s_10     = nil
      @s_09     = nil
      @s_08     = nil
      @s_07     = nil
      @s_06     = nil
      @s_05     = nil
      @s_04     = nil
      @s_03     = nil
      @s_02     = nil
      @s_01     = nil

      @s_09_seq = nil
      @s_08_seq = nil
      @s_07_seq = nil
      @s_06_seq = nil
      @s_05_seq = nil
      @s_04_seq = nil
      @s_03_seq = nil
      @s_02_seq = nil
      @s_01_seq = nil
      randomize_prefix!
    end

    def next
      @seq += @inc
      if @seq >= MAX_SEQ
        randomize_prefix!
        reset_sequential!
        # TODO: Should also reset the memoized values
      end
      l = @seq

      # Check if no change in the base, meaning that would have
      # a memoized version of the complete prefix already.
      s_10 = DIGITS[l % BASE]

      # This one almost never is going to be repeated so just skip
      l /= BASE
      s_09 = DIGITS[l % BASE]

      # Memoization check
      l /= BASE
      s_08 = DIGITS[l % BASE]
      if @s_09_seq and l == @s_09_seq
        return "#{@s_07}#{s_08}#{s_09}#{s_10}"
      end
      @s_09_seq = l

      l /= BASE
      s_07 = DIGITS[l % BASE]
      # puts "#{l} || #{@s_08_seq}"
      if @s_08_seq and l == @s_08_seq
        return "#{@s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      else
        @s_08_seq = l
      end

      l /= BASE
      s_06 = DIGITS[l % BASE]
      # if @s_07_seq and l == @s_07_seq
      #   return "#{@s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      # end
      # @s_07_seq = l

      l /= BASE
      s_05 = DIGITS[l % BASE]
      # puts "#{l} || #{@s_06_seq}"
      # if @s_06_seq and l == @s_06_seq
      #   return "#{@s_04}#{s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      #   # puts "=== #{@s_04}#{s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      # else
      #   @s_06_seq = l
      # end

      l /= BASE
      s_04 = DIGITS[l % BASE]
      # if @s_05_seq and l == @s_05_seq
      #   return "#{@s_03}#{s_04}#{s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      # end
      # @s_05_seq = l

      l /= BASE
      s_03 = DIGITS[l % BASE]
      # if @s_04_seq and l == @s_04_seq
      #   return "#{@s_02}#{s_03}#{s_04}#{s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      # end
      # @s_04_seq = l

      l /= BASE
      s_02 = DIGITS[l % BASE]
      # if @s_03_seq and l == @s_03_seq
      #   return "#{@s_01}#{s_02}#{s_03}#{s_04}#{s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      # end
      # @s_03_seq = l

      l /= BASE
      s_01 = DIGITS[l % BASE]
      # if @s_02_seq and l == @s_02_seq
      #   return "#{s_01}#{s_02}#{s_03}#{s_04}#{s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
      # end
      # @s_02_seq = l

      # Could not memoize anything, so memoize everything so far
      # s_01 = DIGITS[l % BASE]
      # p "#{@s_10} -- #{a_09} | #{a_08} | #{a_07} | #{a_06} | #{a_05} | #{a_04} | #{a_03} | #{a_02}"

      # Memoize the versions so far.
      @s_01 = "#{@prefix}#{s_01}"
      @s_02 = "#{@prefix}#{s_01}#{s_02}"
      @s_03 = "#{@prefix}#{s_01}#{s_02}#{s_03}"
      @s_04 = "#{@prefix}#{s_01}#{s_02}#{s_03}#{s_04}"
      @s_05 = "#{@prefix}#{s_01}#{s_02}#{s_03}#{s_04}#{s_05}"
      @s_06 = "#{@prefix}#{s_01}#{s_02}#{s_03}#{s_04}#{s_05}#{s_06}"
      @s_07 = "#{@prefix}#{s_01}#{s_02}#{s_03}#{s_04}#{s_05}#{s_06}#{s_07}"
      @s_08 = "#{@prefix}#{s_01}#{s_02}#{s_03}#{s_04}#{s_05}#{s_06}#{s_07}#{s_08}"
      return "#{@prefix}#{s_01}#{s_02}#{s_03}#{s_04}#{s_05}#{s_06}#{s_07}#{s_08}#{s_09}#{s_10}"
    end

    def randomize_prefix!
      @prefix = \
      SecureRandom.random_bytes(PREFIX_LENGTH).each_byte
        .reduce('') do |prefix, n|
        prefix << DIGITS[n % BASE]
      end
    end

    private

    def reset_sequential!
      @seq = @prand.rand(MAX_SEQ)
      @inc = MIN_INC + @prand.rand(INC)
    end

    class << self
      @@nuid = NUID.new.extend(MonitorMixin)
      def next
        @@nuid.synchronize do
          @@nuid.next
        end
      end
    end
  end
end
