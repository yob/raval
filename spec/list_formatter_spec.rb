# coding: utf-8

require "spec_helper"
require "ostruct"


def a_valid_directory
  OpenStruct.new(:directory => true,
                 :permissions => "r--r--r--",
                 :owner => "auser",
                 :group => "agroup",
                 :size  => 0,
                 :time  => Time.mktime(2012,10,10,10,10),
                 :name  => "files")
end

def a_valid_file
  OpenStruct.new(:directory => false,
                 :permissions => "r--r--r--",
                 :owner => "auser",
                 :group => "agroup",
                 :size  => 1024,
                 :time  => Time.mktime(2012,10,10,10,10),
                 :name  => "one.txt")
end
describe Raval::ListFormatter, "initialisation" do
  context "with a directory and a file" do
    let!(:files) { [a_valid_directory, a_valid_file] }

    it "should initialise without error" do
      lambda {
        Raval::ListFormatter.new(files)
      }.should_not raise_error(ArgumentError)
    end
  end
  context "with a string" do
    let!(:files) { ["foo"] }

    it "should raise an exception" do
      lambda {
        Raval::ListFormatter.new(files)
      }.should raise_error(ArgumentError)
    end
  end

end

describe Raval::ListFormatter, "#short" do
  context "with a directory and a file" do
    let!(:files) { [a_valid_directory, a_valid_file] }
    subject      { Raval::ListFormatter.new(files)}

    it "should return an array of the names" do
      subject.short.should == ["files","one.txt"]
    end
  end
end

describe Raval::ListFormatter, "#detailed" do
  context "with a directory and a file" do
    let!(:files) { [a_valid_directory, a_valid_file] }
    subject      { Raval::ListFormatter.new(files)}

    it "should return an array of the names" do
      subject.detailed.should == [
        "dr--r--r-- 1 auser  agroup            0 Oct 10 10:10 files",
        "-r--r--r-- 1 auser  agroup         1024 Oct 10 10:10 one.txt",
      ]
    end
  end
end
