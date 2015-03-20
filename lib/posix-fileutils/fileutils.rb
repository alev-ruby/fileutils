require 'fileutils'
require 'pathname'

class Object
  def a?
    Enumerable === self
  end
end

module FileUtils
  $fudeopt = []

  class << self
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
            opts_s << "-#{opt.to_s} " if index(opt) || $fudeopt.index(opt)
          end

          opts_s
        end
      end

      opts.src, opts.dst = src, dst

      [src, dst, opts]
    end

    def cp src, dst, *opts
      src, dst, opts = parse_cp_args src, dst, *opts

      opts << :r if src.a? ? src.inject(false) do |a,p| p.directory? | a end : src.directory?

      Kernel.system "cp #{opts.to_s}#{src.to_s} #{dst.to_s}"
    end

    def mv src, dst, *opts
      src, dst, opts = parse_cp_args src, dst, *opts

      Kernel.system "mv #{opts.to_s}#{src.to_s} #{dst.to_s}"
    end

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
            opts_s << "-#{opt.to_s} " if index(opt) || $fudeopt.index(opt)
          end

          opts_s
        end
      end

      opts.list = list

      [list, opts]
    end

    def rm list, *opts
      list, opts = parse_list_args list, *opts
      opts.flags = [:v, :f, :r]

      opts << :r if list.a? ? list.inject(false) do |a,p| p.directory? | a end : list.directory?

      Kernel.system "rm #{opts.to_s}#{list.to_s}"
    end

    def mkdir list, *opts
      list, opts = parse_list_args list, *opts
      opts.flags = [:v]

      if opts.index :f
        unless list.a?
          return true if list.directory?
        else
          list.select! do |elem| !elem.directory? end
          return true if list.empty?
        end
      end

      Kernel.system "mkdir #{opts.to_s}#{list.to_s}"
    end

    def touch list, *opts
      list, opts = parse_list_args list, *opts
      opts.flags = [:v]

      Kernel.system "touch #{opts.to_s}#{list.to_s}"
    end

    def pwd
      Pathname.new(`pwd`.chomp)
    end

  end # class << self
end # module FileUtils

# vim: sw=2 sts=2 ts=8:

