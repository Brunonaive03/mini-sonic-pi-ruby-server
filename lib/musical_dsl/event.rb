module MusicalDSL
  class Event
    attr_reader :id, :time, :type, :data

    def initialize(id:, time:, type:, data: {})
      @id = id
      @time = time.to_f   # beats
      @type = type.to_s
      @data = data || {}
    end

    def to_h
      {
        id: @id,
        time: @time,
        type: @type,
        data: @data
      }
    end
  end
end