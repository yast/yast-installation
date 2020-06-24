#! /usr/bin/env rspec

require_relative "./test_helper"

# 'require' only works with '.rb' files
memsample_rb = File.expand_path("../bin/memsample-archive-to-csv", __dir__)
load memsample_rb unless defined?(MemsampleCsv)

require "stringio"

data_fn = "#{FIXTURES_DIR}/memsample.cat"

describe MemsampleCsv do
  describe "#write_csv" do
    it "converts sample data correctly" do
      output = StringIO.new
      File.open(data_fn, "r") do |input|
        m = MemsampleCsv.new(input)
        m.write_csv(output)
      end

      expected = <<EOS
disk_total_k,disk_used_k,disk_free_k,mem_total_k,mem_used_k,mem_free_k,swap_total_k,swap_used_k,swap_free_k,rss,rss_all,datetime
993988,271400,722588,993988,112980,236960,0,0,0,0,0,2020-06-23T09:07:09+00:00
993988,216440,777548,993988,247556,285220,1334248,0,1334248,179772,182052,2020-06-23T09:08:52+00:00
EOS

      expect(output.string).to eq expected
    end

    it "reports error when it cannot parse the data" do
      input = StringIO.new("nobody expects the Spanish inquisition")
      output = StringIO.new
      m = MemsampleCsv.new(input)

      expect { m.write_csv(output) }.to raise_error(StandardError)
    end
  end
end
