module MusicalDSL
  class Parser
    def initialize
      # MusicalDSL::LOGGER.debug("[PARSER] Initialized new Parser instance")
    end

    # Simple preprocess: localized keywords -> Ruby-compatible blocks
    def preprocess(code)
      # MusicalDSL::LOGGER.debug("[PARSER] Starting preprocess")
      # MusicalDSL::LOGGER.debug("[PARSER] Input code length: #{code.length} chars")
      
      s = code.dup
      
      # Track transformations
      transformations = []
      
      original = s.dup
      s.gsub!(/(?<!")(\d+)\.vezes\s+faca(?!")/) { transformations << "vezes: #{$1}.vezes faca → vezes(#{$1}) do"; "vezes(#{$1}) do" }
      s.gsub!(/(?<!")(?<![']\s)(?<!["'])\bciclo\s+faca\b(?!")/) { transformations << "ciclo: ciclo faca → ciclo do"; "ciclo do" }
      s.gsub!(/(?<!")(?<!["'])\bfaca\b(?!")/) { transformations << "faca: faca → do"; "do" }
      s.gsub!(/(?<!")(?<!["'])\bse\b(?!")/) { transformations << "se: se → if"; "if" }
      s.gsub!(/(?<!")(?<!["'])\bsenao\b(?!")/) { transformations << "senao: senao → else"; "else" }
      s.gsub!(/(?<!")(?<!["'])\bfim\b(?!")/) { transformations << "fim: fim → end"; "end" }
      
      # transformations.each { |t| MusicalDSL::LOGGER.debug("[PARSER] Transform: #{t}") }
      
      # MusicalDSL::LOGGER.debug("[PARSER] Preprocess complete")
      # MusicalDSL::LOGGER.debug("[PARSER] Output code length: #{s.length} chars")
      # MusicalDSL::LOGGER.debug("[PARSER] Preprocessed code:\n#{s}")
      
      s
    end

    def validate_blocks!(code)
      stack = []

      code.each_line.with_index(1) do |line, line_number|
        tokens = line.scan(/\b\d+\.vezes\b|\bfaca\b|\bfim\b|\bse\b|\bsenao\b|\bciclo\b|\S+/)

        tokens.each do |token|
          case token
          when /\A\d+\.vezes\z/
            stack << { tipo: :vezes, linha: line_number }

          when 'ciclo'
            stack << { tipo: :ciclo, linha: line_number }

          when 'se'
            stack << { tipo: :se, linha: line_number }

          when 'faca'
            if stack.empty? || ![:ciclo, :vezes].include?(stack.last[:tipo])
              raise ErroDeUso, "`faca` fora de um bloco de repetição (linha #{line_number})"
            end

          when 'senao'
            if stack.empty? || stack.last[:tipo] != :se
              raise ErroDeUso, "`senao` sem `se` correspondente (linha #{line_number})"
            end

          when 'fim'
            if stack.empty?
              raise ErroDeSintaxe, "`fim` sem bloco para fechar (linha #{line_number})"
            end
            stack.pop
          end
        end
      end

      unless stack.empty?
        bloco = stack.last
        raise ErroDeSintaxe,
              "Bloco `#{bloco[:tipo]}` aberto na linha #{bloco[:linha]} não foi fechado com `fim`"
      end
    end

  end
end