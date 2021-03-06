
require File.expand_path('../../../spec_helper', __FILE__)

# --------------------------------------------------------------------------
describe Bones::App::FileManager do

  before :each do
    @fm = Bones::App::FileManager.new
  end

  after :each do
    FileUtils.rm_rf(@fm.destination) if @fm.destination
    FileUtils.rm_rf(@fm.archive) if @fm.archive
  end

  it "should have a configurable source" do
    @fm.source.should be_nil

    @fm.source = '/home/user/.mrbones/default'
    @fm.source.should be == '/home/user/.mrbones/default'
  end

  it "should have a configurable destination" do
    @fm.destination.should be_nil

    @fm.destination = 'my_new_app'
    @fm.destination.should be == 'my_new_app'
  end

  it "should set the archive directory when the destination is set" do
    @fm.archive.should be_nil

    @fm.destination = 'my_new_app'
    @fm.archive.should be == 'my_new_app.archive'
  end

  it "should return a list of files to copy" do
    @fm.source = Bones.path %w[spec data default]

    ary = @fm._files_to_copy
    ary.length.should be == 8

    ary.should be == %w[
      .bnsignore
      .rvmrc.bns
      History
      NAME/NAME.rb.bns
      README.md.bns
      Rakefile.bns
      bin/NAME.bns
      lib/NAME.rb.bns
    ]
  end

  it "should archive the destination directory if it exists" do
    @fm.destination = Bones.path(%w[spec data bar])
    test(?e, @fm.destination).should be == false
    test(?e, @fm.archive).should be == false

    FileUtils.mkdir @fm.destination
    @fm.archive_destination
    test(?e, @fm.destination).should be == false
    test(?e, @fm.archive).should be == true
  end

  it "should rename files and folders containing 'NAME'" do
    @fm.source = Bones.path(%w[spec data default])
    @fm.destination = Bones.path(%w[spec data bar])
    @fm.copy

    @fm._rename(File.join(@fm.destination, 'NAME'), 'tirion')

    dir = File.join(@fm.destination, 'tirion')
    test(?d, dir).should be == true
    test(?f, File.join(dir, 'tirion.rb.bns')).should be == true
  end

  it "should raise an error when renaming an existing file or folder" do
    @fm.source = Bones.path(%w[spec data default])
    @fm.destination = Bones.path(%w[spec data bar])
    @fm.copy

    lambda {@fm._rename(File.join(@fm.destination, 'NAME'), 'lib')}.
      should raise_error(RuntimeError)
  end

  it "should perform ERb templating on '.bns' files" do
    @fm.source = Bones.path(%w[spec data default])
    @fm.destination = Bones.path(%w[spec data bar])
    @fm.template('foo_bar')

    dir = @fm.destination
    test(?e, File.join(dir, 'Rakefile.bns')).should be == false
    test(?e, File.join(dir, 'README.md.bns')).should be == false
    test(?e, File.join(dir, %w[foo_bar foo_bar.rb.bns])).should be == false
    test(?e, File.join(dir, '.rvmrc.bns')).should be == false

    test(?e, File.join(dir, 'Rakefile')).should be == true
    test(?e, File.join(dir, 'README.md')).should be == true
    test(?e, File.join(dir, %w[foo_bar foo_bar.rb])).should be == true
    test(?e, File.join(dir, '.rvmrc')).should be == true

    txt = File.read(File.join(@fm.destination, %w[foo_bar foo_bar.rb]))
    txt.should be == <<-TXT
module FooBar
  def self.foo_bar
    p 'just a test'
  end
end
    TXT
  end

  it "preserves the executable status of .bns files" do
    @fm.source = Bones.path(%w[spec data default])
    @fm.destination = Bones.path(%w[spec data bar])
    @fm.template('foo_bar')

    dir = @fm.destination
    test(?e, File.join(dir, 'bin/foo_bar')).should be == true
    test(?x, File.join(dir, 'bin/foo_bar')).should be == true
  end

  # ------------------------------------------------------------------------
  describe 'when configured with a repository as a source' do

    it "should recognize a git repository" do
      @fm.source = 'git://github.com/TwP/bones.git'
      @fm.repository.should be == :git

      @fm.source = 'git://github.com/TwP/bones.git/'
      @fm.repository.should be == :git
    end

    it "should recognize an svn repository" do
      @fm.source = 'file:///home/user/svn/ruby/trunk/apc'
      @fm.repository.should be == :svn

      @fm.source = 'http://svn.ruby-lang.org/repos/ruby/branches/ruby_1_8'
      @fm.repository.should be == :svn

      @fm.source = 'https://svn.ruby-lang.org/repos/ruby/branches/ruby_1_8'
      @fm.repository.should be == :svn

      @fm.source = 'svn://10.10.10.10/project/trunk'
      @fm.repository.should be == :svn

      @fm.source = 'svn+ssh://10.10.10.10/project/trunk'
      @fm.repository.should be == :svn
    end

    it "should return nil if the source is not a repository" do
      @fm.source = '/some/directory/on/your/hard/drive'
      @fm.repository.should be_nil
    end
  end

end

