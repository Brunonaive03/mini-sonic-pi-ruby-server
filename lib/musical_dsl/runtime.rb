require_relative "lang/core"
require_relative "context"
require_relative "parser"

module MusicalDSL
  class Runtime
    include MusicalDSL::Lang::Core

    # Registry (class-level)
    @runtimes = {}
    @next_id = 1
    class << self
      def register(runtime)
        id = (@next_id += 1) - 1
        @runtimes[id] = runtime
        runtime.instance_variable_set(:@id, id)
        MusicalDSL::LOGGER.info("[RUNTIME_REGISTRY] Registered runtime id=#{id}")
        id
      end

      def fetch(id)
        runtime = @runtimes[id]
        MusicalDSL::LOGGER.debug("[RUNTIME_REGISTRY] Fetched runtime id=#{id} found=#{!runtime.nil?}")
        runtime
      end

      def unregister(id)
        @runtimes.delete(id)
        MusicalDSL::LOGGER.info("[RUNTIME_REGISTRY] Unregistered runtime id=#{id}")
      end

      def last
        @runtimes.values.last
      end

      def runtimes
        @runtimes
      end
    end

    attr_reader :context, :thread, :error, :id

    def initialize
      @context = Context.new
      @error = nil
      @thread = nil
      @id = nil
      MusicalDSL::LOGGER.debug("[RUNTIME] New instance created")
    end

    # Start running code in a background thread (streaming)
    def start(code)
      @error = nil
      MusicalDSL::LOGGER.info("[RUNTIME] Starting execution in background thread")
      MusicalDSL::LOGGER.debug("[RUNTIME] Code to execute:\n#{code}")
      
      @thread = Thread.new do
        begin
          @context.reset!

          MusicalDSL::LOGGER.info("[RUNTIME_THREAD] Thread started (id=#{@id})")
          instance_variable_set(:@context, @context)
          
          parser = Parser.new
          parser.validate_blocks!(code)
          ruby_code = parser.preprocess(code)
          
          MusicalDSL::LOGGER.debug("[RUNTIME_THREAD] About to instance_eval preprocessed code")
          instance_eval(ruby_code, "(musical_dsl)")
          
          MusicalDSL::LOGGER.info("[RUNTIME_THREAD] Code execution completed naturally")
          @context.emit(:runtime_end, reason: "completed")
        rescue => e
          @error = e

          MusicalDSL::LOGGER.error("[RUNTIME_THREAD] ERROR: #{e.class}: #{e.message}")
          MusicalDSL::LOGGER.debug("[RUNTIME_THREAD] Backtrace:\n#{e.backtrace.join("\n")}")

          emit_runtime_error(e)

          @context.emit(:runtime_end, reason: "error")

        ensure
          MusicalDSL::LOGGER.info("[RUNTIME_THREAD] Thread exiting (id=#{@id})")
        end
      end
      
      MusicalDSL::LOGGER.info("[RUNTIME] Background thread created (tid=#{@thread.object_id})")
      self
    end

    def stop
      MusicalDSL::LOGGER.info("[RUNTIME] Stop requested (id=#{@id})")

      return unless @thread&.alive?

      # Interrupção cooperativa da DSL
      @context.halt!

      # Aguarda finalização graciosa
      joined = @thread.join(2.0)

      unless joined
        MusicalDSL::LOGGER.warn("[RUNTIME] Thread join timeout, force kill")
        @thread.kill
        @context.emit(:runtime_end, reason: "killed")
      end
    end

    def alive?
      alive = @thread && @thread.alive?
      MusicalDSL::LOGGER.debug("[RUNTIME] alive? check (id=#{@id}) = #{alive}")
      alive
    end

    def bpm
      bpm_val = @context.bpm
      MusicalDSL::LOGGER.debug("[RUNTIME] bpm query = #{bpm_val}")
      bpm_val
    end

    # helper to expose events (thread-safe via Context)
    def events_since(since_id)
      events = @context.events_since(since_id)
      MusicalDSL::LOGGER.debug("[RUNTIME] events_since(#{since_id}) returned #{events.length} events")
      events
    end

    def events_all
      events = @context.events_snapshot
      MusicalDSL::LOGGER.debug("[RUNTIME] events_all returned #{events.length} events")
      events
    end

    def map_error(error)
      case error
      when MusicalDSL::ErroDeSintaxe
        {
          category: :dsl_sintaxe,
          code: :erro_sintaxe,
          message: error.message
        }

      when MusicalDSL::ErroSemantico
        {
          category: :dsl_semantica,
          code: :erro_semantico,
          message: error.message
        }

      when MusicalDSL::ErroDeUso
        {
          category: :dsl_uso,
          code: :erro_uso,
          message: error.message
        }

      else
        {
          category: :tecnico,
          code: :erro_interno,
          message: "Erro interno na execução da linguagem"
        }
      end
    end

    def extract_error_line(error)
      return error.line if error.respond_to?(:line)

      return nil unless error.backtrace

      error.backtrace.each do |frame|
        if frame =~ /\(musical_dsl\):(\d+)/
          return Regexp.last_match(1).to_i
        end
      end

      nil
    end

    def emit_runtime_error(error)
      mapped = map_error(error)
      line = extract_error_line(error)

      @context.emit(
        :runtime_error,
        category: mapped[:category],
        code: mapped[:code],
        message: mapped[:message],
        line: line
      )
    end

  end
end