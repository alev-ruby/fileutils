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

module FileUtils
  $fudeopt = [].to_set
  @popts = {
    :cp    => [:T,:a,:v,:r].to_set,
    :mv    => [:T,:a,:v,:r].to_set,
    :rm    => [:v, :f, :r].to_set,
    :touch => [:v].to_set,
    :pwd   => [].to_set,
    :mkdir => [:v, :p].to_set,
    :dsync => [:v, ].to_set,
  }

  def parse_cp_args src, dst, *opts
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
          opts_s << "-#{opt.to_s} " if include?(opt) || $fudeopt.include?(opt)
        end

        opts_s
      end
    end

    opts.src, opts.dst = src, dst

    [src, dst, opts]
  end
  module_function :parse_cp_args

  def cp src, dst, *opts
    opts = opts.to_set

    src, dst, opts = parse_cp_args src, dst, *opts

    opts << :r if src.a? ? src.inject(false) do |a,p| p.directory? | a end : src.directory?

    Kernel.system "cp #{opts.to_s}#{src.to_s} #{dst.to_s}"
  end
  module_function :cp

  def dsync src, dst, *opts
    src, dst, opts = parse_cp_args src, dst, *opts

    opts = opts.to_set
    
    raise ArgumentError unless src.directory? && dst.directory?

    Dir["#{dst.to_s}/**/{*,.*}"].each do |file|
      file = Pathname.new file
      next unless file.exist?

      srcfile = src + file.relative_path_from(dst)

      (rm file, *(opts&@popts[:rm]) or return false) unless srcfile.exist?
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
  module_function :dsync

  def mv src, dst, *opts
    opts = opts.to_set

    src, dst, opts = parse_cp_args src, dst, *opts

    Kernel.system "mv #{opts.to_s}#{src.to_s} #{dst.to_s}"
  end
  module_function :mv

  def parse_list_args list, *opts
    if list.a?
      return true if list.count == 0

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
          opts_s << "-#{opt.to_s} " if include?(opt) || $fudeopt.include?(opt)
        end

        opts_s
      end
    end

    opts.list = list

    [list, opts]
  end
  module_function :parse_list_args

  def rm list, *opts
    opts = opts.to_set

    list, opts = parse_list_args list, *opts
    opts.flags = [:v, :f, :r]

    opts << :r if list.a? ? list.inject(false) do |a,p| p.directory? | a end : list.directory?

    Kernel.system "rm #{opts.to_s}#{list.to_s}"
  end
  module_function :rm

  def mkdir list, *opts
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

    Kernel.system "mkdir #{opts.to_s}#{list.to_s}"
  end
  module_function :mkdir

  def touch list, *opts
    opts = opts.to_set

    list, opts = parse_list_args list, *opts
    opts.flags = [:v]

    Kernel.system "touch #{opts.to_s}#{list.to_s}"
  end
  module_function :touch

  alias_method :_cd, :cd

  def cd list, *opts
    opts = opts.to_set

    list, opts = parse_list_args list, *opts
    opts.flags = [:v]

    raise ArgumentError if list.a?

    return false unless list.directory?

    _cd list.to_s, opts.include?(:v) ? {:verbose => true} : {:verbose => false}

    true
  end
  module_function :cd

  def pwd
    Pathname.new(`pwd`.chomp)
  end
  module_function :pwd

end # module FileUtils

# vim: sw=2 sts=2 ts=8:

