require_relative 'spec_helper'

RSpec.describe MusicalDSL::Parser do
  let(:parser) { described_class.new }

  describe "#preprocess" do
    it "traduz ciclo faca e fim para sintaxe Ruby" do
      code = <<~DSL
        ciclo faca
          toque :c4
        fim
      DSL

      result = parser.preprocess(code)

      expect(result).to include("ciclo do")
      expect(result).to include("end")
    end

    it "traduz repetição localizada n.vezes faca para vezes(n) do" do
      code = <<~DSL
        3.vezes faca
          toque :d4
        fim
      DSL

      result = parser.preprocess(code)

      expect(result).to include("vezes(3) do")
      expect(result).to include("end")
    end

    it "traduz estruturas condicionais localizadas" do
      code = <<~DSL
        se uma_em(2)
          toque :e4
        senao
          toque :c4
        fim
      DSL

      result = parser.preprocess(code)

      expect(result).to include("if uma_em(2)")
      expect(result).to include("else")
      expect(result).to include("end")
    end

    it "nao altera palavras-chave dentro de strings" do
      code = <<~DSL
        toque "fim"
        toque "ciclo faca"
      DSL

      result = parser.preprocess(code)

      expect(result).to include('"fim"')
      expect(result).to include('"ciclo faca"')
    end

    it "nao altera codigo Ruby ja valido semanticamente" do
      code = <<~RUBY
        if true
          puts "ok"
        end
      RUBY

      result = parser.preprocess(code)

      expect(result).to include("if true")
      expect(result).to include("end")
    end
  end
end
