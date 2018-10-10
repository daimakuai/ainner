require "ainner"

include Ainner

module Ainner
  extend self

  def root
    Pathname(".").join("spec/fixtures").expand_path
  end
end
