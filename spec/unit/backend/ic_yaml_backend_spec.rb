require 'spec_helper'
require 'hiera/backend/ic_yaml_backend'

class Hiera
  module Backend
    class FakeCache
      attr_accessor :value
      def read(path, expected_type, default, &block)
        read_file(path, expected_type, &block)
      rescue => e
        default
      end

      def read_file(path, expected_type, &block)
        output = block.call(@value)
        if !output.is_a? expected_type
          raise TypeError
        end
        output
      end
    end

    describe Ic_yaml_backend do
      before do
        Config.load({
          :backends => "ic_yaml",
          :ic_yaml  => {
            :imports_key    => 'imports',
            :parameters_key => 'parameters',
            :datadir        => File.expand_path(File.dirname(__FILE__) + "../../../fixtures"),
          }
        })
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        @cache   = mock
        @backend = Ic_yaml_backend.new(@cache)
      end

      describe "#initialize" do
        it "should announce its creation" do # because other specs checks this
          Hiera.expects(:debug).with("Hiera IC YAML backend starting")
          Ic_yaml_backend.new
        end
      end

      describe "#create_filecache" do
        it "should create Filecache by default" do
          @backend.create_filecache().kind_of?(Filecache).should == true
        end

        it "should create Filecache when cacheable" do
          Config[:ic_yaml][:cacheable] = true

          @backend.create_filecache().kind_of?(Filecache).should == true
        end

        it "should create Filenocache when not cacheable" do
          Config[:ic_yaml][:cacheable] = false

          @backend.create_filecache().kind_of?(Filenocache).should == true
        end
      end

      describe "#load_yaml_file" do

        it "should load files" do
          @backend.load_yaml_file("role1.yaml", {}).should == {
            "classes"        => ["class1", "class2"],
            "class2::val1"   => "Value 1",
            "class2::val2"   => "Value 2",
            "class1::val1"   => "Value 1",
            "class1::val2"   => "Value 2",
          }
        end

        it "should keep params" do
          @backend.load_yaml_file("role_basic_params.yaml", {}).should == {
            "class_param::config"=>{
              "val1" => "%{::param_val1}",
              "val2" => "%{::param_val2}"},
              "parameters" => {
                "param_val1" => "role val1",
                "param_val2" => "role val2"
              }
            }
        end

        it "should ignore non existing import files" do
          Hiera.expects(:debug).with("Hiera IC YAML backend load import : nonexisting.yaml")
          Hiera.expects(:warn).with("Hiera IC YAML Cannot find datafile nonexisting.yaml, skipping")
          @backend.load_yaml_file("role_nonexisting_import.yaml", {}).should == {
            "classes" => ["nonexisting"]
          }
        end

        it "should merge parameters" do
          @backend.load_yaml_file("role_merge.yaml", {}).should == {
            "classes"     => ["class_merge"],
            "parameters"  => {
              "param_val1"=>"role val1",
              "param_val2"=>"role val2"
            },
            "class_merge::map" => {
                "key1"=>{
                  "val1"=>"%{::param_val1}",
                  "val2"=>"%{::param_val2}"
                },
                "key2"=>{
                  "val1"=>"%{::param_val1}",
                  "val2"=>"%{::param_val2}"
                },
            },
            "class_merge::list"=>[
              "param",
              "%{::param_val2}",
              "%{::param_val1}"
            ]
          }
        end
      end

      describe "#merge_yaml" do
        it "should merge hashes" do
          other      = {"foo" => 1, "bar" => 1}
          overriding = {"foo" => 2, "foobar" => 2}
          actual     = @backend.merge_yaml(overriding, other)

          actual.should == {"foo"=>2, "foobar"=>2, "bar"=>1}
        end
      end

      describe "#lookup" do
        it "should parse parameters using scope variables" do
          scope = {"::username" => "root"}
          Backend.expects(:datasources).yields("one")
          Backend.expects(:datafile).with(:ic_yaml, scope, "one", "yaml").returns("/nonexisting/one.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({
            "key" => "%{::database_name}",
            "parameters"  => {
              "database_name" => "%{::username}_db",
            }
          })

          @backend.lookup("key", scope, nil, :priority).should == "root_db"
        end

        it "should look for data in all sources" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns(nil)
          Backend.expects(:datafile).with(:ic_yaml, {}, "two", "yaml").returns(nil)

          @backend.lookup("key", {}, nil, :priority)
        end

        it "should pick data earliest source that has it for priority searches" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:ic_yaml, {}, "two", "yaml").returns(nil).never
          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"answer"})
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)

          @backend.lookup("key", {}, nil, :priority).should == "answer"
        end

        it "should not look up missing data files" do
          Backend.expects(:datasources).multiple_yields(["one"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns(nil)
          YAML.expects(:load_file).never

          @backend.lookup("key", {}, nil, :priority)
        end

        it "should return nil for empty data files" do
          Backend.expects(:datasources).multiple_yields(["one"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({})

          @backend.lookup("key", {}, nil, :priority).should be_nil
        end

        it "should build an array of all data sources for array searches" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:ic_yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"answer"})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>"answer"})

          @backend.lookup("key", {}, nil, :array).should == ["answer", "answer"]
        end

        it "should ignore empty hash of data sources for hash searches" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:ic_yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"a"=>"answer"}})

          @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer"}
        end

        it "should build a merged hash of data sources for hash searches" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:ic_yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"b"=>"answer", "a"=>"wrong"}})

          @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer", "b" => "answer"}
        end

        it "should fail when trying to << a Hash" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:ic_yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>["a", "answer"]})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"a"=>"answer"}})

          expect {@backend.lookup("key", {}, nil, :array)}.to raise_error(Exception, "Hiera type mismatch: expected Array and got Hash")
        end

        it "should fail when trying to merge an Array" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:ic_yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>["a", "wrong"]})

          expect { @backend.lookup("key", {}, nil, :hash) }.to raise_error(Exception, "Hiera type mismatch: expected Hash and got Array")
        end

        it "should parse the answer for scope variables" do
          Backend.expects(:datasources).yields("one")
          Backend.expects(:datafile).with(:ic_yaml, {"rspec" => "test"}, "one", "yaml").returns("/nonexisting/one.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"test_%{rspec}"})

          @backend.lookup("key", {"rspec" => "test"}, nil, :priority).should == "test_test"
        end

        it "should retain datatypes found in yaml files" do
          Backend.expects(:datasources).yields("one").times(3)
          Backend.expects(:datafile).with(:ic_yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml").times(3)
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)

          yaml = "---\nstringval: 'string'\nboolval: true\nnumericval: 1"

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).times(3).returns({"boolval"=>true, "numericval"=>1, "stringval"=>"string"})

          @backend.lookup("stringval", {}, nil, :priority).should == "string"
          @backend.lookup("boolval", {}, nil, :priority).should == true
          @backend.lookup("numericval", {}, nil, :priority).should == 1
        end
      end

    end
  end
end
