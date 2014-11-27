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
            :imports_key => 'imports',
            :datadir     => File.absolute_path(File.dirname(__FILE__) + "../../../fixtures"),
          }
        })
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        @cache   = FakeCache.new
        @backend = Ic_yaml_backend.new(@cache)
      end

      describe "#initialize" do
        it "should announce its creation" do # because other specs checks this
          Hiera.expects(:debug).with("Hiera IC YAML backend starting")
          Ic_yaml_backend.new
        end
      end

      describe "#load_yaml_data" do
        it "should import files" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
          @cache.value = "imports: [class1.yaml]"

          Hiera.expects(:debug).with("Hiera IC YAML backend load import : class1.yaml")
          @backend.lookup("class1::val1", {}, nil, :priority).should == "Value 1"
        end

        it "should ignore non existing import files" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
          @cache.value = "imports: [nonexisting.yaml]"

          Hiera.expects(:debug).with("Hiera IC YAML backend load import : nonexisting.yaml")
          Hiera.expects(:warn).with("Hiera IC YAML Cannot find datafile nonexisting.yaml, skipping")
          @backend.lookup("class1::val1", {}, nil, :priority).should == nil
        end
      end

      describe "#load_yaml_file" do
        it "should load files" do
          @backend.load_yaml_file("role1.yaml", {}).should == {
            "classes"      => ["class1", "class2"],
            "class2::val1" => "Value 1",
            "class2::val2" => "Value 2",
            "class1::val1" => "Value 1",
            "class1::val2" => "Value 2"
          }
        end
      end

      describe "#merge_yaml" do
        it "should merge hashes" do
          other      = {"foo" => 1, "bar" => 1}
          overriding = {"foo" => 2, "foobar" => 2}
          actual     = @backend.merge_yaml(overriding, other)

          actual.should == {"foo"=>1, "foobar"=>2, "bar"=>1}
        end
      end

      describe "#lookup" do
        it "should pick data earliest source that has it for priority searches" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
          @cache.value = "---\nkey: answer"

          @backend.lookup("key", {}, nil, :priority).should == "answer"
        end

        describe "handling unexpected YAML values" do
          before do
            Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
          end

          it "returns nil when the YAML value is nil" do
            @cache.value = "---\n"
            @backend.lookup("key", {}, nil, :priority).should be_nil
          end

          it "returns nil when the YAML file is false" do
            @cache.value = ""
            @backend.lookup("key", {}, nil, :priority).should be_nil
          end

          it "raises a TypeError when the YAML value is not a hash" do
            @cache.value = "---\n[one, two, three]"
            expect { @backend.lookup("key", {}, nil, :priority) }.to raise_error(TypeError)
          end
        end

        it "should build an array of all data sources for array searches" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])
          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"answer"})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>"answer"})

          @backend.lookup("key", {}, nil, :array).should == ["answer", "answer"]
        end

        it "should ignore empty hash of data sources for hash searches" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"a"=>"answer"}})

          @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer"}
        end

        it "should build a merged hash of data sources for hash searches" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"b"=>"answer", "a"=>"wrong"}})

          @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer", "b" => "answer"}
        end

        it "should parse the answer for scope variables" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {"rspec" => "test"}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"test_%{rspec}"})

          @backend.lookup("key", {"rspec" => "test"}, nil, :priority).should == "test_test"
        end

        it "should retain datatypes found in yaml files" do
          Backend.expects(:datasourcefiles).with(:ic_yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"]).times(3)


          @cache.value = "---\nstringval: 'string'\nboolval: true\nnumericval: 1"

          @backend.lookup("stringval", {}, nil, :priority).should == "string"
          @backend.lookup("boolval", {}, nil, :priority).should == true
          @backend.lookup("numericval", {}, nil, :priority).should == 1
        end
      end
    end
  end
end
