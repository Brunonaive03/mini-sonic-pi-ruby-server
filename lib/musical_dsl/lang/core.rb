module MusicalDSL
  module Lang
    module Core
      def context
        @context
      end

      # =========================
      # DEFINIÇÃO DE FUNÇÕES
      # =========================

      def defina(name, &block)
        # MusicalDSL::LOGGER.info("[DSL:defina] Defining function: #{name.inspect}")
        raise MusicalDSL::ErroDeSintaxe, "`defina` requer um nome e um bloco" unless name && block
        
        # Regra semântica:
        # Funções não podem ser definidas durante a execução musical
        if context.in_execution?
          raise MusicalDSL::ErroSemantico, "Funcoes devem ser definidas antes da execucao musical"
        end

        context.define_function(name.to_sym, block)
        # MusicalDSL::LOGGER.debug("[DSL:defina] Function stored in context: #{name.inspect}")
      end

      # =========================
      # BPM
      # =========================

      def use_bpm(bpm)
        # MusicalDSL::LOGGER.info("[DSL:use_bpm] Called with bpm=#{bpm}")
        bpm = Integer(bpm)
        
        # Validação defensiva do intervalo permitido para ser valor de BPM
        raise MusicalDSL::ErroSemantico, "BPM deve ser maior que zero" if bpm <= 0
        raise MusicalDSL::ErroSemantico, "BPM fora do intervalo permitido (20-300)" if bpm < 20 || bpm > 300

          
        if !context.in_execution?

          if context.root_loop_started?
            raise MusicalDSL::ErroSemantico, "`use_bpm` não pode ser usado após o loop raiz"
          end

          if context.top_level_bpm_defined?
            raise MusicalDSL::ErroSemantico, "`use_bpm` só pode ser definido UMA vez no nível raiz"
          end

          context.mark_top_level_bpm!
        end

        context.set_bpm(bpm)
        context.emit(:set_bpm, bpm: bpm)
      end

      # =========================
      # TOQUE
      # =========================

      def toque(note, duration = 1.0, **kwargs)
        # MusicalDSL::LOGGER.info("[DSL:toque] Called | note=#{note.inspect} duration=#{duration}")

        unless context.in_execution?
          # MusicalDSL::LOGGER.error("[DSL:toque] Not in execution context!")
          raise MusicalDSL::ErroDeUso, "`toque` so pode ser executado dentro de `ciclo` ou `vezes`"
        end

        return if context.halted?

        duration = duration.to_f
        raise MusicalDSL::ErroSemantico, "A duracao do toque deve ser maior que zero" if duration <= 0
        

        # A função suporta listas de notas, que são tocadas de forma simultânea (acordes)
        notes =
          if note.is_a?(Array)
            note
          else
            [note]
          end

        notes.each do |n|
          midi_note = NoteConverter.to_midi(n)
          context.emit(
            :play,
            { note: midi_note, duration: duration.to_f }.merge(kwargs)
          )

          # MusicalDSL::LOGGER.debug("[DSL:toque] Play event emitted | note=#{midi_note} duration=#{duration}")
        end
      end

      # =========================
      # ESPERE
      # =========================

      def espere(duration)
        # MusicalDSL::LOGGER.info("[DSL:espere] Called | duration=#{duration}")
        
        unless context.in_execution?
          # MusicalDSL::LOGGER.error("[DSL:espere] Not in execution context!")
          raise MusicalDSL::ErroDeUso, "`espere` só pode ser executado dentro de `ciclo` ou `vezes`"
        end

        beats = duration.to_f
        raise MusicalDSL::ErroSemantico, "A duraçao de `espere` deve ser maior que zero" if beats <= 0
        context.emit(:sleep, duration: beats)
        
        return if context.halted?

        seconds = (60.0 / context.bpm) * beats
        # MusicalDSL::LOGGER.debug("[DSL:espere] Waiting | beats=#{beats} seconds=#{seconds.round(3)} bpm=#{context.bpm}")
        
        context.wait_seconds(seconds)
        context.advance_time(beats)
      end

      # =========================
      # LOOPS
      # =========================


      def ciclo(&block)
        # MusicalDSL::LOGGER.info("[DSL:ciclo] Starting infinite loop")
        raise MusicalDSL::ErroDeSintaxe, "`ciclo` requer um bloco" unless block
        executar_loop(infinite: true, &block)
      end

      def vezes(n, &block)
        # MusicalDSL::LOGGER.info("[DSL:vezes] Starting #{n} repetitions")
        raise MusicalDSL::ErroDeSintaxe, "`vezes` requer um bloco" unless block

        n = n.to_i
        raise "vezes requer n >= 1" if n < 1

        executar_loop(infinite: false, repetitions: n, &block)
      end

      def executar_loop(infinite:, repetitions: nil, &block)
        # Regra semântica central:
        # Apenas UM loop raiz pode existir
        if !context.in_execution? && context.root_loop_started?
          raise MusicalDSL::ErroSemantico, "So e permitido um unico loop raiz no programa"
        end

        if !context.in_execution? && !context.top_level_bpm_defined?
          raise MusicalDSL::ErroSemantico, "E necessario definir o valor global de BPM uma unica vez fora do loop raiz com `usa_bpm` para rodar o programa"
        end

        context.mark_root_loop if !context.in_execution?

        context.enter_execution
        iterations = 0

        begin
          loop do
            break if context.halted?
            break if !infinite && iterations >= repetitions

            beat_antes = context.current_beat
            block.call
            beat_depois = context.current_beat

            # Proteção contra loop sem avanço de tempo
            if beat_depois <= beat_antes
              raise MusicalDSL::ErroSemantico, "Loop sem avanco de tempo detectado. Use `espere`"
            end

            iterations += 1
            # MusicalDSL::LOGGER.debug("[DSL:#{infinite ? "ciclo" : "vezes"}] Iteration #{iterations}")
          end
        ensure
          context.exit_execution
          # MusicalDSL::LOGGER.info("[DSL:#{infinite ? "ciclo" : "vezes"}] Loop ended after #{iterations} iterations")
        end
      end

      # =========================
      # CONTROLE
      # =========================

      def uma_em(n)
        raise MusicalDSL::ErroSemantico, "`uma_em` requer n >= 1" if n < 1
        result = rand(1..n) == 1
        # MusicalDSL::LOGGER.debug("[DSL:uma_em] Random check | n=#{n} result=#{result}")
        result
      end

      def pare
        # MusicalDSL::LOGGER.info("[DSL:pare] Called")

        unless context.in_execution?
          # MusicalDSL::LOGGER.error("[DSL:pare] Not in execution context!")
          raise MusicalDSL::ErroDeUso, "`pare` so pode ser usado dentro de `ciclo` ou `vezes`"
        end

        context.halt!
      end

      # =========================
      # ESCOLHA
      # =========================
      
      def escolha(notes_list)
        unless notes_list.is_a?(Array) && !notes_list.empty?
          raise MusicalDSL::ErroDeSintaxe, "`escolha` requer uma lista nao vazia"
        end

        choice = notes_list.sample

        # MusicalDSL::LOGGER.debug("[DSL:escolha] Escolhido #{choice.inspect} de #{lista.inspect}")

        choice
      end

      # =========================
      # FUNÇÕES AUXILIRES
      # =========================

      def method_missing(method_name, *args, &block)
        method_sym = method_name.to_sym
        # MusicalDSL::LOGGER.debug("[DSL:method_missing] Called for: #{method_name.inspect} with #{args.length} args")
        
        if context.function_exists?(method_name)
          # MusicalDSL::LOGGER.info("[DSL:method_missing] Found user function: #{method_name.inspect}")
          
          unless context.in_execution?
            # MusicalDSL::LOGGER.error("[DSL:method_missing] Not in execution context for: #{method_name.inspect}")
            raise MusicalDSL::ErroDeUso, "Funcao `#{method_name}` so pode ser executada dentro de `ciclo` ou `vezes`"
          end
          
          # MusicalDSL::LOGGER.debug("[DSL:method_missing] Calling user function: #{method_name.inspect} with args: #{args.inspect}")
          result = context.call_function(method_name, *args)
          # MusicalDSL::LOGGER.debug("[DSL:method_missing] User function completed: #{method_name.inspect}")
          return result
        else
          # MusicalDSL::LOGGER.warn("[DSL:method_missing] Unknown method/function: #{method_name.inspect}")
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        exists = context.function_exists?(method_name)
        # MusicalDSL::LOGGER.debug("[DSL:respond_to_missing?] Checking #{method_name.inspect} | exists=#{exists}")
        exists || super
      end

    end
  end
end