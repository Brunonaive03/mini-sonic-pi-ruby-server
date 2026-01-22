module MusicalDSL
  class ErroDSL < StandardError; end

  class ErroDeSintaxe < ErroDSL; end
  class ErroDeUso < ErroDSL; end      # comando fora de contexto
  class ErroSemantico < ErroDSL; end  # regras da linguagem
end