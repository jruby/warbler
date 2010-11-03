require "test/unit"
require "sample_jar"

class TestSampleJar < Test::Unit::TestCase
  def test_sanity
    SampleJar.hello
  end
end
