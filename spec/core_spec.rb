require_relative 'spec_helper'

RSpec.describe 'MusicalDSL::Lang::Core' do
  # helper class that mixes in the DSL core and gives access to context
  class TestDSL
    include MusicalDSL::Lang::Core
    def initialize(context)
      @context = context
    end
  end

  let(:context) { MusicalDSL::Context.new }
  let(:dsl) { TestDSL.new(context) }

  before do
    # Avoid real sleeping inside espere by stubbing wait_seconds where tests need it.
    allow(context).to receive(:wait_seconds).and_return(true)
  end

  describe '#defina' do
    it 'define função no contexto quando não está em execução' do
      dsl.defina(:minha_func) { :ok }
      expect(context.function_exists?(:minha_func)).to be true
    end

    it 'levanta ErroSemantico se chamada durante execução' do
      context.enter_execution
      expect { dsl.defina(:f) { } }.to raise_error(MusicalDSL::ErroSemantico)
      context.exit_execution
    end
  end

  describe '#use_bpm' do
    it 'altera bpm válido e emite evento' do
      dsl.use_bpm(120)
      expect(context.bpm).to eq(120)
      snap = context.events_snapshot
      # verifica que houve um evento set_bpm (último evento)
      expect(snap.last[:type]).to eq("set_bpm")
      expect(snap.last[:data]).to include(:bpm)
    end

    it 'rejeita valores <= 0' do
      expect { dsl.use_bpm(0) }.to raise_error(MusicalDSL::ErroSemantico, /BPM deve ser maior que zero/)
    end

    it 'rejeita fora do intervalo' do
      expect { dsl.use_bpm(10) }.to raise_error(MusicalDSL::ErroSemantico, /BPM fora do intervalo permitido \(20-300\)/)
    end

    it 'aceita strings numericas convertíveis' do
      dsl.use_bpm('90')
      expect(context.bpm).to eq(90)
    end
  end

  describe '#toque' do
    it 'levanta ErroDeUso quando usado fora de execução' do
      expect { dsl.toque(:DO) }.to raise_error(MusicalDSL::ErroDeUso)
    end 

    it 'emite evento play para nota única quando em execução' do
      context.enter_execution
      dsl.toque('DO4', 1)
      snap = context.events_snapshot
      expect(snap.last[:type]).to eq("play")
      expect(snap.last[:data]).to include(:note, :duration)
      context.exit_execution
    end

    it 'emite multiplos eventos para acordes (lista de notas)' do
      context.enter_execution
      dsl.toque(['DO4', 'RE4'], 0.5)
      # espera pelo menos dois eventos play adicionados (pode haver outros eventos)
      plays = context.events_snapshot.select { |e| e[:type] == "play" }
      expect(plays.length).to be >= 2
      context.exit_execution
    end

    it 'retorna sem emitir se context.halted? for true' do
      context.enter_execution
      allow(context).to receive(:halted?).and_return(true)
      expect { dsl.toque(:DO) }.not_to change { context.events_snapshot.length }
      context.exit_execution
    end

    it 'valida duração > 0' do
      context.enter_execution
      expect { dsl.toque(:DO, 0) }.to raise_error(MusicalDSL::ErroSemantico, /A duracao do toque deve ser maior que zero/)
      context.exit_execution
    end
  end

  describe '#espere' do
    it 'emite sleep e avança current_beat' do
      context.enter_execution
      allow(context).to receive(:bpm).and_return(120)
      expect {
        dsl.espere(2)
      }.to change { context.current_beat }.by(2.0)
      context.exit_execution
    end

    it 'levanta ErroDeUso se usado fora de execução' do
      expect { dsl.espere(1) }.to raise_error(MusicalDSL::ErroDeUso)
    end

    it 'levanta ErroSemantico se duration <= 0' do
      context.enter_execution
      expect { dsl.espere(0) }.to raise_error(MusicalDSL::ErroSemantico)
      context.exit_execution
    end
  end

  describe 'loops (vezes / ciclo / executar_loop)' do
    it 'vezes executa o bloco n vezes e chama enter/exit execution' do
      # ensure root loop not started
      expect(context.root_loop_started?).to be false
      call_count = 0
      allow(context).to receive(:halted?).and_return(false)
      # current_beat must advance inside the block to avoid semantic error
      dsl.vezes(3) { call_count += 1; context.advance_time(1) }
      expect(call_count).to eq(3)
    end

    it 'levanta ErroSemantico se tentar declarar mais de um loop raiz' do
      # simulate root loop already started
      context.mark_root_loop
      expect { dsl.ciclo { context.advance_time(1) } }.to raise_error(MusicalDSL::ErroSemantico)
    end

    it 'valida proteção: loop sem avanço de tempo' do
      # when block doesn't advance time, should raise semantic error
      expect {
        dsl.vezes(1) { } # bloco que não avança tempo
      }.to raise_error(MusicalDSL::ErroSemantico)
    end
  end

  describe '#uma_em' do
    it 'retorna true quando rand devolve 1' do
      allow(dsl).to receive(:rand).with(1..3).and_return(1)
      expect(dsl.uma_em(3)).to be true
    end

    it 'retorna false quando rand devolve >1' do
      allow(dsl).to receive(:rand).with(1..5).and_return(3)
      expect(dsl.uma_em(5)).to be false
    end

    it 'valida n >= 1' do
      expect { dsl.uma_em(0) }.to raise_error(MusicalDSL::ErroSemantico, /`uma_em` requer n >= 1/)
    end
  end

  describe '#pare' do
    it 'chama context.halt! quando em execução' do
      context.enter_execution
      expect(context).to receive(:halt!)
      dsl.pare
      context.exit_execution
    end

    it 'levanta ErroDeUso se usado fora de execução' do
      expect { dsl.pare }.to raise_error(MusicalDSL::ErroDeUso)
    end
  end

  describe '#escolha' do
    it 'retorna um elemento da lista' do
      result = dsl.escolha([:a, :b, :c])
      expect([:a, :b, :c]).to include(result)
    end

    it 'levanta ErroDeSintaxe se lista vazia' do
      expect { dsl.escolha([]) }.to raise_error(MusicalDSL::ErroDeSintaxe)
    end
  end

  describe 'user-defined functions (method_missing)' do
    it 'chama função definida no context se existir' do
      # define a function using the DSL
      dsl.defina(:minha_func) { context.advance_time(1) }
      context.enter_execution
      expect {
        dsl.minha_func
      }.to change { context.current_beat }.by(1.0)
      context.exit_execution
    end

    it 'levanta ErroDeUso se função for chamada fora de execução' do
      dsl.defina(:f) { }
      # ensure not in execution
      expect { dsl.f }.to raise_error(MusicalDSL::ErroDeUso)
    end

    it 'lança NoMethodError para função inexistente' do
      context.enter_execution
      expect { dsl.nao_existe }.to raise_error(NoMethodError)
      context.exit_execution
    end
  end
end
