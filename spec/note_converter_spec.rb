require_relative 'spec_helper'

RSpec.describe MusicalDSL::NoteConverter do
  describe '.to_midi' do
    it 'retorna inteiro quando já é inteiro' do
      expect(described_class.to_midi(60)).to eq(60)
    end

    it 'converte nota PT-BR DO4 para 60 (C4 = 60)' do
      expect(described_class.to_midi('DO4')).to eq(60)
    end

    it 'converte nota inglesa C4 para 60' do
      expect(described_class.to_midi('C4')).to eq(60)
    end

    it 'converte sustenido/bemol e oitava' do
      expect(described_class.to_midi('REs4')).to be_a(Integer)
      expect(described_class.to_midi('As3')).to be_a(Integer)
    end

    it 'lanca ErroDeUso em formato inválido' do
      expect { described_class.to_midi('nota-invalida') }.to raise_error(MusicalDSL::ErroDeUso)
    end

    it 'lanca ErroDeUso para nota desconhecida' do
      expect { described_class.to_midi('X4') }.to raise_error(MusicalDSL::ErroDeUso)
    end
  end
end
