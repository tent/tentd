require 'spec_helper'

describe TentServer::JsonPatch::HashPointer do
  context 'when finding pointer' do
    it 'should find nested hash' do
      hash = { "a" => { "b" => { "c" => "foo" } } }
      pointer = described_class.new(hash, "a/b/c")
      expect(pointer.value).to eq("foo")
    end

    it 'should find position in array' do
      hash = { "a" => ["foo", "bar", "baz"] }
      pointer = described_class.new(hash, "a/1")
      expect(pointer.value).to eq("bar")
    end

    it "should throw exception if key doesn't exist" do
      hash = { "a" => "foo" }
      pointer = described_class.new(hash, "a/b/c")
      expect(lambda { pointer.value }).to raise_error(described_class::InvalidPointer)
    end

    it "should throw exception if array position is outsize index range" do
      hash = { "a" => ["foo", "bar", "baz"] }
      pointer = described_class.new(hash, "a/3")
      expect(lambda { pointer.value }).to raise_error(described_class::InvalidPointer)
    end
  end

  context 'when setting pointer' do
    it "should set nested hash key" do
      pointer = described_class.new({}, "a/b/c")
      pointer.value = "foo"
      expect(pointer.value).to eq("foo")
    end

    it 'should set value at array index' do
      hash = { "a" => ["foo", "bar"] }
      pointer = described_class.new(hash, "a/1")
      pointer.value = "baz"
      expect(hash["a"]).to be_an(Array)
      expect(pointer.value).to eq("baz")
      expect(described_class.new(hash, "a/2").value).to eq("bar")

      hash = { "a" => { "b" =>  ["foo", "baz"] } }
      pointer = described_class.new(hash, "a/b/1")
      pointer.value = "bar"
      expect(hash["a"]["b"]).to be_an(Array)
      expect(pointer.value).to eq("bar")
    end
  end

  context 'when deleting pointer' do
    it 'should delete key from object' do
      hash = { "a" => { "b" => { "c" => "foo" } } }
      pointer = described_class.new(hash, "a/b/c")
      pointer.delete
      expect(hash).to eq({ "a" => { "b" => {} } })
    end

    it 'should delete index from array' do
      hash = { "a" => { "b" => ["foo", "baz", "bar"] } }
      pointer = described_class.new(hash, "a/b/1")
      pointer.delete
      expect(hash).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should throw exception if key does not exist' do
      hash = {}
      pointer = described_class.new(hash, "a")
      expect( lambda { pointer.delete }).to raise_error(described_class::InvalidPointer)
      expect(hash).to eq({})
    end

    it 'should throw exception if index of array does not exist' do
      hash = { "a" => { "b" => ["foo", "bar"] } }
      pointer = described_class.new(hash, "a/b/2")
      expect( lambda { pointer.delete }).to raise_error(described_class::InvalidPointer)
      expect(hash).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end
  end

  context 'when moving pointer' do
    it 'should move key to another key' do
      hash = { "a" => { "b" => { "c" => "foo" } } }
      pointer = described_class.new(hash, "a/b")
      pointer.move_to "/b"
      expect(hash).to eq({ "a" => {}, "b" => { "c" => "foo" } })
    end

    it 'should move array index to another index' do
      hash = { "a" => { "b" => ["foo", "bar"] } }
      pointer = described_class.new(hash, "a/b/0")
      pointer.move_to "a/b/1"
      expect(hash).to eq({ "a" => { "b" => ["bar", "foo"] } })
    end

    it 'should throw exception if to would overwrite another key' do
      hash = { "a" => { "b" => ["foo", "bar"] } }
      pointer = described_class.new(hash, "a/b/0")
      expect( lambda { pointer.move_to "a/b/c" } ).
        to raise_error(described_class::InvalidPointer)
      expect(hash).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end
  end

  describe '#exists?' do
    it 'should return false if key not in hash' do
      hash = { "a" => { "b" =>  { "foo" => "bar" } } }
      pointer = described_class.new(hash, "a/b/c")
      expect(pointer.exists?).to be_false
    end

    it 'should return false if index not in array' do
      hash = { "a" => { "b" => ["foo", "bar"] } }
      pointer = described_class.new(hash, "a/b/2")
      expect(pointer.exists?).to be_false
    end

    it 'should return true if key in hash' do
      hash = { "a" => { "b" =>  { "foo" => "bar" } } }
      pointer = described_class.new(hash, "a/b")
      expect(pointer.exists?).to be_true

      hash = { "a" => "baz" }
      pointer = described_class.new(hash, "a/b")
      expect(pointer.exists?).to be_true
    end

    it 'should return true if index in array' do
      hash = { "a" => { "b" => ["foo", "bar"] } }
      pointer = described_class.new(hash, "a/b/1")
      expect(pointer.exists?).to be_true
    end
  end
