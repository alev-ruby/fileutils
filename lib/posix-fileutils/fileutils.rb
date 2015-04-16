require 'fileutils'
require 'pathname'
require 'set'
require 'digest'


class Object
  def a?
    Enumerable === self
  end
end

class Array
  def to_set
    Set.new self
  end
end

module Fs
  @defopts = [].to_set
  @popts = {
    :cp    => [:T,:a,:v,:r     ],
    :mv    => [:T,:a,:v,:r     ],
    :rm    => [      :v,:r,:f  ],
    :touch => [                ],
    :pwd   => [                ],
    :mkdir => [      :v,     :p],
    :dsync => [      :v,       ],
  }.inject({}) do |h,(k,v)| h[k]=v.to_set; h end

  class << self
    attr_accessor :defopts
  end

  def self.popts
    @popts.clone
  end

  def self.parse_cp_args src, dst, *opts
    raise ArgumentError unless !dst.a?

    dst = Pathname.new dst.to_s unless dst.kind_of? Pathname

    if src.a?
      return true if src.count == 0

      raise ArgumentError unless dst.directory?

      src.map! do |elem| Pathname.new elem.to_s unless elem.kind_of? Pathname end

      class << src
        def to_s
          inject('') do |accu, elem| "#{accu}#{elem.to_s} " end.chomp ' '
        end
      end
    else
      src = Pathname.new src.to_s unless src.kind_of? Pathname
    end

    class << opts
      attr_accessor :src
      attr_accessor :dst

      def to_s
        opts_s = '-f '

        [:T, :a, :v, :r].each do |opt|
          opts_s << "-#{opt.to_s} " if include?(opt) || Fs.defopts.include?(opt)
        end

        opts_s
      end
    end

    opts.src, opts.dst = src, dst

    [src, dst, opts]
  end

  def self.cp src, dst, *opts
    opts = opts.to_set

    src, dst, opts = parse_cp_args src, dst, *opts

    opts << :r if src.a? ? src.inject(false) do |a,p| p.directory? | a end : src.directory?

    Kernel.system "cp #{opts.to_s}#{src.to_s} #{dst.to_s}"
  end

  def self.dsync src, dst, *opts
    src, dst, opts = parse_cp_args src, dst, *opts

    opts = opts.to_set
    
    raise ArgumentError unless src.directory? && dst.directory?

    if opts.include? :d
      Dir["#{dst.to_s}/**/{*,.*}"].each do |file|
        file = Pathname.new file
        next unless file.exist?

        srcfile = src + file.relative_path_from(dst)

        (rm file, *(opts&@popts[:rm]) or return false) unless srcfile.exist?
      end
    end
    
    Dir["#{src.to_s}/**/{*,.*}"].each do |file|
      file = Pathname.new file
      next if file.directory?

      dstfile = dst + file.relative_path_from(src)

      (mkdir dstfile.dirname, *((opts+[:p])&@popts[:mkdir]) or return false) unless dstfile.dirname.directory?

      next if dstfile.file? && Digest::SHA256.file(file) == Digest::SHA256.file(dstfile)

      cp file, dstfile, *(opts&@popts[:cp]) or return false
    end

    true
  end

  def self.mv src, dst, *opts
    opts = opts.to_set

    src, dst, opts = parse_cp_args src, dst, *opts

    Kernel.system "mv #{opts.to_s}#{src.to_s} #{dst.to_s}"
  end

  def self.parse_list_args list, *opts
    opts = opts.to_set

    if list.a?
      return [[],[].to_set] if list.count == 0

      list.map! do |elem| Pathname.new elem.to_s unless elem.kind_of? Pathname end

      class << list
        def to_s
          inject('') do |accu,elem| "#{accu}#{elem.to_s} " end.chomp ' '
        end
      end
    else
      list = Pathname.new list.to_s unless list.kind_of? Pathname
    end

    class << opts
      attr_accessor :list
      attr_accessor :flags

      def to_s
        opts_s = ''

        @flags.each do |opt|
          opts_s << "-#{opt.to_s} " if include?(opt) || Fs.defopts.include?(opt)
        end

        opts_s
      end
    end

    opts.list = list

    [list, opts]
  end

  def self.rm list, *opts
    return true if list.a? && list.empty?

    opts = opts.to_set

    list, opts = parse_list_args list, *opts
    opts.flags = [:v, :f, :r]

    opts << :r if list.a? ? list.inject(false) do |a,p| p.directory? | a end : list.directory?

    Kernel.system "rm #{opts.to_s}#{list.to_s}"
  end

  def self.mkdir list, *opts, &block
    opts = opts.to_set

    list, opts = parse_list_args list, *opts
    opts.flags = [:v, :p]

    if opts.include? :f
      unless list.a?
        return true if list.directory?
      else
        list.select! do |elem| !elem.directory? end
        return true if list.empty?
      end
    end

    res = Kernel.system "mkdir #{opts.to_s}#{list.to_s}"
    
    return res if res != true

    raise ArgumentError, 'Only in case single directory creating passing block is permitted' if list.a? && block

    if block
      err = nil

      cwd = Fs.pwd
      old_defopts = @defopts.clone
      Fs.cd list, *(opts&@popts[:mkdir])

      @defopts += opts

      begin
        yield
      rescue => e
        err = e
      end
      
      Fs.cd Pathname.new(list).absolute? ? cwd : cwd.relative_path_from(self.pwd), *(opts&@popts[:mkdir])
      @defopts = old_defopts

      raise err if e
    end

    true
  end

  def self.touch list, *opts
    list, opts = parse_list_args list, *opts
    opts.flags = [:v]

    opts = opts.to_set

    res = Kernel.system "touch #{list.to_s}"

    puts "touched files #{list.to_s}" if (opts|@defopts.to_set).include? :v

    res
  end

  def self.cd list, *opts, &block
    opts = opts.to_set

    list, opts = parse_list_args list, *opts
    opts.flags = [:v]

    raise ArgumentError if list.a?

    return false unless list.directory?

    cwd = self.pwd
    old_defopts = @defopts.clone

    @defopts += opts

    FileUtils.cd list.to_s, opts.include?(:v) ? {:verbose => true} : {:verbose => false}

    if block
      err = nil

      begin
        yield
      rescue => e
        err = e
      end

      self.cd Pathname.new(list).absolute? ? cwd : cwd.relative_path_from(self.pwd), *opts
      @defopts = old_defopts

      raise err if err
    end

    true
  end

  def self.pwd
    Pathname.new(`pwd`.chomp)
  end

  def self.diff file1, file2, *opts
    file1 = Pathname.new file1 unless file1.kind_of? Pathname
    file2 = Pathname.new file2 unless file2.kind_of? Pathname

    raise ArgumentError unless file1.directory? == file2.directory?

    if file1.directory?
      list1 = Dir["#{file1.to_s}/**/{*,.*}"]
      list2 = Dir["#{file2.to_s}/**/{*,.*}"]

      rellist1 = list1.map do |e| Pathname.new(e).relative_path_from file1 end
      rellist2 = list2.map do |e| Pathname.new(e).relative_path_from file2 end

      return true unless rellist1.to_set == rellist2.to_set

      list1.each do |file|
        file = Pathname.new file
        ofile = file2 + file.relative_path_from(file1)

        if file.directory?
          return true if Dir["#{file.to_s}/{*,.*}"] == Dir["#{ofile.to_s}/{*,.*}"]

          next
        end

        return true unless ofile.exist?
        return true if ofile.directory?
        return true unless Digest::SHA256.file(file) == Digest::SHA256.file(ofile)
      end

      return false
    end

    return true unless Digest::SHA256.file(file1) == Digest::SHA256.file(file2)

    false
  end

end # module Fs

# vim: sw=2 sts=2 ts=8:

