# -*- coding: utf-8 -*-
require 'fluent-logger'

module ActFluentLoggerRails

  class Logger < ::ActiveSupport::TaggedLogging
    def initialize(config_file = Rails.root.join("config", "fluent-logger.yml"))
      fluent_config = YAML.load(ERB.new(config_file.read).result)[Rails.env]
      @settings = {
        tag:  fluent_config['tag'],
        host: fluent_config['fluent_host'],
        port: fluent_config['fluent_port'],
        messages_type: fluent_config['messages_type'],
        add_host: fluent_config['add_host'],
        add_stage: fluent_config['add_stage'],
        every_flush: fluent_config['every_flush']
      }
      @level = SEV_LABEL.index(Rails.application.config.log_level.to_s.upcase)
      super(::ActFluentLoggerRails::FluentLogger.new(@settings, @level))
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if severity < @level
      message = (block_given? ? block.call : progname) if message.blank?
      return true if message.blank?
      @logger.add_message(severity, message, progname)
      true
    end

    def tagged(*tags)
      super(*tags)
    ensure
      @logger.flush
    end

    def info(msg = nil)
      super
      @logger.flush if @settings[:every_flush]
    end

    def error(msg = nil)
      super
      @logger.flush if @settings[:every_flush]
    end

    def fatal(msg = nil)
      super
      @logger.flush if @settings[:every_flush]
    end

    def debug(msg = nil)
      super
      @logger.flush if @settings[:every_flush]
    end

    def warn(msg = nil)
      super
      @logger.flush if @settings[:every_flush]
    end

    # Severity label for logging. (max 5 char)
    SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)
  end

  class FluentLogger < ActiveSupport::BufferedLogger
    def initialize(options, level=DEBUG)
      self.level = level
      port    = options[:port]
      host    = options[:host]
      @messages_type = (options[:messages_type] || :array).to_sym
      @tag = options[:tag]
      @hostname = Socket.gethostname
      @stage = Rails.env
      @fluent_logger = ::Fluent::Logger::FluentLogger.new(nil, host: host, port: port)
      @severity = 0
      @messages = []
      @add_host = options[:add_host]
      @add_stage = options[:add_stage]
    end

    def add_message(severity, message, progname)
      @severity = severity if @severity < severity
      @progname = (message != progname) ? progname : nil
      if message.encoding == Encoding::UTF_8
        @messages << message
      else
        @messages << message.to_s.dup.force_encoding(Encoding::UTF_8)
      end
    end

    def flush
      return if @messages.empty?
      message = @messages_type == :string ? @messages.join("\n") : @messages
      record = { message: message, level: format_severity(@severity) }
      record[:hostname] = @hostname if @add_host
      record[:stage] = @stage if @add_stage
      record[:progname] = @progname if @progname

      @fluent_logger.post(@tag, record)
      @severity = 0
      @messages.clear
    end

    def close
      @fluent_logger.close
    end

    def level
      @level
    end

    def level=(l)
      @level = l
    end

    def format_severity(severity)
      ActFluentLoggerRails::Logger::SEV_LABEL[severity] || 'ANY'
    end
  end
end
