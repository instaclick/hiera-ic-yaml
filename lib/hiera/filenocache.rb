class Hiera
  class Filenocache

    def read(path, expected_type = Object, default=nil, &block)
      read_file(path, expected_type, &block)
    rescue TypeError => detail
      Hiera.debug("#{detail.message}, setting defaults")
      default
    rescue => detail
      error = "Reading data from #{path} failed: #{detail.class}: #{detail}"
      if default.nil?
        raise detail
      else
        Hiera.debug(error)
        default
      end
    end

    def read_file(path, expected_type = Object)
      data   = File.read(path)
      result = block_given? ? yield(data) : data

      if !result.is_a?(expected_type)
        raise TypeError, "Data retrieved from #{path} is #{data.class} not #{expected_type}"
      end

      result
    end
  end
end