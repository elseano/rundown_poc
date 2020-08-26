#!/usr/bin/env ruby
require_relative "bundle/bundler/setup"

require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require "kramdown"
require "tty-markdown"
require "tempfile"
require "whirly"
require "tty-prompt"
require "tty-command"
require "logger"
require "pry"
require "inifile"
require "pathname"

class Rundown
  THEME = {
    em: [:italic],
    header: [:cyan, :bold],
    hr: :green,
    link: [:blue, :underline],
    list: :green,
    strong: [:green, :bold],
    table: :blue,
    quote: :blue,
  }

  attr_reader :logger

  def initialize(script)

    @script_file = Pathname.new(script).realpath
    @script_dir = @script_file.join("..")
    @doc = Kramdown::Document.new(IO.read(@script_file))
    @logger = Logger.new(@script_file.sub_ext(".log"))
    @pastel = Pastel.new

    @current_heading_level = 0
    @break_to_next_heading = false
    @heading_history = []

  end

  def run
    # puts @doc.to_hash_ast[:children]
    logger << "\n\nRunning runbook\n"
    process_all(@doc.root.children)
  end

  def logger; @logger; end

  def process(child)
    return if @break_to_next_heading && child.type != :header
    @break_to_next_heading = false
      
    case child.type
    when :header
      @heading_history = []
      process_header(child)
      @already_newline = true
    when :blockquote
      process_bq(child)
    when :p
      process_p(child.children)
    when :codespan
      execute(child)
    when :text
      process_bq(child)
    when :blank
      puts "\n" unless @already_newline || @last_block_code
      @already_newline = true
    end
  end

  def run_ruby(script)
    prompt = TTY::Prompt.new
    eval(script)
  end

  def execute(child)
    mode_, *script = child.value.split("\n")
    mode, *opts = mode_.strip.split(/\s+/)

    opts ||= []
    script = script.join("\n")

    if opts.include?("display_only")
      puts_indented to_text(child)
      return
    end

    if script == ""
      puts "Error running empty script"
      puts
      puts child.value.inspect
    end

    unless opts.include?("nospin")
      Whirly.start(append_newline: false, remove_after_stop: true)
      Whirly.status = "Running #{@heading_history.join(" ")}"
    end

    cmd = TTY::Command.new(output: logger, color: false)

    begin

      err = []

      result = if mode == "ruby" && opts.include?("rundown")
        logger << "Running in-process ruby code\n"
        logger << script + "\n"

        run_ruby(script)
      else    
        temp = Tempfile.new

        mode = "sh" if mode == ""
        process = `which #{mode}`.chomp

        logger << "Executing script using #{process}\n"
        logger << script + "\n"
        
        f = temp.open
        f.write(script)
        f.close
        
        if opts.include?("interactive")
          logger << "Running script in interactive mode, output ommitted.\n"
          system(process, temp.path)
        else
          result = cmd.run!("#{process} #{temp.path}", chdir: @script_dir, color: false) do |stdout, stderr|
            puts stdout if opts.include?("reveal")
            err << stderr
          end
          !result.failure?
        end

      end

      if opts.include?("skip_on_failure")
        if result == false
          @heading_history << @pastel.dim("-")
          @break_to_next_heading = true
          logger << "Script failure with skip_on_failure, skipping to next heading\n"
        end
      elsif opts.include?("skip_on_success")
        if result == true
          @heading_history << @pastel.dim("-")
          @break_to_next_heading = true
          logger << "Script success with skip_on_success, skipping to next heading\n"
        end
      else
        if result
          @heading_history << @pastel.bright_green(".")
        else
          logger << "Script failed. Aborting.\n"
          @heading_history << @pastel.red("x")
          Whirly.stop
          puts_indented "#{@heading_history.join(' ')}\r"

          puts "\n\n"

          puts @pastel.red.bold("Error Running Script")
          puts @pastel.dim(script)
          puts "\n\n"

          puts @pastel.red(err.join("\n"))

          puts "\n❌ Failed/Aborted.\n\n"

          exit(-1)
        end  
      end

    ensure
      temp&.close(true)
      Whirly.stop
    end

    print_indented "#{@heading_history.join(' ')}\r"
    @last_block_code = true
  end

  def process_header(header)
    @current_heading_level  = header.options[:level]
    puts "\n" if @last_block_code || !@already_newline
    puts "\n"
    puts to_text(header)
    @last_block_code = false
  end

  def process_bq(bq)
    @already_newline = false
    @last_block_code = false
    puts_indented to_text(bq)
  end

  def process_p(children)
    if children.length == 1 && children[0].type == :codespan
      process(children[0])

      @last_block_code = true
      @already_newline = false
    else

      text = to_text(children)
      puts_indented text

      @last_block_code = false
      @already_newline = false
    end
  end

  def process_all(children)
    children.each do |child|
      process(child)
    end
  end

  def to_text(children)
    doc = @doc.dup
    doc.root.children = Array(children)
    TTY::Markdown::Parser.convert(doc.root, doc.options.merge({ theme: THEME })).map do |line|
      line.join.split("\n")
    end.flatten
  end

  def indent_to_s(offset = 0)
    ("  " * (@current_heading_level - 1 + offset))
  end

  def puts_indented(text)
    # binding.pry
    Array(text).each do |line|      
      puts(indent_to_s + line) unless line.strip == ""
    end
  end

  def print_indented(text)
    print(indent_to_s + text)
  end
end

class CLI < Thor
  def self.exit_on_failure?
    true
  end

  desc "preview FILENAME", "Previews a markdown file in the terminal"
  def preview(filename)
    puts TTY::Markdown.parse_file(filename, { theme: Rundown::THEME })
    exit(0)
  end

  desc "execute FILENAME", "Executes a markdown file."
  def execute(script_file)
    puts "Running #{script_file}...\n"

    rundown = Rundown.new(script_file)
    
    begin
      rundown.run
      puts "\n✅ Finished.\n"
      rundown.logger << "Runbook finished.\n"
      exit(0)
    rescue Interrupt
      rundown.logger << "Runbook aborted by user.\n"
      puts Pastel.new.red("\n❌ User Aborted")
      exit(1)
    end
  end
end

CLI.start(ARGV)
