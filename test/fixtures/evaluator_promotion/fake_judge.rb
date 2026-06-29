# frozen_string_literal: true

require "json"
require "rbconfig"

mode = ARGV.shift
bundle_path = ARGV.shift

def passing_results(bundle_path)
  bundle = JSON.parse(File.read(bundle_path))
  bundle.fetch("cases").map do |example|
    {
      "case_id" => example.fetch("case_id"),
      "findings" => example.fetch("promotion_checks").fetch("must_catch"),
      "dimension_scores" => {
        "boundary_fit" => 1.0,
        "novelty" => 1.0,
        "operability" => 1.0,
        "maintenance_cost" => 0.2,
      },
    }
  end
end

case mode
when "pass", "no-rationale"
  puts JSON.generate("results" => passing_results(bundle_path), "bundle_path_seen" => bundle_path)
when "malformed"
  puts "{"
when "wrong-shape"
  puts JSON.generate("results" => {})
when "top-array"
  puts JSON.generate([])
when "background-pipe"
  Process.spawn(RbConfig.ruby, "-e", "sleep 5")
  STDOUT.write(JSON.generate("results" => passing_results(bundle_path)))
  STDOUT.write("\n")
  STDOUT.flush
  exit!(0)
when "sleep"
  sleep 5
when "echo-arg"
  puts JSON.generate("argv_tail" => ARGV)
else
  warn "unknown fake judge mode: #{mode}"
  exit 65
end
