require 'thread'

module MusicalDSL
  class Context
    attr_reader :current_beat, :bpm, :events
    attr_accessor :stop_loop

    def initialize
      @current_beat = 0.0
      @bpm = 60
      @events = []
      @functions = {}

      @execution_depth = 0
      @root_loop_started = false
      @top_level_bpm_defined = false
      @halted = false

      @mutex = Mutex.new
      @cv = ConditionVariable.new
      @next_event_id = 1
      
      # MusicalDSL::LOGGER.debug("[CONTEXT] Initialized (bpm=#{@bpm})")
    end

    # =========================
    # EXECUÇÃO
    # =========================

    def enter_execution
      @mutex.synchronize do
        @execution_depth += 1
        # MusicalDSL::LOGGER.debug("[CONTEXT] enter_execution depth=#{@execution_depth}")
      end
    end

    def exit_execution
      @mutex.synchronize do
        @execution_depth -= 1 if @execution_depth > 0
        # MusicalDSL::LOGGER.debug("[CONTEXT] exit_execution depth=#{@execution_depth}")
      end
    end

    def in_execution?
      @mutex.synchronize do
        in_exec = @execution_depth > 0
        # MusicalDSL::LOGGER.debug("[CONTEXT] in_execution? = #{in_exec} (depth=#{@execution_depth})")
        in_exec
      end
    end

    # =========================
    # LOOP RAIZ
    # =========================

    def mark_root_loop
      @mutex.synchronize do 
      @root_loop_started = true
      # MusicalDSL::LOGGER.debug("[CONTEXT] mark_root_loop")
      end
    end

    def root_loop_started?
      @mutex.synchronize do
      # MusicalDSL::LOGGER.debug("[CONTEXT] root_loop_started? = #{@root_loop_started}")
      @root_loop_started
      end
    end

    # =========================
    # BPM SEMÂNTICO (TOP-LEVEL)
    # =========================

    def top_level_bpm_defined?
      @mutex.synchronize { @top_level_bpm_defined }
    end

    def mark_top_level_bpm!
      @mutex.synchronize { @top_level_bpm_defined = true }
    end

    # =========================
    # TEMPO MUSICAL
    # =========================

    def advance_time(beats)
      @mutex.synchronize do
        old_beat = @current_beat
        @current_beat += beats.to_f
        # MusicalDSL::LOGGER.debug("[CONTEXT] advance_time(#{beats}) #{old_beat} → #{@current_beat}")
      end
    end

    # =========================
    # BPM
    # =========================

    def set_bpm(n)
      @mutex.synchronize do
        old_bpm = @bpm
        @bpm = n.to_i
        # MusicalDSL::LOGGER.debug("[CONTEXT] set_bpm: #{old_bpm} → #{@bpm}")
      end
    end

    # =========================
    # EVENTOS
    # =========================

    def emit(type, data = {})
      @mutex.synchronize do
        event_id = @next_event_id
        @events << Event.new(id: event_id, time: @current_beat, type: type, data: data)
        @next_event_id += 1
        # MusicalDSL::LOGGER.debug("[CONTEXT] emit(type=#{type}, time=#{@current_beat}) id=#{event_id} data=#{data.inspect}")
      end
    end

    def events_snapshot
      @mutex.synchronize do
        snapshot = @events.map(&:to_h)
        # MusicalDSL::LOGGER.debug("[CONTEXT] events_snapshot returned #{snapshot.length} events")
        snapshot
      end
    end

    def events_since(since_id)
      @mutex.synchronize do
        new_events = @events.select { |e| e.id > since_id }
        # MusicalDSL::LOGGER.debug("[CONTEXT] events_since(#{since_id}) returned #{new_events.length} new events (total=#{@events.length})")
        new_events.map(&:to_h)
      end
    end

    # =========================
    # FUNÇÕES
    # =========================

    def define_function(name, block)
      @mutex.synchronize do
        @functions[name.to_sym] = block
        # MusicalDSL::LOGGER.debug("[CONTEXT] define_function(#{name.inspect})")
      end
    end

    def function_exists?(name)
      @mutex.synchronize do
        exists = @functions.key?(name.to_sym)
        # MusicalDSL::LOGGER.debug("[CONTEXT] function_exists?(#{name.inspect}) = #{exists}")
        exists
      end
    end

    def call_function(name, *args)
      func = nil
      @mutex.synchronize { func = @functions[name.to_sym] }
      if func
        # MusicalDSL::LOGGER.debug("[CONTEXT] call_function(#{name.inspect}) with args=#{args.inspect}")
        func.call(*args)
      else
        # MusicalDSL::LOGGER.warn("[CONTEXT] call_function(#{name.inspect}) - function not found!")
      end
    end

    # =========================
    # CONTROLE
    # =========================

    # Espera interrompível em segundos. Retorna true se esperou o tempo completo, false se acordou cedo via stop_loop.
    def wait_seconds(seconds)
      seconds = seconds.to_f
      # MusicalDSL::LOGGER.debug("[CONTEXT] wait_seconds(#{seconds}s) starting")
      
      return true if seconds <= 0.0

      start = Time.now
      @mutex.synchronize do
        while !@stop_loop
          elapsed = Time.now - start
          remaining = seconds - elapsed
          
          # MusicalDSL::LOGGER.debug("[CONTEXT] wait_seconds loop: elapsed=#{elapsed.round(3)}s remaining=#{remaining.round(3)}s stop_loop=#{@stop_loop}")
          
          break if remaining <= 0.0
          @cv.wait(@mutex, remaining)
        end
        
        total_waited = (Time.now - start)
        completed = total_waited >= seconds
        # MusicalDSL::LOGGER.debug("[CONTEXT] wait_seconds completed (waited=#{total_waited.round(3)}s stop_loop=#{@stop_loop})")
        completed && !@stop_loop
      end
    end

    def halt!
      @mutex.synchronize do
        return if @halted

        @halted = true
        # MusicalDSL::LOGGER.info("[CONTEXT] halt! requested")
        @cv.broadcast
      end
    end

    def halted?
      @mutex.synchronize do
        # MusicalDSL::LOGGER.debug("[CONTEXT] halted? = #{@halted}")
        @halted
      end
    end

    def reset!
      bpm = nil

      @mutex.synchronize do
        @beat = 0
        @bpm  = 60
        # MusicalDSL::LOGGER.info("[CONTEXT] reset! (beat=0 bpm=#{@bpm})")
      end

      # 🚨 FORA do mutex
      emit(
        type: :runtime_start,
        time: 0.0,
        data: { bpm: @bpm }
      )
    end

  end
end