end

describe TentServer::JsonPatch do
  describe 'add' do
    it 'should add new value at specified location' do
      object = {}
      patch_object = [{ "add" => "a/b/c", "value" => ["foo", "bar", "baz"] }]
      TentServer::JsonPatch.merge(object, patch_object)
      expect(object).to be_a(Hash)
      expect(object["a"]["b"]["c"]).to eq(["foo", "bar", "baz"])

      object = { "a" => {} }
      patch_object = [{ "add" => "a/b/c", "value" => ["foo", "bar", "baz"] }]
      TentServer::JsonPatch.merge(object, patch_object)
      expect(object).to be_a(Hash)
      expect(object["a"]["b"]["c"]).to eq(["foo", "bar", "baz"])

      object = { "a" => { "b" => {} } }
      patch_object = [{ "add" => "a/b/c", "value" => ["foo", "bar", "baz"] }]
      TentServer::JsonPatch.merge(object, patch_object)
      expect(object).to be_a(Hash)
      expect(object["a"]["b"]["c"]).to eq(["foo", "bar", "baz"])
    end

    it 'should throw exception if specified location exists' do
      object = { "a" => "foo" }
      patch_object = [{ "add" => "a/b/c", "value" => ["foo", "bar", "baz"] }]
      expect( lambda { TentServer::JsonPatch.merge(object, patch_object) } ).
        to raise_error(described_class::ObjectExists)
      expect(object["a"]).to eq("foo")

      object = { "a" => { "b" => "foo" } }
      patch_object = [{ "add" => "a/b/c", "value" => ["foo", "bar", "baz"] }]
      expect( lambda { TentServer::JsonPatch.merge(object, patch_object) } ).
        to raise_error(described_class::ObjectExists)
      expect(object["a"]).to eq("b" => "foo")

      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "add" => "a/b/c", "value" => ["foo", "bar", "baz"] }]
      expect( lambda { TentServer::JsonPatch.merge(object, patch_object) } ).
        to raise_error(described_class::ObjectExists)
      expect(object["a"]).to eq("b" => { "c" => "foo" })

      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "add" => "a/b/c/d/e/f/g", "value" => ["foo", "bar", "baz"] }]
      expect( lambda { TentServer::JsonPatch.merge(object, patch_object) } ).
        to raise_error(described_class::ObjectExists)
      expect(object["a"]).to eq("b" => { "c" => "foo" })

      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "add" => "a/b/c/d/e/f/g", "value" => ["foo", "bar", "baz"] }]
      expect( lambda { TentServer::JsonPatch.merge(object, patch_object) } ).
        to raise_error(described_class::ObjectExists)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    context 'when pointer is an array' do
      it 'should add new value at specified index' do
        object = { "a" => ["foo", "bar"] }
        patch_object = [{ "add" => "a/1", "value" => "baz" }]
        TentServer::JsonPatch.merge(object, patch_object)
        expect(object["a"]).to eq(["foo", "baz", "bar"])
      end
    end
  end

  describe 'remove' do
    it 'should remove specified key' do
      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "remove" => "a/b/c" }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => { "b" => {} } })
    end

    it 'should throw exception if specified key does not exist' do
      object = { "a" => { "b" => {} } }
      patch_object = [{ "remove" => "a/b/c" }]
      expect( lambda { described_class.merge(object, patch_object) } ).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => {} } })
    end

    context 'when pointer is an array' do
      it 'should remove specified index' do
        object = { "a" => { "b" => ["foo", "baz", "bar"] } }
        patch_object = [{ "remove" => "a/b/1" }]
        described_class.merge(object, patch_object)
        expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
      end

      it 'should throw exception if specified index does not exist' do
        object = { "a" => { "b" => ["foo"] } }
        patch_object = [{ "remove" => "a/b/1" }]
        expect( lambda { described_class.merge(object, patch_object) } ).
          to raise_error(described_class::ObjectNotFound)
        expect(object).to eq({ "a" => { "b" => ["foo"] } })
      end
    end
  end

  describe 'replace' do
    it 'should replace specified key value' do
      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "replace" => "a", "value" => ["foo", "bar"] }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => ["foo", "bar"] })
    end

    it 'should replace specified index of array' do
      object = { "a" => { "b" => ["foo", "baz"] } }
      patch_object = [{ "replace" => "a/b/1", "value" => "bar" }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should throw exception if specified key does not exist' do
      object = { "a" => { "b" => {} } }
      patch_object = [{ "replace" => "a/b/c", "value" => "foo" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => {} } })
    end

    it 'should throw exception if specified index does not exist' do
      object = { "a" => [] }
      patch_object = [{ "replace" => "a/1", "value" => "bar" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => [] })
    end
  end

  describe 'move' do
    it 'should move specified key to new key' do
      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "move" => "a/b", "to" => "/b" }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => {}, "b" => { "c" => "foo" } })
    end

    it 'should move specified index to new index' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "move" => "a/b/0", "to" => "a/b/1" }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => { "b" => ["bar", "foo"] } })
    end

    it 'should throw exception if specified key does not exist' do
      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "move" => "a/b/c/d", "to" => "/b" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => { "c" => "foo" } } })

      object = { "a" => { "b" => "foo" } }
      patch_object = [{ "move" => "a/b/c", "to" => "a" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => "foo" } })
    end

    it 'should throw exception if specified index does not exist' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "move" => "a/b/2", "to" => "a/b/0" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should throw exception if to key would overwrite another' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "move" => "a/b/0", "to" => "a/b/c" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end
  end

  describe 'copy' do
    it 'should copy specified key value to new key' do
      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "copy" => "a/b/c", "to" => "/c" }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => { "b" => { "c" => "foo" } }, "c" => "foo" })
    end

    it 'should copy specified index value to new index' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "copy" => "a/b/0", "to" => "a/b/2" }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar", "foo"] } })
    end

    it 'should throw exception if specified key does not exist' do
      object = { "a" => { "b" => { "c" => "foo" } } }
      patch_object = [{ "copy" => "a/b/c/d", "to" => "/b" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => { "c" => "foo" } } })

      object = { "a" => { "b" => "foo" } }
      patch_object = [{ "copy" => "a/b/c", "to" => "a" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => "foo" } })
    end

    it 'should throw exception if specified index does not exist' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "copy" => "a/b/2", "to" => "a/b/0" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should throw exception if to key would overwrite another' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "copy" => "a/b/0", "to" => "a/b/c" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectExists)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end
  end

  describe 'test' do
    it 'should throw exception if specified key does not exist' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "test" => "a/c" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should throw exception if specified key does not equal specified value' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "test" => "a/b/0", "value" => "chunkybacon" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should throw exception if specified index does not exist' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "test" => "a/b/3" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should throw exception if specified index does not equal specified value' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "test" => "a/b/0", "value" => "chunkybacon" }]
      expect(lambda { described_class.merge(object, patch_object) }).
        to raise_error(described_class::ObjectNotFound)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should not do anything if key exists and matches specified value' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "test" => "a/b", "value" => ["foo", "bar"] }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end

    it 'should not do anything if index exists and matches specified value' do
      object = { "a" => { "b" => ["foo", "bar"] } }
      patch_object = [{ "test" => "a/b/0", "value" => "foo" }]
      described_class.merge(object, patch_object)
      expect(object).to eq({ "a" => { "b" => ["foo", "bar"] } })
    end
  end
end
