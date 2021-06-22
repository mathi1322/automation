require "yaml"

class Constants
  def self.method_missing(method_name, *args, &block)
    @@CONSTANTS ||= YAML.load(File.read("constants.yaml")).to_ostruct
    @@CONSTANTS.public_send(method_name, *args, &block)
  end
end
