module Automation
  class InvalidPage < StandardError
    def initialize(message)
      super(message)
    end
  end
end
