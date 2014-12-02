class Hiera
  module Backend
    class Ic_yaml_backend
      def initialize(cache=nil)
        require 'yaml'
        Hiera.debug("Hiera IC YAML backend starting")

        @cache = cache || Filecache.new
      end

      def ic_yaml_config()
        if Config[:ic_yaml]
            return Config[:ic_yaml]
        end

        if Config['ic_yaml']
            return Config['ic_yaml']
        end

        return {}
      end

      def data_dir(scope)
        return Backend.datadir(:ic_yaml, scope)
      end

      def file_path(path, scope)
        datadir = data_dir(scope)
        file    = File.join(datadir, path)

        return file
      end

      def parameters(data)
        key        = parameters_key()
        values     = data[key] || {}
        parameters = {}

        values.each_pair do |k,v|
          parameters["::#{k}"] = v
        end

        return parameters
      end

      def imports_key()
        config = ic_yaml_config()

        if config[:imports_key]
            return config[:imports_key]
        end

        if config['imports_key']
            return config['imports_key']
        end

        return '__imports__'
      end

      def parameters_key()
        config = ic_yaml_config()

        if config[:parameters_key]
            return config[:parameters_key]
        end

        if config['parameters_key']
            return config['parameters_key']
        end

        return '__parameters__'
      end

      def merge_yaml(overriding, other)

        if !overriding.kind_of?(Hash) && !overriding.kind_of?(Array)
            return overriding || other
        end

        if overriding.kind_of?(Array) && other.kind_of?(Array)
            return overriding.concat(other).uniq
        end

        if !overriding.kind_of?(Hash)
            return overriding || other
        end

        result = {}

        overriding.each_pair do |key, overriding_val|
          other_val   = other[key] || overriding_val
          result[key] = merge_yaml(overriding_val, other_val)
        end

        return other.merge(result)
      end

      def load_yaml_file(path, scope)
        Hiera.debug("Hiera IC YAML backend load import : #{path}")

        file = file_path(path, scope)

        if ! File.exist?(file)
          Hiera.warn("Hiera IC YAML Cannot find datafile #{path}, skipping")
          return {}
        end

        return load_yaml_data(File.open(file), scope)
      end

      def load_yaml_data(data, scope)
        config      = YAML.load(data) || {}
        imports_key = imports_key()

        if !config.kind_of?(Hash)
            return config
        end

        if config.has_key?(imports_key)
            imports = {}

            config[imports_key].each { |f|
                element = load_yaml_file(f, scope)
                imports = merge_yaml(element, imports)
            }

            config = merge_yaml(config, imports)
            config.delete(imports_key)
        end

        return config
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Hiera IC YAML Looking up #{key} in YAML backend")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")
          yamlfile = Backend.datafile(:ic_yaml, scope, source, "yaml") || next

          next unless File.exist?(yamlfile)

          data = @cache.read_file(yamlfile, Hash) do |data|
            load_yaml_data(data, scope)
          end

          next if data.empty?
          next unless data.include?(key)

          # Extra logging that we found the key. This can be outputted
          # multiple times if the resolution type is array or hash but that
          # should be expected as the logging will then tell the user ALL the
          # places where the key is found.
          Hiera.debug("Found #{key} in #{source}")

          # for array resolution we just append to the array whatever
          # we find, we then goes onto the next file and keep adding to
          # the array
          #
          # for priority searches we break after the first found data item
          new_answer = Backend.parse_answer(data[key], scope, parameters(data))
          case resolution_type
          when :array
            raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
            answer ||= []
            answer << new_answer
          when :hash
            raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
            answer ||= {}
            answer = Backend.merge_answer(new_answer,answer)
          else
            answer = new_answer
            break
          end
        end

        return answer
      end
    end
  end
end
