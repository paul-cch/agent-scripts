# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"

module EvaluatorPromotion
  module JudgeCommand
    class ExecutionError < StandardError
      attr_reader :bundle_path

      def initialize(message, bundle_path:)
        @bundle_path = bundle_path
        super(message)
      end
    end

    Result = Struct.new(:status, :payload, :stderr, keyword_init: true) do
      def success?
        status == "ok"
      end
    end
    LAUNCH_ERRORS = [Errno::ENOENT, Errno::EACCES, Errno::EISDIR, Errno::ENOEXEC].freeze

    module_function

    def run(argv:, cases:, timeout_seconds:)
      command = validate_argv!(argv)
      bundle_path = nil

      Tempfile.create(["evaluator-promotion-", ".json"]) do |file|
        bundle_path = file.path
        file.write(JSON.pretty_generate("cases" => cases.map { |example| case_payload(example) }))
        file.flush

        captured = capture(command + [bundle_path], timeout_seconds)
      rescue *LAUNCH_ERRORS => e
        return launch_error_result(command.first, e)
      else
        if captured == :timeout
          return Result.new(
            status: "timeout",
            payload: {
              "error" => "judge command timeout",
              "scores" => { "operability" => 0.0 },
            },
            stderr: "",
          )
        end

        stdout, stderr, process = captured
        return failed_result(stderr, process) unless process.success?

        begin
          payload = JSON.parse(stdout)
        rescue JSON::ParserError => e
          raise ExecutionError.new("invalid judge JSON: #{e.message}", bundle_path: bundle_path)
        end

        Result.new(status: "ok", payload: payload, stderr: stderr)
      ensure
        begin
          File.unlink(bundle_path) if bundle_path
        rescue Errno::ENOENT
        end
      end
    end

    def validate_argv!(argv)
      unless argv.is_a?(Array) && !argv.empty? && argv.all? { |item| item.is_a?(String) && !item.empty? }
        raise ArgumentError, "judge command must be an argv array"
      end

      argv
    end

    def capture(command, timeout_seconds)
      Open3.popen3(*command, pgroup: true) do |stdin, stdout_io, stderr_io, wait_thread|
        stdin.close
        stdout_data = +""
        stderr_data = +""
        pipes = { stdout_io => stdout_data, stderr_io => stderr_data }
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds.to_f
        pgid = process_group_id(wait_thread)

        loop do
          if wait_thread.join(0)
            read_ready_pipes(pipes, pipes.keys)
            close_pipes(pipes)
            terminate_process_group(pgid)
            return [stdout_data, stderr_data, wait_thread.value]
          end

          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if remaining <= 0
            terminate_process_group(pgid, wait_thread: wait_thread)
            close_pipes(pipes)
            return :timeout
          end

          if pipes.empty?
            wait_thread.join([remaining, 0.05].min)
            next
          end

          ready = IO.select(pipes.keys, nil, nil, [remaining, 0.05].min)
          read_ready_pipes(pipes, ready.first) if ready
        end
      end
    end

    def process_group_id(wait_thread)
      Process.getpgid(wait_thread.pid)
    rescue Errno::ESRCH
      wait_thread.pid
    end

    def read_ready_pipes(pipes, ready)
      ready.each do |io|
        loop do
          pipes.fetch(io) << io.read_nonblock(4096)
        rescue IO::WaitReadable
          break
        rescue EOFError
          pipes.delete(io)
          io.close unless io.closed?
          break
        end
      end
    end

    def close_pipes(pipes)
      pipes.keys.each do |io|
        io.close unless io.closed?
      rescue IOError
      ensure
        pipes.delete(io)
      end
    end

    def terminate_process_group(pgid, wait_thread: nil)
      Process.kill("TERM", -pgid)
      return if wait_thread.nil? || wait_thread.join(0.5)

      Process.kill("KILL", -pgid)
      wait_thread.join
    rescue Errno::ESRCH
      wait_thread&.join
    end

      def failed_result(stderr, process)
        Result.new(
          status: "failed",
        payload: {
          "error" => "judge command exited #{process.exitstatus}",
          "scores" => { "operability" => 0.0 },
        },
        stderr: stderr,
        )
      end

      def launch_error_result(command_name, error)
        Result.new(
          status: "failed",
          payload: {
            "error" => "judge command unavailable: #{command_label(command_name)}",
            "scores" => { "operability" => 0.0 },
          },
          stderr: error.message,
        )
      end

      def command_label(command_name)
        return command_name unless command_name.include?(File::SEPARATOR) || command_name.start_with?("~")

        expanded = File.expand_path(command_name)
        cwd = File.expand_path(Dir.pwd)
        return expanded.delete_prefix("#{cwd}#{File::SEPARATOR}") if expanded.start_with?("#{cwd}#{File::SEPARATOR}")

        File.basename(expanded)
      end

      def case_payload(example)
      {
        "case_id" => example.case_id,
        "lane" => example.lane,
        "input_summary" => example.input_summary,
        "authorized_boundary" => example.authorized_boundary,
        "evidence_surfaces" => example.evidence_surfaces,
        "expected_findings" => example.expected_findings,
        "forbidden_findings" => example.forbidden_findings,
        "promotion_checks" => example.promotion_checks,
        "confidentiality_level" => example.confidentiality_level,
        "source_class" => example.source_class,
      }
    end
  end
end
