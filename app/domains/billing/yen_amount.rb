module Billing
  class YenAmount
    attr_reader :value

    def initialize(value)
      unless value.is_a?(Integer)
        raise ArgumentError, "yen amount must be an Integer"
      end
      if value.negative?
        raise ArgumentError, "yen amount must be non-negative"
      end

      @value = value
      freeze
    end

    def +(other)
      self.class.new(@value + coerce(other).value)
    end

    def -(other)
      self.class.new(@value - coerce(other).value)
    end

    def ==(other)
      other.is_a?(self.class) && other.value == @value
    end

    alias eql? ==

    def hash
      [ self.class, @value ].hash
    end

    def to_i
      @value
    end

    private

    def coerce(other)
      return other if other.is_a?(self.class)

      raise TypeError, "expected #{self.class.name}, got #{other.class.name}"
    end
  end
end
