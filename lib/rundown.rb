#!/usr/bin/env ruby
require_relative "bundle/bundler/setup"

require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require "kramdown"
require "tty-markdown"
require "tempfile"
require "tty-spinner"
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

  def initialize(script, log_file)
    @script_file = Pathname.new(script).realpath
    @script_dir = @script_file.join("..")
    @doc = Kramdown::Document.new(IO.read(@script_file))

    @log_file = if log_file
      Pathname.new(log_file)
    elsif ENV["HOME"]
      Pathname.new(ENV["HOME"]) / ".rundown" / @script_file.basename.sub_ext(".log")
    else
      @script_file.sub_ext(".log")
    end

    puts @log_file.to_s

    @log_file.dirname.mkdir unless @log_file.dirname.exist?
    
    @logger = Logger.new(@log_file)
    @pastel = Pastel.new

    @current_heading_level = 0
    @break_to_next_heading = false
    @heading_history = []
  end

  def run
    logger << "\n\nRunning runbook\n"
    puts @pastel.dim("Running #{@script_file.basename}...")

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

  def get_task_name_from_script(script, opts)
    if opts.include?("named")
      script_lines = script.split("\n")
      task_name = script_lines[0].sub(/^.*?\s+/, "")
      
      return task_name, script_lines[1..-1].join("\n")
    else
      return "Running...", script
    end
  end

  def execute(child)
    mode_, *script = child.value.split("\n")
    mode, *opts = mode_.strip.split(/\s+/)

    opts ||= []
    script = script.join("\n")

    if opts.include?("display_only")
      puts_indented to_text(child)
      @last_block_code = false
      return
    end

    task_name, script = get_task_name_from_script(script, opts)

    if script == ""
      puts_indented "#{@pastel.red(TTY::Spinner::CROSS)} Empty script found. Ignoring."
      return
    end

    unless opts.include?("nospin")
      spinner = TTY::Spinner.new("#{indent_to_s}:spinner :task_name", success_mark: @pastel.green(TTY::Spinner::TICK), error_mark: @pastel.red(TTY::Spinner::CROSS), hide_cursor: true)
      spinner.update(task_name: task_name)
      spinner.auto_spin
    end

    cmd = TTY::Command.new(output: logger, color: false)

    begin

      err = []

      result = if mode == "ruby" && opts.include?("rundown")
        logger << "Running in-process ruby code\n"
        logger << script + "\n"

        case run_ruby(script)
        when true 
          true
        when false 
          false
        else
          true
        end
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
          spinner && spinner.stop(@pastel.dim("(Not required)"))
          @heading_history << @pastel.dim("-")
          @break_to_next_heading = true
          logger << "Script failure with skip_on_failure, skipping to next heading\n"
        else
          spinner && spinner.success(@pastel.dim("(Done)"))
          @heading_history << @pastel.bright_green(".")
        end
      elsif opts.include?("skip_on_success")
        if result == true
          spinner && spinner.stop(@pastel.dim("(Not required)"))
          @heading_history << @pastel.dim("-")
          @break_to_next_heading = true
          logger << "Script success with skip_on_success, skipping to next heading\n"
        else
          spinner && spinner.success(@pastel.dim("(Done)"))
          @heading_history << @pastel.bright_green(".")
        end
      else
        if result
          spinner && spinner.success(@pastel.dim("(Done)"))
          @heading_history << @pastel.bright_green(".")
        else
          spinner && spinner.error(@pastel.dim("(Failed)"))

          logger << "Script failed. Aborting.\n"
          @heading_history << @pastel.red("x")
          # puts_indented "#{@heading_history.join(' ')}\r"

          puts "\n\n"

          puts @pastel.red.bold("Error Running Script")
          puts @pastel.dim(script)
          puts "\n\n"

          puts @pastel.red(err.join("\n"))

          puts "\n"
          puts "Check the log file at #{@log_file} for more details."

          puts "\n❌ Failed/Aborted.\n\n"

          exit(-1)
        end  
      end

    ensure
      temp&.close(true)
      spinner && spinner.stop
    end

    # print_indented "#{@heading_history.join(' ')}\r"
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
      puts "\n" if @last_block_code

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
      # Hack, as codespan is rendered to yellow, if the terminal background is white then it's really hard to read.
      fix_hardcoded_yellow_on_white(line.join).split("\n")
    end.flatten
  end

  def fix_hardcoded_yellow_on_white(string)
    new_code_start, new_code_end = @pastel.bright_yellow.on_black(" ").split(" ")

    # Super hacky, but TTY hardcodes the colour
    string.gsub("\e[38;5;230m", new_code_start).gsub("\e[39m", "\e[39;0;0m")
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

  desc "preview [FILENAME]", "Previews a markdown file in the terminal"
  def preview(filename)
    puts TTY::Markdown.parse_file(filename, { theme: Rundown::THEME })
    exit(0)
  end

  desc "[FILENAME]", "Executes a markdown file."
  option :log
  def execute(script_file)
    begin
      rundown = Rundown.new(script_file, options["log"])
      rundown.run
      puts "\n✅ Finished.\n"
      rundown.logger << "Runbook finished.\n"
      exit(0)
    rescue Interrupt
      rundown.logger << "Runbook aborted by user.\n"
      puts Pastel.new.red("\n❌ User Aborted")
      exit(1)
    rescue Errno::ENOENT
      puts Pastel.new.red("#{script_file} not found.")
      exit(2)
    end
  end
end

args = ARGV.dup
args.unshift("execute") unless (args & (CLI.printable_commands + ["help"])).length > 0 && args.length > 0

CLI.start(args)
