module MusicalDSL
  module NoteConverter

    # Mapeamento de notas para semitons (C = 0)
    BASE = {
      'C'  => 0,  'Cs' => 1,  'DB' => 1,
      'D'  => 2,  'Ds' => 3, 'Eb' => 3,
      'E'  => 4,  
      'F'  => 5,  'Fs' => 6,  'Gb' => 6,
      'G'  => 7,  'Gs' => 8,  'Ab' => 8,
      'A'  => 9,  'As' => 10, 'Bb' => 10,
      'B'  => 11,

      'DO'  => 0,  'DOs' => 1,  'REb' => 1,
      'RE'  => 2,  'REs' => 3,  'MIb' => 3,
      'MI'  => 4,  
      'FA'  => 5,  'FAs' => 6,  'SOLB'=> 6,
      'SOL' => 7,  'SOLs'=> 8,  'LAb' => 8,
      'LA'  => 9,  'LAs' => 10, 'SIb' => 10,
      'SI'  => 11
    }.freeze

    # Converte nota simbólica ou numérica para MIDI
    def self.to_midi(note)
      return note if note.is_a?(Integer)

      s = note.to_s.strip

      match = s.match(/\A([A-Z]+)([sb])?(\d)?\z/)

      unless match
        raise MusicalDSL::ErroDeUso, "Formato de nota inválido: #{note}"
      end

      name   = match[1]
      alter  = match[2]
      octave = match[3] ? match[3].to_i : 4

      key = alter ? "#{name}#{alter}" : name
      semitone = BASE[key]

      unless semitone
        raise MusicalDSL::ErroDeUso, "Nota desconhecida: #{key}"
      end

      # Padrão MIDI / Sonic Pi:
      # C4 = 60 → (4 + 1) * 12
      midi = (octave + 1) * 12 + semitone

      midi
    end
  end
end
